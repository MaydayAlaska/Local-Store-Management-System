import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/sales_order_search.dart';
import '../services/app_services.dart';
import 'order_dialog.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.services});

  final AppServices services;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrderAgeSelection {
  const _OrderAgeSelection(this.amount, this.unit);

  final int amount;
  final String unit;
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SalesOrderSummary> get _orders =>
      widget.services.customers.searchOrdersMatching(_search.text, 1000);

  Future<void> _openOrder(int orderId) async {
    await showSalesOrderDialog(
      context,
      services: widget.services,
      orderId: orderId,
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteOldOrders() async {
    final amountController = TextEditingController(text: '30');
    var unit = 'days';
    String? validationError;

    final selection = await showDialog<_OrderAgeSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text(_itEn('Elimina ordini vecchi', 'Delete old orders')),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _itEn(
                      'Elimina definitivamente gli ordini più vecchi dell’intervallo indicato. Questa operazione non modifica né il magazzino né il credito dei buoni regalo.',
                      'Permanently delete orders older than the selected interval. This operation changes neither stock nor gift-card credit.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _itEn('Quantità', 'Amount'),
                          errorText: validationError,
                        ),
                        onChanged: (_) {
                          if (validationError != null) {
                            setDialogState(() => validationError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        dropdownColor: theme.canvasColor,
                        borderRadius: BorderRadius.circular(16),
                        iconEnabledColor: theme.colorScheme.onSurfaceVariant,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _itEn('Unità', 'Unit'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'days',
                            child: Text(_itEn('Giorni', 'Days')),
                          ),
                          DropdownMenuItem(
                            value: 'months',
                            child: Text(_itEn('Mesi', 'Months')),
                          ),
                          DropdownMenuItem(
                            value: 'years',
                            child: Text(_itEn('Anni', 'Years')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => unit = value);
                        },
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_itEn('Annulla', 'Cancel')),
              ),
              FilledButton.icon(
                onPressed: () {
                  final amount = int.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    setDialogState(() => validationError = _itEn(
                          'Inserisci un numero maggiore di zero.',
                          'Enter a number greater than zero.',
                        ));
                    return;
                  }
                  Navigator.of(dialogContext)
                      .pop(_OrderAgeSelection(amount, unit));
                },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(_itEn('Continua', 'Continue')),
              ),
            ],
          );
        },
      ),
    );
    amountController.dispose();
    if (selection == null || !mounted) return;

    final cutoffLocal =
        _subtractAge(DateTime.now(), selection.amount, selection.unit);
    final cutoffUtc = cutoffLocal.toUtc();
    final count = widget.services.customers.countOrdersOlderThan(cutoffUtc);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_itEn(
            'Nessun ordine rientra nell’intervallo selezionato.',
            'No orders match the selected age.',
          )),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_itEn('Conferma eliminazione', 'Confirm deletion')),
            content: Text(
              _itEn(
                'Verranno eliminati definitivamente $count ordini creati prima del ${formatLocalDateTime(cutoffUtc)}. Gli articoli NON verranno riaggiunti al magazzino e l’eventuale credito usato dai buoni NON verrà restituito.',
                '$count orders created before ${formatLocalDateTime(cutoffUtc)} will be permanently deleted. Items will NOT be returned to stock and any gift-card credit used will NOT be restored.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_itEn('Annulla', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_itEn('Elimina definitivamente', 'Delete permanently')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final deleted = widget.services.customers.deleteOrdersOlderThan(cutoffUtc);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_itEn(
          '$deleted ordini eliminati. Magazzino e buoni regalo non sono stati modificati.',
          '$deleted orders deleted. Stock and gift cards were not changed.',
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final total = orders
        .where((order) => !order.isCancelled)
        .fold<int>(0, (sum, order) => sum + order.finalTotalCents);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              _itEn('Ordini / Vendite', 'Orders / Sales'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _deleteOldOrders,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(_itEn('Elimina ordini vecchi', 'Delete old orders')),
          ),
          const SizedBox(width: 14),
          Text(
            '${orders.length} ${_itEn(orders.length == 1 ? 'vendita' : 'vendite', orders.length == 1 ? 'sale' : 'sales')}',
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            labelText: _itEn('Cerca ordine o vendita', 'Search order or sale'),
            hintText: _itEn(
              'Numero ordine, codice cliente, cliente, CF, buono regalo oppure prodotto + attributi',
              'Order number, customer code, customer, tax code, gift card or product + attributes',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text(
            '${_itEn('Totale vendite attive nei risultati', 'Active sales total in results')}: ${formatMoney(total)}',
          ),
          const Spacer(),
          if (_search.text.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _search.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close),
              label: Text(_itEn('Azzera ricerca', 'Clear search')),
            ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: orders.isEmpty
                ? Center(
                    child: Text(
                      _itEn('Nessuna vendita trovata.', 'No sales found.'),
                    ),
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final date = formatLocalDateTime(order.createdAtUtc);
                      final customer = order.customerDisplayName?.trim();
                      final fiscal = order.customerFiscalCode?.trim();
                      final code = order.customerCode == null
                          ? null
                          : 'CLI-${order.customerCode!.toString().padLeft(6, '0')}';
                      final customerText = customer?.isNotEmpty == true
                          ? '${code == null ? '' : '$code · '}$customer'
                              '${fiscal?.isNotEmpty == true ? ' · CF $fiscal' : ''}'
                          : _itEn(
                              'Vendita senza cliente',
                              'Sale without customer',
                            );
                      final errorColor = Theme.of(context).colorScheme.error;
                      return ListTile(
                        leading: Icon(
                          order.isCancelled
                              ? Icons.cancel_outlined
                              : order.hasReceipt
                                  ? Icons.receipt_long
                                  : Icons.shopping_bag_outlined,
                          color: order.isCancelled ? errorColor : null,
                        ),
                        title: Row(children: [
                          Expanded(child: Text(order.orderNumber)),
                          if (order.isCancelled) ...[
                            Text(
                              _itEn('ANNULLATO', 'CANCELLED'),
                              style: TextStyle(
                                color: errorColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          Text(
                            order.totalDisplay,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ]),
                        subtitle: Text(
                          '$date · $customerText · ${order.itemCount} ${AppStrings.t(order.itemCount == 1 ? 'item' : 'items')}'
                          '${order.hasGiftCard ? ' · ${_itEn('buono', 'gift card')} ${order.giftCardCode}: −${formatMoney(order.giftCardAppliedCents)}' : ''}'
                          '${order.hasReceipt ? _itEn(' · scontrino salvato', ' · receipt saved') : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openOrder(order.id),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

DateTime _subtractAge(DateTime value, int amount, String unit) {
  if (unit == 'days') return value.subtract(Duration(days: amount));

  if (unit == 'years') {
    final year = value.year - amount;
    final maxDay = DateTime(year, value.month + 1, 0).day;
    final day = value.day > maxDay ? maxDay : value.day;
    return DateTime(
      year,
      value.month,
      day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  final totalMonths = value.year * 12 + (value.month - 1) - amount;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  final day = value.day > maxDay ? maxDay : value.day;
  return DateTime(
    year,
    month,
    day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}
