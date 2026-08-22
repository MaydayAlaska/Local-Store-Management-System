import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/repositories/customer_repository.dart';
import 'package:local_store_management/repositories/product_deletion.dart';
import 'package:local_store_management/repositories/product_repository.dart';

void main() {
  test('hard product deletion removes variants and keeps sales snapshots', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-product-delete-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final database = DatabaseService(path);

    try {
      await database.initialize();
      CustomerRepository(database);
      final repository = ProductRepository(database);
      const now = '2026-08-23T00:00:00.000Z';

      database.db.execute(
        'INSERT INTO products (name, sale_price_cents, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
        ['Prodotto da eliminare', 1500, now, now],
      );
      final productId = database.db.lastInsertRowId;

      final variantIds = <int>[];
      for (var index = 1; index <= 2; index++) {
        database.db.execute(
          'INSERT INTO product_variants (product_id, sku, variant, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, ?, 1, ?, ?);',
          [productId, 'DEL-$index', 'Variante $index', now, now],
        );
        final variantId = database.db.lastInsertRowId;
        variantIds.add(variantId);
        database.db.execute(
          'INSERT INTO product_barcodes (variant_id, barcode, is_primary) VALUES (?, ?, 1);',
          [variantId, '990000000000$index'],
        );
        database.db.execute(
          'INSERT INTO stock_movements (variant_id, movement_type, quantity_delta, note, created_at_utc) VALUES (?, ?, ?, ?, ?);',
          [variantId, 'load', 5, 'Test', now],
        );
        database.db.execute(
          'INSERT INTO variant_images (variant_id, image_bytes, updated_at_utc) VALUES (?, ?, ?);',
          [variantId, Uint8List.fromList(<int>[1, 2, index]), now],
        );
      }

      database.db.execute(
        'INSERT INTO sales_orders (order_number, gross_total_cents, final_total_cents, created_at_utc) VALUES (?, ?, ?, ?);',
        ['ORD-DELETE-1', 1500, 1500, now],
      );
      final orderId = database.db.lastInsertRowId;
      database.db.execute(
        'INSERT INTO sales_order_items (order_id, variant_id, sku, product_name, variant_display, quantity, unit_price_cents, gross_total_cents, final_total_cents) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?);',
        [
          orderId,
          variantIds.first,
          'DEL-1',
          'Prodotto da eliminare',
          'Variante 1',
          1500,
          1500,
          1500,
        ],
      );

      expect(repository.deleteProduct(productId), isTrue);
      expect(repository.getProduct(productId), isNull);
      expect(
        database.db.select(
          'SELECT COUNT(*) AS count FROM product_variants WHERE product_id=?;',
          [productId],
        ).first['count'],
        0,
      );
      expect(database.db.select('SELECT COUNT(*) AS count FROM product_barcodes;').first['count'], 0);
      expect(database.db.select('SELECT COUNT(*) AS count FROM stock_movements;').first['count'], 0);
      expect(database.db.select('SELECT COUNT(*) AS count FROM variant_images;').first['count'], 0);

      final historicalLine = database.db.select(
        'SELECT variant_id, sku, product_name, variant_display FROM sales_order_items WHERE order_id=? LIMIT 1;',
        [orderId],
      ).single;
      expect(historicalLine['variant_id'], isNull);
      expect(historicalLine['sku'], 'DEL-1');
      expect(historicalLine['product_name'], 'Prodotto da eliminare');
      expect(historicalLine['variant_display'], 'Variante 1');

      expect(repository.deleteProduct(productId), isFalse);
    } finally {
      database.dispose();
      await temp.delete(recursive: true);
    }
  });
}
