import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/customer.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SalesOrderSummary> get _orders => widget.services.customers.searchOrders(_search.text, 1000);

  Future<void> _openOrder(int orderId) async {
    await showSalesOrderDialog(context, services: widget.services, orderId: orderId);
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
          Expanded(child: Text('Ordini / Vendite', style: Theme.of(context).textTheme.headlineMedium)),
          Text('${orders.length} ${orders.length == 1 ? 'vendita' : 'vendite'}'),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
            labelText: 'Cerca ordine o vendita',
            hintText: 'Numero ordine, cliente, CF, prodotto, SKU o barcode',
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('Totale risultati: ${formatMoney(total)}'),
          const Spacer(),
          if (_search.text.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _search.clear();
                setState(() {});
              },
              icon: const Icon(Icons.close),
              label: const Text('Azzera ricerca'),
            ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: orders.isEmpty
                ? const Center(child: Text('Nessuna vendita trovata.'))
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final local = order.createdAtUtc.toLocal();
                      final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
                          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                      final customer = order.customerDisplayName?.trim();
                      final fiscal = order.customerFiscalCode?.trim();
                      final customerText = customer?.isNotEmpty == true
                          ? '$customer${fiscal?.isNotEmpty == true ? ' · $fiscal' : ''}'
                          : 'Vendita senza cliente';
                      return ListTile(
                        leading: Icon(order.hasReceipt ? Icons.receipt_long : Icons.shopping_bag_outlined),
                        title: Row(children: [
                          Expanded(child: Text(order.orderNumber)),
                          Text(order.totalDisplay, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        subtitle: Text('$date · $customerText · ${order.itemCount} ${order.itemCount == 1 ? 'articolo' : 'articoli'}'
                            '${order.hasReceipt ? ' · scontrino salvato' : ''}'),
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
