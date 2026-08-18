import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/app_settings.dart';
import '../models/catalog.dart';
import '../services/app_services.dart';
import '../widgets/hid_barcode_listener.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    super.key,
    required this.services,
    required this.settings,
    required this.isActive,
  });
  final AppServices services;
  final AppSettings settings;
  final bool isActive;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  final _search = TextEditingController();
  final _copies = TextEditingController(text: '1');
  final _width = TextEditingController(text: '50');
  final _height = TextEditingController(text: '30');
  ProductVariant? _selected;
  List<Printer> _printers = const [];
  Printer? _printer;
  String? _status;
  bool _printing = false;
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _refreshPrinters();
  }

  @override
  void dispose() {
    _search.dispose();
    _copies.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _refreshPrinters() async {
    if (_loadingPrinters) return;
    setState(() => _loadingPrinters = true);
    try {
      final printers = await widget.services.labels.getPrinters();
      if (!mounted) return;
      final previousUrl = _printer?.url;
      Printer? selected;
      for (final printer in printers) {
        if (printer.url == previousUrl) {
          selected = printer;
          break;
        }
      }
      setState(() {
        _printers = printers;
        _printer = selected ?? (printers.isEmpty ? null : printers.first);
        _status = printers.isEmpty
            ? 'Nessuna stampante rilevata. Verifica che il driver della stampante etichette sia installato.'
            : 'Stampante pronta: ${_printer!.name}.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Impossibile leggere le stampanti: $error');
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  void _scan(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    final product = widget.services.products.findByBarcode(code);
    _search.text = code;
    setState(() {
      _selected = product;
      _status = product == null
          ? 'Nessun prodotto trovato per «$code».'
          : 'Etichetta pronta per ${product.name} · ${product.variantDisplay}.';
    });
  }

  Future<void> _print() async {
    final product = _selected;
    final printer = _printer;
    if (product == null) return;
    if (printer == null) {
      setState(() => _status = 'Seleziona una stampante.');
      return;
    }
    final copies = int.tryParse(_copies.text) ?? 0;
    final width = double.tryParse(_width.text.replaceAll(',', '.')) ?? 0;
    final height = double.tryParse(_height.text.replaceAll(',', '.')) ?? 0;
    if (copies <= 0 || width <= 0 || height <= 0) {
      setState(() => _status = 'Copie e dimensioni devono essere maggiori di zero.');
      return;
    }
    setState(() => _printing = true);
    try {
      final ok = await widget.services.labels.printLabels(
        printer: printer,
        product: product,
        copies: copies,
        widthMm: width,
        heightMm: height,
      );
      if (mounted) {
        setState(() => _status = ok
            ? 'Stampa inviata a ${printer.name}: $copies ${copies == 1 ? 'copia' : 'copie'}.'
            : 'Stampa annullata.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Errore di stampa: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.search(_search.text).take(100).toList();
    final code = _selected?.barcode ?? _selected?.sku;
    final widthMm = double.tryParse(_width.text.replaceAll(',', '.')) ?? 50;
    final heightMm = double.tryParse(_height.text.replaceAll(',', '.')) ?? 30;

    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _scan,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Etichette', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _scan,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Cerca prodotto / SKU / barcode',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      hintText: 'Puoi scansionare anche senza cliccare questo campo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = products[index];
                          return ListTile(
                            selected: _selected?.id == p.id,
                            title: Text(p.name),
                            subtitle: Text('${p.variantDisplay} · ${p.sku}'),
                            trailing: Text(p.barcode ?? 'Code 128 da SKU'),
                            onTap: () => setState(() => _selected = p),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 450,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text('Anteprima', style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                          tooltip: 'Aggiorna stampanti',
                          onPressed: _loadingPrinters ? null : _refreshPrinters,
                          icon: _loadingPrinters
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Printer>(
                        value: _printer,
                        decoration: const InputDecoration(labelText: 'Stampante'),
                        items: _printers
                            .map((printer) => DropdownMenuItem(value: printer, child: Text(printer.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: _printing ? null : (value) => setState(() => _printer = value),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: widthMm > 0 && heightMm > 0 ? widthMm / heightMm : 5 / 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _selected == null
                                  ? const Center(child: Text('Seleziona una variante.', style: TextStyle(color: Colors.black54)))
                                  : _LabelPreview(
                                      product: _selected!,
                                      code: code!,
                                      barcode: widget.services.labels.barcodeFor(code),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextField(controller: _copies, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Copie'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _width, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Larghezza mm'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _height, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Altezza mm'))),
                      ]),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _selected == null || _printer == null || _printing ? null : _print,
                        icon: const Icon(Icons.print),
                        label: Text(_printing ? 'Stampa…' : 'Stampa etichette'),
                      ),
                      if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
                      const SizedBox(height: 6),
                      Text(
                        'Layout allineato alla versione main: nome e variante in alto, barcode al centro, SKU in basso a sinistra e prezzo in basso a destra. Configura nel driver la stessa misura dell’etichetta.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({required this.product, required this.code, required this.barcode});
  final ProductVariant product;
  final String code;
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (product.variant?.trim().isNotEmpty == true) product.variant!.trim(),
      if (product.size?.trim().isNotEmpty == true) product.size!.trim(),
    ].join(' | ');

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final margin = constraints.maxWidth * 0.055;
      return Stack(children: [
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.055,
          height: h * 0.145,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        if (details.isNotEmpty)
          Positioned(
            left: margin,
            right: margin,
            top: h * 0.20,
            height: h * 0.09,
            child: Align(alignment: Alignment.centerLeft, child: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 11))),
          ),
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.30,
          height: h * 0.37,
          child: BarcodeWidget(barcode: barcode, data: code, drawText: false, color: Colors.black, backgroundColor: Colors.white),
        ),
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.67,
          height: h * 0.13,
          child: Center(child: Text(code, maxLines: 1, style: const TextStyle(color: Colors.black, fontSize: 11))),
        ),
        Positioned(
          left: margin,
          right: constraints.maxWidth * 0.50,
          top: h * 0.80,
          bottom: h * 0.045,
          child: Align(alignment: Alignment.centerLeft, child: Text(product.sku, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11))),
        ),
        if (product.salePriceCents != null)
          Positioned(
            left: constraints.maxWidth * 0.48,
            right: margin,
            top: h * 0.80,
            bottom: h * 0.035,
            child: Align(alignment: Alignment.centerRight, child: Text(product.salePriceDisplay, maxLines: 1, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))),
          ),
      ]);
    });
  }
}
