import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../repositories/sales_order_search.dart';
import '../services/app_services.dart';
import '../services/birth_place_service.dart';
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
  late String _status;

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void initState() {
    super.initState();
    _status = _itEn(
      'Scansiona una Tessera Sanitaria oppure cerca un cliente.',
      'Scan a health card / tax code or search for a customer.',
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Customer> get _customers =>
      widget.services.customers.search(_search.text, 500);

  Future<void> _scan(String raw) async {
    final data = FiscalCodeService.tryParse(raw);
    if (data == null) {
      setState(() => _status = _itEn(
            'La scansione non contiene un codice fiscale valido.',
            'The scan does not contain a valid tax code.',
          ));
      return;
    }
    final existing = widget.services.customers.findByFiscalCode(data.fiscalCode);
    if (existing != null) {
      setState(() {
        _selected = existing;
        _status = _itEn(
          'Cliente trovato: ${existing.displayName}.',
          'Customer found: ${existing.displayName}.',
        );
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
      _status = _itEn(
        'Cliente ${created.displayName} registrato.',
        'Customer ${created.displayName} registered.',
      );
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
      _status = _itEn(
        'Cliente ${created.displayName} registrato.',
        'Customer ${created.displayName} registered.',
      );
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
      _status = _itEn('Dati cliente aggiornati.', 'Customer details updated.');
    });
  }

  Future<void> _deleteCustomer() async {
    final selected = _selected;
    if (selected == null) return;
    final orders = widget.services.customers.ordersForCustomer(selected.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_itEn('Eliminare il cliente?', 'Delete customer?')),
        content: Text(
          orders.isEmpty
              ? _itEn(
                  'Vuoi eliminare definitivamente ${selected.displayName} (${selected.fiscalCode})?',
                  'Do you want to permanently delete ${selected.displayName} (${selected.fiscalCode})?',
                )
              : _itEn(
                  'Vuoi eliminare definitivamente ${selected.displayName} (${selected.fiscalCode})?\n\n'
                  'I ${orders.length} ordini associati resteranno nello storico Vendite con nome e codice fiscale memorizzati, ma non saranno più collegati a un cliente attivo.',
                  'Do you want to permanently delete ${selected.displayName} (${selected.fiscalCode})?\n\n'
                  'The ${orders.length} linked orders will remain in Sales history with the stored name and tax code, but will no longer be linked to an active customer.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppStrings.t('cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: Text(_itEn('Elimina cliente', 'Delete customer')),
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
            ? _itEn(
                'Cliente ${selected.displayName} eliminato. Lo storico vendite è stato conservato.',
                'Customer ${selected.displayName} deleted. Sales history was preserved.',
              )
            : _itEn('Il cliente non esiste più.', 'The customer no longer exists.');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _itEn(
            'Impossibile eliminare il cliente: $error',
            'Unable to delete customer: $error',
          ));
    }
  }

  Future<void> _openOrder(int orderId) async {
    await showSalesOrderDialog(
      context,
      services: widget.services,
      orderId: orderId,
    );
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
            Expanded(
              child: Text(
                AppStrings.t('customers'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: _newCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_itEn('Nuovo cliente', 'New customer')),
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
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          labelText: AppStrings.t('search_customer'),
                          hintText: _itEn(
                            'Nome, cognome o codice fiscale',
                            'First name, last name or tax code',
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: customers.isEmpty
                          ? Center(
                              child: Text(
                                _itEn(
                                  'Nessun cliente trovato.',
                                  'No customers found.',
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: customers.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = customers[index];
                                return ListTile(
                                  selected: selected?.id == customer.id,
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline),
                                  ),
                                  title: Text(customer.displayName),
                                  subtitle: Text(customer.fiscalCode),
                                  onTap: () =>
                                      setState(() => _selected = customer),
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
                    ? Card(
                        child: Center(
                          child: Text(
                            _itEn(
                              'Seleziona un cliente oppure scansiona la Tessera Sanitaria.',
                              'Select a customer or scan the health card / tax code.',
                            ),
                          ),
                        ),
                      )
                    : _CustomerDetail(
                        key: ValueKey(selected.id),
                        customer: selected,
                        repository: widget.services.customers,
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

class _CustomerDetail extends StatefulWidget {
  const _CustomerDetail({
    super.key,
    required this.customer,
    required this.repository,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenOrder,
  });

  final Customer customer;
  final CustomerRepository repository;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onOpenOrder;

  @override
  State<_CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<_CustomerDetail> {
  final _historySearch = TextEditingController();

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void dispose() {
    _historySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.repository.ordersForCustomer(widget.customer.id);
    final visibleOrders = widget.repository.ordersForCustomerMatching(
      widget.customer.id,
      _historySearch.text,
    );
    final spent = orders.fold<int>(0, (sum, order) => sum + order.finalTotalCents);
    final hasFilter = _historySearch.text.trim().isNotEmpty;
    final birthPlaceName = BirthPlaceService.resolve(
      widget.customer.birthPlaceCode,
      widget.customer.birthDate,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(
                  widget.customer.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(_itEn('Modifica', 'Edit')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(_itEn('Elimina', 'Delete')),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 22, runSpacing: 8, children: [
              Text('${_itEn('CF', 'Tax code')}: ${widget.customer.fiscalCode}'),
              Text('${_itEn('Nascita', 'Birth date')}: ${widget.customer.birthDateDisplay}'),
              Text('${_itEn('Sesso', 'Sex')}: ${widget.customer.sex}'),
              Text(
                '${_itEn('Luogo di nascita', 'Birth place')}: '
                '${birthPlaceName ?? _itEn('Non disponibile', 'Not available')}',
              ),
            ]),
            if (widget.customer.notes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('${AppStrings.t('notes')}: ${widget.customer.notes}'),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 26, children: [
              Text(
                '${orders.length} ${_itEn(orders.length == 1 ? 'acquisto' : 'acquisti', orders.length == 1 ? 'purchase' : 'purchases')}',
              ),
              Text(
                '${_itEn('Totale storico', 'History total')}: ${formatMoney(spent)}',
              ),
            ]),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Expanded(
              child: Text(
                _itEn('Storico acquisti', 'Purchase history'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (hasFilter)
              Text(
                '${visibleOrders.length} ${_itEn(visibleOrders.length == 1 ? 'risultato' : 'risultati', visibleOrders.length == 1 ? 'result' : 'results')}',
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _historySearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              labelText: _itEn(
                'Cerca prodotto nello storico',
                'Search product in history',
              ),
              hintText: _itEn(
                'Nome e attributi, es. Maglietta Blu M',
                'Name and attributes, e.g. Shirt Blue M',
              ),
              suffixIcon: hasFilter
                  ? IconButton(
                      tooltip: _itEn('Azzera ricerca', 'Clear search'),
                      onPressed: () {
                        _historySearch.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: visibleOrders.isEmpty
              ? Center(
                  child: Text(
                    hasFilter
                        ? _itEn(
                            'Nessun acquisto contiene un prodotto con questi attributi.',
                            'No purchase contains a product with these attributes.',
                          )
                        : _itEn(
                            'Nessun acquisto registrato per questo cliente.',
                            'No purchases recorded for this customer.',
                          ),
                  ),
                )
              : ListView.separated(
                  itemCount: visibleOrders.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = visibleOrders[index];
                    final date = formatLocalDateTime(order.createdAtUtc);
                    return ListTile(
                      leading: Icon(
                        order.hasReceipt
                            ? Icons.receipt_long
                            : Icons.shopping_bag_outlined,
                      ),
                      title: Text('${order.orderNumber} · ${order.totalDisplay}'),
                      subtitle: Text(
                        '$date · ${order.itemCount} ${AppStrings.t(order.itemCount == 1 ? 'item' : 'items')}'
                        '${order.hasReceipt ? _itEn(' · scontrino salvato', ' · receipt saved') : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenOrder(order.id),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
