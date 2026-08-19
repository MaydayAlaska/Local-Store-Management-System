import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/customer.dart';
import '../services/app_services.dart';

Future<void> showSalesOrderDialog(
  BuildContext context, {
  required AppServices services,
  required int orderId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _OrderDialog(services: services, orderId: orderId),
    );

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.services, required this.orderId});

  final AppServices services;
  final int orderId;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  String? _status;

  SalesOrderDetail? get _detail => widget.services.customers.getOrder(widget.orderId);

  Future<void> _attachReceipt() async {
    const types = XTypeGroup(
      label: 'Scontrino',
      extensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: const [types]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    try {
      widget.services.customers.attachReceipt(widget.orderId, file.name, bytes);
      setState(() => _status = 'Scontrino salvato nel database.');
    } catch (error) {
      setState(() => _status = 'Impossibile allegare lo scontrino: $error');
    }
  }

  Future<void> _saveReceipt() async {
    final receipt = widget.services.customers.getReceipt(widget.orderId);
    if (receipt == null) return;
    final location = await getSaveLocation(suggestedName: receipt.filename);
    if (location == null) return;
    await File(location.path).writeAsBytes(receipt.bytes, flush: true);
    if (!mounted) return;
    setState(() => _status = 'Scontrino esportato in ${location.path}.');
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return const AlertDialog(content: Text('Ordine non trovato.'));
    }
    final order = detail.summary;
    final percent = order.orderDiscountBasisPoints / 100;
    final local = order.createdAtUtc.toLocal();
    final date = _formatDateTime(local);
    final customer = order.customerDisplayName?.trim();
    final fiscalCode = order.customerFiscalCode?.trim();

    return AlertDialog(
      title: Text(order.orderNumber),
      content: SizedBox(
        width: 780,
        height: 590,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 20, runSpacing: 6, children: [
            Text('Data: $date'),
            Text(customer?.isNotEmpty == true ? 'Cliente: $customer' : 'Vendita senza cliente'),
            if (fiscalCode?.isNotEmpty == true) Text('CF: $fiscalCode'),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 20, runSpacing: 6, children: [
            Text('Lordo: ${formatMoney(order.grossTotalCents)}'),
            if (order.itemDiscountCents > 0) Text('Sconti articoli: −${formatMoney(order.itemDiscountCents)}'),
            if (order.orderPercentDiscountCents > 0)
              Text('Sconto totale ${_percentText(percent)}%: −${formatMoney(order.orderPercentDiscountCents)}'),
            if (order.fixedDiscountCents > 0) Text('Sconti fissi: −${formatMoney(order.fixedDiscountCents)}'),
            Text('Pagato: ${formatMoney(order.finalTotalCents)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: detail.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = detail.items[index];
                final itemDiscount = item.discountBasisPoints / 100;
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text('${item.variantDisplay} · SKU ${item.sku}'
                      '${item.barcode == null ? '' : ' · ${item.barcode}'}\n'
                      '${item.quantity} × ${formatMoney(item.unitPriceCents)}'
                      '${item.discountBasisPoints == 0 ? '' : ' · sconto ${_percentText(itemDiscount)}%'}'),
                  trailing: Text(formatMoney(item.finalTotalCents)),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                order.hasReceipt ? 'Scontrino: ${order.receiptFilename}' : 'Nessuno scontrino allegato.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _attachReceipt,
              icon: const Icon(Icons.attach_file),
              label: Text(order.hasReceipt ? 'Sostituisci' : 'Allega scontrino'),
            ),
            if (order.hasReceipt) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveReceipt,
                icon: const Icon(Icons.save_alt),
                label: const Text('Esporta'),
              ),
            ],
          ]),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Chiudi'))],
    );
  }

  static String _percentText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');

  static String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
