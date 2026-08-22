import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_runtime.dart';
import '../core/formatters.dart';
import '../core/vat_calculator.dart';
import '../l10n/app_strings.dart';
import '../models/catalog.dart';
import '../models/customer.dart';
import '../services/app_services.dart';
import '../services/fiscal_code_service.dart';
import '../theme/ui_style_tokens.dart';
import '../widgets/hid_barcode_listener.dart';
import 'customer_editor_dialog.dart';
import 'customer_picker_dialog.dart';
import 'gift_card_purchase_dialog.dart';

enum _ProductViewMode { list, grid }

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
  GiftCard? _giftCard;
  int _nextDiscountId = 1;
  int _nextGenericLineId = 1;
  int _nextGiftCardLineId = 1;
  int _keypadPriceCents = 0;
  bool _showKeypad = false;
  _ProductViewMode _productViewMode = _ProductViewMode.list;
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

  String _dateText(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

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
        _giftCard = null;
        _searchStatus = _itEn(
          'Cliente associato: ${existing.displayName} (${existing.customerCodeDisplay}).',
          'Customer linked: ${existing.displayName} (${existing.customerCodeDisplay}).',
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
      _giftCard = null;
      _searchStatus = _itEn(
        'Nuovo cliente associato: ${created.displayName} (${created.customerCodeDisplay}).',
        'New customer linked: ${created.displayName} (${created.customerCodeDisplay}).',
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
      _giftCard = null;
      _searchStatus = _itEn(
        'Cliente associato: ${customer.displayName} (${customer.customerCodeDisplay}).',
        'Customer linked: ${customer.displayName} (${customer.customerCodeDisplay}).',
      );
    });
  }

  Future<void> _addGiftCardPurchase() async {
    final customer = _customer;
    if (customer == null) {
      return _cartMessage(_itEn(
        'Associa prima un cliente per acquistare un buono regalo.',
        'Link a customer before purchasing a gift card.',
      ));
    }

    final draft = await showGiftCardPurchaseDialog(
      context,
      customerName: customer.displayName,
    );
    if (!mounted || draft == null) return;

    final line = _CashLine.giftCard(
      giftCardLineId: _nextGiftCardLineId++,
      unitPriceCents: draft.valueCents,
      expiresAtUtc: draft.expiresAtUtc,
    );
    setState(() {
      _cart.add(line);
      _cartStatus = draft.expiresAtUtc == null
          ? _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello senza scadenza.',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart with no expiration.',
            )
          : _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello. Scadenza: ${_dateText(draft.expiresAtUtc!)}.',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart. Expires: ${_dateText(draft.expiresAtUtc!)}.',
            );
    });
  }

  Future<void> _pickGiftCard() async {
    final customer = _customer;
    if (customer == null) {
      return _cartMessage(_itEn(
        'Associa prima un cliente per usare un buono regalo.',
        'Link a customer before using a gift card.',
      ));
    }

    final cards =
        widget.services.customers.availableGiftCardsForCustomer(customer.id);
    if (cards.isEmpty) {
      return _cartMessage(_itEn(
        'Il cliente non ha buoni regalo validi con credito residuo.',
        'The customer has no valid gift cards with remaining credit.',
      ));
    }

    final selected = await showDialog<GiftCard>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_itEn('Seleziona buono regalo', 'Select gift card')),
        content: SizedBox(
          width: 560,
          height: (cards.length * 88.0).clamp(170.0, 440.0).toDouble(),
          child: ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final card = cards[index];
              final expiration = card.expirationDateDisplay;
              return ListTile(
                leading: const Icon(Icons.card_giftcard_outlined),
                title: Text(
                  card.code,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_itEn('Valore totale', 'Total value')}: ${card.totalDisplay} · '
                  '${_itEn('Speso', 'Spent')}: ${card.spentDisplay}\n'
                  '${_itEn('Acquistato', 'Purchased')}: ${card.purchasedDateDisplay} · '
                  '${expiration == null ? _itEn('Nessuna scadenza', 'No expiration') : '${_itEn('Scadenza', 'Expires')}: $expiration'}',
                ),
                trailing: Text(
                  '${_itEn('Residuo', 'Remaining')}\n${card.remainingDisplay}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.of(dialogContext).pop(card),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.t('cancel')),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _giftCard = selected;
      _cartStatus = _itEn(
        'Buono ${selected.code} aggiunto al carrello. Credito residuo: ${selected.remainingDisplay}.',
        'Gift card ${selected.code} added to the cart. Remaining credit: ${selected.remainingDisplay}.',
      );
    });
  }

  void _removeCustomer() {
    final pendingGiftCards =
        _cart.where((line) => line.isGiftCardPurchase).length;
    setState(() {
      _customer = null;
      _giftCard = null;
      _cart.removeWhere((line) => line.isGiftCardPurchase);
      _normalizeDiscounts();
      _cartStatus = pendingGiftCards > 0
          ? _itEn(
              'Cliente rimosso. Sono stati rimossi anche $pendingGiftCards buoni regalo in acquisto e l’eventuale buono usato come pagamento.',
              'Customer removed. $pendingGiftCards gift-card purchases and any gift card used as payment were removed too.',
            )
          : _itEn(
              'Cliente rimosso dal carrello. L’eventuale buono regalo è stato rimosso.',
              'Customer removed from the cart. Any selected gift card was removed too.',
            );
    });
  }

  void _removeGiftCard() {
    final card = _giftCard;
    if (card == null) return;
    setState(() {
      _giftCard = null;
      _cartStatus = _itEn(
        'Buono ${card.code} rimosso dal carrello.',
        'Gift card ${card.code} removed from the cart.',
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
      (line) => !line.isGeneric &&
          !line.isGiftCardPurchase &&
          line.variantId == latest.id,
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
    if (line.isGiftCardPurchase) {
      return _cartMessage(_itEn(
        'Ogni buono regalo è una riga singola. Aggiungi un altro buono per crearne più di uno.',
        'Each gift card is a single cart line. Add another gift card to create more than one.',
      ));
    }

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
    if (line.isGiftCardPurchase) {
      return _cartMessage(_itEn(
        'Il prezzo di un buono regalo deve coincidere con il suo valore e non può essere scontato.',
        'A gift card price must match its value and cannot be discounted.',
      ));
    }
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
    if (!_hasDiscountableItems) {
      return _cartMessage(_itEn(
        'Aggiungi almeno un articolo scontabile prima di inserire uno sconto percentuale.',
        'Add at least one discountable item before entering a percentage discount.',
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

    final requestedCents =
        (_discountableSubtotalCents * percent / 100).round();
    final alreadyDiscounted =
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    final rawRemaining = _discountableSubtotalCents - alreadyDiscounted;
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    if (remaining <= 0) {
      return _cartMessage(_itEn(
        'Il totale scontabile è già interamente coperto dagli sconti inseriti.',
        'The discountable total is already fully covered by the entered discounts.',
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
    if (!_hasDiscountableItems) {
      return _cartMessage(_itEn(
        'Aggiungi almeno un articolo scontabile prima di inserire uno sconto in valuta.',
        'Add at least one discountable item before entering a fixed discount.',
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
    final rawRemaining = _afterPercentDiscountableCents -
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    final remaining = rawRemaining < 0 ? 0 : rawRemaining;
    if (cents > remaining) {
      return _cartMessage(_itEn(
        'Lo sconto supera il totale scontabile residuo di ${formatMoney(remaining)}.',
        'The discount exceeds the remaining discountable total of ${formatMoney(remaining)}.',
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
    _giftCard = null;
    _totalPercent.clear();
    _fixedDiscount.clear();
    _keypadPriceCents = 0;
    if (!keepStatus) {
      setState(() => _cartStatus = _itEn(
            'Carrello svuotato. Nessun movimento di magazzino o buono regalo è stato registrato.',
            'Cart cleared. No stock movement or gift-card usage was recorded.',
          ));
    }
  }

  void _normalizeDiscounts() {
    if (!_hasDiscountableItems) {
      _fixedDiscounts.clear();
      _totalPercent.clear();
      _fixedDiscount.clear();
    }
  }

  bool get _hasDiscountableItems =>
      _cart.any((line) => !line.isGiftCardPurchase);
  double get _totalDiscountPercent => _clampPercent(
        double.tryParse(_totalPercent.text.replaceAll(',', '.')) ?? 0,
      );
  int get _giftCardPurchaseCents => _cart
      .where((line) => line.isGiftCardPurchase)
      .fold(0, (sum, line) => sum + line.grossLineTotalCents);
  int get _discountableGrossCents => _cart
      .where((line) => !line.isGiftCardPurchase)
      .fold(0, (sum, line) => sum + line.grossLineTotalCents);
  int get _grossCents => _discountableGrossCents + _giftCardPurchaseCents;
  int get _discountableSubtotalCents => _cart
      .where((line) => !line.isGiftCardPurchase)
      .fold(0, (sum, line) => sum + line.lineTotalCents);
  int get _afterPercentDiscountableCents =>
      _applyPercent(_discountableSubtotalCents, _totalDiscountPercent);
  int get _fixedCents {
    final requested =
        _fixedDiscounts.fold<int>(0, (sum, line) => sum + line.amountCents);
    return requested > _afterPercentDiscountableCents
        ? _afterPercentDiscountableCents
        : requested;
  }

  int get _discountableFinalCents {
    final total = _afterPercentDiscountableCents - _fixedCents;
    return total < 0 ? 0 : total;
  }

  int get _finalTotalCents => _discountableFinalCents + _giftCardPurchaseCents;

  int get _giftCardAppliedCents {
    final card = _giftCard;
    if (card == null || _discountableFinalCents <= 0) return 0;
    return card.remainingValueCents < _discountableFinalCents
        ? card.remainingValueCents
        : _discountableFinalCents;
  }

  int get _amountDueCents {
    final value = _finalTotalCents - _giftCardAppliedCents;
    return value < 0 ? 0 : value;
  }

  int get _giftCardRemainingAfterSaleCents {
    final card = _giftCard;
    if (card == null) return 0;
    final value = card.remainingValueCents - _giftCardAppliedCents;
    return value < 0 ? 0 : value;
  }

  int _applyPercent(int cents, double percent) =>
      (cents * (1 - _clampPercent(percent) / 100)).round();
  double _clampPercent(double value) => value.clamp(0, 100).toDouble();
  String _percentText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');

  void _registerSale() {
    if (_cart.isEmpty) return;
    final pendingGiftCards =
        _cart.where((line) => line.isGiftCardPurchase).toList(growable: false);
    final customer = _customer;
    if (pendingGiftCards.isNotEmpty && customer == null) {
      return _cartMessage(_itEn(
        'Associa un cliente prima di registrare l’acquisto del buono regalo.',
        'Link a customer before registering the gift-card purchase.',
      ));
    }

    final itemDiscountRaw =
        _discountableGrossCents - _discountableSubtotalCents;
    final itemDiscount = itemDiscountRaw < 0 ? 0 : itemDiscountRaw;
    final totalPercentDiscountRaw =
        _discountableSubtotalCents - _afterPercentDiscountableCents;
    final totalPercentDiscount =
        totalPercentDiscountRaw < 0 ? 0 : totalPercentDiscountRaw;
    final giftApplied = _giftCardAppliedCents;

    final draft = SalesOrderDraft(
      customerId: customer?.id,
      giftCardId: giftApplied > 0 ? _giftCard?.id : null,
      giftCardAppliedCents: giftApplied,
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

    SalesOrderSummary? order;
    final createdGiftCards = <GiftCard>[];
    try {
      final registeredOrder = widget.services.customers.recordSale(draft);
      order = registeredOrder;
      if (pendingGiftCards.isNotEmpty) {
        for (final line in pendingGiftCards) {
          createdGiftCards.add(
            widget.services.customers.createGiftCard(
              customer!.id,
              line.unitPriceCents,
              expiresAtUtc: line.giftCardExpiresAtUtc,
            ),
          );
        }
      }

      final usedGift = giftApplied > 0;
      final usedGiftCode = _giftCard?.code;
      final createdCodes = createdGiftCards.map((card) => card.code).join(', ');
      _clear(keepStatus: true);
      setState(() {
        final details = <String>[];
        if (createdGiftCards.isNotEmpty) {
          details.add(_itEn(
            'Buoni creati: $createdCodes.',
            'Gift cards created: $createdCodes.',
          ));
        }
        if (usedGift) {
          details.add(_itEn(
            'Usati ${formatMoney(giftApplied)} dal buono $usedGiftCode.',
            '${formatMoney(giftApplied)} used from gift card $usedGiftCode.',
          ));
        }
        _cartStatus = _itEn(
              'Vendita ${registeredOrder.orderNumber} registrata. Magazzino aggiornato dove previsto.',
              'Sale ${registeredOrder.orderNumber} registered. Stock updated where applicable.',
            ) +
            (details.isEmpty ? '' : ' ${details.join(' ')}');
        _searchStatus = _itEn(
          'Vendita completata. Scanner pronto per il prossimo cliente o prodotto.',
          'Sale completed. Scanner ready for the next customer or product.',
        );
      });
    } catch (error) {
      for (final card in createdGiftCards.reversed) {
        try {
          widget.services.customers.deleteGiftCard(card.id);
        } catch (_) {}
      }
      if (order != null) {
        try {
          widget.services.customers.cancelOrder(order.id);
          widget.services.customers.deleteOrder(order.id);
        } catch (_) {}
      }
      setState(() => _cartStatus = _itEn(
            'Impossibile registrare la vendita: $error',
            'Unable to register the sale: $error',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final variantImages = _productViewMode == _ProductViewMode.grid
        ? widget.services.variantImages.getMany(results.map((item) => item.id))
        : const <int, Uint8List>{};
    final cartVariantImages = widget.services.variantImages.getMany(
      _cart.map((line) => line.variantId).whereType<int>(),
    );
    final itemDiscountRaw =
        _discountableGrossCents - _discountableSubtotalCents;
    final itemDiscount = itemDiscountRaw < 0 ? 0 : itemDiscountRaw;
    final totalPercentDiscountRaw =
        _discountableSubtotalCents - _afterPercentDiscountableCents;
    final totalPercentDiscount =
        totalPercentDiscountRaw < 0 ? 0 : totalPercentDiscountRaw;
    final count = _cart.fold<int>(0, (sum, line) => sum + line.quantity);
    final vatPercent = widget.services.settings.load().vatPercent;
    final vatCents = calculateVatCents(_finalTotalCents, vatPercent);
    final availableGiftCards = _customer == null
        ? const <GiftCard>[]
        : widget.services.customers.availableGiftCardsForCustomer(_customer!.id);
    final fiscalCode = _customer?.fiscalCode?.trim();

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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
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
                        ),
                        const SizedBox(width: 8),
                        SegmentedButton<_ProductViewMode>(
                          segments: [
                            ButtonSegment<_ProductViewMode>(
                              value: _ProductViewMode.list,
                              icon: const Icon(Icons.view_list_rounded),
                              tooltip: _itEn(
                                'Visualizzazione elenco',
                                'List view',
                              ),
                            ),
                            ButtonSegment<_ProductViewMode>(
                              value: _ProductViewMode.grid,
                              icon: const Icon(Icons.grid_view_rounded),
                              tooltip: _itEn(
                                'Visualizzazione anteprima',
                                'Preview grid view',
                              ),
                            ),
                          ],
                          selected: {_productViewMode},
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            minimumSize: const Size(44, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                          onSelectionChanged: (value) => setState(
                            () => _productViewMode = value.first,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_searchStatus),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: results.isEmpty
                            ? Center(child: Text(AppStrings.t('no_product_found')))
                            : _productViewMode == _ProductViewMode.list
                                ? ListView.separated(
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
                                        trailing:
                                            Text(product.salePriceDisplay),
                                        onTap: () => _add(product),
                                      );
                                    },
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final calculated =
                                          (constraints.maxWidth / 210).floor();
                                      final columns = calculated < 2
                                          ? 2
                                          : calculated > 6
                                              ? 6
                                              : calculated;
                                      return GridView.builder(
                                        padding: const EdgeInsets.all(10),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: 0.88,
                                        ),
                                        itemCount: results.length,
                                        itemBuilder: (context, index) {
                                          final product = results[index];
                                          return _ProductGridTile(
                                            product: product,
                                            imageBytes:
                                                variantImages[product.id],
                                            onTap: () => _add(product),
                                          );
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 500,
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
                                  _giftCard == null &&
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
                      child: Column(children: [
                        Row(children: [
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
                                      Text(
                                        _customer!.customerCodeDisplay +
                                            (fiscalCode?.isNotEmpty == true
                                                ? ' · CF $fiscalCode'
                                                : ''),
                                      ),
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
                              onPressed: _removeCustomer,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ]),
                        if (_customer != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.card_giftcard_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _giftCard == null
                                    ? _itEn(
                                        '${availableGiftCards.length} buoni validi con credito residuo',
                                        '${availableGiftCards.length} valid gift cards with remaining credit',
                                      )
                                    : '${_giftCard!.code} · ${_itEn('residuo', 'remaining')} ${_giftCard!.remainingDisplay}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _addGiftCardPurchase,
                              icon: const Icon(Icons.add_card_outlined),
                              label: Text(_itEn('Nuovo buono', 'New gift card')),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              onPressed: availableGiftCards.isEmpty
                                  ? null
                                  : _pickGiftCard,
                              icon: const Icon(Icons.redeem_outlined),
                              label: Text(
                                _giftCard == null
                                    ? _itEn('Usa buono', 'Use gift card')
                                    : _itEn('Cambia', 'Change'),
                              ),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _cart.isEmpty &&
                              _fixedDiscounts.isEmpty &&
                              _giftCard == null
                          ? Center(child: Text(AppStrings.t('empty_cart')))
                          : ListView(children: [
                              ..._cart.map((line) => _CartTile(
                                    key: ValueKey(line.key),
                                    line: line,
                                    imageBytes: line.variantId == null
                                        ? null
                                        : cartVariantImages[line.variantId],
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
                              if (_giftCard != null)
                                ListTile(
                                  leading: const Icon(Icons.card_giftcard_outlined),
                                  title: Text(
                                    '${_itEn('Buono regalo', 'Gift card')} ${_giftCard!.code}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${_itEn('Residuo disponibile', 'Available credit')}: ${_giftCard!.remainingDisplay} · '
                                    '${_itEn('Residuo dopo vendita', 'Credit after sale')}: ${formatMoney(_giftCardRemainingAfterSaleCents)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _giftCardAppliedCents > 0
                                            ? '−${formatMoney(_giftCardAppliedCents)}'
                                            : formatMoney(0),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _removeGiftCard,
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                ),
                            ]),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _totalPercent,
                                enabled: _hasDiscountableItems,
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
                                enabled: _hasDiscountableItems,
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
                          if (_giftCardPurchaseCents > 0)
                            Text(
                              '${_itEn('Buoni regalo in acquisto', 'Gift cards being purchased')}: ${formatMoney(_giftCardPurchaseCents)}',
                            ),
                          if (_giftCard != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_itEn('Totale vendita', 'Sale total')}: ${formatMoney(_finalTotalCents)}',
                            ),
                            if (_giftCardAppliedCents > 0)
                              Text(
                                '${_itEn('Buono regalo', 'Gift card')} ${_giftCard!.code}: −${formatMoney(_giftCardAppliedCents)}',
                              ),
                          ],
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Text(
                                _giftCard == null
                                    ? AppStrings.t('total')
                                    : _itEn('Totale da pagare', 'Amount due'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              formatMoney(
                                _giftCard == null
                                    ? _finalTotalCents
                                    : _amountDueCents,
                              ),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Text(
                                '${AppStrings.t('vat_included')} (${_percentText(vatPercent)}%)',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              formatMoney(vatCents),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ]),
                        ],
                      ),
                    ),
                    if (_showKeypad) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: (MediaQuery.sizeOf(context).height * 0.32)
                            .clamp(300.0, 460.0)
                            .toDouble(),
                        child: _CashKeypad(
                          priceText: formatMoney(_keypadPriceCents),
                          onKey: _keypadInsert,
                          onBackspace: _keypadBackspace,
                          onClear: _keypadClear,
                          onSubmit: _keypadSubmit,
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _cartStatus,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 108,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed:
                                        _cart.isEmpty ? null : _registerSale,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 26,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _itEn(
                                            'Registra vendita',
                                            'Register sale',
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: null,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.receipt_long, size: 26),
                                        const SizedBox(height: 6),
                                        Text(
                                          _itEn(
                                            'Emetti scontrino',
                                            'Issue receipt',
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                      () => _showKeypad = !_showKeypad,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _showKeypad
                                              ? Icons.keyboard_hide_outlined
                                              : Icons.keyboard_alt_outlined,
                                          size: 26,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _showKeypad
                                              ? _itEn(
                                                  'Nascondi tastierino',
                                                  'Hide keypad',
                                                )
                                              : _itEn(
                                                  'Mostra tastierino',
                                                  'Show keypad',
                                                ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

class _ProductGridTile extends StatelessWidget {
  const _ProductGridTile({
    required this.product,
    required this.imageBytes,
    required this.onTap,
  });

  final ProductVariant product;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageBytes == null
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_outlined,
                            size: 52,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          product.salePriceDisplay,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.variantDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SKU ${product.sku}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${product.stockQuantity}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _CartTile extends StatefulWidget {
  const _CartTile({
    super.key,
    required this.line,
    required this.imageBytes,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDiscount,
    required this.onRemove,
  });

  final _CashLine line;
  final Uint8List? imageBytes;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onDiscount;
  final VoidCallback onRemove;

  @override
  State<_CartTile> createState() => _CartTileState();
}

class _CartTileState extends State<_CartTile> {
  final GlobalKey _articleKey = GlobalKey();
  OverlayEntry? _previewOverlay;

  void _showPreview() {
    final bytes = widget.imageBytes;
    if (bytes == null || _previewOverlay != null || !mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final targetBox =
        _articleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (targetBox == null || overlayBox == null) return;

    final targetTopLeft =
        targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    const previewBodySize = 190.0;
    const arrowWidth = 12.0;
    const previewWidth = previewBodySize + arrowWidth;
    const previewHeight = previewBodySize;
    const gap = 10.0;
    const edgePadding = 8.0;

    final showLeft = targetTopLeft.dx >= previewWidth + gap + edgePadding;
    final rawLeft = showLeft
        ? targetTopLeft.dx - previewWidth - gap
        : targetTopLeft.dx + targetBox.size.width + gap;
    final maxLeft = overlayBox.size.width - previewWidth - edgePadding;
    final left = rawLeft.clamp(edgePadding, maxLeft).toDouble();

    final rawTop = targetTopLeft.dy +
        (targetBox.size.height / 2) -
        (previewHeight / 2);
    final maxTop = overlayBox.size.height - previewHeight - edgePadding;
    final top = rawTop.clamp(edgePadding, maxTop).toDouble();

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: _CartImageHoverPreview(
              imageBytes: bytes,
              arrowOnRight: showLeft,
            ),
          ),
        ),
      ),
    );
    _previewOverlay = entry;
    overlay.insert(entry);
  }

  void _hidePreview() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }

  Future<void> _showLargeImage() async {
    final bytes = widget.imageBytes;
    if (bytes == null) return;
    _hidePreview();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return AlertDialog(
          title: Text(widget.line.cartTitle),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.72,
              maxHeight: size.height * 0.72,
            ),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
              label: Text(AppStrings.pair('Chiudi', 'Close')),
            ),
          ],
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant _CartTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) _hidePreview();
  }

  @override
  void dispose() {
    _hidePreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final bytes = widget.imageBytes;
    final theme = Theme.of(context);
    final articleDetails = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.cartTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(line.cartSubtitle),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        Flexible(
          fit: FlexFit.loose,
          child: MouseRegion(
            key: _articleKey,
            cursor: bytes == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            onEnter: bytes == null ? null : (_) => _showPreview(),
            onExit: bytes == null ? null : (_) => _hidePreview(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: bytes == null ? null : _showLargeImage,
              child: articleDetails,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: line.isGiftCardPurchase ? null : widget.onDecrease,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('${line.quantity}'),
        IconButton(
          onPressed: line.isGiftCardPurchase ? null : widget.onIncrease,
          icon: const Icon(Icons.add_circle_outline),
        ),
        SizedBox(
          width: 84,
          child: TextFormField(
            key: ValueKey('${line.key}-${line.discountPercent}'),
            initialValue: line.discountPercent == 0
                ? ''
                : line.discountPercent.toString().replaceAll('.', ','),
            enabled: !line.isGiftCardPurchase,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onFieldSubmitted: widget.onDiscount,
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
          onPressed: widget.onRemove,
          tooltip: AppStrings.t('remove'),
          icon: const Icon(Icons.close),
        ),
      ]),
    );
  }
}

class _CartImageHoverPreview extends StatelessWidget {
  const _CartImageHoverPreview({
    required this.imageBytes,
    required this.arrowOnRight,
  });

  final Uint8List imageBytes;
  final bool arrowOnRight;

  @override
  Widget build(BuildContext context) {
    final tokens = UiStyleTokens.of(context);
    final background = tokens.tooltipSurface;
    final border = tokens.tooltipBorder;
    final shadow = tokens.tooltipShadow;

    final body = Container(
      width: 190,
      height: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: tokens.imagePreviewSurface,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );

    final arrow = CustomPaint(
      size: const Size(12, 28),
      painter: _CartPreviewArrowPainter(
        fillColor: background,
        borderColor: border,
        shadowColor: shadow,
        pointsRight: arrowOnRight,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: arrowOnRight ? [body, arrow] : [arrow, body],
    );
  }
}

class _CartPreviewArrowPainter extends CustomPainter {
  const _CartPreviewArrowPainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
    required this.pointsRight,
  });

  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    path.close();

    canvas.drawShadow(path, shadowColor, 5, true);
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CartPreviewArrowPainter oldDelegate) =>
      fillColor != oldDelegate.fillColor ||
      borderColor != oldDelegate.borderColor ||
      shadowColor != oldDelegate.shadowColor ||
      pointsRight != oldDelegate.pointsRight;
}

class _CashLine {
  const _CashLine.product({
    required ProductVariant product,
    required this.quantity,
    required this.discountPercent,
  })  : product = product,
        genericId = null,
        genericName = null,
        genericUnitPriceCents = null,
        giftCardLineId = null,
        giftCardExpiresAtUtc = null;

  const _CashLine.generic({
    required int genericId,
    required String genericName,
    required int unitPriceCents,
    required this.quantity,
    required this.discountPercent,
  })  : product = null,
        genericId = genericId,
        genericName = genericName,
        genericUnitPriceCents = unitPriceCents,
        giftCardLineId = null,
        giftCardExpiresAtUtc = null;

  const _CashLine.giftCard({
    required int giftCardLineId,
    required int unitPriceCents,
    DateTime? expiresAtUtc,
  })  : product = null,
        genericId = null,
        genericName = 'Buono regalo',
        genericUnitPriceCents = unitPriceCents,
        giftCardLineId = giftCardLineId,
        giftCardExpiresAtUtc = expiresAtUtc,
        quantity = 1,
        discountPercent = 0;

  final ProductVariant? product;
  final int? genericId;
  final String? genericName;
  final int? genericUnitPriceCents;
  final int? giftCardLineId;
  final DateTime? giftCardExpiresAtUtc;
  final int quantity;
  final double discountPercent;

  bool get isGiftCardPurchase => giftCardLineId != null;
  bool get isGeneric => product == null && !isGiftCardPurchase;
  String get key => isGiftCardPurchase
      ? 'gift-card-$giftCardLineId'
      : isGeneric
          ? 'generic-$genericId'
          : 'variant-${product!.id}';
  int? get variantId => product?.id;
  String get sku => isGiftCardPurchase ? 'GIFT-CARD' : product?.sku ?? 'GENERIC';
  String? get barcode => product?.barcode;
  String get productName => isGiftCardPurchase
      ? AppStrings.pair('Buono regalo', 'Gift card')
      : product?.name ?? genericName ?? 'Articolo generico';

  String get cartTitle => product?.cartTitleDisplay ?? productName;

  String get cartSubtitle {
    if (isGiftCardPurchase) {
      return '${AppStrings.pair('Valore buono', 'Gift card value')} · ${formatMoney(unitPriceCents)} · $variantDisplay';
    }
    if (isGeneric) {
      return '${AppStrings.isEnglish ? 'Generic item' : 'Articolo generico'} · ${formatMoney(unitPriceCents)} ${AppStrings.t('each')}';
    }
    return product?.cartVariantSizeDisplay ?? variantDisplay;
  }

  String get variantDisplay {
    if (isGiftCardPurchase) {
      final expiration = giftCardExpiresAtUtc;
      if (expiration == null) {
        return AppStrings.pair('Nessuna scadenza', 'No expiration');
      }
      final local = expiration.toLocal();
      final date =
          '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
      return AppStrings.pair('Scadenza $date', 'Expires $date');
    }
    return product?.variantDisplay ?? '';
  }

  int get unitPriceCents => product?.salePriceCents ?? genericUnitPriceCents ?? 0;
  int get grossLineTotalCents => unitPriceCents * quantity;
  int get lineTotalCents => isGiftCardPurchase
      ? grossLineTotalCents
      : (grossLineTotalCents * (1 - discountPercent.clamp(0, 100) / 100))
          .round();

  _CashLine copyWith({
    ProductVariant? product,
    int? quantity,
    double? discountPercent,
  }) {
    if (isGiftCardPurchase) {
      return _CashLine.giftCard(
        giftCardLineId: giftCardLineId!,
        unitPriceCents: genericUnitPriceCents!,
        expiresAtUtc: giftCardExpiresAtUtc,
      );
    }
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
