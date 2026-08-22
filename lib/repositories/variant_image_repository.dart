import 'dart:typed_data';

import '../core/database_service.dart';

class VariantImageRepository {
  VariantImageRepository(this.database) {
    _ensureSchema();
  }

  final DatabaseService database;

  void _ensureSchema() {
    database.db.execute('''
      CREATE TABLE IF NOT EXISTS variant_images (
        variant_id INTEGER PRIMARY KEY,
        image_bytes BLOB NOT NULL,
        updated_at_utc TEXT NOT NULL,
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
      );
    ''');
  }

  Uint8List? get(int variantId) {
    final rows = database.db.select(
      'SELECT image_bytes FROM variant_images WHERE variant_id = ? LIMIT 1;',
      [variantId],
    );
    if (rows.isEmpty) return null;
    return _asBytes(rows.first['image_bytes']);
  }

  Map<int, Uint8List> getMany(Iterable<int> variantIds) {
    final ids = variantIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const <int, Uint8List>{};

    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = database.db.select(
      'SELECT variant_id, image_bytes FROM variant_images '
      'WHERE variant_id IN ($placeholders);',
      ids,
    );
    final result = <int, Uint8List>{};
    for (final row in rows) {
      final bytes = _asBytes(row['image_bytes']);
      if (bytes != null) result[row['variant_id'] as int] = bytes;
    }
    return result;
  }

  void set(int variantId, Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      database.db.execute(
        'DELETE FROM variant_images WHERE variant_id = ?;',
        [variantId],
      );
      return;
    }

    database.db.execute('''
      INSERT INTO variant_images (variant_id, image_bytes, updated_at_utc)
      VALUES (?, ?, ?)
      ON CONFLICT(variant_id) DO UPDATE SET
        image_bytes = excluded.image_bytes,
        updated_at_utc = excluded.updated_at_utc;
    ''', [variantId, bytes, DateTime.now().toUtc().toIso8601String()]);
  }

  Uint8List? _asBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }
}
