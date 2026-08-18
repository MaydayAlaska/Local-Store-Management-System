import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';

void main() {
  test('fresh database creates schema version 3 with product prices', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-db-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final version = service.db.select('PRAGMA user_version;').first.values.first as int;
      expect(version, 3);
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
}
