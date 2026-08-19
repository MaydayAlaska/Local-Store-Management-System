import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/customer.dart';
import '../services/app_services.dart';
import '../services/fiscal_code_service.dart';
import '../widgets/hid_barcode_listener.dart';
import 'customer_editor_dialog.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.services, required this.isActive});

  final AppServices services;
  final bool isActive;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
  Customer? _selected;
  String _status = 'Scansiona una Tessera Sanitaria oppure cerca un cliente.';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Customer> get _customers => widget.services.customers.search(_search.text, 500);

  Future<void> _scan(String raw) async {
    final data = FiscalCodeService.tryParse(raw);
    if (data == null) {
      setState(() => _status = 'La scansione non contiene un codice fiscale valido.');
      return;
    }
    final existing = widget.services.customers.findByFiscalCode(data.fiscalCode);
    if (existing != null) {
      setState(() {
        _selected = existing;
        _status = 'Cliente trovato: ${existing.displayName}.';
      });
      return;
    }

    final created = await showCustomerEditorDialog(
      context,
      repository: widget.services.customers,
      scanned: data,
    );
    if (!mounted || created == null) return;
    setState(() {
      _selected = created;
      _status = 'Cliente ${created.displayName} registrato.';
    });
  }

  Future<void> _newCustomer() async {
    final created = await showCustomerEditorDialog(
      context,
      repository: widget.services.customers,
    );
    if (!mounted || created == null) return;
    setState(() {
      _selected = created;
      _status = 'Cliente ${created.displayName} registrato.';
    });
  }

  Future<void> _editCustomer() async {
    final selected = _selected;
    if (selected == null) return;
    final updated = await showCustomerEditorDialog(
      context,
      repository: widget.services.customers,
      customer: selected,
    );
    if (!mounted || updated == null) return;
    setState(() {
      _selected = updated;
      _status = 'Dati cliente aggiornati.';
    });
  }

  Future<void> _openOrder(int orderId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _OrderDialog(services: widget.services, orderId: orderId),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;
    final selected = _selected;
    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: (value) => _scan(value),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Clienti', style: Theme.of(context).textTheme.headlineMedium)),
            FilledButton.icon(
              onPressed: _newCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuovo cliente'),
            ),
          ]),
          const SizedBox(height: 12),
          Text(_status),
          const SizedBox(height: 12),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 390,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Cerca cliente',
                          hintText: 'Nome, cognome o codice fiscale',
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: customers.isEmpty
                          ? const Center(child: Text('Nessun cliente trovato.'))
                          : ListView.separated(
                              itemCount: customers.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = customers[index];
                                return ListTile(
                                  selected: selected?.id == customer.id,
                                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                                  title: Text(customer.displayName),
                                  subtitle: Text(customer.fiscalCode),
                                  onTap: () => setState(() => _selected = customer),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: selected == null
                    ? const Card(
                        child: Center(
                          child: Text('Seleziona un cliente oppure scansiona la Tessera Sanitaria.'),
                        ),
                      )
                    : _CustomerDetail(
                        customer: selected,
                        orders: widget.services.customers.ordersForCustomer(selected.id),
                        onEdit: _editCustomer,
                        onOpenOrder: _openOrder,
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CustomerDetail extends StatelessWidget {
  const _CustomerDetail({
    required this.customer,
    required this.orders,
    required this.onEdit,
    required this.onOpenOrder,
  });

  final Customer customer;
  final List<SalesOrderSummary> orders;
  final VoidCallback onEdit;
  final ValueChanged<int> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final spent = orders.fold<int>(0, (sum, order) => sum + order.finalTotalCents);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(customer.displayName, style: Theme.of(context).textTheme.headlineSmall)),
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Modifica')),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 22, runSpacing: 8, children: [
              Text('CF: ${customer.fiscalCode}'),
              Text('Nascita: ${customer.birthDateDisplay}'),
              Text('Sesso: ${customer.sex}'),
              Text('Codice luogo: ${customer.birthPlaceCode}'),
            ]),
            if (customer.notes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Note: ${customer.notes}'),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 26, children: [
              Text('${orders.length} ${orders.length == 1 ? 'acquisto' : 'acquisti'}'),
              Text('Totale storico: ${formatMoney(spent)}'),
            ]),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('Storico acquisti', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('Nessun acquisto registrato per questo cliente.'))
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final local = order.createdAtUtc.toLocal();
                    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
                        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: Icon(order.hasReceipt ? Icons.receipt_long : Icons.shopping_bag_outlined),
                      title: Text('${order.orderNumber} · ${order.totalDisplay}'),
                      subtitle: Text('$date · ${order.itemCount} ${order.itemCount == 1 ? 'articolo' : 'articoli'}'
                          '${order.hasReceipt ? ' · scontrino salvato' : ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpenOrder(order.id),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

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
    return AlertDialog(
      title: Text(order.orderNumber),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
}
