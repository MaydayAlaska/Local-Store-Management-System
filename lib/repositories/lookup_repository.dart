import '../core/database_service.dart';
import '../models/catalog.dart';

enum LookupKind { brand, category }

class LookupRepository {
  LookupRepository(this.database);
  final DatabaseService database;

  String _table(LookupKind kind) => kind == LookupKind.brand ? 'brands' : 'categories';
  String _foreignKey(LookupKind kind) => kind == LookupKind.brand ? 'brand_id' : 'category_id';
  String _label(LookupKind kind) => kind == LookupKind.brand ? 'marca' : 'categoria';

  List<LookupItem> getAll(LookupKind kind) {
    final table = _table(kind);
    final key = _foreignKey(kind);
    return database.db.select('''
      SELECT l.id, l.name, COUNT(p.id) AS product_count
      FROM $table l LEFT JOIN products p ON p.$key=l.id
      GROUP BY l.id, l.name ORDER BY l.name COLLATE NOCASE, l.id;
    ''').map((row) => LookupItem(
      id: row['id'] as int,
      name: row['name'] as String,
      productCount: row['product_count'] as int,
    )).toList();
  }

  int create(LookupKind kind, String name) {
    final normalized = _normalize(kind, name);
    final table = _table(kind);
    final ids = database.db.select('SELECT id FROM $table ORDER BY id;');
    var next = 1;
    for (final row in ids) {
      final id = row['id'] as int;
      if (id > next) break;
      if (id == next) next++;
    }
    database.db.execute('INSERT INTO $table (id, name) VALUES (?, ?);', [next, normalized]);
    return next;
  }

  void rename(LookupKind kind, int id, String name) {
    final normalized = _normalize(kind, name);
    final table = _table(kind);
    database.db.execute('UPDATE $table SET name=? WHERE id=?;', [normalized, id]);
    if (database.db.updatedRows == 0) throw StateError('La ${_label(kind)} non esiste più.');
  }

  void deleteAndReassign(LookupKind kind, int id, int? targetId) {
    if (id == targetId) throw StateError('La ${_label(kind)} di destinazione deve essere diversa da quella eliminata.');
    final table = _table(kind);
    final key = _foreignKey(kind);
    final db = database.db;
    db.execute('BEGIN;');
    try {
      if (targetId != null) {
        final exists = db.select('SELECT COUNT(*) AS count FROM $table WHERE id=?;', [targetId]).first['count'] as int;
        if (exists == 0) throw StateError('La ${_label(kind)} di destinazione non esiste più.');
      }
      db.execute('UPDATE products SET $key=? WHERE $key=?;', [targetId, id]);
      db.execute('DELETE FROM $table WHERE id=?;', [id]);
      if (db.updatedRows == 0) throw StateError('La ${_label(kind)} non esiste più.');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  String _normalize(LookupKind kind, String name) {
    final result = name.trim();
    if (result.isEmpty) throw ArgumentError('Il nome della ${_label(kind)} è obbligatorio.');
    return result;
  }
}
