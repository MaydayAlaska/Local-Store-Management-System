import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../services/app_services.dart';
import 'product_editor_dialog.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.services});
  final AppServices services;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open([ProductSummary? product]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditorDialog(services: widget.services, product: product),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.searchProducts(_search.text);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Prodotti', style: Theme.of(context).textTheme.headlineMedium)),
          FilledButton.icon(onPressed: () => _open(), icon: const Icon(Icons.add), label: const Text('Nuovo prodotto')),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.search), labelText: 'Cerca nome, SKU, barcode, marca o categoria'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: products.isEmpty
                ? const Center(child: Text('Nessun prodotto.'))
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.brand ?? 'Senza marca'} · ${p.category ?? 'Senza categoria'} · ${p.variantCountDisplay}'),
                        leading: CircleAvatar(child: Text('${p.stockQuantity}')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(p.salePriceDisplay),
                          const SizedBox(width: 16),
                          Icon(p.isActive ? Icons.check_circle : Icons.pause_circle_outline),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ]),
                        onTap: () => _open(p),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
