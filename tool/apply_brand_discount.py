from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)


# Database schema / migration.
path = 'lib/core/database_service.dart'
text = read(path)
text = replace_once(
    text,
    """      CREATE TABLE IF NOT EXISTS brands (\n        id INTEGER PRIMARY KEY,\n        name TEXT NOT NULL COLLATE NOCASE UNIQUE\n      );""",
    """      CREATE TABLE IF NOT EXISTS brands (\n        id INTEGER PRIMARY KEY,\n        name TEXT NOT NULL COLLATE NOCASE UNIQUE,\n        discount_basis_points INTEGER\n          CHECK(discount_basis_points IS NULL OR\n            (discount_basis_points >= 0 AND discount_basis_points <= 10000))\n      );""",
    'brands schema',
)
text = replace_once(
    text,
    """        purchase_price_cents INTEGER,\n        sale_price_cents INTEGER,\n        notes TEXT,""",
    """        purchase_price_cents INTEGER,\n        purchase_price_is_manual INTEGER NOT NULL DEFAULT 0\n          CHECK(purchase_price_is_manual IN (0, 1)),\n        sale_price_cents INTEGER,\n        notes TEXT,""",
    'products purchase source schema',
)
text = replace_once(
    text,
    """    _createVariantImageSchema();\n    _createIndexes();\n    _database.execute('PRAGMA user_version = 4;');""",
    """    _createVariantImageSchema();\n    _ensureBrandDiscountSchema();\n    _ensureProductPurchasePriceSourceSchema();\n    _createIndexes();\n    _database.execute('PRAGMA user_version = 5;');""",
    'schema initialization',
)
text = replace_once(
    text,
    """  void _ensureProductPriceColumns() {\n    _ensureColumn('products', 'purchase_price_cents', 'INTEGER');\n    _ensureColumn('products', 'sale_price_cents', 'INTEGER');\n  }""",
    """  void _ensureBrandDiscountSchema() {\n    if (!_hasColumn('brands', 'discount_basis_points')) {\n      _database.execute(\n        'ALTER TABLE brands ADD COLUMN discount_basis_points INTEGER '
        'CHECK(discount_basis_points IS NULL OR '
        '(discount_basis_points >= 0 AND discount_basis_points <= 10000));',\n      );\n    }\n  }\n\n  void _ensureProductPurchasePriceSourceSchema() {\n    if (_hasColumn('products', 'purchase_price_is_manual')) return;\n    _database.execute(\n      'ALTER TABLE products ADD COLUMN purchase_price_is_manual INTEGER '
      'NOT NULL DEFAULT 0 CHECK(purchase_price_is_manual IN (0, 1));',\n    );\n    _database.execute('''\n      UPDATE products\n      SET purchase_price_is_manual = CASE\n        WHEN purchase_price_cents IS NULL THEN 0\n        ELSE 1\n      END;\n    ''');\n  }\n\n  void _ensureProductPriceColumns() {\n    _ensureColumn('products', 'purchase_price_cents', 'INTEGER');\n    _ensureColumn('products', 'sale_price_cents', 'INTEGER');\n  }""",
    'schema helpers',
)
text = replace_once(
    text,
    """          INSERT INTO products (\n            id, name, category_id, brand_id, purchase_price_cents, sale_price_cents,\n            notes, is_active, created_at_utc, updated_at_utc)\n          SELECT id, name, category_id, brand_id, purchase_price_cents, sale_price_cents,\n            notes, COALESCE(is_active, 1), created_at_utc, updated_at_utc\n          FROM legacy_products;""",
    """          INSERT INTO products (\n            id, name, category_id, brand_id, purchase_price_cents,\n            purchase_price_is_manual, sale_price_cents,\n            notes, is_active, created_at_utc, updated_at_utc)\n          SELECT id, name, category_id, brand_id, purchase_price_cents,\n            CASE WHEN purchase_price_cents IS NULL THEN 0 ELSE 1 END, sale_price_cents,\n            notes, COALESCE(is_active, 1), created_at_utc, updated_at_utc\n          FROM legacy_products;""",
    'legacy products migration',
)
write(path, text)


# Catalog model additions.
path = 'lib/models/catalog.dart'
text = read(path)
text = replace_once(
    text,
    """class LookupItem {\n  const LookupItem({required this.id, required this.name, required this.productCount});\n  final int id;\n  final String name;\n  final int productCount;\n}""",
    """class LookupItem {\n  const LookupItem({\n    required this.id,\n    required this.name,\n    required this.productCount,\n    this.discountBasisPoints,\n  });\n\n  final int id;\n  final String name;\n  final int productCount;\n  final int? discountBasisPoints;\n\n  String? get discountPercentDisplay {\n    final value = discountBasisPoints;\n    if (value == null) return null;\n    final whole = value ~/ 100;\n    final decimals = value % 100;\n    if (decimals == 0) return '$whole%';\n    var fraction = decimals.toString().padLeft(2, '0');\n    if (fraction.endsWith('0')) fraction = fraction.substring(0, 1);\n    final separator = AppStrings.isEnglish ? '.' : ',';\n    return '$whole$separator$fraction%';\n  }\n}""",
    'LookupItem model',
)
text = replace_once(
    text,
    """    this.purchasePriceCents,\n    this.salePriceCents,\n    this.notes,""",
    """    this.purchasePriceCents,\n    this.purchasePriceIsManual = false,\n    this.salePriceCents,\n    this.notes,""",
    'ProductSummary constructor',
)
text = replace_once(
    text,
    """  final int? purchasePriceCents;\n  final int? salePriceCents;\n  final String? notes;""",
    """  final int? purchasePriceCents;\n  final bool purchasePriceIsManual;\n  final int? salePriceCents;\n  final String? notes;""",
    'ProductSummary fields',
)
text = replace_once(
    text,
    """    this.purchasePriceCents,\n    this.salePriceCents,\n    this.notes,\n    required this.isActive,\n    required this.variants,""",
    """    this.purchasePriceCents,\n    this.purchasePriceIsManual,\n    this.salePriceCents,\n    this.notes,\n    required this.isActive,\n    required this.variants,""",
    'ProductDraft constructor',
)
text = replace_once(
    text,
    """  final int? purchasePriceCents;\n  final int? salePriceCents;\n  final String? notes;\n  final bool isActive;\n  final List<ProductVariantDraft> variants;""",
    """  final int? purchasePriceCents;\n  final bool? purchasePriceIsManual;\n  final int? salePriceCents;\n  final String? notes;\n  final bool isActive;\n  final List<ProductVariantDraft> variants;""",
    'ProductDraft fields',
)
write(path, text)


# Lookup repository with brand discounts and recalculation.
write('lib/repositories/lookup_repository.dart', r'''import '../core/database_service.dart';
import '../models/catalog.dart';

enum LookupKind { brand, category }

class LookupRepository {
  LookupRepository(this.database);
  final DatabaseService database;

  String _table(LookupKind kind) =>
      kind == LookupKind.brand ? 'brands' : 'categories';
  String _foreignKey(LookupKind kind) =>
      kind == LookupKind.brand ? 'brand_id' : 'category_id';
  String _label(LookupKind kind) =>
      kind == LookupKind.brand ? 'marca' : 'categoria';

  List<LookupItem> getAll(LookupKind kind) {
    final table = _table(kind);
    final key = _foreignKey(kind);
    final discountSelect = kind == LookupKind.brand
        ? 'l.discount_basis_points AS discount_basis_points'
        : 'NULL AS discount_basis_points';
    return database.db.select('''
      SELECT l.id, l.name, $discountSelect, COUNT(p.id) AS product_count
      FROM $table l LEFT JOIN products p ON p.$key=l.id
      GROUP BY l.id, l.name ORDER BY l.name COLLATE NOCASE, l.id;
    ''').map((row) => LookupItem(
      id: row['id'] as int,
      name: row['name'] as String,
      productCount: row['product_count'] as int,
      discountBasisPoints: row['discount_basis_points'] as int?,
    )).toList();
  }

  int create(
    LookupKind kind,
    String name, {
    int? discountBasisPoints,
  }) {
    final normalized = _normalize(kind, name);
    final table = _table(kind);
    if (kind == LookupKind.brand) _validateDiscount(discountBasisPoints);
    final ids = database.db.select('SELECT id FROM $table ORDER BY id;');
    var next = 1;
    for (final row in ids) {
      final id = row['id'] as int;
      if (id > next) break;
      if (id == next) next++;
    }
    if (kind == LookupKind.brand) {
      database.db.execute(
        'INSERT INTO brands (id, name, discount_basis_points) VALUES (?, ?, ?);',
        [next, normalized, discountBasisPoints],
      );
    } else {
      database.db.execute(
        'INSERT INTO categories (id, name) VALUES (?, ?);',
        [next, normalized],
      );
    }
    return next;
  }

  void rename(LookupKind kind, int id, String name) {
    if (kind == LookupKind.brand) {
      final rows = database.db.select(
        'SELECT discount_basis_points FROM brands WHERE id=? LIMIT 1;',
        [id],
      );
      if (rows.isEmpty) throw StateError('La marca non esiste più.');
      update(
        kind,
        id,
        name,
        discountBasisPoints: rows.first['discount_basis_points'] as int?,
      );
      return;
    }
    update(kind, id, name);
  }

  void update(
    LookupKind kind,
    int id,
    String name, {
    int? discountBasisPoints,
  }) {
    final normalized = _normalize(kind, name);
    final db = database.db;
    if (kind != LookupKind.brand) {
      db.execute('UPDATE categories SET name=? WHERE id=?;', [normalized, id]);
      if (db.updatedRows == 0) {
        throw StateError('La ${_label(kind)} non esiste più.');
      }
      return;
    }

    _validateDiscount(discountBasisPoints);
    db.execute('BEGIN;');
    try {
      final rows = db.select(
        'SELECT discount_basis_points FROM brands WHERE id=? LIMIT 1;',
        [id],
      );
      if (rows.isEmpty) throw StateError('La marca non esiste più.');
      final previous = rows.first['discount_basis_points'] as int?;
      db.execute(
        'UPDATE brands SET name=?, discount_basis_points=? WHERE id=?;',
        [normalized, discountBasisPoints, id],
      );
      if (previous != discountBasisPoints) {
        _recalculateAutomaticPurchasePrices(id, discountBasisPoints);
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void deleteAndReassign(LookupKind kind, int id, int? targetId) {
    if (id == targetId) {
      throw StateError(
        'La ${_label(kind)} di destinazione deve essere diversa da quella eliminata.',
      );
    }
    final table = _table(kind);
    final key = _foreignKey(kind);
    final db = database.db;
    db.execute('BEGIN;');
    try {
      int? targetDiscount;
      if (targetId != null) {
        final exists = db.select(
          'SELECT * FROM $table WHERE id=? LIMIT 1;',
          [targetId],
        );
        if (exists.isEmpty) {
          throw StateError(
            'La ${_label(kind)} di destinazione non esiste più.',
          );
        }
        if (kind == LookupKind.brand) {
          targetDiscount = exists.first['discount_basis_points'] as int?;
        }
      }

      if (kind == LookupKind.brand) {
        final now = DateTime.now().toUtc().toIso8601String();
        db.execute('''
          UPDATE products
          SET brand_id=?,
              purchase_price_cents = CASE
                WHEN purchase_price_is_manual=1 THEN purchase_price_cents
                WHEN ? IS NULL OR sale_price_cents IS NULL THEN NULL
                ELSE CAST(ROUND(
                  sale_price_cents * (10000 - ?) / 10000.0
                ) AS INTEGER)
              END,
              updated_at_utc=?
          WHERE brand_id=?;
        ''', [targetId, targetDiscount, targetDiscount, now, id]);
      } else {
        db.execute('UPDATE products SET $key=? WHERE $key=?;', [targetId, id]);
      }

      db.execute('DELETE FROM $table WHERE id=?;', [id]);
      if (db.updatedRows == 0) {
        throw StateError('La ${_label(kind)} non esiste più.');
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _recalculateAutomaticPurchasePrices(
    int brandId,
    int? discountBasisPoints,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute('''
      UPDATE products
      SET purchase_price_cents = CASE
            WHEN ? IS NULL OR sale_price_cents IS NULL THEN NULL
            ELSE CAST(ROUND(
              sale_price_cents * (10000 - ?) / 10000.0
            ) AS INTEGER)
          END,
          updated_at_utc=?
      WHERE brand_id=? AND purchase_price_is_manual=0;
    ''', [discountBasisPoints, discountBasisPoints, now, brandId]);
  }

  void _validateDiscount(int? value) {
    if (value == null) return;
    if (value < 0 || value > 10000) {
      throw ArgumentError('Lo sconto del brand deve essere compreso tra 0% e 100%.');
    }
  }

  String _normalize(LookupKind kind, String name) {
    final result = name.trim();
    if (result.isEmpty) {
      throw ArgumentError('Il nome della ${_label(kind)} è obbligatorio.');
    }
    return result;
  }
}
''')


# Lookup UI: add optional brand discount percentage.
path = 'lib/pages/lookups_page.dart'
text = read(path)
start = text.index('  Future<void> _edit(')
end = text.index('  Future<void> _delete(', start)
new_edit = r'''  Future<void> _edit(LookupKind kind, [LookupItem? item]) async {
    final controller = TextEditingController(text: item?.name ?? '');
    final discountController = TextEditingController(
      text: item?.discountBasisPoints == null
          ? ''
          : (item!.discountBasisPoints! / 100)
              .toStringAsFixed(item.discountBasisPoints! % 100 == 0 ? 0 : 2)
              .replaceAll('.', AppStrings.isEnglish ? '.' : ','),
    );
    final label = _kindLabel(kind);
    String? discountError;

    final value = await showDialog<_LookupEditDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          void submit() {
            int? discountBasisPoints;
            if (kind == LookupKind.brand) {
              final raw = discountController.text.trim().replaceAll(',', '.');
              if (raw.isNotEmpty) {
                final percent = double.tryParse(raw);
                if (percent == null || percent < 0 || percent > 100) {
                  setLocal(() => discountError = AppStrings.pair(
                        'Inserisci una percentuale compresa tra 0 e 100.',
                        'Enter a percentage between 0 and 100.',
                      ));
                  return;
                }
                discountBasisPoints = (percent * 100).round();
              }
            }
            Navigator.pop(
              dialogContext,
              _LookupEditDraft(
                name: controller.text,
                discountBasisPoints: discountBasisPoints,
              ),
            );
          }

          return AlertDialog(
            title: Text(
              item == null
                  ? AppStrings.pair('Nuova $label', 'New $label')
                  : AppStrings.pair('Modifica $label', 'Edit $label'),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: AppStrings.pair('Nome $label', '$label name'),
                    ),
                  ),
                  if (kind == LookupKind.brand) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: discountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        if (discountError != null) {
                          setLocal(() => discountError = null);
                        }
                      },
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: AppStrings.pair(
                          'Sconto al negozio',
                          'Store discount',
                        ),
                        suffixText: '%',
                        helperText: AppStrings.pair(
                          'Facoltativo. Usato per calcolare automaticamente il prezzo di acquisto.',
                          'Optional. Used to calculate the purchase price automatically.',
                        ),
                        errorText: discountError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                onPressed: submit,
                child: Text(AppStrings.t('save')),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    discountController.dispose();
    if (value == null) return;
    try {
      if (item == null) {
        widget.services.lookups.create(
          kind,
          value.name,
          discountBasisPoints: value.discountBasisPoints,
        );
      } else {
        widget.services.lookups.update(
          kind,
          item.id,
          value.name,
          discountBasisPoints: value.discountBasisPoints,
        );
      }
      setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

'''
text = text[:start] + new_edit + text[end:]
insert_at = text.index('class _LookupList extends StatelessWidget')
text = text[:insert_at] + r'''class _LookupEditDraft {
  const _LookupEditDraft({
    required this.name,
    required this.discountBasisPoints,
  });

  final String name;
  final int? discountBasisPoints;
}

''' + text[insert_at:]
old_subtitle = """                      subtitle: Text(\n                        '${item.productCount} ${item.productCount == 1 ? AppStrings.pair('prodotto', 'product') : AppStrings.pair('prodotti', 'products')}',\n                      ),"""
new_subtitle = """                      subtitle: Text(\n                        kind == LookupKind.brand\n                            ? '${AppStrings.pair('Sconto al negozio', 'Store discount')}: ${item.discountPercentDisplay ?? AppStrings.pair('non impostato', 'not set')} · '\n                                '${item.productCount} ${item.productCount == 1 ? AppStrings.pair('prodotto', 'product') : AppStrings.pair('prodotti', 'products')}'\n                            : '${item.productCount} ${item.productCount == 1 ? AppStrings.pair('prodotto', 'product') : AppStrings.pair('prodotti', 'products')}',\n                      ),"""
text = replace_once(text, old_subtitle, new_subtitle, 'lookup list subtitle')
write(path, text)


# Product repository: automatic purchase price source.
path = 'lib/repositories/product_repository.dart'
text = read(path)
old_method = """  int _saveProductRow(int productId, ProductVariantDraft variant, String now) {"""
# no-op sentinel: make sure the following target exists separately
if old_method in text:
    pass
# Add helper before _saveProductRow for products.
needle = "  int _saveProductRow(ProductDraft draft, String name, String now) {\n"
helper = r'''  int? _automaticPurchasePrice(int? brandId, int? salePriceCents) {
    if (brandId == null || salePriceCents == null) return null;
    final rows = _db.select(
      'SELECT discount_basis_points FROM brands WHERE id=? LIMIT 1;',
      [brandId],
    );
    if (rows.isEmpty) return null;
    final discount = rows.first['discount_basis_points'] as int?;
    if (discount == null) return null;
    return ((salePriceCents * (10000 - discount)) + 5000) ~/ 10000;
  }

'''
text = replace_once(text, needle, helper + needle, 'automatic purchase helper')
start = text.index('  int _saveProductRow(ProductDraft draft, String name, String now) {')
end = text.index('  int _saveVariantRow(', start)
new_save_product = r'''  int _saveProductRow(ProductDraft draft, String name, String now) {
    final purchaseIsManual =
        draft.purchasePriceIsManual ?? draft.purchasePriceCents != null;
    final purchasePrice = purchaseIsManual
        ? draft.purchasePriceCents
        : _automaticPurchasePrice(draft.brandId, draft.salePriceCents);

    if (draft.id != null) {
      _db.execute('''
        UPDATE products
        SET name=?, category_id=?, brand_id=?, purchase_price_cents=?,
            purchase_price_is_manual=?, sale_price_cents=?, notes=?, is_active=?,
            updated_at_utc=?
        WHERE id=?;
      ''', [
        name,
        draft.categoryId,
        draft.brandId,
        purchasePrice,
        purchaseIsManual ? 1 : 0,
        draft.salePriceCents,
        _optional(draft.notes),
        draft.isActive ? 1 : 0,
        now,
        draft.id,
      ]);
      if (_db.updatedRows == 0) {
        throw StateError('Il prodotto da modificare non esiste più.');
      }
      return draft.id!;
    }
    _db.execute('''
      INSERT INTO products (
        name, category_id, brand_id, purchase_price_cents,
        purchase_price_is_manual, sale_price_cents,
        notes, is_active, created_at_utc, updated_at_utc)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      name,
      draft.categoryId,
      draft.brandId,
      purchasePrice,
      purchaseIsManual ? 1 : 0,
      draft.salePriceCents,
      _optional(draft.notes),
      draft.isActive ? 1 : 0,
      now,
      now,
    ]);
    return _db.lastInsertRowId;
  }

'''
text = text[:start] + new_save_product + text[end:]
text = replace_once(
    text,
    """        purchasePriceCents: row['product_purchase_price_cents'] as int?,\n        salePriceCents: row['product_sale_price_cents'] as int?,""",
    """        purchasePriceCents: row['product_purchase_price_cents'] as int?,\n        purchasePriceIsManual: (row['purchase_price_is_manual'] as int) != 0,\n        salePriceCents: row['product_sale_price_cents'] as int?,""",
    'summary manual flag reader',
)
text = replace_once(
    text,
    """      p.purchase_price_cents AS product_purchase_price_cents,\n      p.sale_price_cents AS product_sale_price_cents,""",
    """      p.purchase_price_cents AS product_purchase_price_cents,\n      p.purchase_price_is_manual,\n      p.sale_price_cents AS product_sale_price_cents,""",
    'summary manual flag select',
)
write(path, text)


# Product editor: live automatic calculation + clearer labels.
path = 'lib/pages/product_editor_dialog.dart'
text = read(path)
text = replace_once(
    text,
    """  bool _active = true;\n  String? _error;""",
    """  bool _active = true;\n  bool _purchaseManual = false;\n  String? _error;""",
    'purchase manual state',
)
needle = "  String _itEn(String it, String en) => AppStrings.pair(it, en);\n\n"
helpers = r'''  LookupItem? _selectedBrand() {
    final id = _brandId;
    if (id == null) return null;
    for (final brand in widget.services.lookups.getAll(LookupKind.brand)) {
      if (brand.id == id) return brand;
    }
    return null;
  }

  int? _automaticPurchaseCents() {
    final discount = _selectedBrand()?.discountBasisPoints;
    if (discount == null) return null;
    final sale = parseEuroCents(_sale.text);
    if (sale == null) return null;
    return ((sale * (10000 - discount)) + 5000) ~/ 10000;
  }

  void _writePurchaseValue(int? cents) {
    final formatted = _moneyInput(cents);
    _purchase.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _refreshAutomaticPurchase() {
    if (_purchaseManual) return;
    try {
      _writePurchaseValue(_automaticPurchaseCents());
    } catch (_) {
      // Durante la digitazione il prezzo di vendita può essere temporaneamente
      // incompleto: in quel caso conserviamo l'ultimo calcolo valido.
    }
  }

  void _purchaseChanged(String value) {
    if (value.trim().isEmpty) {
      _purchaseManual = false;
      _refreshAutomaticPurchase();
      setState(() {});
      return;
    }
    if (!_purchaseManual) setState(() => _purchaseManual = true);
  }

  void _useAutomaticBrandPrice() {
    _purchaseManual = false;
    _refreshAutomaticPurchase();
    setState(() => _error = null);
  }

'''
text = replace_once(text, needle, needle + helpers, 'product editor helpers')
text = replace_once(
    text,
    """      final cents = parsePriceFormulaCents(_purchase.text);\n      if (cents == null) return;""",
    """      final cents = parsePriceFormulaCents(_purchase.text);\n      if (cents == null) return;\n      _purchaseManual = true;""",
    'manual formula flag',
)
text = replace_once(
    text,
    """    _brandId = product?.brandId;\n    _categoryId = product?.categoryId;\n    _active = product?.isActive ?? true;""",
    """    _brandId = product?.brandId;\n    _categoryId = product?.categoryId;\n    _active = product?.isActive ?? true;\n    _purchaseManual = product?.purchasePriceIsManual ?? false;\n    if (!_purchaseManual) _refreshAutomaticPurchase();""",
    'initial purchase source',
)
text = replace_once(
    text,
    """        purchasePriceCents: parsePriceFormulaCents(_purchase.text),\n        salePriceCents: parseEuroCents(_sale.text),""",
    """        purchasePriceCents: parsePriceFormulaCents(_purchase.text),\n        purchasePriceIsManual: _purchaseManual,\n        salePriceCents: parseEuroCents(_sale.text),""",
    'save purchase source',
)
text = replace_once(
    text,
    """                    onChanged: (value) => setState(() => _brandId = value),""",
    """                    onChanged: (value) {\n                      _brandId = value;\n                      if (!_purchaseManual) _refreshAutomaticPurchase();\n                      setState(() {});\n                    },""",
    'brand changed behavior',
)
old_purchase_field = r'''                  child: TextField(
                    controller: _purchase,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _evaluatePurchaseFormula(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Prezzo acquisto prodotto $currency',
                        'Product purchase price $currency',
                      ),
                    ),
                  ),'''
new_purchase_field = r'''                  child: TextField(
                    controller: _purchase,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onChanged: _purchaseChanged,
                    onSubmitted: (_) => _evaluatePurchaseFormula(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Prezzo di acquisto $currency',
                        'Purchase price $currency',
                      ),
                      helperText: _selectedBrand()?.discountPercentDisplay == null
                          ? null
                          : _purchaseManual
                              ? _itEn(
                                  'Manuale · sconto brand ${_selectedBrand()!.discountPercentDisplay}',
                                  'Manual · brand discount ${_selectedBrand()!.discountPercentDisplay}',
                                )
                              : _itEn(
                                  'Automatico da ${_selectedBrand()!.name}: -${_selectedBrand()!.discountPercentDisplay}',
                                  'Automatic from ${_selectedBrand()!.name}: -${_selectedBrand()!.discountPercentDisplay}',
                                ),
                      suffixIcon: _purchaseManual &&
                              _selectedBrand()?.discountBasisPoints != null
                          ? IconButton(
                              tooltip: _itEn(
                                'Ripristina calcolo automatico dal brand',
                                'Restore automatic brand calculation',
                              ),
                              onPressed: _useAutomaticBrandPrice,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                            )
                          : null,
                    ),
                  ),'''
text = replace_once(text, old_purchase_field, new_purchase_field, 'purchase field')
old_sale_field = r'''                  child: TextField(
                    controller: _sale,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Prezzo vendita prodotto $currency',
                        'Product sale price $currency',
                      ),
                    ),
                  ),'''
new_sale_field = r'''                  child: TextField(
                    controller: _sale,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      if (!_purchaseManual) {
                        _refreshAutomaticPurchase();
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Prezzo di vendita $currency',
                        'Sale price $currency',
                      ),
                    ),
                  ),'''
text = replace_once(text, old_sale_field, new_sale_field, 'sale field')
write(path, text)


# Database test schema version / columns.
path = 'test/database_service_test.dart'
text = read(path)
text = text.replace(
    "fresh database creates schema version 4 with product prices and variant images",
    "fresh database creates schema version 5 with brand discounts and purchase price source",
)
text = replace_once(text, 'expect(version, 4);', 'expect(version, 5);', 'database schema version test')
text = replace_once(
    text,
    """      expect(productColumns, containsAll(<String>{'purchase_price_cents', 'sale_price_cents'}));""",
    """      expect(\n        productColumns,\n        containsAll(<String>{\n          'purchase_price_cents',\n          'purchase_price_is_manual',\n          'sale_price_cents',\n        }),\n      );\n      final brandColumns = service.db\n          .select('PRAGMA table_info(brands);')\n          .map((row) => row['name'] as String)\n          .toSet();\n      expect(brandColumns, contains('discount_basis_points'));""",
    'database schema columns test',
)
write(path, text)


# Dedicated behavior tests.
write('test/brand_discount_test.dart', r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/catalog.dart';
import 'package:local_store_management/repositories/lookup_repository.dart';
import 'package:local_store_management/repositories/product_repository.dart';

void main() {
  late Directory temp;
  late DatabaseService database;
  late LookupRepository lookups;
  late ProductRepository products;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lsms-brand-discount-');
    database = DatabaseService(
      '${temp.path}${Platform.pathSeparator}store.db',
    );
    await database.initialize();
    lookups = LookupRepository(database);
    products = ProductRepository(database);
  });

  tearDown(() async {
    database.dispose();
    await temp.delete(recursive: true);
  });

  ProductDraft draft({
    int? id,
    required String name,
    required int brandId,
    required int salePriceCents,
    int? purchasePriceCents,
    bool? purchasePriceIsManual,
  }) => ProductDraft(
        id: id,
        name: name,
        brandId: brandId,
        salePriceCents: salePriceCents,
        purchasePriceCents: purchasePriceCents,
        purchasePriceIsManual: purchasePriceIsManual,
        isActive: true,
        variants: [
          ProductVariantDraft(
            sku: products.generateSku(),
            isActive: true,
            barcodes: const [],
          ),
        ],
      );

  test('brand discount calculates automatic purchase price', () {
    final brandId = lookups.create(
      LookupKind.brand,
      'Macna',
      discountBasisPoints: 4000,
    );
    final productId = products.save(
      draft(
        name: 'Giacca',
        brandId: brandId,
        salePriceCents: 20000,
        purchasePriceIsManual: false,
      ),
    );

    final product = products.getProduct(productId)!;
    expect(product.purchasePriceCents, 12000);
    expect(product.purchasePriceIsManual, isFalse);
  });

  test('changing brand discount updates only automatic purchase prices', () {
    final brandId = lookups.create(
      LookupKind.brand,
      'Macna',
      discountBasisPoints: 4000,
    );
    final automaticId = products.save(
      draft(
        name: 'Automatico',
        brandId: brandId,
        salePriceCents: 20000,
        purchasePriceIsManual: false,
      ),
    );
    final manualId = products.save(
      draft(
        name: 'Manuale',
        brandId: brandId,
        salePriceCents: 20000,
        purchasePriceCents: 13500,
        purchasePriceIsManual: true,
      ),
    );

    lookups.update(
      LookupKind.brand,
      brandId,
      'Macna',
      discountBasisPoints: 5000,
    );

    expect(products.getProduct(automaticId)!.purchasePriceCents, 10000);
    expect(products.getProduct(automaticId)!.purchasePriceIsManual, isFalse);
    expect(products.getProduct(manualId)!.purchasePriceCents, 13500);
    expect(products.getProduct(manualId)!.purchasePriceIsManual, isTrue);
  });

  test('removing brand discount clears only automatic purchase price', () {
    final brandId = lookups.create(
      LookupKind.brand,
      'Macna',
      discountBasisPoints: 4000,
    );
    final automaticId = products.save(
      draft(
        name: 'Automatico',
        brandId: brandId,
        salePriceCents: 20000,
        purchasePriceIsManual: false,
      ),
    );

    lookups.update(
      LookupKind.brand,
      brandId,
      'Macna',
      discountBasisPoints: null,
    );

    expect(products.getProduct(automaticId)!.purchasePriceCents, isNull);
    expect(products.getProduct(automaticId)!.purchasePriceIsManual, isFalse);
  });
}
''')


# Remove temporary helper files from the final application commit.
for temporary in (
    'tool/apply_brand_discount.py',
    '.github/workflows/apply-brand-discount.yml',
    '.github/brand-discount-trigger',
):
    target = Path(temporary)
    if target.exists():
        target.unlink()

print('Brand discount patch applied successfully.')
