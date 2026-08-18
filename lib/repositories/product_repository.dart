import 'package:sqlite3/sqlite3.dart';

import '../core/database_service.dart';
import '../models/catalog.dart';

class ProductRepository {
  ProductRepository(this.database);

  final DatabaseService database;
  Database get _db => database.db;

  List<ProductVariant> search([String? query]) {
    final q = query?.trim() ?? '';
    final rows = _db.select('''
      $_variantSelect
      WHERE ? = ''
         OR pv.sku LIKE ? COLLATE NOCASE
         OR p.name LIKE ? COLLATE NOCASE
         OR COALESCE(b.name, '') LIKE ? COLLATE NOCASE
         OR COALESCE(c.name, '') LIKE ? COLLATE NOCASE
         OR COALESCE(pv.variant, '') LIKE ? COLLATE NOCASE
         OR COALESCE(pv.size, '') LIKE ? COLLATE NOCASE
         OR EXISTS (
              SELECT 1 FROM product_barcodes search_pb
              WHERE search_pb.variant_id = pv.id
                AND search_pb.barcode LIKE ? COLLATE NOCASE)
      ORDER BY COALESCE(b.name, '') COLLATE NOCASE,
               p.name COLLATE NOCASE,
               COALESCE(pv.variant, '') COLLATE NOCASE,
               COALESCE(pv.size, '') COLLATE NOCASE,
               pv.sku COLLATE NOCASE;
    ''', [q, for (var i = 0; i < 7; i++) '%$q%']);
    return rows.map(_readVariant).toList();
  }

  List<ProductSummary> searchProducts([String? query]) {
    final q = query?.trim() ?? '';
    final pattern = '%$q%';
    final rows = _db.select('''
      $_productSummarySelect
      WHERE ? = ''
         OR p.name LIKE ? COLLATE NOCASE
         OR COALESCE(b.name, '') LIKE ? COLLATE NOCASE
         OR COALESCE(c.name, '') LIKE ? COLLATE NOCASE
         OR EXISTS (
              SELECT 1
              FROM product_variants search_pv
              LEFT JOIN product_barcodes search_pb ON search_pb.variant_id = search_pv.id
              WHERE search_pv.product_id = p.id
                AND (search_pv.sku LIKE ? COLLATE NOCASE
                  OR COALESCE(search_pv.variant, '') LIKE ? COLLATE NOCASE
                  OR COALESCE(search_pv.size, '') LIKE ? COLLATE NOCASE
                  OR COALESCE(search_pb.barcode, '') LIKE ? COLLATE NOCASE))
      ORDER BY COALESCE(b.name, '') COLLATE NOCASE, p.name COLLATE NOCASE;
    ''', [q, pattern, pattern, pattern, pattern, pattern, pattern, pattern]);
    return rows.map(_readSummary).toList();
  }

  ProductSummary? getProduct(int productId) {
    final rows = _db.select('$_productSummarySelect WHERE p.id = ? LIMIT 1;', [productId]);
    return rows.isEmpty ? null : _readSummary(rows.first);
  }

  ProductVariant? getById(int variantId) {
    final rows = _db.select('$_variantSelect WHERE pv.id = ? LIMIT 1;', [variantId]);
    return rows.isEmpty ? null : _readVariant(rows.first);
  }

  List<ProductVariantDraft> getVariants(int productId) {
    final rows = _db.select('''
      SELECT pv.id, pv.sku, pv.variant, pv.size,
             pv.purchase_price_cents, pv.sale_price_cents, pv.is_active,
             COALESCE((SELECT SUM(sm.quantity_delta) FROM stock_movements sm WHERE sm.variant_id = pv.id), 0) AS stock
      FROM product_variants pv
      WHERE pv.product_id = ?
      ORDER BY COALESCE(pv.variant, '') COLLATE NOCASE,
               COALESCE(pv.size, '') COLLATE NOCASE,
               pv.sku COLLATE NOCASE;
    ''', [productId]);
    return rows.map((row) => ProductVariantDraft(
      id: row['id'] as int,
      sku: row['sku'] as String,
      variant: row['variant'] as String?,
      size: row['size'] as String?,
      purchasePriceCents: row['purchase_price_cents'] as int?,
      salePriceCents: row['sale_price_cents'] as int?,
      isActive: (row['is_active'] as int) != 0,
      barcodes: _getBarcodes(row['id'] as int),
      stockQuantity: row['stock'] as int,
    )).toList();
  }

  ProductVariant? findByBarcode(String barcodeOrSku) {
    final code = barcodeOrSku.trim();
    if (code.isEmpty) return null;
    final rows = _db.select('''
      $_variantSelect
      WHERE pv.sku = ? COLLATE NOCASE
         OR EXISTS (SELECT 1 FROM product_barcodes exact_pb
                    WHERE exact_pb.variant_id = pv.id AND exact_pb.barcode = ?)
      ORDER BY CASE WHEN pv.sku = ? COLLATE NOCASE THEN 1 ELSE 0 END DESC, pv.id
      LIMIT 1;
    ''', [code, code, code]);
    return rows.isEmpty ? null : _readVariant(rows.first);
  }

  int count() => _db.select('SELECT COUNT(*) AS count FROM products;').first['count'] as int;

  String generateSku() {
    final next = _db.select('SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM product_variants;').first['next_id'] as int;
    return 'ART${next.toString().padLeft(6, '0')}';
  }

  int save(ProductDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) throw StateError('Il nome del prodotto è obbligatorio.');
    if (draft.variants.isEmpty) throw StateError('Il prodotto deve contenere almeno una variante.');

    final variants = draft.variants.map(_normalizeVariant).toList();
    _validateLocalUniqueness(name, variants);

    _db.execute('BEGIN;');
    try {
      for (final variant in variants) {
        final skuOwner = _findSkuOwner(variant.sku, variant.id);
        if (skuOwner != null) {
          throw StateError('Lo SKU «${variant.sku}» è già utilizzato da $skuOwner.');
        }
        for (final barcode in variant.barcodes) {
          final barcodeOwner = _findBarcodeOwner(barcode, variant.id);
          if (barcodeOwner != null) {
            throw StateError('Il barcode «$barcode» è già utilizzato da $barcodeOwner.');
          }
        }
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final productId = _saveProductRow(draft, name, now);
      for (final variant in variants) {
        final variantId = _saveVariantRow(productId, variant, now);
        _replaceBarcodes(variantId, variant.barcodes);
      }
      _db.execute('COMMIT;');
      return productId;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  int _saveProductRow(ProductDraft draft, String name, String now) {
    if (draft.id != null) {
      _db.execute('''
        UPDATE products
        SET name=?, category_id=?, brand_id=?, purchase_price_cents=?, sale_price_cents=?,
            notes=?, is_active=?, updated_at_utc=?
        WHERE id=?;
      ''', [
        name,
        draft.categoryId,
        draft.brandId,
        draft.purchasePriceCents,
        draft.salePriceCents,
        _optional(draft.notes),
        draft.isActive ? 1 : 0,
        now,
        draft.id,
      ]);
      if (_db.updatedRows == 0) throw StateError('Il prodotto da modificare non esiste più.');
      return draft.id!;
    }
    _db.execute('''
      INSERT INTO products (
        name, category_id, brand_id, purchase_price_cents, sale_price_cents,
        notes, is_active, created_at_utc, updated_at_utc)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      name,
      draft.categoryId,
      draft.brandId,
      draft.purchasePriceCents,
      draft.salePriceCents,
      _optional(draft.notes),
      draft.isActive ? 1 : 0,
      now,
      now,
    ]);
    return _db.lastInsertRowId;
  }

  int _saveVariantRow(int productId, ProductVariantDraft variant, String now) {
    if (variant.id != null) {
      _db.execute('''
        UPDATE product_variants SET sku=?, variant=?, size=?, purchase_price_cents=?, sale_price_cents=?,
          is_active=?, updated_at_utc=? WHERE id=? AND product_id=?;
      ''', [variant.sku, _optional(variant.variant), _optional(variant.size), variant.purchasePriceCents,
        variant.salePriceCents, variant.isActive ? 1 : 0, now, variant.id, productId]);
      if (_db.updatedRows == 0) throw StateError('La variante SKU ${variant.sku} non esiste più o non appartiene a questo prodotto.');
      return variant.id!;
    }
    _db.execute('''
      INSERT INTO product_variants (product_id, sku, variant, size, purchase_price_cents, sale_price_cents,
        is_active, created_at_utc, updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [productId, variant.sku, _optional(variant.variant), _optional(variant.size), variant.purchasePriceCents,
      variant.salePriceCents, variant.isActive ? 1 : 0, now, now]);
    return _db.lastInsertRowId;
  }

  void _replaceBarcodes(int variantId, List<String> barcodes) {
    _db.execute('DELETE FROM product_barcodes WHERE variant_id=?;', [variantId]);
    for (var i = 0; i < barcodes.length; i++) {
      _db.execute('INSERT INTO product_barcodes (variant_id, barcode, is_primary) VALUES (?, ?, ?);',
          [variantId, barcodes[i], i == 0 ? 1 : 0]);
    }
  }

  List<String> _getBarcodes(int variantId) => _db
      .select('SELECT barcode FROM product_barcodes WHERE variant_id=? ORDER BY is_primary DESC, id;', [variantId])
      .map((row) => row['barcode'] as String)
      .toList();

  String? _findSkuOwner(String sku, int? excludeId) {
    final rows = _db.select('''
      SELECT p.name, pv.sku, pv.variant, pv.size FROM product_variants pv
      JOIN products p ON p.id=pv.product_id
      WHERE pv.sku=? COLLATE NOCASE AND (? IS NULL OR pv.id<>?) LIMIT 1;
    ''', [sku, excludeId, excludeId]);
    return rows.isEmpty ? null : _ownerDisplay(rows.first);
  }

  String? _findBarcodeOwner(String barcode, int? excludeId) {
    final rows = _db.select('''
      SELECT p.name, pv.sku, pv.variant, pv.size FROM product_barcodes pb
      JOIN product_variants pv ON pv.id=pb.variant_id JOIN products p ON p.id=pv.product_id
      WHERE pb.barcode=? AND (? IS NULL OR pv.id<>?) LIMIT 1;
    ''', [barcode, excludeId, excludeId]);
    return rows.isEmpty ? null : _ownerDisplay(rows.first);
  }

  String _ownerDisplay(Row row) {
    final parts = <String>[];
    final variant = row['variant'] as String?;
    final size = row['size'] as String?;
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) parts.add('Taglia ${size!.trim()}');
    final detail = parts.isEmpty ? 'Variante base' : parts.join(' · ');
    return '${row['name']} — $detail (SKU ${row['sku']})';
  }

  void _validateLocalUniqueness(String productName, List<ProductVariantDraft> variants) {
    final skus = <String, ProductVariantDraft>{};
    final barcodes = <String, ProductVariantDraft>{};
    for (final variant in variants) {
      if (variant.sku.isEmpty) throw StateError('Ogni variante deve avere uno SKU.');
      final key = variant.sku.toLowerCase();
      final skuOwner = skus[key];
      if (skuOwner != null && skuOwner.id != variant.id) {
        throw StateError('Lo SKU «${variant.sku}» è usato due volte nel prodotto $productName.');
      }
      skus[key] = variant;
      for (final barcode in variant.barcodes) {
        final owner = barcodes[barcode];
        if (owner != null && owner.id != variant.id) {
          throw StateError('Il barcode «$barcode» è già assegnato a $productName — ${owner.variantDisplay}.');
        }
        barcodes[barcode] = variant;
      }
    }
  }

  ProductVariantDraft _normalizeVariant(ProductVariantDraft value) => ProductVariantDraft(
        id: value.id,
        sku: value.sku.trim(),
        variant: _optional(value.variant),
        size: _optional(value.size),
        purchasePriceCents: value.purchasePriceCents,
        salePriceCents: value.salePriceCents,
        isActive: value.isActive,
        barcodes: value.barcodes.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(),
        stockQuantity: value.stockQuantity,
      );

  String? _optional(String? value) => value?.trim().isNotEmpty == true ? value!.trim() : null;

  ProductVariant _readVariant(Row row) => ProductVariant(
        id: row['id'] as int,
        productId: row['product_id'] as int,
        sku: row['sku'] as String,
        barcode: row['primary_barcode'] as String?,
        name: row['name'] as String,
        categoryId: row['category_id'] as int?,
        category: row['category_name'] as String?,
        brandId: row['brand_id'] as int?,
        brand: row['brand_name'] as String?,
        variant: row['variant'] as String?,
        size: row['size'] as String?,
        purchasePriceCents: row['purchase_price_cents'] as int?,
        salePriceCents: row['sale_price_cents'] as int?,
        notes: row['notes'] as String?,
        isActive: (row['is_active'] as int) != 0,
        stockQuantity: row['stock_quantity'] as int,
        barcodesDisplay: row['barcodes_display'] as String?,
      );

  ProductSummary _readSummary(Row row) => ProductSummary(
        id: row['id'] as int,
        name: row['name'] as String,
        categoryId: row['category_id'] as int?,
        category: row['category_name'] as String?,
        brandId: row['brand_id'] as int?,
        brand: row['brand_name'] as String?,
        purchasePriceCents: row['product_purchase_price_cents'] as int?,
        salePriceCents: row['product_sale_price_cents'] as int?,
        notes: row['notes'] as String?,
        isActive: (row['is_active'] as int) != 0,
        variantCount: row['variant_count'] as int,
        stockQuantity: row['stock_quantity'] as int,
        minimumSalePriceCents: row['min_sale_price'] as int?,
        maximumSalePriceCents: row['max_sale_price'] as int?,
      );

  static const _variantSelect = '''
    SELECT pv.id, p.id AS product_id, pv.sku,
      (SELECT pb.barcode FROM product_barcodes pb WHERE pb.variant_id=pv.id ORDER BY pb.is_primary DESC, pb.id LIMIT 1) AS primary_barcode,
      p.name, p.category_id, c.name AS category_name, p.brand_id, b.name AS brand_name,
      pv.variant, pv.size,
      COALESCE(pv.purchase_price_cents, p.purchase_price_cents) AS purchase_price_cents,
      COALESCE(pv.sale_price_cents, p.sale_price_cents) AS sale_price_cents,
      p.notes,
      CASE WHEN p.is_active=1 AND pv.is_active=1 THEN 1 ELSE 0 END AS is_active,
      COALESCE((SELECT SUM(sm.quantity_delta) FROM stock_movements sm WHERE sm.variant_id=pv.id), 0) AS stock_quantity,
      (SELECT GROUP_CONCAT(pb2.barcode, ' • ') FROM product_barcodes pb2 WHERE pb2.variant_id=pv.id) AS barcodes_display
    FROM product_variants pv
    JOIN products p ON p.id=pv.product_id
    LEFT JOIN categories c ON c.id=p.category_id
    LEFT JOIN brands b ON b.id=p.brand_id
  ''';

  static const _productSummarySelect = '''
    SELECT p.id, p.name, p.category_id, c.name AS category_name, p.brand_id, b.name AS brand_name,
      p.purchase_price_cents AS product_purchase_price_cents,
      p.sale_price_cents AS product_sale_price_cents,
      p.notes, p.is_active,
      (SELECT COUNT(*) FROM product_variants pv_count WHERE pv_count.product_id=p.id) AS variant_count,
      COALESCE((SELECT SUM(sm.quantity_delta) FROM product_variants pv_stock
        LEFT JOIN stock_movements sm ON sm.variant_id=pv_stock.id WHERE pv_stock.product_id=p.id), 0) AS stock_quantity,
      (SELECT MIN(COALESCE(pv_min.sale_price_cents, p.sale_price_cents)) FROM product_variants pv_min
        WHERE pv_min.product_id=p.id) AS min_sale_price,
      (SELECT MAX(COALESCE(pv_max.sale_price_cents, p.sale_price_cents)) FROM product_variants pv_max
        WHERE pv_max.product_id=p.id) AS max_sale_price
    FROM products p
    LEFT JOIN categories c ON c.id=p.category_id
    LEFT JOIN brands b ON b.id=p.brand_id
  ''';
}
