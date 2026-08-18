import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/catalog.dart';
import '../services/app_services.dart';
import '../widgets/hid_barcode_listener.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key, required this.services, required this.isActive});
  final AppServices services;
  final bool isActive;

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _totalPercent = TextEditingController(text: '0');
  final _fixedDiscount = TextEditingController();
  final List<_CashLine> _cart = [];
  final List<_FixedDiscountLine> _fixedDiscounts = [];
  int _nextDiscountId = 1;
  String _searchStatus = 'Scanner HID pronto. Scansiona barcode/SKU oppure cerca un prodotto.';
  String _cartStatus = 'Vendita in preparazione: nessun movimento di magazzino viene registrato.';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _totalPercent.dispose();
    _fixedDiscount.dispose();
    super.dispose();
  }

  List<ProductVariant> get _results => widget.services.products.search(_search.text).take(50).toList();

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    final exact = widget.services.products.findByBarcode(query);
    if (exact != null) {
      _add(exact);
    } else {
      final matches = widget.services.products.search(query).take(2).toList();
      if (matches.length == 1) {
        _add(matches.first);
      } else {
        setState(() => _searchStatus = 'Nessun prodotto univoco trovato per «$query».');
      }
    }
    _search.clear();
    setState(() {});
  }

  void _add(ProductVariant candidate) {
    final latest = widget.services.products.getById(candidate.id);
    if (latest == null) return _message('Il prodotto selezionato non esiste più.');
    if (!latest.isActive) return _message('${latest.name}: variante disattivata, non aggiunta.');
    if (latest.salePriceCents == null) return _message('${latest.name}: prezzo di vendita non impostato.');
    if (latest.stockQuantity <= 0) return _message('${latest.name}: nessun pezzo disponibile in magazzino.');

    final index = _cart.indexWhere((line) => line.variantId == latest.id);
    final current = index < 0 ? null : _cart[index];
    final quantity = current?.quantity ?? 0;
    if (quantity >= latest.stockQuantity) {
      return _message('${latest.name}: nel carrello ci sono già tutti i ${latest.stockQuantity} pezzi disponibili.');
    }

    final line = _CashLine(product: latest, quantity: quantity + 1, discountPercent: current?.discountPercent ?? 0);
    if (index < 0) {
      _cart.add(line);
    } else {
      _cart[index] = line;
    }
    setState(() {
      _searchStatus = 'Aggiunto: ${latest.name} · ${latest.variantDisplay}. Quantità: ${line.quantity}.';
      _cartStatus = 'La giacenza verrà modificata solo quando sarà integrata la chiusura fiscale.';
    });
  }

  void _message(String value) => setState(() => _searchStatus = value);

  void _changeQuantity(_CashLine line, int delta) {
    final index = _cart.indexWhere((item) => item.variantId == line.variantId);
    if (index < 0) return;
    final latest = widget.services.products.getById(line.variantId);
    if (latest == null || !latest.isActive || latest.salePriceCents == null || latest.stockQuantity <= 0) {
      _cart.removeAt(index);
      _normalizeDiscounts();
      setState(() => _cartStatus = 'La variante non è più vendibile ed è stata rimossa dal carrello.');
      return;
    }
    final next = _cart[index].quantity + delta;
    if (next < 1) return _cartMessage('Usa «Rimuovi» per eliminare completamente la riga.');
    if (next > latest.stockQuantity) return _cartMessage('Quantità massima raggiunta: ${latest.stockQuantity} pezzi disponibili.');
    _cart[index] = _CashLine(product: latest, quantity: next, discountPercent: line.discountPercent);
    setState(() => _cartStatus = '${latest.name}: quantità aggiornata a $next.');
  }

  void _cartMessage(String value) => setState(() => _cartStatus = value);

  void _setLineDiscount(_CashLine line, String value) {
    final percent = _clampPercent(double.tryParse(value.replaceAll(',', '.')) ?? 0);
    final index = _cart.indexWhere((e) => e.variantId == line.variantId);
    if (index < 0) return;
    _cart[index] = line.copyWith(discountPercent: percent);
    setState(() => _cartStatus = percent == 0
        ? 'Sconto rimosso da ${line.product.name}.'
        : 'Sconto del ${_percentText(percent)}% applicato a ${line.product.name}.');
  }

  void _addFixedDiscount() {
    if (_cart.isEmpty) return _cartMessage('Aggiungi almeno un articolo prima di inserire uno sconto in euro.');
    final parsed = double.tryParse(_fixedDiscount.text.trim().replaceAll(',', '.'))?.abs() ?? 0;
    final cents = (parsed * 100).round();
    if (cents <= 0) return _cartMessage('Inserisci uno sconto maggiore di 0 euro e premi Invio.');
    final rawRemaining = _afterPercentCents - _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    if (cents > remaining) return _cartMessage('Lo sconto supera il totale residuo di ${formatMoney(remaining)}.');
    _fixedDiscounts.add(_FixedDiscountLine(id: _nextDiscountId++, amountCents: cents));
    _fixedDiscount.clear();
    setState(() => _cartStatus = 'Sconto di ${formatMoney(cents)} aggiunto al carrello come −${formatMoney(cents)}.');
  }

  void _removeLine(_CashLine line) {
    _cart.removeWhere((e) => e.variantId == line.variantId);
    _normalizeDiscounts();
    setState(() => _cartStatus = '${line.product.name} rimosso dal carrello.');
  }

  void _removeFixed(_FixedDiscountLine line) {
    _fixedDiscounts.removeWhere((e) => e.id == line.id);
    setState(() => _cartStatus = 'Sconto di ${formatMoney(line.amountCents)} rimosso dal carrello.');
  }

  void _clear() {
    _cart.clear();
    _fixedDiscounts.clear();
    _totalPercent.text = '0';
    _fixedDiscount.clear();
    setState(() => _cartStatus = 'Carrello svuotato. Nessun movimento di magazzino è stato registrato.');
  }

  void _normalizeDiscounts() {
    if (_cart.isEmpty) {
      _fixedDiscounts.clear();
      _totalPercent.text = '0';
    }
  }

  double get _totalDiscountPercent => _clampPercent(double.tryParse(_totalPercent.text.replaceAll(',', '.')) ?? 0);
  int get _grossCents => _cart.fold(0, (sum, line) => sum + line.grossLineTotalCents);
  int get _subtotalCents => _cart.fold(0, (sum, line) => sum + line.lineTotalCents);
  int get _afterPercentCents => _applyPercent(_subtotalCents, _totalDiscountPercent);
  int get _fixedCents {
    final requested = _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    return requested > _afterPercentCents ? _afterPercentCents : requested;
  }

  int get _finalTotalCents {
    final total = _afterPercentCents - _fixedCents;
    return total < 0 ? 0 : total;
  }

  int _applyPercent(int cents, double percent) => (cents * (1 - _clampPercent(percent) / 100)).round();
  double _clampPercent(double value) => value.clamp(0, 100).toDouble();
  String _percentText(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final itemDiscountRaw = _grossCents - _subtotalCents;
    final itemDiscount = itemDiscountRaw < 0 ? 0 : itemDiscountRaw;
    final totalPercentDiscountRaw = _subtotalCents - _afterPercentCents;
    final totalPercentDiscount = totalPercentDiscountRaw < 0 ? 0 : totalPercentDiscountRaw;
    final count = _cart.fold<int>(0, (sum, line) => sum + line.quantity);

    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _submitSearch,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cassa', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _submitSearch,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      labelText: 'Scansiona barcode/SKU o cerca prodotto',
                      hintText: 'Puoi scansionare anche senza cliccare questo campo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_searchStatus),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: results.isEmpty
                          ? const Center(child: Text('Nessun prodotto trovato.'))
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = results[index];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text('${p.variantDisplay} · SKU ${p.sku} · giacenza ${p.stockQuantity}'),
                                  trailing: Text(p.salePriceDisplay),
                                  onTap: () => _add(p),
                                );
                              },
                            ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(child: Text('Carrello · $count ${count == 1 ? 'articolo' : 'articoli'}', style: Theme.of(context).textTheme.titleLarge)),
                        TextButton.icon(onPressed: _cart.isEmpty && _fixedDiscounts.isEmpty ? null : _clear, icon: const Icon(Icons.delete_sweep), label: const Text('Svuota')),
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _cart.isEmpty && _fixedDiscounts.isEmpty
                          ? const Center(child: Text('Carrello vuoto.'))
                          : ListView(children: [
                              ..._cart.map((line) => _CartTile(
                                    line: line,
                                    onDecrease: () => _changeQuantity(line, -1),
                                    onIncrease: () => _changeQuantity(line, 1),
                                    onDiscount: (value) => _setLineDiscount(line, value),
                                    onRemove: () => _removeLine(line),
                                  )),
                              ..._fixedDiscounts.map((line) => ListTile(
                                    leading: const Icon(Icons.discount_outlined),
                                    title: const Text('Sconto fisso'),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('−${formatMoney(line.amountCents)}'),
                                      IconButton(onPressed: () => _removeFixed(line), icon: const Icon(Icons.close)),
                                    ]),
                                  )),
                            ]),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(child: TextField(
                            controller: _totalPercent,
                            enabled: _cart.isNotEmpty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Sconto totale %', suffixText: '%'),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(
                            controller: _fixedDiscount,
                            enabled: _cart.isNotEmpty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onSubmitted: (_) => _addFixedDiscount(),
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Sconto €', prefixText: '− € '),
                          )),
                        ]),
                        const SizedBox(height: 10),
                        if (itemDiscount > 0) Text('Sconti articoli: −${formatMoney(itemDiscount)}'),
                        if (totalPercentDiscount > 0) Text('Sconto totale ${_percentText(_totalDiscountPercent)}%: −${formatMoney(totalPercentDiscount)}'),
                        if (_fixedCents > 0) Text('Sconti fissi: −${formatMoney(_fixedCents)}'),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: Text('Totale', style: Theme.of(context).textTheme.titleLarge)),
                          Text(formatMoney(_finalTotalCents), style: Theme.of(context).textTheme.headlineMedium),
                        ]),
                        const SizedBox(height: 8),
                        Text(_cartStatus, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Emetti documento commerciale (RT non integrato)'),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.line,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDiscount,
    required this.onRemove,
  });
  final _CashLine line;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onDiscount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.product.name, style: Theme.of(context).textTheme.titleSmall),
              Text('${line.product.variantDisplay} · ${line.product.sku} · ${formatMoney(line.product.salePriceCents)} cad.'),
            ]),
          ),
          IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove_circle_outline)),
          Text('${line.quantity}'),
          IconButton(onPressed: onIncrease, icon: const Icon(Icons.add_circle_outline)),
          SizedBox(
            width: 84,
            child: TextFormField(
              key: ValueKey('${line.variantId}-${line.discountPercent}'),
              initialValue: line.discountPercent == 0 ? '' : line.discountPercent.toString().replaceAll('.', ','),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: onDiscount,
              decoration: const InputDecoration(isDense: true, labelText: 'Sconto', suffixText: '%'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 88, child: Text(formatMoney(line.lineTotalCents), textAlign: TextAlign.right)),
          IconButton(onPressed: onRemove, tooltip: 'Rimuovi', icon: const Icon(Icons.close)),
        ]),
      );
}

class _CashLine {
  const _CashLine({required this.product, required this.quantity, required this.discountPercent});
  final ProductVariant product;
  final int quantity;
  final double discountPercent;
  int get variantId => product.id;
  int get grossLineTotalCents => (product.salePriceCents ?? 0) * quantity;
  int get lineTotalCents => (grossLineTotalCents * (1 - discountPercent.clamp(0, 100) / 100)).round();
  _CashLine copyWith({double? discountPercent}) => _CashLine(product: product, quantity: quantity, discountPercent: discountPercent ?? this.discountPercent);
}

class _FixedDiscountLine {
  const _FixedDiscountLine({required this.id, required this.amountCents});
  final int id;
  final int amountCents;
}
