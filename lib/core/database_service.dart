import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'app_paths.dart';

class DatabaseService {
  DatabaseService(this.path);

  final String path;
  late Database _database;

  Database get db => _database;

  Future<void> initialize() async {
    Directory(p.dirname(path)).createSync(recursive: true);
    _database = sqlite3.open(path);
    _database.execute('PRAGMA journal_mode = DELETE;');
    _database.execute('PRAGMA foreign_keys = ON;');
    _createLookupTables();

    if (!_tableExists('products')) {
      _createCatalogSchema();
    } else if (_hasColumn('products', 'sku')) {
      _ensureLegacyColumns();
      _migrateLegacyCategories();
      _migrateLegacyBrands();
      await _createPreMigrationBackup('variants');
      _migrateToProductVariantSchema();
    } else {
      _createCatalogSchema();
      final needsPriceMigration =
          !_hasColumn('products', 'purchase_price_cents') || !_hasColumn('products', 'sale_price_cents');
      if (needsPriceMigration) {
        await _createPreMigrationBackup('prices');
        _ensureProductPriceColumns();
        _migrateExistingVariantPricesToProducts();
      } else {
        _ensureProductPriceColumns();
      }
    }

    _createIndexes();
    _database.execute('PRAGMA user_version = 3;');
  }

  void dispose() => _database.dispose();

  void _createLookupTables() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
      );
      CREATE TABLE IF NOT EXISTS brands (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
      );
    ''');
  }

  void _createCatalogSchema() {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER,
        brand_id INTEGER,
        purchase_price_cents INTEGER,
        sale_price_cents INTEGER,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE SET NULL
      );
      CREATE TABLE IF NOT EXISTS product_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        sku TEXT NOT NULL COLLATE NOCASE UNIQUE,
        variant TEXT,
        size TEXT,
        purchase_price_cents INTEGER,
        sale_price_cents INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
      );
      CREATE TABLE IF NOT EXISTS product_barcodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant_id INTEGER NOT NULL,
        barcode TEXT NOT NULL UNIQUE,
        is_primary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
      );
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        quantity_delta INTEGER NOT NULL,
        note TEXT,
        created_at_utc TEXT NOT NULL,
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE RESTRICT
      );
    ''');
  }

  void _ensureProductPriceColumns() {
    _ensureColumn('products', 'purchase_price_cents', 'INTEGER');
    _ensureColumn('products', 'sale_price_cents', 'INTEGER');
  }

  void _ensureLegacyColumns() {
    _ensureColumn('products', 'category_id', 'INTEGER REFERENCES categories(id) ON DELETE SET NULL');
    _ensureColumn('products', 'brand_id', 'INTEGER REFERENCES brands(id) ON DELETE SET NULL');
    _ensureColumn('products', 'variant', 'TEXT');
    _ensureColumn('products', 'size', 'TEXT');
    _ensureColumn('products', 'notes', 'TEXT');
    _ensureColumn('products', 'is_active', 'INTEGER NOT NULL DEFAULT 1');
  }

  void _migrateLegacyCategories() {
    if (!_hasColumn('products', 'category')) return;
    _transaction(() {
      _database.execute('''
        INSERT OR IGNORE INTO categories (name)
        SELECT DISTINCT TRIM(category) FROM products
        WHERE category IS NOT NULL AND TRIM(category) <> '';
      ''');
      _database.execute('''
        UPDATE products SET category_id = (
          SELECT c.id FROM categories c
          WHERE c.name = TRIM(products.category) COLLATE NOCASE LIMIT 1
        )
        WHERE category_id IS NULL AND category IS NOT NULL AND TRIM(category) <> '';
      ''');
    });
  }

  void _migrateLegacyBrands() {
    if (!_hasColumn('products', 'brand')) return;
    _transaction(() {
      _database.execute('''
        INSERT OR IGNORE INTO brands (name)
        SELECT DISTINCT TRIM(brand) FROM products
        WHERE brand IS NOT NULL AND TRIM(brand) <> '';
      ''');
      _database.execute('''
        UPDATE products SET brand_id = (
          SELECT b.id FROM brands b
          WHERE b.name = TRIM(products.brand) COLLATE NOCASE LIMIT 1
        )
        WHERE brand_id IS NULL AND brand IS NOT NULL AND TRIM(brand) <> '';
      ''');
    });
  }

  Future<void> _createPreMigrationBackup(String reason) async {
    final destination = p.join(
      AppPaths.backupsDirectory,
      'store-pre-$reason-${_timestamp(DateTime.now())}.db',
    );
    _database.dispose();
    await File(path).copy(destination);
    _database = sqlite3.open(path);
    _database.execute('PRAGMA journal_mode = DELETE;');
    _database.execute('PRAGMA foreign_keys = ON;');
  }

  void _migrateToProductVariantSchema() {
    final hasLegacyMovements = _tableExists('stock_movements');
    _database.execute('PRAGMA foreign_keys = OFF;');
    try {
      _transaction(() {
        _database.execute('ALTER TABLE products RENAME TO legacy_products;');
        if (hasLegacyMovements) {
          _database.execute('ALTER TABLE stock_movements RENAME TO legacy_stock_movements;');
        }
        _createCatalogSchema();
        _database.execute('''
          INSERT INTO products (
            id, name, category_id, brand_id, purchase_price_cents, sale_price_cents,
            notes, is_active, created_at_utc, updated_at_utc)
          SELECT id, name, category_id, brand_id, purchase_price_cents, sale_price_cents,
            notes, COALESCE(is_active, 1), created_at_utc, updated_at_utc
          FROM legacy_products;
        ''');
        _database.execute('''
          INSERT INTO product_variants (
            id, product_id, sku, variant, size, purchase_price_cents, sale_price_cents,
            is_active, created_at_utc, updated_at_utc)
          SELECT id, id, sku, variant, size, NULL, NULL,
            COALESCE(is_active, 1), created_at_utc, updated_at_utc
          FROM legacy_products;
        ''');
        _database.execute('''
          INSERT INTO product_barcodes (variant_id, barcode, is_primary)
          SELECT id, TRIM(barcode), 1 FROM legacy_products
          WHERE barcode IS NOT NULL AND TRIM(barcode) <> '';
        ''');
        if (hasLegacyMovements) {
          _database.execute('''
            INSERT INTO stock_movements (id, variant_id, movement_type, quantity_delta, note, created_at_utc)
            SELECT id, product_id, movement_type, quantity_delta, note, created_at_utc
            FROM legacy_stock_movements;
          ''');
        }
        _database.execute('DROP TABLE legacy_products;');
        if (hasLegacyMovements) _database.execute('DROP TABLE legacy_stock_movements;');
      });
    } finally {
      _database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  void _migrateExistingVariantPricesToProducts() {
    _transaction(() {
      _promoteCommonVariantPrice('purchase_price_cents');
      _promoteCommonVariantPrice('sale_price_cents');
    });
  }

  void _promoteCommonVariantPrice(String column) {
    _database.execute('''
      UPDATE products
      SET $column = (
        SELECT MIN(pv.$column)
        FROM product_variants pv
        WHERE pv.product_id = products.id
      )
      WHERE $column IS NULL
        AND EXISTS (
          SELECT 1 FROM product_variants pv
          WHERE pv.product_id = products.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM product_variants pv
          WHERE pv.product_id = products.id AND pv.$column IS NULL
        )
        AND (
          SELECT COUNT(DISTINCT pv.$column)
          FROM product_variants pv
          WHERE pv.product_id = products.id
        ) = 1;
    ''');

    _database.execute('''
      UPDATE product_variants
      SET $column = NULL
      WHERE $column IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM products p
          WHERE p.id = product_variants.product_id
            AND p.$column IS NOT NULL
            AND p.$column = product_variants.$column
        );
    ''');
  }

  void _createIndexes() {
    _database.execute('''
      CREATE INDEX IF NOT EXISTS ix_categories_name ON categories(name COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_brands_name ON brands(name COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_products_brand_id ON products(brand_id);
      CREATE INDEX IF NOT EXISTS ix_products_category_id ON products(category_id);
      CREATE INDEX IF NOT EXISTS ix_product_variants_product_id ON product_variants(product_id);
      CREATE INDEX IF NOT EXISTS ix_product_variants_sku ON product_variants(sku COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_product_barcodes_variant_id ON product_barcodes(variant_id);
      CREATE INDEX IF NOT EXISTS ix_product_barcodes_barcode ON product_barcodes(barcode);
      CREATE INDEX IF NOT EXISTS ix_stock_movements_variant_id ON stock_movements(variant_id);
      CREATE INDEX IF NOT EXISTS ix_stock_movements_created_at ON stock_movements(created_at_utc DESC, id DESC);
    ''');
  }

  void _ensureColumn(String table, String column, String definition) {
    if (!_hasColumn(table, column)) {
      _database.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    }
  }

  bool _tableExists(String table) {
    final rows = _database.select(
      "SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name=?;",
      [table],
    );
    return (rows.first['count'] as int) > 0;
  }

  bool _hasColumn(String table, String column) {
    if (!_tableExists(table)) return false;
    return _database.select('PRAGMA table_info($table);').any(
      (row) => (row['name'] as String).toLowerCase() == column.toLowerCase(),
    );
  }

  void _transaction(void Function() action) {
    _database.execute('BEGIN;');
    try {
      action();
      _database.execute('COMMIT;');
    } catch (_) {
      _database.execute('ROLLBACK;');
      rethrow;
    }
  }

  static String _timestamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}';
}
