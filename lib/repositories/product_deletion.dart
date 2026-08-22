import 'product_repository.dart';

extension ProductDeletion on ProductRepository {
  /// Elimina definitivamente un prodotto e tutte le sue varianti.
  ///
  /// Le righe delle vendite storiche restano disponibili grazie agli snapshot
  /// già salvati in sales_order_items; il relativo variant_id viene azzerato
  /// dalla FK ON DELETE SET NULL. Barcode e immagini variante vengono rimossi
  /// in cascata, mentre i movimenti di magazzino devono essere eliminati prima
  /// delle varianti perché la loro FK usa ON DELETE RESTRICT.
  bool deleteProduct(int productId) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final exists = db.select(
        'SELECT 1 FROM products WHERE id=? LIMIT 1;',
        [productId],
      ).isNotEmpty;
      if (!exists) {
        db.execute('ROLLBACK;');
        return false;
      }

      final variants = db
          .select(
            'SELECT id FROM product_variants WHERE product_id=?;',
            [productId],
          )
          .map((row) => row['id'] as int)
          .toList(growable: false);

      if (variants.isNotEmpty) {
        final placeholders = List.filled(variants.length, '?').join(',');
        db.execute(
          'DELETE FROM stock_movements WHERE variant_id IN ($placeholders);',
          variants,
        );
      }

      db.execute('DELETE FROM product_variants WHERE product_id=?;', [productId]);
      db.execute('DELETE FROM products WHERE id=?;', [productId]);
      final deleted = db.updatedRows > 0;
      db.execute('COMMIT;');
      return deleted;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
