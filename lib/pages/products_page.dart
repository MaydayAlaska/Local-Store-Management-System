import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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
          Expanded(
            child: Text(
              AppStrings.t('products'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          FilledButton.icon(
            onPressed: () => _open(),
            icon: const Icon(Icons.add),
            label: Text(AppStrings.t('new_product')),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            labelText: AppStrings.isEnglish
                ? 'Search name, SKU, barcode, brand or category'
                : 'Cerca nome, SKU, barcode, marca o categoria',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: products.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.isEnglish ? 'No products.' : 'Nessun prodotto.',
                    ),
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final noBrand = AppStrings.isEnglish ? 'No brand' : 'Senza marca';
                      final noCategory =
                          AppStrings.isEnglish ? 'No category' : 'Senza categoria';
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.brand ?? noBrand} · ${product.category ?? noCategory} · ${product.variantCountDisplay}',
                        ),
                        leading: CircleAvatar(child: Text('${product.stockQuantity}')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(product.salePriceDisplay),
                          const SizedBox(width: 16),
                          Icon(
                            product.isActive
                                ? Icons.check_circle
                                : Icons.pause_circle_outline,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ]),
                        onTap: () => _open(product),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
