import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../models/catalog.dart';
import '../models/stock.dart';
import '../services/app_services.dart';
import '../widgets/hid_barcode_listener.dart';
import 'product_editor_dialog.dart';

enum _ScanMode { search, incoming, outgoing }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.services, required this.isActive});
  final AppServices services;
  final bool isActive;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  _ScanMode _mode = _ScanMode.search;
  String _status = 'Scanner HID pronto.';
  String? _scannedCode;
  ProductVariant? _scannedProduct;

  List<ProductVariant> get _results {
    final scanned = _scannedCode;
    if (scanned != null) {
      final exact = _scannedProduct;
      return exact == null ? const [] : [exact];
    }
    return widget.services.products.search(_search.text, 50);
  }

  bool get _scannedCodeIsMissing => _scannedCode != null && _scannedProduct == null;

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
      if (_mode == _ScanMode.search) {
        _search.text = code;
        setState(() {
          _scannedCode = code;
          _scannedProduct = product;
          _status = product == null
              ? 'Barcode «$code» non presente. Puoi aggiungerlo dall’elenco qui sotto.'
              : 'Trovato: ${product.name} · ${product.variantDisplay}.';
        });
      } else if (product == null) {
        _search.text = code;
        setState(() {
          _scannedCode = code;
          _scannedProduct = null;
          _status = 'Nessun prodotto trovato per «$code».';
        });
      } else if (_mode == _ScanMode.incoming) {
        widget.services.stock.addMovement(product.id, StockMovementKind.incoming, 1, 'Carico rapido da scanner');
        final latest = widget.services.products.getById(product.id) ?? product;
        _search.text = code;
        setState(() {
          _scannedCode = code;
          _scannedProduct = latest;
          _status = '${product.name}: caricato +1.';
        });
      } else {
        widget.services.stock.addMovement(product.id, StockMovementKind.outgoing, 1, 'Scarico rapido da scanner');
        final latest = widget.services.products.getById(product.id) ?? product;
        _search.text = code;
        setState(() {
          _scannedCode = code;
          _scannedProduct = latest;
          _status = '${product.name}: scaricato -1.';
        });
      }
    } catch (error) {
      setState(() => _status = error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _editProduct(int productId) async {
    final summary = widget.services.products.getProduct(productId);
    if (summary == null) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditorDialog(services: widget.services, product: summary),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addScannedBarcode(String code) async {
    final action = await showDialog<_BarcodeAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi articolo'),
        content: Text(
          'Il barcode $code non è presente nel database. Vuoi creare un nuovo articolo oppure aggiungerlo come nuova variante di un articolo esistente?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _BarcodeAction.existingProduct),
            icon: const Icon(Icons.library_add_outlined),
            label: const Text('Articolo esistente'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _BarcodeAction.newProduct),
            icon: const Icon(Icons.add),
            label: const Text('Nuovo articolo'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;

    if (action == _BarcodeAction.newProduct) {
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProductEditorDialog(services: widget.services, initialBarcode: code),
      );
      if (changed == true && mounted) {
        _refreshAfterBarcodeAssignment(code);
      }
      return;
    }

    final product = await _pickExistingProduct();
    if (!mounted || product == null) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductEditorDialog(
        services: widget.services,
        product: product,
        initialBarcode: code,
      ),
    );
    if (changed == true && mounted) {
      _refreshAfterBarcodeAssignment(code);
    }
  }

  Future<ProductSummary?> _pickExistingProduct() async {
    final controller = TextEditingController();
    try {
      return await showDialog<ProductSummary>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocalState) {
            final products = widget.services.products.searchProducts(controller.text, 100);
            return AlertDialog(
              title: const Text('Scegli articolo esistente'),
              content: SizedBox(
                width: 620,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setLocalState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Cerca articolo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: products.isEmpty
                          ? const Center(child: Text('Nessun articolo trovato.'))
                          : ListView.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return ListTile(
                                  title: Text(product.name),
                                  subtitle: Text('${product.brand ?? 'Senza marca'} · ${product.category ?? 'Senza categoria'} · ${product.variantCountDisplay}'),
                                  onTap: () => Navigator.pop(dialogContext, product),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annulla')),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _refreshAfterBarcodeAssignment(String code) {
    final product = widget.services.products.findByBarcode(code);
    _search.text = code;
    setState(() {
      _scannedCode = code;
      _scannedProduct = product;
      _status = product == null
          ? 'Barcode non ancora assegnato.'
          : 'Barcode assegnato a ${product.name} · ${product.variantDisplay}.';
    });
  }

  void _manualSearchChanged(String _) {
    setState(() {
      _scannedCode = null;
      _scannedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.count();
    final stock = widget.services.stock.getTotalStock();
    final results = _results;
    final missing = _scannedCodeIsMissing;

    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _submit,
      child: Padding(
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
                ButtonSegment(value: _ScanMode.search, icon: Icon(Icons.search), label: Text('Cerca / mostra')),
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
              onChanged: _manualSearchChanged,
              onSubmitted: _submit,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
                labelText: 'Scansiona barcode/SKU o cerca per nome',
                hintText: 'Puoi scansionare anche senza cliccare questo campo',
              ),
            ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: missing
                    ? ListView(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.add)),
                            title: const Text('Aggiungi articolo'),
                            subtitle: Text('Barcode ${_scannedCode!} non presente nel database'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _addScannedBarcode(_scannedCode!),
                          ),
                        ],
                      )
                    : results.isEmpty
                        ? const Center(child: Text('Nessun prodotto trovato.'))
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
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
      ),
    );
  }
}

enum _BarcodeAction { newProduct, existingProduct }

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
