import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/stock.dart';
import '../services/app_services.dart';
import '../widgets/glass_dropdown.dart';
import '../widgets/hid_barcode_listener.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key, required this.services, required this.isActive});
  final AppServices services;
  final bool isActive;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _search = TextEditingController();
  final _historySearch = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  ProductVariant? _selected;
  StockMovementKind _kind = StockMovementKind.incoming;
  String? _status;

  @override
  void dispose() {
    _search.dispose();
    _historySearch.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
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
          : 'Selezionato ${product.name} · ${product.variantDisplay}.';
    });
  }

  void _register() {
    if (_selected == null) return;
    final quantity = int.tryParse(_quantity.text.trim());
    if (quantity == null) {
      setState(() => _status = 'Inserisci una quantità intera valida.');
      return;
    }
    try {
      widget.services.stock.addMovement(_selected!.id, _kind, quantity, _note.text);
      final latest = widget.services.products.getById(_selected!.id);
      setState(() {
        _selected = latest;
        _status = 'Movimento registrato. Giacenza: ${latest?.stockQuantity ?? 0}.';
        _note.clear();
      });
    } catch (error) {
      setState(() => _status = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.search(_search.text).take(100).toList();
    final history = widget.services.stock.search(_historySearch.text, 500);
    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _scan,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Magazzino', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _scan,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Cerca variante / SKU / barcode',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                    hintText: 'Puoi scansionare anche senza cliccare questo campo',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 190,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        return ListTile(
                          dense: true,
                          selected: _selected?.id == p.id,
                          title: Text(p.name),
                          subtitle: Text('${p.variantDisplay} · ${p.sku}'),
                          trailing: Text('Giacenza ${p.stockQuantity}'),
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
              width: 390,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(
                      _selected == null
                          ? 'Seleziona una variante'
                          : '${_selected!.name} · ${_selected!.variantDisplay}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    GlassDropdown<StockMovementKind>(
                      value: _kind,
                      labelText: 'Tipo movimento',
                      items: const [
                        GlassDropdownItem(
                          value: StockMovementKind.incoming,
                          label: 'Carico',
                          icon: Icons.arrow_downward,
                        ),
                        GlassDropdownItem(
                          value: StockMovementKind.outgoing,
                          label: 'Scarico',
                          icon: Icons.arrow_upward,
                        ),
                        GlassDropdownItem(
                          value: StockMovementKind.adjustment,
                          label: 'Rettifica giacenza',
                          icon: Icons.tune,
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _kind = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: _kind == StockMovementKind.adjustment ? 'Nuova giacenza' : 'Quantità',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Nota',
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _selected == null ? null : _register,
                      icon: const Icon(Icons.save),
                      label: const Text('Registra movimento'),
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_status!),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _historySearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Cerca nello storico',
              prefixIcon: Icon(Icons.history),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = history[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      m.kind == StockMovementKind.incoming
                          ? Icons.arrow_downward
                          : m.kind == StockMovementKind.outgoing
                              ? Icons.arrow_upward
                              : Icons.tune,
                    ),
                    title: Text('${m.productName} · SKU ${m.sku}'),
                    subtitle: Text('${m.createdAtDisplay}${m.note == null ? '' : ' · ${m.note}'}'),
                    trailing: Text('${m.typeDisplay} ${m.quantityDisplay}  →  ${m.stockAfter}'),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
