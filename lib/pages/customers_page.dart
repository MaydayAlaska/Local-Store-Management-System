import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/customer.dart';
import '../services/app_services.dart';
import '../services/fiscal_code_service.dart';
import '../widgets/hid_barcode_listener.dart';
import 'customer_editor_dialog.dart';
import 'order_dialog.dart';

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

  Future<void> _deleteCustomer() async {
    final selected = _selected;
    if (selected == null) return;
    final orders = widget.services.customers.ordersForCustomer(selected.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare il cliente?'),
        content: Text(
          orders.isEmpty
              ? 'Vuoi eliminare definitivamente ${selected.displayName} (${selected.fiscalCode})?'
              : 'Vuoi eliminare definitivamente ${selected.displayName} (${selected.fiscalCode})?\n\n'
                  'I ${orders.length} ordini associati resteranno nello storico Vendite con nome e codice fiscale memorizzati, ma non saranno più collegati a un cliente attivo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annulla')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Elimina cliente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final deleted = widget.services.customers.deleteCustomer(selected.id);
      if (!mounted) return;
      setState(() {
        _selected = null;
        _status = deleted
            ? 'Cliente ${selected.displayName} eliminato. Lo storico vendite è stato conservato.'
            : 'Il cliente non esiste più.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Impossibile eliminare il cliente: $error');
    }
  }

  Future<void> _openOrder(int orderId) async {
    await showSalesOrderDialog(context, services: widget.services, orderId: orderId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;
    final selected = _selected;
    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _scan,
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
                        onSubmitted: _scan,
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
                        child: Center(child: Text('Seleziona un cliente oppure scansiona la Tessera Sanitaria.')),
                      )
                    : _CustomerDetail(
                        customer: selected,
                        orders: widget.services.customers.ordersForCustomer(selected.id),
                        onEdit: _editCustomer,
                        onDelete: _deleteCustomer,
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
    required this.onDelete,
    required this.onOpenOrder,
  });

  final Customer customer;
  final List<SalesOrderSummary> orders;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
              ),
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
