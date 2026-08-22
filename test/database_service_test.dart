import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/repositories/product_repository.dart';
import 'package:local_store_management/repositories/variant_image_repository.dart';

void main() {
  test('fresh database creates schema version 4 with product prices and variant images', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-db-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final version = service.db.select('PRAGMA user_version;').first.values.first as int;
      expect(version, 4);
      final tables = service.db
          .select("SELECT name FROM sqlite_master WHERE type='table';")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tables, containsAll(<String>{
        'products',
        'product_variants',
        'product_barcodes',
        'stock_movements',
        'brands',
        'categories',
        'variant_images',
      }));
      final productColumns = service.db
          .select('PRAGMA table_info(products);')
          .map((row) => row['name'] as String)
          .toSet();
      expect(productColumns, containsAll(<String>{'purchase_price_cents', 'sale_price_cents'}));
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('variant image repository stores replaces and removes image bytes', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-images-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      const now = '2026-08-22T00:00:00.000Z';
      service.db.execute(
        'INSERT INTO products (name, is_active, created_at_utc, updated_at_utc) VALUES (?, 1, ?, ?);',
        ['Immagine test', now, now],
      );
      final productId = service.db.lastInsertRowId;
      service.db.execute(
        'INSERT INTO product_variants (product_id, sku, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
        [productId, 'IMG-TEST', now, now],
      );
      final variantId = service.db.lastInsertRowId;

      final repository = VariantImageRepository(service);
      final first = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final second = Uint8List.fromList(<int>[9, 8, 7]);

      expect(repository.get(variantId), isNull);
      repository.set(variantId, first);
      expect(repository.get(variantId), orderedEquals(first));
      expect(repository.getMany(<int>[variantId])[variantId], orderedEquals(first));

      repository.set(variantId, second);
      expect(repository.get(variantId), orderedEquals(second));

      repository.set(variantId, null);
      expect(repository.get(variantId), isNull);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('product search can limit SQL results and barcode lookup stays exact', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-search-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      const now = '2026-08-19T00:00:00.000Z';
      for (var i = 1; i <= 3; i++) {
        service.db.execute(
          'INSERT INTO products (name, sale_price_cents, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
          ['Prodotto $i', 1000 + i, now, now],
        );
        final productId = service.db.lastInsertRowId;
        service.db.execute(
          'INSERT INTO product_variants (product_id, sku, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
          [productId, 'SKU$i', now, now],
        );
        final variantId = service.db.lastInsertRowId;
        service.db.execute(
          'INSERT INTO product_barcodes (variant_id, barcode, is_primary) VALUES (?, ?, 1);',
          [variantId, '800000000000$i'],
        );
      }

      final repository = ProductRepository(service);
      expect(repository.search('', 2), hasLength(2));

      final found = repository.findByBarcode('8000000000002');
      expect(found, isNotNull);
      expect(found!.sku, 'SKU2');
      expect(found.name, 'Prodotto 2');
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
