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

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final total = orders.fold<int>(0, (sum, order) => sum + order.finalTotalCents);
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
              'Numero ordine, cliente, CF oppure prodotto + attributi (es. Maglietta Blu M)',
              'Order number, customer, tax code or product + attributes (e.g. Shirt Blue M)',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text(
            '${_itEn('Totale risultati', 'Results total')}: ${formatMoney(total)}',
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
                      final customerText = customer?.isNotEmpty == true
                          ? '$customer${fiscal?.isNotEmpty == true ? ' · $fiscal' : ''}'
                          : _itEn('Vendita senza cliente', 'Sale without customer');
                      return ListTile(
                        leading: Icon(
                          order.hasReceipt
                              ? Icons.receipt_long
                              : Icons.shopping_bag_outlined,
                        ),
                        title: Row(children: [
                          Expanded(child: Text(order.orderNumber)),
                          Text(
                            order.totalDisplay,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ]),
                        subtitle: Text(
                          '$date · $customerText · ${order.itemCount} ${AppStrings.t(order.itemCount == 1 ? 'item' : 'items')}'
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
