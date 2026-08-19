import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/catalog.dart';
import '../repositories/lookup_repository.dart';
import '../services/app_services.dart';
import '../widgets/glass_dropdown.dart';

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({
    super.key,
    required this.services,
    this.product,
    this.initialBarcode,
  });

  final AppServices services;
  final ProductSummary? product;
  final String? initialBarcode;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _purchase;
  late final TextEditingController _sale;
  late List<_VariantForm> _variants;
  int? _brandId;
  int? _categoryId;
  bool _active = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _notes = TextEditingController(text: product?.notes ?? '');
    _purchase = TextEditingController(text: _moneyInput(product?.purchasePriceCents));
    _sale = TextEditingController(text: _moneyInput(product?.salePriceCents));
    _brandId = product?.brandId;
    _categoryId = product?.categoryId;
    _active = product?.isActive ?? true;

    final scannedBarcode = widget.initialBarcode?.trim();
    if (product != null) {
      _variants = widget.services.products
          .getVariants(product.id)
          .map(_VariantForm.fromDraft)
          .toList();
      if (scannedBarcode?.isNotEmpty == true &&
          !_variants.any((variant) => variant.containsBarcode(scannedBarcode!))) {
        _variants.add(_VariantForm(
          id: null,
          sku: widget.services.products.generateSku(),
          barcodes: scannedBarcode!,
          expanded: true,
        ));
      }
    } else {
      _variants = [
        _VariantForm(
          id: null,
          sku: widget.services.products.generateSku(),
          barcodes: scannedBarcode?.isNotEmpty == true ? scannedBarcode! : '',
          expanded: true,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _purchase.dispose();
    _sale.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  String _nextSku() {
    final base = widget.services.products.generateSku();
    final match = RegExp(r'^(.*?)(\d+)$').firstMatch(base);
    if (match == null) return '$base-${_variants.length + 1}';
    final prefix = match.group(1)!;
    var number = int.parse(match.group(2)!);
    var result = base;
    final used = _variants.map((e) => e.sku.text.toLowerCase()).toSet();
    while (used.contains(result.toLowerCase())) {
      number++;
      result = '$prefix${number.toString().padLeft(match.group(2)!.length, '0')}';
    }
    return result;
  }

  void _addVariant() => setState(() => _variants.add(_VariantForm(
        id: null,
        sku: _nextSku(),
        expanded: true,
      )));

  void _removeVariant(int index) {
    if (_variants.length == 1 || _variants[index].id != null) return;
    final form = _variants.removeAt(index);
    form.dispose();
    setState(() {});
  }

  void _save() {
    try {
      final draft = ProductDraft(
        id: widget.product?.id,
        name: _name.text,
        categoryId: _categoryId,
        brandId: _brandId,
        purchasePriceCents: parseEuroCents(_purchase.text),
        salePriceCents: parseEuroCents(_sale.text),
        notes: _notes.text,
        isActive: _active,
        variants: _variants.map((v) => v.toDraft()).toList(),
      );
      widget.services.products.save(draft);
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _error = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brands = widget.services.lookups.getAll(LookupKind.brand);
    final categories = widget.services.lookups.getAll(LookupKind.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFA1E2430) : const Color(0xFAFFFFFF),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    widget.product == null ? 'Nuovo prodotto' : 'Modifica prodotto',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ]),
              if (widget.initialBarcode?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  widget.product == null
                      ? 'Barcode scansionato: ${widget.initialBarcode!.trim()}'
                      : 'Nuova variante precompilata con barcode: ${widget.initialBarcode!.trim()}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nome *',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassDropdown<int>(
                    value: _brandId,
                    labelText: 'Marca',
                    items: [
                      const GlassDropdownItem<int>(value: null, label: '—'),
                      ...brands.map((b) => GlassDropdownItem<int>(value: b.id, label: b.name)),
                    ],
                    onChanged: (value) => setState(() => _brandId = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassDropdown<int>(
                    value: _categoryId,
                    labelText: 'Categoria',
                    items: [
                      const GlassDropdownItem<int>(value: null, label: '—'),
                      ...categories.map((c) => GlassDropdownItem<int>(value: c.id, label: c.name)),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _purchase,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Prezzo acquisto prodotto €',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _sale,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Prezzo vendita prodotto €',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Note',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
                const Text('Attivo'),
              ]),
              const SizedBox(height: 12),
              Text(
                'I prezzi del prodotto vengono usati da tutte le varianti. Compila un prezzo nella variante solo se deve sovrascrivere quello del prodotto.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Text('Varianti', style: Theme.of(context).textTheme.titleMedium),
                ),
                OutlinedButton.icon(
                  onPressed: _addVariant,
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi variante'),
                ),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _variants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _VariantEditor(
                    key: ObjectKey(_variants[index]),
                    form: _variants[index],
                    index: index,
                    canRemove: _variants[index].id == null && _variants.length > 1,
                    onRemove: () => _removeVariant(index),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Salva'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _moneyInput(int? cents) =>
      cents == null ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
}

class _VariantEditor extends StatefulWidget {
  const _VariantEditor({
    super.key,
    required this.form,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final _VariantForm form;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<_VariantEditor> createState() => _VariantEditorState();
}

class _VariantEditorState extends State<_VariantEditor> {
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: widget.form.expanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (expanded) => widget.form.expanded = expanded,
          title: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.form.variant,
            builder: (context, value, _) {
              final name = value.text.trim();
              return Text(
                name.isEmpty ? 'Variante ${widget.index + 1}' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              );
            },
          ),
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: widget.form.sku,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'SKU *',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.form.variant,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Variante',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.form.size,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Taglia',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.canRemove ? widget.onRemove : null,
                tooltip: widget.canRemove
                    ? 'Rimuovi variante nuova'
                    : 'Le varianti già salvate non vengono eliminate per preservare lo storico',
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: widget.form.barcodes,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Barcode (uno per riga o separati da virgola)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.form.purchase,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Override acquisto €',
                    hintText: 'Eredita prodotto',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.form.sale,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Override vendita €',
                    hintText: 'Eredita prodotto',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatefulBuilder(
                builder: (context, setLocal) => Row(children: [
                  Switch(
                    value: widget.form.active,
                    onChanged: (v) => setLocal(() => widget.form.active = v),
                  ),
                  const Text('Attiva'),
                ]),
              ),
              const SizedBox(width: 12),
              Text('Giacenza: ${widget.form.stock}'),
            ]),
          ],
        ),
      );
}

class _VariantForm {
  _VariantForm({
    required this.id,
    required String sku,
    String variant = '',
    String size = '',
    String purchase = '',
    String sale = '',
    String barcodes = '',
    this.active = true,
    this.stock = 0,
    this.expanded = false,
  })  : sku = TextEditingController(text: sku),
        variant = TextEditingController(text: variant),
        size = TextEditingController(text: size),
        purchase = TextEditingController(text: purchase),
        sale = TextEditingController(text: sale),
        barcodes = TextEditingController(text: barcodes);

  factory _VariantForm.fromDraft(ProductVariantDraft draft) => _VariantForm(
        id: draft.id,
        sku: draft.sku,
        variant: draft.variant ?? '',
        size: draft.size ?? '',
        purchase: draft.purchasePriceCents == null
            ? ''
            : (draft.purchasePriceCents! / 100).toStringAsFixed(2).replaceAll('.', ','),
        sale: draft.salePriceCents == null
            ? ''
            : (draft.salePriceCents! / 100).toStringAsFixed(2).replaceAll('.', ','),
        barcodes: draft.barcodes.join('\n'),
        active: draft.isActive,
        stock: draft.stockQuantity,
      );

  final int? id;
  final TextEditingController sku;
  final TextEditingController variant;
  final TextEditingController size;
  final TextEditingController purchase;
  final TextEditingController sale;
  final TextEditingController barcodes;
  bool active;
  final int stock;
  bool expanded;

  bool containsBarcode(String value) => barcodes.text
      .split(RegExp(r'[,;\n\r]+'))
      .map((e) => e.trim())
      .any((e) => e == value.trim());

  ProductVariantDraft toDraft() => ProductVariantDraft(
        id: id,
        sku: sku.text,
        variant: variant.text,
        size: size.text,
        purchasePriceCents: parseEuroCents(purchase.text),
        salePriceCents: parseEuroCents(sale.text),
        isActive: active,
        barcodes: barcodes.text
            .split(RegExp(r'[,;\n\r]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        stockQuantity: stock,
      );

  void dispose() {
    sku.dispose();
    variant.dispose();
    size.dispose();
    purchase.dispose();
    sale.dispose();
    barcodes.dispose();
  }
}
