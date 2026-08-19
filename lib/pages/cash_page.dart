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
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _totalPercent = TextEditingController();
  final _fixedDiscount = TextEditingController();
  final List<_CashLine> _cart = [];
  final List<_FixedDiscountLine> _fixedDiscounts = [];
  Customer? _customer;
  int _nextDiscountId = 1;
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
    _searchFocus.dispose();
    _totalPercent.dispose();
    _fixedDiscount.dispose();
    super.dispose();
  }

  List<ProductVariant> get _results => widget.services.products.search(_search.text, 50);

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

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

    final index = _cart.indexWhere((line) => line.variantId == latest.id);
    final current = index < 0 ? null : _cart[index];
    final quantity = current?.quantity ?? 0;
    if (quantity >= latest.stockQuantity) {
      return _message(_itEn(
        '${latest.name}: nel carrello ci sono già tutti i ${latest.stockQuantity} pezzi disponibili.',
        '${latest.name}: all ${latest.stockQuantity} available items are already in the cart.',
      ));
    }

    final line = _CashLine(
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
    final index = _cart.indexWhere((item) => item.variantId == line.variantId);
    if (index < 0) return;
    final latest = widget.services.products.getById(line.variantId);
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
    final next = _cart[index].quantity + delta;
    if (next < 1) {
      return _cartMessage(_itEn(
        'Usa «Rimuovi» per eliminare completamente la riga.',
        'Use “Remove” to delete the line completely.',
      ));
    }
    if (next > latest.stockQuantity) {
      return _cartMessage(_itEn(
        'Quantità massima raggiunta: ${latest.stockQuantity} pezzi disponibili.',
        'Maximum quantity reached: ${latest.stockQuantity} items available.',
      ));
    }
    _cart[index] = _CashLine(
      product: latest,
      quantity: next,
      discountPercent: line.discountPercent,
    );
    setState(() => _cartStatus = _itEn(
          '${latest.name}: quantità aggiornata a $next.',
          '${latest.name}: quantity updated to $next.',
        ));
  }

  void _cartMessage(String value) => setState(() => _cartStatus = value);

  void _setLineDiscount(_CashLine line, String value) {
    final percent =
        _clampPercent(double.tryParse(value.replaceAll(',', '.')) ?? 0);
    final index = _cart.indexWhere((e) => e.variantId == line.variantId);
    if (index < 0) return;
    _cart[index] = line.copyWith(discountPercent: percent);
    setState(() => _cartStatus = percent == 0
        ? _itEn(
            'Sconto rimosso da ${line.product.name}.',
            'Discount removed from ${line.product.name}.',
          )
        : _itEn(
            'Sconto del ${_percentText(percent)}% applicato a ${line.product.name}.',
            '${_percentText(percent)}% discount applied to ${line.product.name}.',
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
    _cart.removeWhere((e) => e.variantId == line.variantId);
    _normalizeDiscounts();
    setState(() => _cartStatus = _itEn(
          '${line.product.name} rimosso dal carrello.',
          '${line.product.name} removed from the cart.',
        ));
  }

  void _removeFixed(_FixedDiscountLine line) {
    _fixedDiscounts.removeWhere((e) => e.id == line.id);
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
                sku: line.product.sku,
                barcode: line.product.barcode,
                productName: line.product.name,
                variantDisplay: line.product.variantDisplay,
                quantity: line.quantity,
                unitPriceCents: line.product.salePriceCents ?? 0,
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
          'Vendita ${order.orderNumber} registrata. Magazzino aggiornato.',
          'Sale ${order.orderNumber} registered. Stock updated.',
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
          Text(AppStrings.t('cash'),
              style: Theme.of(context).textTheme.headlineMedium),
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
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: results.isEmpty
                          ? Center(child: Text(AppStrings.t('no_product_found')))
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
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
                        Expanded(
                          child: Text(
                            '${AppStrings.t('cart')} · $count ${AppStrings.t(count == 1 ? 'item' : 'items')}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cart.isEmpty &&
                                  _fixedDiscounts.isEmpty &&
                                  _customer == null
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
                                    onDecrease: () => _changeQuantity(line, -1),
                                    onIncrease: () => _changeQuantity(line, 1),
                                    onDiscount: (value) =>
                                        _setLineDiscount(line, value),
                                    onRemove: () => _removeLine(line),
                                  )),
                              ..._fixedDiscounts.map((line) => ListTile(
                                    leading: const Icon(Icons.discount_outlined),
                                    title: Text(line.label),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('−${formatMoney(line.amountCents)}'),
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
                                keyboardType: const TextInputType.numberWithOptions(
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
                                keyboardType: const TextInputType.numberWithOptions(
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
                  line.product.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${line.product.variantDisplay} · ${line.product.sku} · ${formatMoney(line.product.salePriceCents)} ${AppStrings.t('each')}',
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
              key: ValueKey('${line.variantId}-${line.discountPercent}'),
              initialValue: line.discountPercent == 0
                  ? ''
                  : line.discountPercent.toString().replaceAll('.', ','),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: onDiscount,
              decoration: InputDecoration(
                isDense: true,
                labelText: AppStrings.t('discount_percent'),
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
  const _CashLine({
    required this.product,
    required this.quantity,
    required this.discountPercent,
  });
  final ProductVariant product;
  final int quantity;
  final double discountPercent;
  int get variantId => product.id;
  int get grossLineTotalCents => (product.salePriceCents ?? 0) * quantity;
  int get lineTotalCents =>
      (grossLineTotalCents * (1 - discountPercent.clamp(0, 100) / 100)).round();
  _CashLine copyWith({double? discountPercent}) => _CashLine(
        product: product,
        quantity: quantity,
        discountPercent: discountPercent ?? this.discountPercent,
      );
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
