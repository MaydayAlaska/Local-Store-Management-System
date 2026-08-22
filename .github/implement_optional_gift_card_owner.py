from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"{path}: exact fragment not found: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text()
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{path}: regex match count {count}: {pattern[:120]!r}")
    p.write_text(new_text)


# Model: a gift card may have no associated customer.
replace_once(
    "lib/models/customer.dart",
    "  final int customerId;\n  final int totalValueCents;",
    "  final int? customerId;\n  final int totalValueCents;",
)

# Repository schema: nullable owner, ON DELETE SET NULL.
repo_path = Path("lib/repositories/customer_repository.dart")
repo_text = repo_path.read_text()
repo_text = repo_text.replace("customer_id INTEGER NOT NULL,", "customer_id INTEGER,")
repo_text = repo_text.replace(
    "FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE",
    "FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL",
)
repo_path.write_text(repo_text)

regex_once(
    "lib/repositories/customer_repository.dart",
    r"  void _migrateGiftCardSchemaIfNeeded\(\) \{.*?\n  \}\n\n  void _backfillCustomerSnapshots\(\)",
    """  void _migrateGiftCardSchemaIfNeeded() {
    final columns = database.db.select('PRAGMA table_info(gift_cards);');
    final customerColumn = columns.firstWhere(
      (row) => (row['name'] as String).toLowerCase() == 'customer_id',
    );
    final hasDeletedAt = columns.any(
      (row) => (row['name'] as String).toLowerCase() == 'deleted_at_utc',
    );
    final customerIsRequired = (customerColumn['notnull'] as int) != 0;
    final foreignKeys = database.db.select('PRAGMA foreign_key_list(gift_cards);');
    final customerForeignKey = foreignKeys.where(
      (row) => (row['from'] as String).toLowerCase() == 'customer_id',
    );
    final customerDeleteActionIsWrong = customerForeignKey.isEmpty ||
        ((customerForeignKey.first['on_delete'] as String?) ?? '').toUpperCase() !=
            'SET NULL';
    if (!hasDeletedAt && !customerIsRequired && !customerDeleteActionIsWrong) {
      return;
    }

    final db = database.db;
    if (hasDeletedAt) {
      db.execute('DELETE FROM gift_cards WHERE deleted_at_utc IS NOT NULL;');
    }
    db.execute('DROP INDEX IF EXISTS ix_gift_cards_cleanup;');

    db.execute('PRAGMA foreign_keys = OFF;');
    try {
      db.execute('BEGIN IMMEDIATE;');
      db.execute('DROP TABLE IF EXISTS gift_cards_new;');
      db.execute('''
        CREATE TABLE gift_cards_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL COLLATE NOCASE UNIQUE,
          customer_id INTEGER,
          total_value_cents INTEGER NOT NULL CHECK(total_value_cents > 0),
          spent_value_cents INTEGER NOT NULL DEFAULT 0
            CHECK(spent_value_cents >= 0 AND spent_value_cents <= total_value_cents),
          expires_at_utc TEXT,
          purchase_order_id INTEGER,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
        );
      ''');
      final activeFilter = hasDeletedAt ? ' WHERE deleted_at_utc IS NULL' : '';
      db.execute('''
        INSERT INTO gift_cards_new (
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc)
        SELECT
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc
        FROM gift_cards$activeFilter;
      ''');
      db.execute('DROP TABLE gift_cards;');
      db.execute('ALTER TABLE gift_cards_new RENAME TO gift_cards;');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  void _backfillCustomerSnapshots()""",
)

# Backfill and purchase-order matching support anonymous gift cards.
replace_once(
    "lib/repositories/customer_repository.dart",
    "        customerId: row['customer_id'] as int,\n        totalValueCents: row['total_value_cents'] as int,\n        giftCardCreatedAtUtc: row['created_at_utc'] as String,",
    "        customerId: row['customer_id'] as int?,\n        totalValueCents: row['total_value_cents'] as int,\n        giftCardCreatedAtUtc: row['created_at_utc'] as String,",
)

regex_once(
    "lib/repositories/customer_repository.dart",
    r"  int\? _findAvailableGiftCardPurchaseOrder\(\{.*?\n  \}\n\n  List<Customer> search",
    """  int? _findAvailableGiftCardPurchaseOrder({
    required int? customerId,
    required int totalValueCents,
    required String giftCardCreatedAtUtc,
  }) {
    final rows = database.db.select('''
      SELECT so.id
      FROM sales_orders so
      WHERE ((? IS NULL AND so.customer_id IS NULL) OR so.customer_id=?)
        AND ABS((julianday(so.created_at_utc) - julianday(?)) * 86400.0) <= 120
        AND (
          SELECT COALESCE(SUM(soi.quantity), 0)
          FROM sales_order_items soi
          WHERE soi.order_id=so.id
            AND soi.sku='GIFT-CARD' COLLATE NOCASE
            AND soi.unit_price_cents=?
        ) > (
          SELECT COUNT(*)
          FROM gift_cards linked
          WHERE linked.purchase_order_id=so.id
            AND linked.total_value_cents=?
        )
      ORDER BY
        ABS((julianday(so.created_at_utc) - julianday(?)) * 86400.0),
        so.id DESC
      LIMIT 1;
    ''', [
      customerId,
      customerId,
      giftCardCreatedAtUtc,
      totalValueCents,
      totalValueCents,
      giftCardCreatedAtUtc,
    ]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  List<Customer> search""",
)

# Deleting a customer now leaves their gift cards alive and unassigned.
replace_once(
    "lib/repositories/customer_repository.dart",
    "      db.execute('DELETE FROM customers WHERE id=?;', [customerId]);\n      db.execute('COMMIT;');",
    "      final giftCardUpdatedAt = DateTime.now().toUtc().toIso8601String();\n      db.execute(\n        'UPDATE gift_cards SET customer_id=NULL, updated_at_utc=? WHERE customer_id=?;',\n        [giftCardUpdatedAt, customerId],\n      );\n      db.execute('DELETE FROM customers WHERE id=?;', [customerId]);\n      db.execute('COMMIT;');",
)

# Global list and cash-available list.
replace_once(
    "lib/repositories/customer_repository.dart",
    "  List<GiftCard> availableGiftCardsForCustomer(int customerId, [int limit = 500]) {",
    """  List<GiftCard> giftCards([int limit = 5000]) {
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [limit.clamp(1, 10000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> availableGiftCardsForCash(int? customerId, [int limit = 500]) {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      WHERE (customer_id IS NULL OR customer_id=?)
        AND spent_value_cents < total_value_cents
        AND (expires_at_utc IS NULL OR expires_at_utc > ?)
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [customerId, now, limit.clamp(1, 5000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> availableGiftCardsForCustomer(int customerId, [int limit = 500]) {""",
)

# Creation allows null owner, explicit purchase order; editing supports owner and expiry.
regex_once(
    "lib/repositories/customer_repository.dart",
    r"  GiftCard createGiftCard\(.*?\n  \}\n\n  SalesOrderSummary\? purchaseOrderForGiftCard",
    """  GiftCard createGiftCard(
    int? customerId,
    int totalValueCents, {
    DateTime? expiresAtUtc,
    int? purchaseOrderId,
  }) {
    if (totalValueCents <= 0) {
      throw ArgumentError('Il valore del buono regalo deve essere maggiore di zero.');
    }
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      if (customerId != null) {
        final customerExists = db.select(
          'SELECT 1 FROM customers WHERE id=? LIMIT 1;',
          [customerId],
        ).isNotEmpty;
        if (!customerExists) {
          throw StateError('Il cliente selezionato non esiste più.');
        }
      }

      final nowUtc = DateTime.now().toUtc();
      final now = nowUtc.toIso8601String();
      final expiration = expiresAtUtc?.toUtc().toIso8601String();
      final resolvedPurchaseOrderId = purchaseOrderId ??
          _findAvailableGiftCardPurchaseOrder(
            customerId: customerId,
            totalValueCents: totalValueCents,
            giftCardCreatedAtUtc: now,
          );
      final id = _nextAvailableGiftCardId();
      final code = _newUniqueGiftCardCode();
      db.execute('''
        INSERT INTO gift_cards (
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc)
        VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?);
      ''', [
        id,
        code,
        customerId,
        totalValueCents,
        expiration,
        resolvedPurchaseOrderId,
        now,
        now,
      ]);
      db.execute('COMMIT;');
      return getGiftCard(id)!;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  GiftCard updateGiftCard(
    int giftCardId, {
    required int? customerId,
    required DateTime? expiresAtUtc,
  }) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final exists = db.select(
        'SELECT 1 FROM gift_cards WHERE id=? LIMIT 1;',
        [giftCardId],
      ).isNotEmpty;
      if (!exists) throw StateError('Buono regalo non trovato.');
      if (customerId != null) {
        final customerExists = db.select(
          'SELECT 1 FROM customers WHERE id=? LIMIT 1;',
          [customerId],
        ).isNotEmpty;
        if (!customerExists) {
          throw StateError('Il cliente selezionato non esiste più.');
        }
      }
      final now = DateTime.now().toUtc().toIso8601String();
      db.execute('''
        UPDATE gift_cards
        SET customer_id=?, expires_at_utc=?, updated_at_utc=?
        WHERE id=?;
      ''', [
        customerId,
        expiresAtUtc?.toUtc().toIso8601String(),
        now,
        giftCardId,
      ]);
      db.execute('COMMIT;');
      return getGiftCard(giftCardId)!;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  SalesOrderSummary? purchaseOrderForGiftCard""",
)

# Redemption: an assigned card still requires its matching customer;
# an unassigned card can be used without selecting a customer.
replace_once(
    "lib/repositories/customer_repository.dart",
    """        if (draft.customerId == null) {
          throw ArgumentError('Per usare un buono regalo è necessario associare il cliente.');
        }
""",
    "",
)
replace_once(
    "lib/repositories/customer_repository.dart",
    """        if ((card['customer_id'] as int) != draft.customerId) {
          throw StateError('Il buono regalo non appartiene al cliente selezionato.');
        }
""",
    """        final ownerId = card['customer_id'] as int?;
        if (ownerId != null && ownerId != draft.customerId) {
          throw StateError('Il buono regalo è associato a un altro cliente.');
        }
""",
)

# Mapper uses nullable owner.
replace_once(
    "lib/repositories/customer_repository.dart",
    "        customerId: row['customer_id'] as int,\n        totalValueCents: row['total_value_cents'] as int,",
    "        customerId: row['customer_id'] as int?,\n        totalValueCents: row['total_value_cents'] as int,",
)

# Purchase popup: customer is optional and association is explicitly selectable.
dialog_path = Path("lib/pages/gift_card_purchase_dialog.dart")
dialog = dialog_path.read_text()
dialog = dialog.replace(
    """  const GiftCardPurchaseDraft({
    required this.valueCents,
    this.expiresAtUtc,
  });

  final int valueCents;
  final DateTime? expiresAtUtc;
""",
    """  const GiftCardPurchaseDraft({
    required this.valueCents,
    required this.associateCustomer,
    this.expiresAtUtc,
  });

  final int valueCents;
  final bool associateCustomer;
  final DateTime? expiresAtUtc;
""",
)
dialog = dialog.replace(
    """Future<GiftCardPurchaseDraft?> showGiftCardPurchaseDialog(
  BuildContext context, {
  required String customerName,
}) async {""",
    """Future<GiftCardPurchaseDraft?> showGiftCardPurchaseDialog(
  BuildContext context, {
  String? customerName,
}) async {""",
)
dialog = dialog.replace(
    """  DateTime? expirationDate;
  String? error;
""",
    """  DateTime? expirationDate;
  var associateCustomer = customerName != null;
  String? error;
""",
)
dialog = dialog.replace(
    """            GiftCardPurchaseDraft(
              valueCents: cents,
              expiresAtUtc: expiresAtUtc,
            ),""",
    """            GiftCardPurchaseDraft(
              valueCents: cents,
              associateCustomer: associateCustomer,
              expiresAtUtc: expiresAtUtc,
            ),""",
)
dialog = dialog.replace(
    """                Text(
                  AppStrings.t(
                    'gift_card_purchase_help',
                    {'customerName': customerName},
                  ),
                ),
                const SizedBox(height: 14),""",
    """                Text(
                  customerName == null
                      ? AppStrings.pair(
                          'Il buono verrà emesso senza cliente associato. Potrai associarlo successivamente dalla gestione Buoni regalo.',
                          'The gift card will be issued without an associated customer. You can assign one later from Gift card management.',
                        )
                      : AppStrings.t(
                          'gift_card_purchase_help',
                          {'customerName': customerName},
                        ),
                ),
                if (customerName != null) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: associateCustomer,
                    onChanged: (value) => setDialogState(
                      () => associateCustomer = value ?? false,
                    ),
                    title: Text(
                      AppStrings.pair(
                        'Associa il buono a $customerName',
                        'Associate the gift card with $customerName',
                      ),
                    ),
                    subtitle: Text(
                      AppStrings.pair(
                        'Facoltativo: l’associazione potrà essere cambiata o rimossa in seguito.',
                        'Optional: the association can be changed or removed later.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),""",
)
dialog_path.write_text(dialog)

# Dedicated gift-card editor dialog.
Path("lib/pages/gift_card_editor_dialog.dart").write_text(r"""import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import 'customer_picker_dialog.dart';

class GiftCardEditDraft {
  const GiftCardEditDraft({
    required this.customerId,
    required this.expiresAtUtc,
  });

  final int? customerId;
  final DateTime? expiresAtUtc;
}

Future<GiftCardEditDraft?> showGiftCardEditorDialog(
  BuildContext context, {
  required CustomerRepository repository,
  required GiftCard card,
}) async {
  Customer? customer =
      card.customerId == null ? null : repository.getById(card.customerId!);
  DateTime? expirationDate = card.expiresAtUtc?.toLocal();

  String t(String it, String en) => AppStrings.pair(it, en);
  String dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  return showDialog<GiftCardEditDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> pickCustomer() async {
          final selected = await showCustomerPickerDialog(
            dialogContext,
            repository: repository,
          );
          if (selected == null) return;
          setDialogState(() => customer = selected);
        }

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

        void save() {
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
            GiftCardEditDraft(
              customerId: customer?.id,
              expiresAtUtc: expiresAtUtc,
            ),
          );
        }

        return AlertDialog(
          title: Text(t('Modifica buono regalo', 'Edit gift card')),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.card_giftcard_outlined),
                  title: Text(
                    card.code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${t('Valore', 'Value')}: ${card.totalDisplay} · ${t('Residuo', 'Remaining')}: ${card.remainingDisplay}',
                  ),
                ),
                const Divider(),
                Text(
                  t('Cliente associato', 'Associated customer'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer == null
                            ? t('Nessun cliente associato', 'No associated customer')
                            : '${customer!.displayName} (${customer!.customerCodeDisplay})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: pickCustomer,
                      icon: const Icon(Icons.person_search_outlined),
                      label: Text(
                        customer == null ? t('Associa', 'Assign') : t('Cambia', 'Change'),
                      ),
                    ),
                    if (customer != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: t('Rimuovi associazione', 'Remove association'),
                        onPressed: () => setDialogState(() => customer = null),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  t('Scadenza', 'Expiration'),
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
                              ? t('Nessuna scadenza', 'No expiration')
                              : dateText(expirationDate!),
                        ),
                      ),
                    ),
                    if (expirationDate != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: t('Rimuovi scadenza', 'Remove expiration'),
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
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: Text(t('Salva modifiche', 'Save changes')),
            ),
          ],
        );
      },
    ),
  );
}
""")

# Global Gift Cards page: include unassigned cards and expose edit/delete menu.
page_path = Path("lib/pages/gift_cards_page.dart")
page = page_path.read_text()
page = page.replace(
    "import 'gift_card_management_dialog.dart';\n",
    "import 'gift_card_editor_dialog.dart';\nimport 'gift_card_management_dialog.dart';\n",
    1,
)
page = page.replace(
    "  Future<void> _deleteGiftCard(GiftCard card, Customer? customer) async {",
    """  Future<void> _editGiftCard(GiftCard card) async {
    final draft = await showGiftCardEditorDialog(
      context,
      repository: widget.services.customers,
      card: card,
    );
    if (!mounted || draft == null) return;
    try {
      final updated = widget.services.customers.updateGiftCard(
        card.id,
        customerId: draft.customerId,
        expiresAtUtc: draft.expiresAtUtc,
      );
      if (!mounted) return;
      setState(() {
        _status = _t(
          'Buono ${updated.code} aggiornato.',
          'Gift card ${updated.code} updated.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _t(
          'Impossibile aggiornare il buono: $error',
          'Unable to update the gift card: $error',
        );
      });
    }
  }

  Future<void> _deleteGiftCard(GiftCard card, Customer? customer) async {""",
    1,
)
replace_entries = """    final entries = <_GiftCardEntry>[];
    for (final customer in customers) {
      for (final card in repository.giftCardsForCustomer(customer.id, 5000)) {
        entries.add(_GiftCardEntry(card: card, customer: customer));
      }
    }
    entries.sort(
      (a, b) => b.card.createdAtUtc.compareTo(a.card.createdAtUtc),
    );
"""
new_entries = """    final entries = repository
        .giftCards(5000)
        .map(
          (card) => _GiftCardEntry(
            card: card,
            customer: card.customerId == null
                ? null
                : customerById[card.customerId!],
          ),
        )
        .toList(growable: false);
"""
if replace_entries not in page:
    raise SystemExit("gift_cards_page.dart: entries block not found")
page = page.replace(replace_entries, new_entries, 1)
page = page.replace(
    "            final customer = customerById[entry.card.customerId];",
    "            final customer = entry.customer;",
    1,
)
page = page.replace(
    """                            '${customer.displayName} · ${customer.customerCodeDisplay}\\n'
                            '${_t('Totale', 'Total')}: ${card.totalDisplay} · '
""",
    """                            '${customer == null ? _t('Nessun cliente associato', 'No associated customer') : '${customer.displayName} · ${customer.customerCodeDisplay}'}\\n'
                            '${_t('Totale', 'Total')}: ${card.totalDisplay} · '
""",
    1,
)
page = page.replace(
    """                          trailing: IconButton(
                            tooltip: _t('Elimina buono', 'Delete gift card'),
                            onPressed: () => _deleteGiftCard(card, customer),
                            icon: const Icon(Icons.delete_outline),
                          ),
""",
    """                          trailing: PopupMenuButton<String>(
                            tooltip: _t('Azioni buono', 'Gift card actions'),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editGiftCard(card);
                              } else if (value == 'delete') {
                                _deleteGiftCard(card, customer);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.edit_outlined),
                                  title: Text(_t('Modifica', 'Edit')),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  title: Text(_t('Elimina', 'Delete')),
                                ),
                              ),
                            ],
                          ),
""",
    1,
)
page = page.replace("  final Customer customer;", "  final Customer? customer;", 1)
page_path.write_text(page)

# Cash page: virtual article, optional association, anonymous purchase/use.
cash_path = Path("lib/pages/cash_page.dart")
cash = cash_path.read_text()
cash = cash.replace(
    """  List<ProductVariant> get _results =>
      widget.services.products.search(_search.text, 50);
""",
    """  List<ProductVariant> get _results =>
      widget.services.products.search(_search.text, 50);

  bool get _showGiftCardVirtualItem {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return 'buono regalo'.contains(query) ||
        'gift card'.contains(query) ||
        'regalo'.contains(query) ||
        'gift'.contains(query);
  }
""",
    1,
)

regex_once(
    "lib/pages/cash_page.dart",
    r"  Future<void> _addGiftCardPurchase\(\) async \{.*?\n  \}\n\n  Future<void> _pickGiftCard",
    """  Future<void> _addGiftCardPurchase() async {
    final customer = _customer;
    final draft = await showGiftCardPurchaseDialog(
      context,
      customerName: customer?.displayName,
    );
    if (!mounted || draft == null) return;

    final associate = draft.associateCustomer && customer != null;
    final line = _CashLine.giftCard(
      giftCardLineId: _nextGiftCardLineId++,
      unitPriceCents: draft.valueCents,
      expiresAtUtc: draft.expiresAtUtc,
      customerId: associate ? customer.id : null,
      customerName: associate ? customer.displayName : null,
    );
    setState(() {
      _cart.add(line);
      final ownerText = associate
          ? _itEn(
              'Associato a ${customer.displayName}.',
              'Associated with ${customer.displayName}.',
            )
          : _itEn('Nessun cliente associato.', 'No associated customer.');
      _cartStatus = draft.expiresAtUtc == null
          ? _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello senza scadenza. $ownerText',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart with no expiration. $ownerText',
            )
          : _itEn(
              'Buono regalo da ${formatMoney(draft.valueCents)} aggiunto al carrello. Scadenza: ${_dateText(draft.expiresAtUtc!)}. $ownerText',
              'Gift card for ${formatMoney(draft.valueCents)} added to the cart. Expires: ${_dateText(draft.expiresAtUtc!)}. $ownerText',
            );
    });
  }

  Future<void> _pickGiftCard""",
)

regex_once(
    "lib/pages/cash_page.dart",
    r"  Future<void> _pickGiftCard\(\) async \{.*?\n    final selected = await showDialog<GiftCard>",
    """  Future<void> _pickGiftCard() async {
    final customer = _customer;
    final cards = widget.services.customers.availableGiftCardsForCash(customer?.id);
    if (cards.isEmpty) {
      return _cartMessage(
        customer == null
            ? _itEn(
                'Non ci sono buoni regalo non associati validi con credito residuo.',
                'There are no valid unassigned gift cards with remaining credit.',
              )
            : _itEn(
                'Non ci sono buoni validi utilizzabili per questo cliente.',
                'There are no valid gift cards available for this customer.',
              ),
      );
    }

    final selected = await showDialog<GiftCard>""",
)

regex_once(
    "lib/pages/cash_page.dart",
    r"  void _removeCustomer\(\) \{.*?\n  \}\n\n  void _removeGiftCard",
    """  void _removeCustomer() {
    setState(() {
      _customer = null;
      _giftCard = null;
      _cartStatus = _itEn(
        'Cliente rimosso dall’ordine. I buoni regalo in acquisto restano nel carrello con l’associazione scelta al momento dell’aggiunta.',
        'Customer removed from the order. Gift cards being purchased remain in the cart with the association chosen when they were added.',
      );
    });
  }

  void _removeGiftCard""",
)

cash = cash.replace(
    """    final customer = _customer;
    if (pendingGiftCards.isNotEmpty && customer == null) {
      return _cartMessage(_itEn(
        'Associa un cliente prima di registrare l’acquisto del buono regalo.',
        'Link a customer before registering the gift-card purchase.',
      ));
    }

""",
    """    final customer = _customer;
""",
    1,
)
cash = cash.replace(
    """            widget.services.customers.createGiftCard(
              customer!.id,
              line.unitPriceCents,
              expiresAtUtc: line.giftCardExpiresAtUtc,
            ),
""",
    """            widget.services.customers.createGiftCard(
              line.giftCardCustomerId,
              line.unitPriceCents,
              expiresAtUtc: line.giftCardExpiresAtUtc,
              purchaseOrderId: registeredOrder.id,
            ),
""",
    1,
)
cash = cash.replace(
    """    final availableGiftCards = _customer == null
        ? const <GiftCard>[]
        : widget.services.customers.availableGiftCardsForCustomer(_customer!.id);
""",
    """    final availableGiftCards =
        widget.services.customers.availableGiftCardsForCash(_customer?.id);
""",
    1,
)

# Product list: virtual gift card is shown as a normal selectable cash item.
old_list = """                        child: results.isEmpty
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
"""
new_list = """                        child: results.isEmpty && !_showGiftCardVirtualItem
                            ? Center(child: Text(AppStrings.t('no_product_found')))
                            : _productViewMode == _ProductViewMode.list
                                ? ListView.separated(
                                    itemCount: results.length +
                                        (_showGiftCardVirtualItem ? 1 : 0),
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      if (_showGiftCardVirtualItem && index == 0) {
                                        return ListTile(
                                          leading: Icon(
                                            Icons.card_giftcard_rounded,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          title: Text(_itEn('Buono regalo', 'Gift card')),
                                          subtitle: Text(_itEn(
                                            'Articolo speciale · valore da impostare',
                                            'Special item · value to be entered',
                                          )),
                                          trailing: Text(_itEn('Valore libero', 'Custom value')),
                                          onTap: _addGiftCardPurchase,
                                        );
                                      }
                                      final productIndex = index -
                                          (_showGiftCardVirtualItem ? 1 : 0);
                                      final product = results[productIndex];
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
"""
if old_list not in cash:
    raise SystemExit("cash_page.dart: product list block not found")
cash = cash.replace(old_list, new_list, 1)

old_grid = """                                        itemCount: results.length,
                                        itemBuilder: (context, index) {
                                          final product = results[index];
                                          return _ProductGridTile(
                                            product: product,
                                            imageBytes:
                                                variantImages[product.id],
                                            onTap: () => _add(product),
                                          );
                                        },
"""
new_grid = """                                        itemCount: results.length +
                                            (_showGiftCardVirtualItem ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (_showGiftCardVirtualItem && index == 0) {
                                            return _GiftCardGridTile(
                                              onTap: _addGiftCardPurchase,
                                            );
                                          }
                                          final productIndex = index -
                                              (_showGiftCardVirtualItem ? 1 : 0);
                                          final product = results[productIndex];
                                          return _ProductGridTile(
                                            product: product,
                                            imageBytes:
                                                variantImages[product.id],
                                            onTap: () => _add(product),
                                          );
                                        },
"""
if old_grid not in cash:
    raise SystemExit("cash_page.dart: grid block not found")
cash = cash.replace(old_grid, new_grid, 1)

# Redemption row is always visible. The old New gift card button is removed because
# the gift card is now a virtual article in the product list/grid.
regex_once(
    "lib/pages/cash_page.dart",
    r"                        if \(_customer != null\) \.\.\.\[\n                          const SizedBox\(height: 8\),\n                          Row\(children: \[\n                            const Icon\(Icons.card_giftcard_outlined, size: 20\),.*?\n                          \]\),\n                        \],",
    """                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.card_giftcard_outlined, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _giftCard == null
                                  ? _itEn(
                                      '${availableGiftCards.length} buoni validi utilizzabili',
                                      '${availableGiftCards.length} valid gift cards available',
                                    )
                                  : '${_giftCard!.code} · ${_itEn('residuo', 'remaining')} ${_giftCard!.remainingDisplay}',
                            ),
                          ),
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
                        ]),""",
)

# Themed gift-card grid tile.
marker = "class _ProductGridTile extends StatelessWidget {"
gift_tile = r"""class _GiftCardGridTile extends StatelessWidget {
  const _GiftCardGridTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = UiStyleTokens.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.imagePreviewSurface,
                ),
                child: Center(
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    size: 82,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.pair('Buono regalo', 'Gift card'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppStrings.pair('Valore da impostare', 'Custom value'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppStrings.pair('Articolo speciale', 'Special item'),
                    style: theme.textTheme.labelSmall,
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

"""
if marker not in cash:
    raise SystemExit("cash_page.dart: ProductGridTile marker missing")
cash = cash.replace(marker, gift_tile + marker, 1)

# Cart line title gets the themed gift icon.
cash = cash.replace(
    """          Text(
            line.cartTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
""",
    """          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (line.isGiftCardPurchase) ...[
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  line.cartTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
""",
    1,
)

# Cash-line gift-card metadata stores association chosen when item was added.
cash = cash.replace(
    """        giftCardLineId = null,
        giftCardExpiresAtUtc = null;""",
    """        giftCardLineId = null,
        giftCardExpiresAtUtc = null,
        giftCardCustomerId = null,
        giftCardCustomerName = null;""",
    2,
)
cash = cash.replace(
    """  const _CashLine.giftCard({
    required int giftCardLineId,
    required int unitPriceCents,
    DateTime? expiresAtUtc,
  })  : product = null,""",
    """  const _CashLine.giftCard({
    required int giftCardLineId,
    required int unitPriceCents,
    DateTime? expiresAtUtc,
    int? customerId,
    String? customerName,
  })  : product = null,""",
    1,
)
cash = cash.replace(
    """        giftCardLineId = giftCardLineId,
        giftCardExpiresAtUtc = expiresAtUtc,
        quantity = 1,""",
    """        giftCardLineId = giftCardLineId,
        giftCardExpiresAtUtc = expiresAtUtc,
        giftCardCustomerId = customerId,
        giftCardCustomerName = customerName,
        quantity = 1,""",
    1,
)
cash = cash.replace(
    """  final int? giftCardLineId;
  final DateTime? giftCardExpiresAtUtc;
  final int quantity;""",
    """  final int? giftCardLineId;
  final DateTime? giftCardExpiresAtUtc;
  final int? giftCardCustomerId;
  final String? giftCardCustomerName;
  final int quantity;""",
    1,
)
cash = cash.replace(
    """    if (isGiftCardPurchase) {
      return '${AppStrings.pair('Valore buono', 'Gift card value')} · ${formatMoney(unitPriceCents)} · $variantDisplay';
    }""",
    """    if (isGiftCardPurchase) {
      final owner = giftCardCustomerName == null
          ? AppStrings.pair('Nessun cliente', 'No customer')
          : AppStrings.pair(
              'Cliente: $giftCardCustomerName',
              'Customer: $giftCardCustomerName',
            );
      return '${AppStrings.pair('Valore buono', 'Gift card value')} · ${formatMoney(unitPriceCents)} · $variantDisplay · $owner';
    }""",
    1,
)
cash = cash.replace(
    """        expiresAtUtc: giftCardExpiresAtUtc,
      );""",
    """        expiresAtUtc: giftCardExpiresAtUtc,
        customerId: giftCardCustomerId,
        customerName: giftCardCustomerName,
      );""",
    1,
)
cash_path.write_text(cash)

# Tests: deleting a customer detaches cards; owner can be assigned/changed/removed;
# unassigned cards can be used anonymously.
test_path = Path("test/customer_repository_test.dart")
test = test_path.read_text()
test = test.replace(
    "test('deleting a customer deletes gift cards and releases customer code', () async {",
    "test('deleting a customer detaches gift cards and releases customer code', () async {",
    1,
)
test = test.replace(
    """      expect(repository.deleteCustomer(first.id), isTrue);
      expect(repository.getGiftCard(card.id), isNull);""",
    """      expect(repository.deleteCustomer(first.id), isTrue);
      expect(repository.getGiftCard(card.id), isNotNull);
      expect(repository.getGiftCard(card.id)!.customerId, isNull);""",
    1,
)
insert_marker = """  test(
    'generic sale item is stored without changing stock and order numbers stay unique',"""
optional_test = r"""  test('gift card customer association is optional and editable', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-optional-owner-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      final first = repository.save(const CustomerDraft(
        firstName: 'Mario',
        lastName: 'Rossi',
      ));
      final second = repository.save(const CustomerDraft(
        firstName: 'Luigi',
        lastName: 'Bianchi',
      ));

      final card = repository.createGiftCard(null, 5000);
      expect(card.customerId, isNull);

      final assigned = repository.updateGiftCard(
        card.id,
        customerId: first.id,
        expiresAtUtc: null,
      );
      expect(assigned.customerId, first.id);

      final changed = repository.updateGiftCard(
        card.id,
        customerId: second.id,
        expiresAtUtc: DateTime.utc(2027, 12, 31, 23, 59, 59),
      );
      expect(changed.customerId, second.id);
      expect(changed.expiresAtUtc, isNotNull);

      final unassigned = repository.updateGiftCard(
        card.id,
        customerId: null,
        expiresAtUtc: null,
      );
      expect(unassigned.customerId, isNull);
      expect(unassigned.expiresAtUtc, isNull);

      final sale = repository.recordSale(SalesOrderDraft(
        customerId: null,
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
      ));
      expect(sale.customerId, isNull);
      expect(sale.giftCardCode, card.code);
      expect(repository.getGiftCard(card.id)!.remainingValueCents, 4000);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

"""
if insert_marker not in test:
    raise SystemExit("customer_repository_test.dart: insertion marker not found")
test = test.replace(insert_marker, optional_test + insert_marker, 1)
test_path.write_text(test)

cleanup_path = Path("test/gift_card_cleanup_test.dart")
cleanup = cleanup_path.read_text()
marker = "      expect(repository.getGiftCard(2), isNull);\n"
addition = """      expect(repository.getGiftCard(2), isNull);
      final customerColumn =
          columns.firstWhere((row) => row['name'] == 'customer_id');
      expect(customerColumn['notnull'], 0);
      final customerFk = service.db
          .select('PRAGMA foreign_key_list(gift_cards);')
          .firstWhere((row) => row['from'] == 'customer_id');
      expect((customerFk['on_delete'] as String).toUpperCase(), 'SET NULL');
"""
if marker not in cleanup:
    raise SystemExit("gift_card_cleanup_test.dart: migration marker not found")
cleanup = cleanup.replace(marker, addition, 1)
cleanup_path.write_text(cleanup)
