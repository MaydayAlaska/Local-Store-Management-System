import '../core/database_service.dart';
import '../models/stock.dart';

class StockRepository {
  StockRepository(this.database);
  final DatabaseService database;

  int getCurrentStock(int variantId) => database.db
      .select('SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements WHERE variant_id=?;', [variantId])
      .first['stock'] as int;

  int getTotalStock() => database.db
      .select('SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements;')
      .first['stock'] as int;

  int addMovement(int variantId, StockMovementKind kind, int quantity, String? note) {
    final db = database.db;
    db.execute('BEGIN;');
    try {
      final current = db.select(
        'SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements WHERE variant_id=?;',
        [variantId],
      ).first['stock'] as int;
      late final String type;
      late final int delta;
      switch (kind) {
        case StockMovementKind.incoming:
          if (quantity <= 0) throw ArgumentError('La quantità di carico deve essere maggiore di zero.');
          type = 'IN';
          delta = quantity;
        case StockMovementKind.outgoing:
          if (quantity <= 0) throw ArgumentError('La quantità di scarico deve essere maggiore di zero.');
          if (quantity > current) throw StateError('Giacenza insufficiente. Disponibili: $current.');
          type = 'OUT';
          delta = -quantity;
        case StockMovementKind.adjustment:
          if (quantity < 0) throw ArgumentError('La giacenza rettificata non può essere negativa.');
          type = 'ADJUSTMENT';
          delta = quantity - current;
          if (delta == 0) throw StateError('La giacenza indicata coincide già con quella attuale.');
      }
      db.execute('''
        INSERT INTO stock_movements (variant_id, movement_type, quantity_delta, note, created_at_utc)
        VALUES (?, ?, ?, ?, ?);
      ''', [variantId, type, delta, _optional(note), DateTime.now().toUtc().toIso8601String()]);
      final id = db.lastInsertRowId;
      db.execute('COMMIT;');
      return id;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  List<StockMovement> search([String? query, int limit = 500]) {
    final q = query?.trim() ?? '';
    final pattern = '%$q%';
    final safeLimit = limit.clamp(1, 5000);
    final rows = database.db.select('''
      WITH movement_rows AS (
        SELECT sm.id, sm.variant_id, pv.sku,
          (SELECT pb.barcode FROM product_barcodes pb WHERE pb.variant_id=pv.id ORDER BY pb.is_primary DESC, pb.id LIMIT 1) AS barcode,
          p.name, pv.variant, pv.size, b.name AS brand, c.name AS category,
          sm.movement_type, sm.quantity_delta, sm.note, sm.created_at_utc,
          SUM(sm.quantity_delta) OVER (PARTITION BY sm.variant_id ORDER BY sm.created_at_utc, sm.id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS stock_after
        FROM stock_movements sm
        JOIN product_variants pv ON pv.id=sm.variant_id
        JOIN products p ON p.id=pv.product_id
        LEFT JOIN brands b ON b.id=p.brand_id
        LEFT JOIN categories c ON c.id=p.category_id
      )
      SELECT id, variant_id, sku, barcode,
        name || CASE WHEN COALESCE(variant, '')<>'' THEN ' · '||variant ELSE '' END ||
        CASE WHEN COALESCE(size, '')<>'' THEN ' · Taglia '||size ELSE '' END AS display_name,
        brand, category, movement_type, quantity_delta, note, created_at_utc, stock_after
      FROM movement_rows
      WHERE ?=''
        OR sku LIKE ? COLLATE NOCASE OR COALESCE(barcode,'') LIKE ? COLLATE NOCASE
        OR name LIKE ? COLLATE NOCASE OR COALESCE(variant,'') LIKE ? COLLATE NOCASE
        OR COALESCE(size,'') LIKE ? COLLATE NOCASE OR COALESCE(brand,'') LIKE ? COLLATE NOCASE
        OR COALESCE(category,'') LIKE ? COLLATE NOCASE OR COALESCE(note,'') LIKE ? COLLATE NOCASE
        OR movement_type LIKE ? COLLATE NOCASE
        OR EXISTS (SELECT 1 FROM product_barcodes search_pb
          WHERE search_pb.variant_id=movement_rows.variant_id AND search_pb.barcode LIKE ? COLLATE NOCASE)
      ORDER BY created_at_utc DESC, id DESC LIMIT ?;
    ''', [q, for (var i = 0; i < 10; i++) pattern, safeLimit]);
    return rows.map((row) => StockMovement(
      id: row['id'] as int,
      variantId: row['variant_id'] as int,
      sku: row['sku'] as String,
      barcode: row['barcode'] as String?,
      productName: row['display_name'] as String,
      brand: row['brand'] as String?,
      category: row['category'] as String?,
      kind: _parseKind(row['movement_type'] as String),
      quantityDelta: row['quantity_delta'] as int,
      note: row['note'] as String?,
      createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
      stockAfter: row['stock_after'] as int,
    )).toList();
  }

  StockMovementKind _parseKind(String value) => switch (value) {
        'IN' => StockMovementKind.incoming,
        'OUT' => StockMovementKind.outgoing,
        _ => StockMovementKind.adjustment,
      };

  String? _optional(String? value) => value?.trim().isNotEmpty == true ? value!.trim() : null;
}
