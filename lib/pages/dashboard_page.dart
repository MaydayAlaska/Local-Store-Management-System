import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../models/catalog.dart';
import '../models/stock.dart';
import '../services/app_services.dart';
import 'product_editor_dialog.dart';

enum _ScanMode { search, incoming, outgoing }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.services});
  final AppServices services;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  _ScanMode _mode = _ScanMode.search;
  String _status = 'Scanner HID pronto.';

  List<ProductVariant> get _results => widget.services.products.search(_search.text).take(50).toList();

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    final product = widget.services.products.findByBarcode(code);
    try {
      if (product == null) {
        if (_mode == _ScanMode.search) {
          await showDialog<bool>(
            context: context,
            builder: (_) => ProductEditorDialog(services: widget.services, initialBarcode: code),
          );
          setState(() => _status = 'Codice non presente: creazione prodotto aperta.');
        } else {
          setState(() => _status = 'Nessun prodotto trovato per «$code».');
        }
      } else if (_mode == _ScanMode.incoming) {
        widget.services.stock.addMovement(product.id, StockMovementKind.incoming, 1, 'Carico rapido da scanner');
        setState(() => _status = '${product.name}: caricato +1.');
      } else if (_mode == _ScanMode.outgoing) {
        widget.services.stock.addMovement(product.id, StockMovementKind.outgoing, 1, 'Scarico rapido da scanner');
        setState(() => _status = '${product.name}: scaricato -1.');
      } else {
        await _editProduct(product.productId);
      }
    } catch (error) {
      setState(() => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
    _search.clear();
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _editProduct(int productId) async {
    final summary = widget.services.products.getProduct(productId);
    if (summary == null) return;
    await showDialog<bool>(context: context, builder: (_) => ProductEditorDialog(services: widget.services, product: summary));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.count();
    final stock = widget.services.stock.getTotalStock();
    final results = _results;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricCard(label: 'Prodotti', value: '$products', icon: Icons.inventory_2),
            _MetricCard(label: 'Pezzi a magazzino', value: '$stock', icon: Icons.warehouse),
          ]),
          const SizedBox(height: 20),
          SegmentedButton<_ScanMode>(
            segments: const [
              ButtonSegment(value: _ScanMode.search, icon: Icon(Icons.search), label: Text('Cerca / apri')),
              ButtonSegment(value: _ScanMode.incoming, icon: Icon(Icons.add), label: Text('Carico rapido +1')),
              ButtonSegment(value: _ScanMode.outgoing, icon: Icon(Icons.remove), label: Text('Scarico rapido -1')),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            focusNode: _focus,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: _submit,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
              labelText: 'Scansiona barcode/SKU o cerca per nome',
              hintText: 'Lo scanner HID termina con Invio',
            ),
          ),
          const SizedBox(height: 8),
          Text(_status),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: results.isEmpty
                  ? const Center(child: Text('Nessun prodotto trovato.'))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${item.stockQuantity}')),
                          title: Text(item.name),
                          subtitle: Text('${item.variantDisplay} · SKU ${item.sku} · ${item.barcode ?? 'nessun barcode'}'),
                          trailing: Text(item.salePriceDisplay),
                          onTap: () => _editProduct(item.productId),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Database: ${AppPaths.databasePath}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 30),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label),
              ]),
            ]),
          ),
        ),
      );
}
