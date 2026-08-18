import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/catalog.dart';
import '../services/app_services.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({super.key, required this.services, required this.settings});
  final AppServices services;
  final AppSettings settings;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  final _search = TextEditingController();
  final _copies = TextEditingController(text: '1');
  final _width = TextEditingController(text: '50');
  final _height = TextEditingController(text: '30');
  ProductVariant? _selected;
  String? _status;
  bool _printing = false;

  @override
  void dispose() {
    _search.dispose();
    _copies.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    final product = _selected;
    if (product == null) return;
    final copies = int.tryParse(_copies.text) ?? 0;
    final width = double.tryParse(_width.text.replaceAll(',', '.')) ?? 0;
    final height = double.tryParse(_height.text.replaceAll(',', '.')) ?? 0;
    if (copies <= 0 || width <= 0 || height <= 0) {
      setState(() => _status = 'Copie e dimensioni devono essere maggiori di zero.');
      return;
    }
    setState(() => _printing = true);
    try {
      final ok = await widget.services.labels.printLabels(product: product, copies: copies, widthMm: width, heightMm: height);
      if (mounted) setState(() => _status = ok ? 'Etichette inviate al sistema di stampa.' : 'Stampa annullata.');
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Etichette', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Column(children: [
                TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cerca prodotto / SKU / barcode', prefixIcon: Icon(Icons.search))),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
              width: 430,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Anteprima', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)),
                        child: _selected == null
                            ? const Center(child: Text('Seleziona una variante.', style: TextStyle(color: Colors.black54)))
                            : Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(_selected!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  if (code != null) BarcodeWidget(
                                    barcode: widget.services.labels.barcodeFor(code),
                                    data: code,
                                    drawText: true,
                                    color: Colors.black,
                                    backgroundColor: Colors.white,
                                    height: 100,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_selected!.salePriceDisplay, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: _copies, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Copie'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _width, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Larghezza mm'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Altezza mm'))),
                    ]),
                    const SizedBox(height: 10),
                    FilledButton.icon(onPressed: _selected == null || _printing ? null : _print, icon: const Icon(Icons.print), label: Text(_printing ? 'Stampa…' : 'Stampa etichette')),
                    if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
                    const SizedBox(height: 6),
                    Text('EAN-13 viene usato quando il codice è valido; negli altri casi viene generato Code 128. La coda di stampa viene scelta dal dialogo di sistema.', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
