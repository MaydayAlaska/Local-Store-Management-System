import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/catalog.dart';
import '../repositories/product_deletion.dart';
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

  Future<void> _deleteProduct(ProductSummary product) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              AppStrings.pair(
                'Eliminare definitivamente il prodotto?',
                'Permanently delete product?',
              ),
            ),
            content: Text(
              AppStrings.pair(
                'Vuoi eliminare definitivamente «${product.name}» e tutte le sue ${product.variantCount} varianti?\n\n'
                    'Verranno eliminati anche barcode, immagini e movimenti di magazzino collegati alle varianti. '
                    'Le righe delle vendite già registrate resteranno nello storico come dati salvati, ma non saranno più collegate alle varianti eliminate.\n\n'
                    'Questa operazione non può essere annullata.',
                'Do you want to permanently delete “${product.name}” and all ${product.variantCount} variants?\n\n'
                    'Barcodes, images, and stock movements linked to those variants will also be deleted. '
                    'Already recorded sales lines will remain in history as stored snapshots, but will no longer be linked to the deleted variants.\n\n'
                    'This action cannot be undone.',
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
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  AppStrings.pair(
                    'Elimina definitivamente',
                    'Delete permanently',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      final deleted = widget.services.products.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? AppStrings.pair(
                    'Prodotto «${product.name}» e tutte le sue varianti eliminati definitivamente.',
                    'Product “${product.name}” and all its variants permanently deleted.',
                  )
                : AppStrings.pair(
                    'Il prodotto non esiste più.',
                    'The product no longer exists.',
                  ),
          ),
        ),
      );
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.pair(
              'Impossibile eliminare il prodotto: $error',
              'Unable to delete the product: $error',
            ),
          ),
        ),
      );
    }
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
            labelText: AppStrings.pair(
              'Cerca nome, SKU, barcode, marca o categoria',
              'Search name, SKU, barcode, brand or category',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: products.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.pair('Nessun prodotto.', 'No products.'),
                    ),
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final noBrand = AppStrings.pair('Senza marca', 'No brand');
                      final noCategory =
                          AppStrings.pair('Senza categoria', 'No category');
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
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: AppStrings.pair(
                              'Elimina prodotto e varianti',
                              'Delete product and variants',
                            ),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _deleteProduct(product),
                            icon: const Icon(Icons.delete_forever_outlined),
                          ),
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
