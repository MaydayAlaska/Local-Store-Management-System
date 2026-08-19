import 'package:flutter/material.dart';

import '../core/app_runtime.dart';
import '../core/formatters.dart';
import '../l10n/app_strings.dart';
import '../models/catalog.dart';
import '../models/customer.dart';
import '../services/app_services.dart';
import '../services/fiscal_code_service.dart';
import '../widgets/hid_barcode_listener.dart';
import 'customer_editor_dialog.dart';
import 'customer_picker_dialog.dart';

class CashPage extends StatefulWidget {
  const CashPage({super.key, required this.services, required this.isActive});
  final AppServices services;
  final bool isActive;

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  static const _maxGenericPriceCents = 99999999;

  final _search = TextEditingController();
  final _totalPercent = TextEditingController();
  final _fixedDiscount = TextEditingController();
  final List<_CashLine> _cart = [];
  final List<_FixedDiscountLine> _fixedDiscounts = [];
  Customer? _customer;
  int _nextDiscountId = 1;
  int _nextGenericLineId = 1;
  int _keypadPriceCents = 0;
  late String _searchStatus;
  late String _cartStatus;

  @override
  void initState() {
    super.initState();
    _searchStatus = AppStrings.t('ready_scanner');
    _cartStatus = AppStrings.t('sale_preparing');
  }

  @override
  void dispose() {
    _search.dispose();
    _totalPercent.dispose();
    _fixedDiscount.dispose();
    super.dispose();
  }

  List<ProductVariant> get _results =>
      widget.services.products.search(_search.text, 50);

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  void _keypadInsert(String value) {
    var next = _keypadPriceCents;
    for (final digit in value.split('')) {
      final parsed = int.tryParse(digit);
      if (parsed == null) continue;
      next = next * 10 + parsed;
      if (next > _maxGenericPriceCents) {
        setState(() {
          _cartStatus = _itEn(
            'Importo troppo alto per un articolo generico.',
            'The generic item amount is too high.',
          );
        });
        return;
      }
    }
    setState(() => _keypadPriceCents = next);
  }

  void _keypadBackspace() {
    if (_keypadPriceCents == 0) return;
    setState(() => _keypadPriceCents ~/= 10);
  }

  void _keypadClear() {
    if (_keypadPriceCents == 0) return;
    setState(() => _keypadPriceCents = 0);
  }

  void _keypadSubmit() {
    final cents = _keypadPriceCents;
    if (cents <= 0) {
      return _cartMessage(_itEn(
        'Inserisci un prezzo maggiore di zero e conferma.',
        'Enter a price greater than zero and confirm.',
      ));
    }

    final line = _CashLine.generic(
      genericId: _nextGenericLineId++,
      genericName: _itEn('Articolo generico', 'Generic item'),
      unitPriceCents: cents,
      quantity: 1,
      discountPercent: 0,
    );
    setState(() {
      _cart.add(line);
      _keypadPriceCents = 0;
      _cartStatus = _itEn(
        'Articolo generico da ${formatMoney(cents)} aggiunto al carrello.',
        'Generic item for ${formatMoney(cents)} added to the cart.',
      );
    });
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;

    final fiscalCode = FiscalCodeService.tryParse(query);
    if (fiscalCode != null) {
      _search.clear();
      _handleFiscalCode(fiscalCode);
      setState(() {});
      return;
    }

    final exact = widget.services.products.findByBarcode(query);
    if (exact != null) {
      _add(exact, refresh: false);
    } else {
      final matches = widget.services.products.search(query, 2);
      if (matches.length == 1) {
        _add(matches.first, refresh: false);
      } else {
        setState(() => _searchStatus = _itEn(
              'Nessun prodotto univoco trovato per «$query».',
              'No unique product found for “$query”.',
            ));
      }
    }
    _search.clear();
    setState(() {});
  }

  Future<void> _handleFiscalCode(FiscalCodeData data) async {
    final existing = widget.services.customers.findByFiscalCode(data.fiscalCode);
    if (existing != null) {
      setState(() {
        _customer = existing;
        _searchStatus = _itEn(
          'Cliente associato: ${existing.displayName}.',
          'Customer linked: ${existing.displayName}.',
        );
      });
      return;
    }

    final created = await showCustomerEditorDialog(
      context,
      repository: widget.services.customers,
      scanned: data,
    );
    if (!mounted || created == null) return;
    setState(() {
      _customer = created;
      _searchStatus = _itEn(
        'Nuovo cliente associato: ${created.displayName}.',
        'New customer linked: ${created.displayName}.',
      );
    });
  }

  Future<void> _pickCustomer() async {
    final customer = await showCustomerPickerDialog(
      context,
      repository: widget.services.customers,
    );
    if (!mounted || customer == null) return;
    setState(() {
      _customer = customer;
      _searchStatus = _itEn(
        'Cliente associato: ${customer.displayName}.',
        'Customer linked: ${customer.displayName}.',
      );
    });
  }

  void _add(ProductVariant candidate, {bool refresh = true}) {
    final ProductVariant? latest =
        refresh ? widget.services.products.getById(candidate.id) : candidate;
    if (latest == null) {
      return _message(_itEn(
        'Il prodotto selezionato non esiste più.',
        'The selected product no longer exists.',
      ));
    }
    if (!latest.isActive) {
      return _message(_itEn(
        '${latest.name}: variante disattivata, non aggiunta.',
        '${latest.name}: variant disabled, not added.',
      ));
    }
    if (latest.salePriceCents == null) {
      return _message(_itEn(
        '${latest.name}: prezzo di vendita non impostato.',
        '${latest.name}: sale price is not set.',
      ));
    }
    if (latest.stockQuantity <= 0) {
      return _message(_itEn(
        '${latest.name}: nessun pezzo disponibile in magazzino.',
        '${latest.name}: no stock available.',
      ));
    }

    final index = _cart.indexWhere(
      (line) => !line.isGeneric && line.variantId == latest.id,
    );
    final current = index < 0 ? null : _cart[index];
    final quantity = current?.quantity ?? 0;
    if (quantity >= latest.stockQuantity) {
      return _message(_itEn(
        '${latest.name}: nel carrello ci sono già tutti i ${latest.stockQuantity} pezzi disponibili.',
        '${latest.name}: all ${latest.stockQuantity} available items are already in the cart.',
      ));
    }

    final line = _CashLine.product(
      product: latest,
      quantity: quantity + 1,
      discountPercent: current?.discountPercent ?? 0,
    );
    if (index < 0) {
      _cart.add(line);
    } else {
      _cart[index] = line;
    }
    setState(() {
      _searchStatus = _itEn(
        'Aggiunto: ${latest.name} · ${latest.variantDisplay}. Quantità: ${line.quantity}.',
        'Added: ${latest.name} · ${latest.variantDisplay}. Quantity: ${line.quantity}.',
      );
      _cartStatus = AppStrings.t('sale_preparing');
    });
  }

  void _message(String value) => setState(() => _searchStatus = value);

  void _changeQuantity(_CashLine line, int delta) {
    final index = _cart.indexWhere((item) => item.key == line.key);
    if (index < 0) return;
    final next = line.quantity + delta;
    if (next < 1) {
      return _cartMessage(_itEn(
        'Usa «Rimuovi» per eliminare completamente la riga.',
        'Use “Remove” to delete the line completely.',
      ));
    }

    if (line.isGeneric) {
      if (next > 999) {
        return _cartMessage(_itEn(
          'Quantità massima raggiunta per l’articolo generico.',
          'Maximum quantity reached for the generic item.',
        ));
      }
      _cart[index] = line.copyWith(quantity: next);
      return setState(() => _cartStatus = _itEn(
            '${line.productName}: quantità aggiornata a $next.',
            '${line.productName}: quantity updated to $next.',
          ));
    }

    final variantId = line.variantId;
    if (variantId == null) return;
    final latest = widget.services.products.getById(variantId);
    if (latest == null ||
        !latest.isActive ||
        latest.salePriceCents == null ||
        latest.stockQuantity <= 0) {
      _cart.removeAt(index);
      _normalizeDiscounts();
      setState(() => _cartStatus = _itEn(
            'La variante non è più vendibile ed è stata rimossa dal carrello.',
            'The variant is no longer sellable and was removed from the cart.',
          ));
      return;
    }
    if (next > latest.stockQuantity) {
      return _cartMessage(_itEn(
        'Quantità massima raggiunta: ${latest.stockQuantity} pezzi disponibili.',
        'Maximum quantity reached: ${latest.stockQuantity} items available.',
      ));
    }
    _cart[index] = line.copyWith(product: latest, quantity: next);
    setState(() => _cartStatus = _itEn(
          '${latest.name}: quantità aggiornata a $next.',
          '${latest.name}: quantity updated to $next.',
        ));
  }

  void _cartMessage(String value) => setState(() => _cartStatus = value);

  void _setLineDiscount(_CashLine line, String value) {
    final percent =
        _clampPercent(double.tryParse(value.replaceAll(',', '.')) ?? 0);
    final index = _cart.indexWhere((item) => item.key == line.key);
    if (index < 0) return;
    _cart[index] = line.copyWith(discountPercent: percent);
    setState(() => _cartStatus = percent == 0
        ? _itEn(
            'Sconto rimosso da ${line.productName}.',
            'Discount removed from ${line.productName}.',
          )
        : _itEn(
            'Sconto del ${_percentText(percent)}% applicato a ${line.productName}.',
            '${_percentText(percent)}% discount applied to ${line.productName}.',
          ));
  }

  void _addPercentDiscount() {
    if (_cart.isEmpty) {
      return _cartMessage(_itEn(
        'Aggiungi almeno un articolo prima di inserire uno sconto percentuale.',
        'Add at least one item before entering a percentage discount.',
      ));
    }
    final parsed =
        double.tryParse(_totalPercent.text.trim().replaceAll(',', '.'))?.abs() ?? 0;
    final percent = _clampPercent(parsed);
    if (percent <= 0) {
      return _cartMessage(_itEn(
        'Inserisci uno sconto maggiore di 0% e premi Invio.',
        'Enter a discount greater than 0% and press Enter.',
      ));
    }

    final requestedCents = (_subtotalCents * percent / 100).round();
    final alreadyDiscounted =
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    final rawRemaining = _subtotalCents - alreadyDiscounted;
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    if (remaining <= 0) {
      return _cartMessage(_itEn(
        'Il totale è già interamente coperto dagli sconti inseriti.',
        'The total is already fully covered by the entered discounts.',
      ));
    }

    final cents = requestedCents > remaining ? remaining : requestedCents;
    if (cents <= 0) {
      return _cartMessage(_itEn(
        'Lo sconto percentuale calcolato è inferiore a un centesimo.',
        'The calculated percentage discount is less than one cent.',
      ));
    }

    _fixedDiscounts.add(
      _FixedDiscountLine(
        id: _nextDiscountId++,
        amountCents: cents,
        label: '${AppStrings.t('discount_amount')} ${_percentText(percent)}%',
      ),
    );
    _totalPercent.clear();
    setState(() => _cartStatus = _itEn(
          'Sconto ${_percentText(percent)}% aggiunto al carrello come −${formatMoney(cents)}.',
          '${_percentText(percent)}% discount added to the cart as −${formatMoney(cents)}.',
        ));
  }

  void _addFixedDiscount() {
    if (_cart.isEmpty) {
      return _cartMessage(_itEn(
        'Aggiungi almeno un articolo prima di inserire uno sconto in valuta.',
        'Add at least one item before entering a fixed discount.',
      ));
    }
    final parsed =
        double.tryParse(_fixedDiscount.text.trim().replaceAll(',', '.'))?.abs() ?? 0;
    final cents = (parsed * 100).round();
    if (cents <= 0) {
      return _cartMessage(_itEn(
        'Inserisci uno sconto maggiore di 0 e premi Invio.',
        'Enter a discount greater than 0 and press Enter.',
      ));
    }
    final rawRemaining = _afterPercentCents -
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    if (cents > remaining) {
      return _cartMessage(_itEn(
        'Lo sconto supera il totale residuo di ${formatMoney(remaining)}.',
        'The discount exceeds the remaining total of ${formatMoney(remaining)}.',
      ));
    }
    _fixedDiscounts.add(
      _FixedDiscountLine(
        id: _nextDiscountId++,
        amountCents: cents,
        label: '${AppStrings.t('discount_amount')} ${AppRuntime.currencySymbol}',
      ),
    );
    _fixedDiscount.clear();
    setState(() => _cartStatus = _itEn(
          'Sconto di ${formatMoney(cents)} aggiunto al carrello.',
          'Discount of ${formatMoney(cents)} added to the cart.',
        ));
  }

  void _removeLine(_CashLine line) {
    _cart.removeWhere((item) => item.key == line.key);
    _normalizeDiscounts();
    setState(() => _cartStatus = _itEn(
          '${line.productName} rimosso dal carrello.',
          '${line.productName} removed from the cart.',
        ));
  }

  void _removeFixed(_FixedDiscountLine line) {
    _fixedDiscounts.removeWhere((item) => item.id == line.id);
    setState(() => _cartStatus = _itEn(
          'Sconto di ${formatMoney(line.amountCents)} rimosso dal carrello.',
          'Discount of ${formatMoney(line.amountCents)} removed from the cart.',
        ));
  }

  void _clear({bool keepStatus = false}) {
    _cart.clear();
    _fixedDiscounts.clear();
    _customer = null;
    _totalPercent.clear();
    _fixedDiscount.clear();
    _keypadPriceCents = 0;
    if (!keepStatus) {
      setState(() => _cartStatus = _itEn(
            'Carrello svuotato. Nessun movimento di magazzino è stato registrato.',
            'Cart cleared. No stock movement was recorded.',
          ));
    }
  }

  void _normalizeDiscounts() {
    if (_cart.isEmpty) {
      _fixedDiscounts.clear();
      _totalPercent.clear();
      _fixedDiscount.clear();
    }
  }

  double get _totalDiscountPercent => _clampPercent(
        double.tryParse(_totalPercent.text.replaceAll(',', '.')) ?? 0,
      );
  int get _grossCents =>
      _cart.fold(0, (sum, line) => sum + line.grossLineTotalCents);
  int get _subtotalCents =>
      _cart.fold(0, (sum, line) => sum + line.lineTotalCents);
  int get _afterPercentCents =>
      _applyPercent(_subtotalCents, _totalDiscountPercent);
  int get _fixedCents {
    final requested =
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    return requested > _afterPercentCents ? _afterPercentCents : requested;
  }

  int get _finalTotalCents {
    final total = _afterPercentCents - _fixedCents;
    return total < 0 ? 0 : total;
  }

  int _applyPercent(int cents, double percent) =>
      (cents * (1 - _clampPercent(percent) / 100)).round();
  double _clampPercent(double value) => value.clamp(0, 100).toDouble();
  String _percentText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');

  void _registerSale() {
    if (_cart.isEmpty) return;
    final itemDiscountRaw = _grossCents - _subtotalCents;
    final itemDiscount = itemDiscountRaw < 0 ? 0 : itemDiscountRaw;
    final totalPercentDiscountRaw = _subtotalCents - _afterPercentCents;
    final totalPercentDiscount =
        totalPercentDiscountRaw < 0 ? 0 : totalPercentDiscountRaw;

    final draft = SalesOrderDraft(
      customerId: _customer?.id,
      lines: _cart
          .map((line) => SalesOrderDraftLine(
                variantId: line.variantId,
                sku: line.sku,
                barcode: line.barcode,
                productName: line.productName,
                variantDisplay: line.variantDisplay,
                quantity: line.quantity,
                unitPriceCents: line.unitPriceCents,
                discountBasisPoints: (line.discountPercent * 100).round(),
                grossTotalCents: line.grossLineTotalCents,
                finalTotalCents: line.lineTotalCents,
              ))
          .toList(growable: false),
      grossTotalCents: _grossCents,
      itemDiscountCents: itemDiscount,
      orderDiscountBasisPoints: (_totalDiscountPercent * 100).round(),
      orderPercentDiscountCents: totalPercentDiscount,
      fixedDiscountCents: _fixedCents,
      finalTotalCents: _finalTotalCents,
    );

    try {
      final order = widget.services.customers.recordSale(draft);
      _clear(keepStatus: true);
      setState(() {
        _cartStatus = _itEn(
          'Vendita ${order.orderNumber} registrata. Magazzino aggiornato dove previsto.',
          'Sale ${order.orderNumber} registered. Stock updated where applicable.',
        );
        _searchStatus = _itEn(
          'Vendita completata. Scanner pronto per il prossimo cliente o prodotto.',
          'Sale completed. Scanner ready for the next customer or product.',
        );
      });
    } catch (error) {
      setState(() => _cartStatus = _itEn(
            'Impossibile registrare la vendita: $error',
            'Unable to register the sale: $error',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final itemDiscountRaw = _grossCents - _subtotalCents;
    final itemDiscount = itemDiscountRaw < 0 ? 0 : itemDiscountRaw;
    final totalPercentDiscountRaw = _subtotalCents - _afterPercentCents;
    final totalPercentDiscount =
        totalPercentDiscountRaw < 0 ? 0 : totalPercentDiscountRaw;
    final count = _cart.fold<int>(0, (sum, line) => sum + line.quantity);

    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _submitSearch,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            AppStrings.t('cash'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code_scanner),
                        labelText: AppStrings.t('scan_search'),
                        hintText: AppStrings.t('scanner_hint'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_searchStatus),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 188,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: results.isEmpty
                            ? Center(child: Text(AppStrings.t('no_product_found')))
                            : ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final product = results[index];
                                  return ListTile(
                                    title: Text(product.name),
                                    subtitle: Text(
                                      '${product.variantDisplay} · SKU ${product.sku} · ${AppStrings.t('quantity').toLowerCase()} ${product.stockQuantity}',
                                    ),
                                    trailing: Text(product.salePriceDisplay),
                                    onTap: () => _add(product),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final keypadWidth = constraints.maxWidth > 500
                              ? 500.0
                              : constraints.maxWidth;
                          final keypadHeight = constraints.maxHeight > 460
                              ? 460.0
                              : constraints.maxHeight;
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: keypadWidth,
                              height: keypadHeight,
                              child: _CashKeypad(
                                priceText: formatMoney(_keypadPriceCents),
                                onKey: _keypadInsert,
                                onBackspace: _keypadBackspace,
                                onClear: _keypadClear,
                                onSubmit: _keypadSubmit,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${AppStrings.t('cart')} · $count ${AppStrings.t(count == 1 ? 'item' : 'items')}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cart.isEmpty &&
                                  _fixedDiscounts.isEmpty &&
                                  _customer == null &&
                                  _keypadPriceCents == 0
                              ? null
                              : _clear,
                          icon: const Icon(Icons.delete_sweep),
                          label: Text(AppStrings.t('clear')),
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _customer == null
                              ? Text(AppStrings.t('no_customer'))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _customer!.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(_customer!.fiscalCode),
                                  ],
                                ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickCustomer,
                          icon: const Icon(Icons.search),
                          label: Text(AppStrings.t(
                            _customer == null
                                ? 'search_customer'
                                : 'change_customer',
                          )),
                        ),
                        if (_customer != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: AppStrings.t('remove_customer'),
                            onPressed: () => setState(() => _customer = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _cart.isEmpty && _fixedDiscounts.isEmpty
                          ? Center(child: Text(AppStrings.t('empty_cart')))
                          : ListView(children: [
                              ..._cart.map((line) => _CartTile(
                                    line: line,
                                    onDecrease: () =>
                                        _changeQuantity(line, -1),
                                    onIncrease: () => _changeQuantity(line, 1),
                                    onDiscount: (value) =>
                                        _setLineDiscount(line, value),
                                    onRemove: () => _removeLine(line),
                                  )),
                              ..._fixedDiscounts.map((line) => ListTile(
                                    leading:
                                        const Icon(Icons.discount_outlined),
                                    title: Text(line.label),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '−${formatMoney(line.amountCents)}',
                                        ),
                                        IconButton(
                                          onPressed: () => _removeFixed(line),
                                          icon: const Icon(Icons.close),
                                        ),
                                      ],
                                    ),
                                  )),
                            ]),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _totalPercent,
                                enabled: _cart.isNotEmpty,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _addPercentDiscount(),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: AppStrings.t('discount_percent'),
                                  prefixText: '% ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _fixedDiscount,
                                enabled: _cart.isNotEmpty,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onSubmitted: (_) => _addFixedDiscount(),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText:
                                      '${AppStrings.t('discount_amount')} ${AppRuntime.currencySymbol}',
                                  prefixText: '${AppRuntime.currencySymbol} ',
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          if (itemDiscount > 0)
                            Text(
                              '${AppStrings.t('item_discounts')}: −${formatMoney(itemDiscount)}',
                            ),
                          if (totalPercentDiscount > 0)
                            Text(
                              '${AppStrings.t('discount_amount')} ${_percentText(_totalDiscountPercent)}%: −${formatMoney(totalPercentDiscount)}',
                            ),
                          if (_fixedCents > 0)
                            Text(
                              '${AppStrings.t('fixed_discounts')}: −${formatMoney(_fixedCents)}',
                            ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Text(
                                AppStrings.t('total'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              formatMoney(_finalTotalCents),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            _cartStatus,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _cart.isEmpty ? null : _registerSale,
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: Text(
                              _customer == null
                                  ? AppStrings.t('register_without_customer')
                                  : '${AppStrings.t('register_for')} ${_customer!.displayName}',
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.receipt_long),
                            label: Text(AppStrings.t('fiscal_document')),
                          ),
                        ],
                      ),
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

class _CashKeypad extends StatelessWidget {
  const _CashKeypad({
    required this.priceText,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    required this.onSubmit,
  });

  final String priceText;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  Widget _numberButton(String value, {int flex = 1}) => Expanded(
        flex: flex,
        child: SizedBox.expand(
          child: OutlinedButton(
            onPressed: () => onKey(value),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.dialpad_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppStrings.isEnglish
                          ? 'Generic item price'
                          : 'Prezzo articolo generico',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.isEnglish
                    ? 'Enter the amount, then confirm to add it to the cart.'
                    : 'Inserisci l’importo e conferma per aggiungerlo al carrello.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    priceText,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(children: [
                              _numberButton('7'),
                              const SizedBox(width: 6),
                              _numberButton('8'),
                              const SizedBox(width: 6),
                              _numberButton('9'),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Row(children: [
                              _numberButton('4'),
                              const SizedBox(width: 6),
                              _numberButton('5'),
                              const SizedBox(width: 6),
                              _numberButton('6'),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Row(children: [
                              _numberButton('1'),
                              const SizedBox(width: 6),
                              _numberButton('2'),
                              const SizedBox(width: 6),
                              _numberButton('3'),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Row(children: [
                              _numberButton('0'),
                              const SizedBox(width: 6),
                              _numberButton('00', flex: 2),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Expanded(
                            child: IconButton.outlined(
                              tooltip: AppStrings.isEnglish
                                  ? 'Backspace'
                                  : 'Cancella cifra',
                              onPressed: onBackspace,
                              icon: const Icon(Icons.backspace_outlined),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onClear,
                              child: const Text('C'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: FilledButton(
                              onPressed: onSubmit,
                              child:
                                  const Icon(Icons.keyboard_return_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  line.isGeneric
                      ? '${AppStrings.isEnglish ? 'Generic item' : 'Articolo generico'} · ${formatMoney(line.unitPriceCents)} ${AppStrings.t('each')}'
                      : '${line.variantDisplay} · ${line.sku} · ${formatMoney(line.unitPriceCents)} ${AppStrings.t('each')}',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${line.quantity}'),
          IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_circle_outline),
          ),
          SizedBox(
            width: 84,
            child: TextFormField(
              key: ValueKey('${line.key}-${line.discountPercent}'),
              initialValue: line.discountPercent == 0
                  ? ''
                  : line.discountPercent.toString().replaceAll('.', ','),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: onDiscount,
              decoration: InputDecoration(
                isDense: true,
                labelText: AppStrings.isEnglish ? 'Discount' : 'Sconto',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixText: '%',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              formatMoney(line.lineTotalCents),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: AppStrings.t('remove'),
            icon: const Icon(Icons.close),
          ),
        ]),
      );
}

class _CashLine {
  const _CashLine.product({
    required ProductVariant product,
    required this.quantity,
    required this.discountPercent,
  })  : product = product,
        genericId = null,
        genericName = null,
        genericUnitPriceCents = null;

  const _CashLine.generic({
    required int genericId,
    required String genericName,
    required int unitPriceCents,
    required this.quantity,
    required this.discountPercent,
  })  : product = null,
        genericId = genericId,
        genericName = genericName,
        genericUnitPriceCents = unitPriceCents;

  final ProductVariant? product;
  final int? genericId;
  final String? genericName;
  final int? genericUnitPriceCents;
  final int quantity;
  final double discountPercent;

  bool get isGeneric => product == null;
  String get key => isGeneric ? 'generic-$genericId' : 'variant-${product!.id}';
  int? get variantId => product?.id;
  String get sku => product?.sku ?? 'GENERIC';
  String? get barcode => product?.barcode;
  String get productName => product?.name ?? genericName ?? 'Articolo generico';
  String get variantDisplay => product?.variantDisplay ?? '';
  int get unitPriceCents => product?.salePriceCents ?? genericUnitPriceCents ?? 0;
  int get grossLineTotalCents => unitPriceCents * quantity;
  int get lineTotalCents =>
      (grossLineTotalCents * (1 - discountPercent.clamp(0, 100) / 100))
          .round();

  _CashLine copyWith({
    ProductVariant? product,
    int? quantity,
    double? discountPercent,
  }) {
    if (isGeneric) {
      return _CashLine.generic(
        genericId: genericId!,
        genericName: genericName!,
        unitPriceCents: genericUnitPriceCents!,
        quantity: quantity ?? this.quantity,
        discountPercent: discountPercent ?? this.discountPercent,
      );
    }
    return _CashLine.product(
      product: product ?? this.product!,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}

class _FixedDiscountLine {
  const _FixedDiscountLine({
    required this.id,
    required this.amountCents,
    required this.label,
  });

  final int id;
  final int amountCents;
  final String label;
}