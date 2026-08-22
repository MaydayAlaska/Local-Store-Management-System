from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 exact match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 regex match, found {count}: {pattern}')
    p.write_text(new_text)


# Customers: creating a gift card from the customer tab must support an optional expiration.
regex_once(
    'lib/pages/customers_page.dart',
    r"  Future<void> _createGiftCard\(\) async \{.*?\n  \}\n\n  Future<void> _deleteGiftCard",
    """  Future<void> _createGiftCard() async {
    final valueController = TextEditingController();
    DateTime? expirationDate;
    String? error;

    String dateText(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    int valueCents() {
      final parsed = double.tryParse(
        valueController.text.trim().replaceAll(',', '.'),
      );
      return parsed == null ? 0 : (parsed * 100).round();
    }

    final draft = await showDialog<_CustomerGiftCardDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickExpiration() async {
            final now = DateTime.now();
            final selected = await showDatePicker(
              context: dialogContext,
              initialDate: expirationDate ?? now.add(const Duration(days: 365)),
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 20, 12, 31),
            );
            if (selected == null) return;
            setDialogState(() => expirationDate = selected);
          }

          void submit() {
            final cents = valueCents();
            if (cents <= 0) {
              setDialogState(() => error = _itEn(
                    'Inserisci un valore maggiore di zero.',
                    'Enter a value greater than zero.',
                  ));
              return;
            }

            DateTime? expiresAtUtc;
            if (expirationDate != null) {
              final value = expirationDate!;
              expiresAtUtc = DateTime(
                value.year,
                value.month,
                value.day,
                23,
                59,
                59,
                999,
              ).toUtc();
            }
            Navigator.of(dialogContext).pop(
              _CustomerGiftCardDraft(
                valueCents: cents,
                expiresAtUtc: expiresAtUtc,
              ),
            );
          }

          return AlertDialog(
            title: Text(_itEn('Nuovo buono regalo', 'New gift card')),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _itEn(
                      'Il buono verrà associato a ${widget.customer.displayName}. Il valore speso partirà da zero.',
                      'The gift card will be linked to ${widget.customer.displayName}. Its spent value will start at zero.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valueController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn('Valore totale', 'Total value'),
                      prefixText: '€ ',
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) setDialogState(() => error = null);
                    },
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _itEn('Scadenza (facoltativa)', 'Expiration (optional)'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickExpiration,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            expirationDate == null
                                ? _itEn('Nessuna scadenza', 'No expiration')
                                : dateText(expirationDate!),
                          ),
                        ),
                      ),
                      if (expirationDate != null) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: _itEn('Rimuovi scadenza', 'Remove expiration'),
                          onPressed: () =>
                              setDialogState(() => expirationDate = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton.icon(
                onPressed: submit,
                icon: const Icon(Icons.card_giftcard),
                label: Text(_itEn('Crea buono', 'Create gift card')),
              ),
            ],
          );
        },
      ),
    );
    valueController.dispose();
    if (draft == null || !mounted) return;

    try {
      final card = widget.repository.createGiftCard(
        widget.customer.id,
        draft.valueCents,
        expiresAtUtc: draft.expiresAtUtc,
      );
      if (!mounted) return;
      final expiration = card.expirationDateDisplay;
      setState(() => _giftStatus = _itEn(
            'Buono ${card.code} creato con valore ${card.totalDisplay}. ${expiration == null ? 'Nessuna scadenza.' : 'Scadenza: $expiration.'}',
            'Gift card ${card.code} created with value ${card.totalDisplay}. ${expiration == null ? 'No expiration.' : 'Expires: $expiration.'}',
          ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _giftStatus = _itEn(
            'Impossibile creare il buono regalo: $error',
            'Unable to create gift card: $error',
          ));
    }
  }

  Future<void> _deleteGiftCard""",
)

replace_once(
    'lib/pages/customers_page.dart',
    """class _CustomerDetail extends StatefulWidget {
""",
    """class _CustomerGiftCardDraft {
  const _CustomerGiftCardDraft({
    required this.valueCents,
    required this.expiresAtUtc,
  });

  final int valueCents;
  final DateTime? expiresAtUtc;
}

class _CustomerDetail extends StatefulWidget {
""",
)

replace_once(
    'lib/pages/customers_page.dart',
    """      details.add(_itEn(
        'Verranno eliminati definitivamente anche ${giftCards.length} buoni regalo associati. Il credito residuo complessivo di ${formatMoney(remainingGiftValue)} verrà perso.',
        '${giftCards.length} linked gift cards will also be permanently deleted. Their total remaining credit of ${formatMoney(remainingGiftValue)} will be lost.',
      ));
""",
    """      details.add(_itEn(
        'I ${giftCards.length} buoni regalo associati non verranno eliminati: verrà rimossa soltanto l’associazione al cliente. Il credito residuo complessivo di ${formatMoney(remainingGiftValue)} resterà disponibile.',
        'The ${giftCards.length} linked gift cards will not be deleted: only their customer association will be removed. Their total remaining credit of ${formatMoney(remainingGiftValue)} will remain available.',
      ));
""",
)

# Cash: gift-card purchase is an article-like flow and no longer requires a customer.
regex_once(
    'lib/pages/cash_page.dart',
    r"  Future<void> _addGiftCardPurchase\(\) async \{.*?\n  \}\n\n  Future<void> _pickGiftCard",
    """  Future<void> _addGiftCardPurchase() async {
    final customer = _customer;
    final draft = await showGiftCardPurchaseDialog(
      context,
      customerName: customer?.displayName,
    );
    if (!mounted || draft == null) return;

    final associateCustomer = customer != null && draft.associateCustomer;
    final line = _CashLine.giftCard(
      giftCardLineId: _nextGiftCardLineId++,
      unitPriceCents: draft.valueCents,
      expiresAtUtc: draft.expiresAtUtc,
      customerId: associateCustomer ? customer.id : null,
      customerName: associateCustomer ? customer.displayName : null,
    );
    setState(() {
      _cart.add(line);
      final ownerText = associateCustomer
          ? _itEn(
              ' Associato a ${customer.displayName}.',
              ' Associated with ${customer.displayName}.',
            )
          : _itEn(' Nessun cliente associato.', ' No associated customer.');
      _cartStatus = draft.expiresAtUtc == null
          ? _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello senza scadenza.$ownerText',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart with no expiration.$ownerText',
            )
          : _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello. Scadenza: ${_dateText(draft.expiresAtUtc!)}.$ownerText',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart. Expires: ${_dateText(draft.expiresAtUtc!)}.$ownerText',
            );
    });
  }

  Future<void> _pickGiftCard""",
)

# Cash: Use gift card can select any valid card. If it has an owner, offer to attach that owner to the order.
regex_once(
    'lib/pages/cash_page.dart',
    r"  Future<void> _pickGiftCard\(\) async \{.*?\n  \}\n\n  void _removeCustomer",
    """  Future<void> _pickGiftCard() async {
    final cards = widget.services.customers.availableGiftCards();
    if (cards.isEmpty) {
      return _cartMessage(_itEn(
        'Non ci sono buoni regalo validi con credito residuo.',
        'There are no valid gift cards with remaining credit.',
      ));
    }

    final selected = await showDialog<GiftCard>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_itEn('Seleziona buono regalo', 'Select gift card')),
        content: SizedBox(
          width: 600,
          height: (cards.length * 98.0).clamp(180.0, 460.0).toDouble(),
          child: ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final card = cards[index];
              final expiration = card.expirationDateDisplay;
              final owner = card.customerId == null
                  ? null
                  : widget.services.customers.getById(card.customerId!);
              final ownerText = owner == null
                  ? _itEn('Nessun cliente associato', 'No associated customer')
                  : _itEn(
                      'Cliente: ${owner.displayName} (${owner.customerCodeDisplay})',
                      'Customer: ${owner.displayName} (${owner.customerCodeDisplay})',
                    );
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
                  '${expiration == null ? _itEn('Nessuna scadenza', 'No expiration') : '${_itEn('Scadenza', 'Expires')}: $expiration'}\n'
                  '$ownerText',
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

    final owner = selected.customerId == null
        ? null
        : widget.services.customers.getById(selected.customerId!);
    if (owner != null && _customer?.id != owner.id) {
      final associate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_itEn('Buono associato a un cliente', 'Gift card linked to a customer')),
          content: Text(
            _itEn(
              'Il buono ${selected.code} è associato a ${owner.displayName} (${owner.customerCodeDisplay}). Vuoi associare questo cliente anche all’ordine?',
              'Gift card ${selected.code} is linked to ${owner.displayName} (${owner.customerCodeDisplay}). Do you want to link this customer to the order as well?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppStrings.t('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_itEn('Usa senza associare', 'Use without linking')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_itEn('Associa cliente', 'Link customer')),
            ),
          ],
        ),
      );
      if (!mounted || associate == null) return;
      if (associate) {
        setState(() => _customer = owner);
      }
    }

    setState(() {
      _giftCard = selected;
      _cartStatus = _itEn(
        'Buono ${selected.code} selezionato. Credito residuo: ${selected.remainingDisplay}.',
        'Gift card ${selected.code} selected. Remaining credit: ${selected.remainingDisplay}.',
      );
    });
  }

  void _removeCustomer""",
)

regex_once(
    'lib/pages/cash_page.dart',
    r"  void _removeCustomer\(\) \{.*?\n  \}\n\n  void _removeGiftCard",
    """  void _removeCustomer() {
    final customer = _customer;
    if (customer == null) return;
    setState(() {
      _customer = null;
      _cartStatus = _itEn(
        'Cliente ${customer.displayName} rimosso dall’ordine. I buoni regalo nel carrello e l’eventuale buono usato come pagamento restano invariati.',
        'Customer ${customer.displayName} removed from the order. Gift cards in the cart and any gift card used as payment remain unchanged.',
      );
    });
  }

  void _removeGiftCard""",
)

# Changing/adding an order customer must not silently discard a selected payment gift card.
for old, new in [
    ("""        _customer = existing;
        _giftCard = null;
        _searchStatus = _itEn(
""", """        _customer = existing;
        _searchStatus = _itEn(
"""),
    ("""      _customer = created;
      _giftCard = null;
      _searchStatus = _itEn(
""", """      _customer = created;
      _searchStatus = _itEn(
"""),
    ("""      _customer = customer;
      _giftCard = null;
      _searchStatus = _itEn(
""", """      _customer = customer;
      _searchStatus = _itEn(
"""),
]:
    replace_once('lib/pages/cash_page.dart', old, new)

replace_once(
    'lib/pages/cash_page.dart',
    """    final availableGiftCards =
        widget.services.customers.availableGiftCardsForCash(_customer?.id);
""",
    '',
)

# Move "Use gift card" to the cart header next to Clear and keep it always visible.
replace_once(
    'lib/pages/cash_page.dart',
    """                        TextButton.icon(
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
""",
    """                        TextButton.icon(
                          onPressed: _pickGiftCard,
                          icon: const Icon(Icons.redeem_outlined),
                          label: Text(_itEn('Usa buono', 'Use gift card')),
                        ),
                        const SizedBox(width: 4),
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
""",
)

# Remove the old customer-scoped New gift card / Use gift card row.
replace_once(
    'lib/pages/cash_page.dart',
    """                        if (_customer != null) ...[
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
""",
    '',
)

# Repository: expose all valid gift cards to the cash picker.
replace_once(
    'lib/repositories/customer_repository.dart',
    """  List<GiftCard> availableGiftCardsForCash(int? customerId, [int limit = 500]) {
""",
    """  List<GiftCard> availableGiftCards([int limit = 500]) {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      WHERE spent_value_cents < total_value_cents
        AND (expires_at_utc IS NULL OR expires_at_utc > ?)
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [now, limit.clamp(1, 5000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> availableGiftCardsForCash(int? customerId, [int limit = 500]) {
""",
)

replace_once(
    'lib/repositories/customer_repository.dart',
    """        final ownerId = card['customer_id'] as int?;
        if (ownerId != null && ownerId != draft.customerId) {
          throw StateError('Il buono regalo è associato a un altro cliente.');
        }
""",
    '',
)

# Tests: an associated gift card can pay an order for another/no customer; UI decides whether to link the owner.
regex_once(
    'test/customer_repository_test.dart',
    r"  test\('gift cards are customer-bound and physical deletion preserves order snapshots', \(\) async \{.*?\n  \}\);\n\n  test\('deleting a customer detaches gift cards and releases customer code'",
    """  test('associated gift cards can be used without changing the order customer', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-independent-customer-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      final owner = repository.save(const CustomerDraft(
        firstName: 'Mario',
        lastName: 'Rossi',
      ));
      final other = repository.save(const CustomerDraft(
        firstName: 'Luigi',
        lastName: 'Bianchi',
      ));
      final card = repository.createGiftCard(owner.id, 5000);

      expect(repository.availableGiftCards().map((item) => item.id), contains(card.id));

      SalesOrderDraft draftFor(int? customerId) => SalesOrderDraft(
            customerId: customerId,
            giftCardId: card.id,
            giftCardAppliedCents: 1000,
            lines: const [
              SalesOrderDraftLine(
                variantId: null,
                sku: 'GENERIC',
                productName: 'Articolo generico',
                variantDisplay: '',
                quantity: 1,
                unitPriceCents: 1000,
                discountBasisPoints: 0,
                grossTotalCents: 1000,
                finalTotalCents: 1000,
              ),
            ],
            grossTotalCents: 1000,
            itemDiscountCents: 0,
            orderDiscountBasisPoints: 0,
            orderPercentDiscountCents: 0,
            fixedDiscountCents: 0,
            finalTotalCents: 1000,
          );

      final otherOrder = repository.recordSale(draftFor(other.id));
      expect(otherOrder.customerId, other.id);
      expect(otherOrder.giftCardCode, card.code);
      expect(repository.getGiftCard(card.id)!.remainingValueCents, 4000);

      final anonymousOrder = repository.recordSale(draftFor(null));
      expect(anonymousOrder.customerId, isNull);
      expect(anonymousOrder.giftCardCode, card.code);
      expect(repository.getGiftCard(card.id)!.remainingValueCents, 3000);

      expect(repository.deleteGiftCard(card.id), isTrue);
      expect(repository.getGiftCard(card.id), isNull);

      final preserved = repository.getOrder(otherOrder.id)!.summary;
      expect(preserved.giftCardId, isNull);
      expect(preserved.giftCardCode, card.code);
      expect(preserved.giftCardAppliedCents, 1000);
      expect(preserved.amountDueCents, 0);
      expect(repository.searchOrders(card.code).map((order) => order.id), contains(otherOrder.id));
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('deleting a customer detaches gift cards and releases customer code'""",
)
