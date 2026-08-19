import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../l10n/app_strings.dart';
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

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  SalesOrderDetail? get _detail =>
      widget.services.customers.getOrder(widget.orderId);

  Future<void> _attachReceipt() async {
    final types = XTypeGroup(
      label: _itEn('Scontrino', 'Receipt'),
      extensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: [types]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    try {
      widget.services.customers.attachReceipt(widget.orderId, file.name, bytes);
      setState(() => _status = _itEn(
            'Scontrino salvato nel database.',
            'Receipt saved in the database.',
          ));
    } catch (error) {
      setState(() => _status = _itEn(
            'Impossibile allegare lo scontrino: $error',
            'Unable to attach receipt: $error',
          ));
    }
  }

  Future<void> _saveReceipt() async {
    final receipt = widget.services.customers.getReceipt(widget.orderId);
    if (receipt == null) return;
    final location = await getSaveLocation(suggestedName: receipt.filename);
    if (location == null) return;
    await File(location.path).writeAsBytes(receipt.bytes, flush: true);
    if (!mounted) return;
    setState(() => _status = _itEn(
          'Scontrino esportato in ${location.path}.',
          'Receipt exported to ${location.path}.',
        ));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return AlertDialog(
        content: Text(_itEn('Ordine non trovato.', 'Order not found.')),
      );
    }
    final order = detail.summary;
    final percent = order.orderDiscountBasisPoints / 100;
    final date = formatLocalDateTime(order.createdAtUtc);
    final customer = order.customerDisplayName?.trim();
    final fiscalCode = order.customerFiscalCode?.trim();

    return AlertDialog(
      title: Text(order.orderNumber),
      content: SizedBox(
        width: 780,
        height: 590,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 20, runSpacing: 6, children: [
            Text('${_itEn('Data', 'Date')}: $date'),
            Text(
              customer?.isNotEmpty == true
                  ? '${_itEn('Cliente', 'Customer')}: $customer'
                  : _itEn('Vendita senza cliente', 'Sale without customer'),
            ),
            if (fiscalCode?.isNotEmpty == true)
              Text('${_itEn('CF', 'Tax code')}: $fiscalCode'),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 20, runSpacing: 6, children: [
            Text('${_itEn('Lordo', 'Gross')}: ${formatMoney(order.grossTotalCents)}'),
            if (order.itemDiscountCents > 0)
              Text(
                '${AppStrings.t('item_discounts')}: −${formatMoney(order.itemDiscountCents)}',
              ),
            if (order.orderPercentDiscountCents > 0)
              Text(
                '${AppStrings.t('discount_amount')} ${_percentText(percent)}%: −${formatMoney(order.orderPercentDiscountCents)}',
              ),
            if (order.fixedDiscountCents > 0)
              Text(
                '${AppStrings.t('fixed_discounts')}: −${formatMoney(order.fixedDiscountCents)}',
              ),
            Text(
              '${_itEn('Pagato', 'Paid')}: ${formatMoney(order.finalTotalCents)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
                  subtitle: Text(
                    '${item.variantDisplay} · SKU ${item.sku}'
                    '${item.barcode == null ? '' : ' · ${item.barcode}'}\n'
                    '${item.quantity} × ${formatMoney(item.unitPriceCents)}'
                    '${item.discountBasisPoints == 0 ? '' : ' · ${_itEn('sconto', 'discount')} ${_percentText(itemDiscount)}%'}',
                  ),
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
                order.hasReceipt
                    ? '${_itEn('Scontrino', 'Receipt')}: ${order.receiptFilename}'
                    : _itEn(
                        'Nessuno scontrino allegato.',
                        'No receipt attached.',
                      ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _attachReceipt,
              icon: const Icon(Icons.attach_file),
              label: Text(
                order.hasReceipt
                    ? _itEn('Sostituisci', 'Replace')
                    : _itEn('Allega scontrino', 'Attach receipt'),
              ),
            ),
            if (order.hasReceipt) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveReceipt,
                icon: const Icon(Icons.save_alt),
                label: Text(_itEn('Esporta', 'Export')),
              ),
            ],
          ]),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.t('close')),
        ),
      ],
    );
  }

  static String _percentText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');
}
