import 'dart:math';
import 'dart:typed_data';

import '../core/database_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this.database) {
    _ensureSchema();
  }

  static final Random _giftCardRandom = Random.secure();

  final DatabaseService database;

  void _ensureSchema() {
    if (!_tableExists('customers')) {
      _createCustomerTable('customers');
    } else {
      _migrateCustomerSchemaIfNeeded();
    }

    database.db.execute('''
      CREATE TABLE IF NOT EXISTS gift_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL COLLATE NOCASE UNIQUE,
        customer_id INTEGER,
        total_value_cents INTEGER NOT NULL CHECK(total_value_cents > 0),
        spent_value_cents INTEGER NOT NULL DEFAULT 0
          CHECK(spent_value_cents >= 0 AND spent_value_cents <= total_value_cents),
        expires_at_utc TEXT,
        purchase_order_id INTEGER,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
      );
      CREATE TABLE IF NOT EXISTS sales_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_code INTEGER,
        customer_display_name TEXT,
        customer_fiscal_code TEXT,
        gross_total_cents INTEGER NOT NULL,
        item_discount_cents INTEGER NOT NULL DEFAULT 0,
        order_discount_basis_points INTEGER NOT NULL DEFAULT 0,
        order_percent_discount_cents INTEGER NOT NULL DEFAULT 0,
        fixed_discount_cents INTEGER NOT NULL DEFAULT 0,
        final_total_cents INTEGER NOT NULL,
        gift_card_id INTEGER,
        gift_card_code TEXT,
        gift_card_applied_cents INTEGER NOT NULL DEFAULT 0,
        receipt_filename TEXT,
        receipt_blob BLOB,
        cancelled_at_utc TEXT,
        created_at_utc TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
        FOREIGN KEY (gift_card_id) REFERENCES gift_cards(id) ON DELETE SET NULL
      );
      CREATE TABLE IF NOT EXISTS sales_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        variant_id INTEGER,
        sku TEXT NOT NULL,
        barcode TEXT,
        product_name TEXT NOT NULL,
        variant_display TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_cents INTEGER NOT NULL,
        discount_basis_points INTEGER NOT NULL DEFAULT 0,
        gross_total_cents INTEGER NOT NULL,
        final_total_cents INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES sales_orders(id) ON DELETE CASCADE,
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL
      );
      CREATE INDEX IF NOT EXISTS ix_customers_name
        ON customers(last_name COLLATE NOCASE, first_name COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_customers_fiscal_code
        ON customers(fiscal_code COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_customers_customer_code
        ON customers(customer_code);
      CREATE INDEX IF NOT EXISTS ix_gift_cards_customer
        ON gift_cards(customer_id, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_sales_orders_customer_date
        ON sales_orders(customer_id, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_sales_order_items_order
        ON sales_order_items(order_id, id);
    ''');

    _ensureColumn('gift_cards', 'expires_at_utc', 'TEXT');
    _ensureColumn('gift_cards', 'purchase_order_id', 'INTEGER');
    _migrateGiftCardSchemaIfNeeded();
    database.db.execute('DROP TABLE IF EXISTS gift_card_code_registry;');
    _ensureColumn('sales_orders', 'customer_code', 'INTEGER');
    _ensureColumn('sales_orders', 'customer_display_name', 'TEXT');
    _ensureColumn('sales_orders', 'customer_fiscal_code', 'TEXT');
    _ensureColumn(
      'sales_orders',
      'gift_card_id',
      'INTEGER REFERENCES gift_cards(id) ON DELETE SET NULL',
    );
    _ensureColumn('sales_orders', 'gift_card_code', 'TEXT');
    _ensureColumn(
      'sales_orders',
      'gift_card_applied_cents',
      'INTEGER NOT NULL DEFAULT 0',
    );
    _ensureColumn('sales_orders', 'cancelled_at_utc', 'TEXT');
    database.db.execute('''
      CREATE INDEX IF NOT EXISTS ix_sales_orders_cancelled_date
        ON sales_orders(cancelled_at_utc, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_sales_orders_gift_card
        ON sales_orders(gift_card_id, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_gift_cards_customer
        ON gift_cards(customer_id, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_gift_cards_purchase_order
        ON gift_cards(purchase_order_id);
      CREATE INDEX IF NOT EXISTS ix_gift_cards_cleanup
        ON gift_cards(created_at_utc, expires_at_utc);
    ''');
    _backfillCustomerSnapshots();
    _backfillGiftCardPurchaseOrders();
  }

  void _createCustomerTable(String table) {
    database.db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_code INTEGER NOT NULL UNIQUE CHECK(customer_code > 0),
        fiscal_code TEXT COLLATE NOCASE UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        birth_date TEXT,
        sex TEXT,
        birth_place_code TEXT,
        notes TEXT,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      );
    ''');
  }

  void _migrateCustomerSchemaIfNeeded() {
    final columns = database.db.select('PRAGMA table_info(customers);');
    bool has(String name) => columns.any(
          (row) => (row['name'] as String).toLowerCase() == name.toLowerCase(),
        );
    int notNull(String name) => columns
        .firstWhere((row) =>
            (row['name'] as String).toLowerCase() == name.toLowerCase())['notnull'] as int;

    final needsMigration = !has('customer_code') ||
        (has('fiscal_code') && notNull('fiscal_code') != 0) ||
        (has('birth_date') && notNull('birth_date') != 0) ||
        (has('sex') && notNull('sex') != 0) ||
        (has('birth_place_code') && notNull('birth_place_code') != 0);
    if (!needsMigration) return;

    final hasCustomerCode = has('customer_code');
    final db = database.db;
    db.execute('PRAGMA foreign_keys = OFF;');
    try {
      db.execute('BEGIN IMMEDIATE;');
      db.execute('DROP TABLE IF EXISTS customers_new;');
      _createCustomerTable('customers_new');
      final codeExpression =
          hasCustomerCode ? 'COALESCE(customer_code, id)' : 'id';
      db.execute('''
        INSERT INTO customers_new (
          id, customer_code, fiscal_code, first_name, last_name,
          birth_date, sex, birth_place_code, notes, created_at_utc, updated_at_utc)
        SELECT
          id,
          $codeExpression,
          NULLIF(TRIM(fiscal_code), ''),
          first_name,
          last_name,
          NULLIF(TRIM(birth_date), ''),
          NULLIF(TRIM(sex), ''),
          NULLIF(TRIM(birth_place_code), ''),
          notes,
          created_at_utc,
          updated_at_utc
        FROM customers;
      ''');
      db.execute('DROP TABLE customers;');
      db.execute('ALTER TABLE customers_new RENAME TO customers;');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  void _migrateGiftCardSchemaIfNeeded() {
    final columns = database.db.select('PRAGMA table_info(gift_cards);');
    final customerColumn = columns.firstWhere(
      (row) => (row['name'] as String).toLowerCase() == 'customer_id',
    );
    final hasDeletedAt = columns.any(
      (row) => (row['name'] as String).toLowerCase() == 'deleted_at_utc',
    );
    final customerIsRequired = (customerColumn['notnull'] as int) != 0;
    final foreignKeys = database.db.select('PRAGMA foreign_key_list(gift_cards);');
    final customerForeignKey = foreignKeys.where(
      (row) => (row['from'] as String).toLowerCase() == 'customer_id',
    );
    final customerDeleteActionIsWrong = customerForeignKey.isEmpty ||
        ((customerForeignKey.first['on_delete'] as String?) ?? '').toUpperCase() !=
            'SET NULL';
    if (!hasDeletedAt && !customerIsRequired && !customerDeleteActionIsWrong) {
      return;
    }

    final db = database.db;
    if (hasDeletedAt) {
      db.execute('DELETE FROM gift_cards WHERE deleted_at_utc IS NOT NULL;');
    }
    db.execute('DROP INDEX IF EXISTS ix_gift_cards_cleanup;');

    db.execute('PRAGMA foreign_keys = OFF;');
    try {
      db.execute('BEGIN IMMEDIATE;');
      db.execute('DROP TABLE IF EXISTS gift_cards_new;');
      db.execute('''
        CREATE TABLE gift_cards_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL COLLATE NOCASE UNIQUE,
          customer_id INTEGER,
          total_value_cents INTEGER NOT NULL CHECK(total_value_cents > 0),
          spent_value_cents INTEGER NOT NULL DEFAULT 0
            CHECK(spent_value_cents >= 0 AND spent_value_cents <= total_value_cents),
          expires_at_utc TEXT,
          purchase_order_id INTEGER,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL
        );
      ''');
      final activeFilter = hasDeletedAt ? ' WHERE deleted_at_utc IS NULL' : '';
      db.execute('''
        INSERT INTO gift_cards_new (
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc)
        SELECT
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc
        FROM gift_cards$activeFilter;
      ''');
      db.execute('DROP TABLE gift_cards;');
      db.execute('ALTER TABLE gift_cards_new RENAME TO gift_cards;');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  void _backfillCustomerSnapshots() {
    database.db.execute('''
      UPDATE sales_orders
      SET customer_display_name = (
        SELECT TRIM(c.last_name || ' ' || c.first_name)
        FROM customers c WHERE c.id = sales_orders.customer_id
      )
      WHERE customer_id IS NOT NULL
        AND (customer_display_name IS NULL OR TRIM(customer_display_name) = '');

      UPDATE sales_orders
      SET customer_code = (
        SELECT c.customer_code
        FROM customers c WHERE c.id = sales_orders.customer_id
      )
      WHERE customer_id IS NOT NULL AND customer_code IS NULL;

      UPDATE sales_orders
      SET customer_fiscal_code = (
        SELECT c.fiscal_code
        FROM customers c WHERE c.id = sales_orders.customer_id
      )
      WHERE customer_id IS NOT NULL
        AND (customer_fiscal_code IS NULL OR TRIM(customer_fiscal_code) = '');
    ''');
  }

  void _backfillGiftCardPurchaseOrders() {
    final rows = database.db.select('''
      SELECT id, customer_id, total_value_cents, created_at_utc
      FROM gift_cards
      WHERE purchase_order_id IS NULL
      ORDER BY created_at_utc, id;
    ''');
    for (final row in rows) {
      final orderId = _findAvailableGiftCardPurchaseOrder(
        customerId: row['customer_id'] as int?,
        totalValueCents: row['total_value_cents'] as int,
        giftCardCreatedAtUtc: row['created_at_utc'] as String,
      );
      if (orderId == null) continue;
      database.db.execute(
        'UPDATE gift_cards SET purchase_order_id=? WHERE id=? AND purchase_order_id IS NULL;',
        [orderId, row['id'] as int],
      );
    }
  }

  int? _findAvailableGiftCardPurchaseOrder({
    required int? customerId,
    required int totalValueCents,
    required String giftCardCreatedAtUtc,
  }) {
    final rows = database.db.select('''
      SELECT so.id
      FROM sales_orders so
      WHERE ((? IS NULL AND so.customer_id IS NULL) OR so.customer_id=?)
        AND ABS((julianday(so.created_at_utc) - julianday(?)) * 86400.0) <= 120
        AND (
          SELECT COALESCE(SUM(soi.quantity), 0)
          FROM sales_order_items soi
          WHERE soi.order_id=so.id
            AND soi.sku='GIFT-CARD' COLLATE NOCASE
            AND soi.unit_price_cents=?
        ) > (
          SELECT COUNT(*)
          FROM gift_cards linked
          WHERE linked.purchase_order_id=so.id
            AND linked.total_value_cents=?
        )
      ORDER BY
        ABS((julianday(so.created_at_utc) - julianday(?)) * 86400.0),
        so.id DESC
      LIMIT 1;
    ''', [
      customerId,
      customerId,
      giftCardCreatedAtUtc,
      totalValueCents,
      totalValueCents,
      giftCardCreatedAtUtc,
    ]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  List<Customer> search([String? query, int limit = 500]) {
    final q = query?.trim() ?? '';
    final pattern = '%$q%';
    final rows = database.db.select('''
      SELECT * FROM customers
      WHERE ?=''
         OR COALESCE(fiscal_code, '') LIKE ? COLLATE NOCASE
         OR first_name LIKE ? COLLATE NOCASE
         OR last_name LIKE ? COLLATE NOCASE
         OR (last_name || ' ' || first_name) LIKE ? COLLATE NOCASE
         OR printf('CLI-%06d', customer_code) LIKE ? COLLATE NOCASE
         OR CAST(customer_code AS TEXT) LIKE ? COLLATE NOCASE
         OR COALESCE(notes, '') LIKE ? COLLATE NOCASE
      ORDER BY last_name COLLATE NOCASE, first_name COLLATE NOCASE, customer_code
      LIMIT ?;
    ''', [
      q,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      limit.clamp(1, 5000),
    ]);
    return rows.map(_customerFromRow).toList();
  }

  Customer? getById(int id) {
    final rows = database.db.select(
      'SELECT * FROM customers WHERE id=? LIMIT 1;',
      [id],
    );
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  Customer? findByFiscalCode(String fiscalCode) {
    final value = fiscalCode.trim().toUpperCase();
    if (value.isEmpty) return null;
    final rows = database.db.select(
      'SELECT id FROM customers WHERE fiscal_code=? COLLATE NOCASE LIMIT 1;',
      [value],
    );
    if (rows.isEmpty) return null;
    return getById(rows.first['id'] as int);
  }

  Customer save(CustomerDraft draft) {
    final firstName = draft.firstName.trim();
    final lastName = draft.lastName.trim();
    if (firstName.isEmpty) throw ArgumentError('Il nome è obbligatorio.');
    if (lastName.isEmpty) throw ArgumentError('Il cognome è obbligatorio.');

    final data = draft.fiscalCodeData;
    final fiscalCode = data?.fiscalCode.trim().toUpperCase();
    final now = DateTime.now().toUtc().toIso8601String();
    final birthDate = data == null ? null : _dateOnly(data.birthDate);
    final notes = _optional(draft.notes);
    final db = database.db;

    db.execute('BEGIN IMMEDIATE;');
    try {
      _assertFiscalCodeAvailable(fiscalCode, draft.id);
      int id;
      if (draft.id == null) {
        final customerCode = _nextAvailableCustomerCode();
        db.execute('''
          INSERT INTO customers (
            customer_code, fiscal_code, first_name, last_name, birth_date, sex,
            birth_place_code, notes, created_at_utc, updated_at_utc)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''', [
          customerCode,
          fiscalCode,
          firstName,
          lastName,
          birthDate,
          data?.sex,
          data?.birthPlaceCode,
          notes,
          now,
          now,
        ]);
        id = db.lastInsertRowId;
      } else {
        db.execute('''
          UPDATE customers
          SET fiscal_code=?, first_name=?, last_name=?, birth_date=?, sex=?,
              birth_place_code=?, notes=?, updated_at_utc=?
          WHERE id=?;
        ''', [
          fiscalCode,
          firstName,
          lastName,
          birthDate,
          data?.sex,
          data?.birthPlaceCode,
          notes,
          now,
          draft.id,
        ]);
        if (db.updatedRows == 0) throw StateError('Cliente non trovato.');
        id = draft.id!;
      }
      db.execute('COMMIT;');
      return getById(id)!;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void _assertFiscalCodeAvailable(String? fiscalCode, int? customerId) {
    if (fiscalCode == null || fiscalCode.isEmpty) return;
    final rows = database.db.select(
      'SELECT id FROM customers WHERE fiscal_code=? COLLATE NOCASE LIMIT 1;',
      [fiscalCode],
    );
    if (rows.isEmpty) return;
    final existingId = rows.first['id'] as int;
    if (existingId != customerId) {
      throw ArgumentError('Il codice fiscale è già associato a un altro cliente.');
    }
  }

  bool deleteCustomer(int customerId) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final rows = db.select(
        'SELECT customer_code, first_name, last_name, fiscal_code FROM customers WHERE id=? LIMIT 1;',
        [customerId],
      );
      if (rows.isEmpty) {
        db.execute('ROLLBACK;');
        return false;
      }

      final row = rows.first;
      final displayName = '${row['last_name']} ${row['first_name']}'.trim();
      final customerCode = row['customer_code'] as int;
      final fiscalCode = row['fiscal_code'] as String?;
      db.execute('''
        UPDATE sales_orders
        SET customer_display_name = CASE
              WHEN customer_display_name IS NULL OR TRIM(customer_display_name) = '' THEN ?
              ELSE customer_display_name
            END,
            customer_code = COALESCE(customer_code, ?),
            customer_fiscal_code = CASE
              WHEN customer_fiscal_code IS NULL OR TRIM(customer_fiscal_code) = '' THEN ?
              ELSE customer_fiscal_code
            END,
            customer_id = NULL
        WHERE customer_id=?;
      ''', [displayName, customerCode, fiscalCode, customerId]);
      final giftCardUpdatedAt = DateTime.now().toUtc().toIso8601String();
      db.execute(
        'UPDATE gift_cards SET customer_id=NULL, updated_at_utc=? WHERE customer_id=?;',
        [giftCardUpdatedAt, customerId],
      );
      db.execute('DELETE FROM customers WHERE id=?;', [customerId]);
      db.execute('COMMIT;');
      return true;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  List<GiftCard> giftCardsForCustomer(int customerId, [int limit = 500]) {
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      WHERE customer_id=?
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [customerId, limit.clamp(1, 5000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> giftCards([int limit = 5000]) {
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [limit.clamp(1, 10000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> availableGiftCardsForCash(int? customerId, [int limit = 500]) {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      WHERE (customer_id IS NULL OR customer_id=?)
        AND spent_value_cents < total_value_cents
        AND (expires_at_utc IS NULL OR expires_at_utc > ?)
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [customerId, now, limit.clamp(1, 5000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  List<GiftCard> availableGiftCardsForCustomer(int customerId, [int limit = 500]) {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = database.db.select('''
      SELECT * FROM gift_cards
      WHERE customer_id=?
        AND spent_value_cents < total_value_cents
        AND (expires_at_utc IS NULL OR expires_at_utc > ?)
      ORDER BY created_at_utc DESC, id DESC
      LIMIT ?;
    ''', [customerId, now, limit.clamp(1, 5000)]);
    return rows.map(_giftCardFromRow).toList();
  }

  GiftCard? getGiftCard(int giftCardId) {
    final rows = database.db.select(
      'SELECT * FROM gift_cards WHERE id=? LIMIT 1;',
      [giftCardId],
    );
    return rows.isEmpty ? null : _giftCardFromRow(rows.first);
  }

  GiftCard createGiftCard(
    int? customerId,
    int totalValueCents, {
    DateTime? expiresAtUtc,
    int? purchaseOrderId,
  }) {
    if (totalValueCents <= 0) {
      throw ArgumentError('Il valore del buono regalo deve essere maggiore di zero.');
    }
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      if (customerId != null) {
        final customerExists = db.select(
          'SELECT 1 FROM customers WHERE id=? LIMIT 1;',
          [customerId],
        ).isNotEmpty;
        if (!customerExists) {
          throw StateError('Il cliente selezionato non esiste più.');
        }
      }

      final nowUtc = DateTime.now().toUtc();
      final now = nowUtc.toIso8601String();
      final expiration = expiresAtUtc?.toUtc().toIso8601String();
      final resolvedPurchaseOrderId = purchaseOrderId ??
          _findAvailableGiftCardPurchaseOrder(
            customerId: customerId,
            totalValueCents: totalValueCents,
            giftCardCreatedAtUtc: now,
          );
      final id = _nextAvailableGiftCardId();
      final code = _newUniqueGiftCardCode();
      db.execute('''
        INSERT INTO gift_cards (
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc)
        VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?);
      ''', [
        id,
        code,
        customerId,
        totalValueCents,
        expiration,
        resolvedPurchaseOrderId,
        now,
        now,
      ]);
      db.execute('COMMIT;');
      return getGiftCard(id)!;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  GiftCard updateGiftCard(
    int giftCardId, {
    required int? customerId,
    required DateTime? expiresAtUtc,
  }) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final exists = db.select(
        'SELECT 1 FROM gift_cards WHERE id=? LIMIT 1;',
        [giftCardId],
      ).isNotEmpty;
      if (!exists) throw StateError('Buono regalo non trovato.');
      if (customerId != null) {
        final customerExists = db.select(
          'SELECT 1 FROM customers WHERE id=? LIMIT 1;',
          [customerId],
        ).isNotEmpty;
        if (!customerExists) {
          throw StateError('Il cliente selezionato non esiste più.');
        }
      }
      final now = DateTime.now().toUtc().toIso8601String();
      db.execute('''
        UPDATE gift_cards
        SET customer_id=?, expires_at_utc=?, updated_at_utc=?
        WHERE id=?;
      ''', [
        customerId,
        expiresAtUtc?.toUtc().toIso8601String(),
        now,
        giftCardId,
      ]);
      db.execute('COMMIT;');
      return getGiftCard(giftCardId)!;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  SalesOrderSummary? purchaseOrderForGiftCard(int giftCardId) {
    final rows = database.db.select(
      'SELECT purchase_order_id FROM gift_cards WHERE id=? LIMIT 1;',
      [giftCardId],
    );
    if (rows.isEmpty) return null;
    final orderId = rows.first['purchase_order_id'] as int?;
    if (orderId == null) return null;
    return getOrder(orderId)?.summary;
  }

  ReceiptAttachment? getGiftCardReceipt(int giftCardId) {
    final rows = database.db.select('''
      SELECT so.receipt_filename, so.receipt_blob
      FROM gift_cards gc
      JOIN sales_orders so ON so.id=gc.purchase_order_id
      WHERE gc.id=?
      LIMIT 1;
    ''', [giftCardId]);
    if (rows.isEmpty || rows.first['receipt_blob'] == null) return null;
    final bytes = rows.first['receipt_blob'];
    if (bytes is! Uint8List) return null;
    return ReceiptAttachment(
      filename: (rows.first['receipt_filename'] as String?) ?? 'scontrino',
      bytes: bytes,
    );
  }

  bool deleteGiftCard(int giftCardId) {
    database.db.execute('DELETE FROM gift_cards WHERE id=?;', [giftCardId]);
    return database.db.updatedRows > 0;
  }

  int countGiftCardsForCleanup({
    int? olderThanYears,
    bool exhausted = false,
    bool expired = false,
    DateTime? nowUtc,
  }) {
    final args = <Object?>[];
    final where = _giftCardCleanupWhere(
      olderThanYears: olderThanYears,
      exhausted: exhausted,
      expired: expired,
      nowUtc: (nowUtc ?? DateTime.now()).toUtc(),
      args: args,
    );
    if (where == null) return 0;
    return database.db.select(
      'SELECT COUNT(*) AS count FROM gift_cards WHERE $where;',
      args,
    ).first['count'] as int;
  }

  int deleteGiftCardsForCleanup({
    int? olderThanYears,
    bool exhausted = false,
    bool expired = false,
    DateTime? nowUtc,
  }) {
    final args = <Object?>[];
    final where = _giftCardCleanupWhere(
      olderThanYears: olderThanYears,
      exhausted: exhausted,
      expired: expired,
      nowUtc: (nowUtc ?? DateTime.now()).toUtc(),
      args: args,
    );
    if (where == null) return 0;
    database.db.execute('DELETE FROM gift_cards WHERE $where;', args);
    return database.db.updatedRows;
  }

  String? _giftCardCleanupWhere({
    required int? olderThanYears,
    required bool exhausted,
    required bool expired,
    required DateTime nowUtc,
    required List<Object?> args,
  }) {
    final conditions = <String>[];
    if (olderThanYears != null) {
      if (olderThanYears <= 0) {
        throw ArgumentError('Il numero di anni deve essere maggiore di zero.');
      }
      final cutoff = DateTime.utc(
        nowUtc.year - olderThanYears,
        nowUtc.month,
        nowUtc.day,
        nowUtc.hour,
        nowUtc.minute,
        nowUtc.second,
        nowUtc.millisecond,
        nowUtc.microsecond,
      );
      conditions.add('created_at_utc < ?');
      args.add(cutoff.toIso8601String());
    }
    if (exhausted) {
      conditions.add('spent_value_cents >= total_value_cents');
    }
    if (expired) {
      conditions.add('(expires_at_utc IS NOT NULL AND expires_at_utc <= ?)');
      args.add(nowUtc.toIso8601String());
    }
    if (conditions.isEmpty) return null;
    return '(${conditions.join(' OR ')})';
  }

  List<SalesOrderSummary> ordersForCustomer(int customerId, [int limit = 500]) {
    final rows = database.db.select('''
      SELECT so.*,
        COALESCE((SELECT SUM(soi.quantity) FROM sales_order_items soi WHERE soi.order_id=so.id), 0) AS item_count
      FROM sales_orders so
      WHERE so.customer_id=?
      ORDER BY so.created_at_utc DESC, so.id DESC
      LIMIT ?;
    ''', [customerId, limit.clamp(1, 5000)]);
    return rows.map(_orderSummaryFromRow).toList();
  }

  List<SalesOrderSummary> searchOrders([String? query, int limit = 1000]) {
    final q = query?.trim() ?? '';
    final pattern = '%$q%';
    final rows = database.db.select('''
      SELECT so.*,
        COALESCE((SELECT SUM(soi.quantity) FROM sales_order_items soi WHERE soi.order_id=so.id), 0) AS item_count
      FROM sales_orders so
      WHERE ?=''
         OR so.order_number LIKE ? COLLATE NOCASE
         OR COALESCE(so.customer_display_name, '') LIKE ? COLLATE NOCASE
         OR COALESCE(so.customer_fiscal_code, '') LIKE ? COLLATE NOCASE
         OR printf('CLI-%06d', COALESCE(so.customer_code, 0)) LIKE ? COLLATE NOCASE
         OR COALESCE(so.gift_card_code, '') LIKE ? COLLATE NOCASE
         OR so.created_at_utc LIKE ? COLLATE NOCASE
         OR EXISTS (
           SELECT 1 FROM sales_order_items soi
           WHERE soi.order_id=so.id
             AND (
               soi.sku LIKE ? COLLATE NOCASE
               OR COALESCE(soi.barcode, '') LIKE ? COLLATE NOCASE
               OR soi.product_name LIKE ? COLLATE NOCASE
               OR soi.variant_display LIKE ? COLLATE NOCASE
             )
         )
      ORDER BY so.created_at_utc DESC, so.id DESC
      LIMIT ?;
    ''', [
      q,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      limit.clamp(1, 10000),
    ]);
    return rows.map(_orderSummaryFromRow).toList();
  }

  SalesOrderDetail? getOrder(int orderId) {
    final rows = database.db.select('''
      SELECT so.*,
        COALESCE((SELECT SUM(soi.quantity) FROM sales_order_items soi WHERE soi.order_id=so.id), 0) AS item_count
      FROM sales_orders so WHERE so.id=? LIMIT 1;
    ''', [orderId]);
    if (rows.isEmpty) return null;
    final itemRows = database.db.select(
      'SELECT * FROM sales_order_items WHERE order_id=? ORDER BY id;',
      [orderId],
    );
    return SalesOrderDetail(
      summary: _orderSummaryFromRow(rows.first),
      items: itemRows.map(_orderItemFromRow).toList(),
    );
  }

  bool cancelOrder(int orderId) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final rows = db.select('''
        SELECT order_number, cancelled_at_utc, gift_card_id, gift_card_applied_cents
        FROM sales_orders WHERE id=? LIMIT 1;
      ''', [orderId]);
      if (rows.isEmpty) {
        db.execute('ROLLBACK;');
        return false;
      }
      final row = rows.first;
      if (row['cancelled_at_utc'] != null) {
        db.execute('ROLLBACK;');
        return false;
      }

      final orderNumber = row['order_number'] as String;
      final now = DateTime.now().toUtc().toIso8601String();
      final items = db.select(
        'SELECT variant_id, quantity FROM sales_order_items WHERE order_id=? ORDER BY id;',
        [orderId],
      );
      for (final item in items) {
        final variantId = item['variant_id'] as int?;
        if (variantId == null) continue;
        final quantity = item['quantity'] as int;
        if (quantity <= 0) continue;
        db.execute('''
          INSERT INTO stock_movements (
            variant_id, movement_type, quantity_delta, note, created_at_utc)
          VALUES (?, 'IN', ?, ?, ?);
        ''', [variantId, quantity, 'Annullamento vendita $orderNumber', now]);
      }

      final giftCardId = row['gift_card_id'] as int?;
      final giftApplied = (row['gift_card_applied_cents'] as int?) ?? 0;
      if (giftCardId != null && giftApplied > 0) {
        db.execute('''
          UPDATE gift_cards
          SET spent_value_cents = MAX(0, spent_value_cents - ?),
              updated_at_utc = ?
          WHERE id=?;
        ''', [giftApplied, now, giftCardId]);
      }

      db.execute(
        'UPDATE sales_orders SET cancelled_at_utc=? WHERE id=? AND cancelled_at_utc IS NULL;',
        [now, orderId],
      );
      if (db.updatedRows != 1) {
        throw StateError('Impossibile contrassegnare l’ordine come annullato.');
      }
      db.execute('COMMIT;');
      return true;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  bool deleteOrder(int orderId) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      db.execute(
        'UPDATE gift_cards SET purchase_order_id=NULL WHERE purchase_order_id=?;',
        [orderId],
      );
      db.execute('DELETE FROM sales_orders WHERE id=?;', [orderId]);
      final deleted = db.updatedRows > 0;
      db.execute('COMMIT;');
      return deleted;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  int countOrdersOlderThan(DateTime cutoffUtc) {
    final cutoff = cutoffUtc.toUtc().toIso8601String();
    return database.db.select(
      'SELECT COUNT(*) AS count FROM sales_orders WHERE created_at_utc < ?;',
      [cutoff],
    ).first['count'] as int;
  }

  int deleteOrdersOlderThan(DateTime cutoffUtc) {
    final cutoff = cutoffUtc.toUtc().toIso8601String();
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      db.execute('''
        UPDATE gift_cards
        SET purchase_order_id=NULL
        WHERE purchase_order_id IN (
          SELECT id FROM sales_orders WHERE created_at_utc < ?
        );
      ''', [cutoff]);
      db.execute(
        'DELETE FROM sales_orders WHERE created_at_utc < ?;',
        [cutoff],
      );
      final deleted = db.updatedRows;
      db.execute('COMMIT;');
      return deleted;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  SalesOrderSummary recordSale(SalesOrderDraft draft) {
    if (draft.lines.isEmpty) throw ArgumentError('La vendita non contiene articoli.');
    if (draft.finalTotalCents < 0) {
      throw ArgumentError('Il totale della vendita non può essere negativo.');
    }
    if (draft.giftCardAppliedCents < 0) {
      throw ArgumentError('L’importo del buono regalo non può essere negativo.');
    }

    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      int? customerCode;
      String? customerDisplayName;
      String? customerFiscalCode;
      if (draft.customerId != null) {
        final customers = db.select('''
          SELECT customer_code, first_name, last_name, fiscal_code
          FROM customers WHERE id=? LIMIT 1;
        ''', [draft.customerId]);
        if (customers.isEmpty) {
          throw StateError('Il cliente selezionato non esiste più.');
        }
        final customer = customers.first;
        customerCode = customer['customer_code'] as int;
        customerDisplayName =
            '${customer['last_name']} ${customer['first_name']}'.trim();
        customerFiscalCode = customer['fiscal_code'] as String?;
      }

      String? giftCardCode;
      if (draft.giftCardId == null) {
        if (draft.giftCardAppliedCents != 0) {
          throw ArgumentError('Importo buono regalo senza un buono selezionato.');
        }
      } else {
        if (draft.giftCardAppliedCents <= 0) {
          throw ArgumentError('Il buono regalo selezionato non ha un importo da utilizzare.');
        }
        if (draft.giftCardAppliedCents > draft.finalTotalCents) {
          throw ArgumentError('Il buono regalo supera il totale della vendita.');
        }
        final cards = db.select(
          'SELECT * FROM gift_cards WHERE id=? LIMIT 1;',
          [draft.giftCardId],
        );
        if (cards.isEmpty) throw StateError('Il buono regalo selezionato non esiste più.');
        final card = cards.first;
        final ownerId = card['customer_id'] as int?;
        if (ownerId != null && ownerId != draft.customerId) {
          throw StateError('Il buono regalo è associato a un altro cliente.');
        }
        final expirationText = card['expires_at_utc'] as String?;
        if (expirationText != null &&
            DateTime.now().toUtc().isAfter(DateTime.parse(expirationText).toUtc())) {
          throw StateError('Il buono regalo selezionato è scaduto.');
        }
        final remaining =
            (card['total_value_cents'] as int) - (card['spent_value_cents'] as int);
        if (remaining < draft.giftCardAppliedCents) {
          throw StateError('Credito del buono regalo insufficiente. Residuo disponibile: $remaining centesimi.');
        }
        giftCardCode = card['code'] as String;
      }

      for (final line in draft.lines) {
        if (line.quantity <= 0) throw ArgumentError('Quantità di vendita non valida.');
        final variantId = line.variantId;
        if (variantId == null) continue;
        final available = db.select(
          'SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements WHERE variant_id=?;',
          [variantId],
        ).first['stock'] as int;
        if (available < line.quantity) {
          throw StateError(
            '${line.productName}: giacenza insufficiente. Disponibili: $available.',
          );
        }
      }

      final now = DateTime.now().toUtc();
      final nowText = now.toIso8601String();
      final orderNumber = _newUniqueOrderNumber(now);
      db.execute('''
        INSERT INTO sales_orders (
          order_number, customer_id, customer_code, customer_display_name,
          customer_fiscal_code, gross_total_cents, item_discount_cents,
          order_discount_basis_points, order_percent_discount_cents,
          fixed_discount_cents, final_total_cents, gift_card_id,
          gift_card_code, gift_card_applied_cents, created_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        orderNumber,
        draft.customerId,
        customerCode,
        customerDisplayName,
        customerFiscalCode,
        draft.grossTotalCents,
        draft.itemDiscountCents,
        draft.orderDiscountBasisPoints,
        draft.orderPercentDiscountCents,
        draft.fixedDiscountCents,
        draft.finalTotalCents,
        draft.giftCardId,
        giftCardCode,
        draft.giftCardAppliedCents,
        nowText,
      ]);
      final orderId = db.lastInsertRowId;

      for (final line in draft.lines) {
        db.execute('''
          INSERT INTO sales_order_items (
            order_id, variant_id, sku, barcode, product_name, variant_display,
            quantity, unit_price_cents, discount_basis_points,
            gross_total_cents, final_total_cents)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''', [
          orderId,
          line.variantId,
          line.sku,
          _optional(line.barcode),
          line.productName,
          line.variantDisplay,
          line.quantity,
          line.unitPriceCents,
          line.discountBasisPoints,
          line.grossTotalCents,
          line.finalTotalCents,
        ]);

        final variantId = line.variantId;
        if (variantId != null) {
          db.execute('''
            INSERT INTO stock_movements (
              variant_id, movement_type, quantity_delta, note, created_at_utc)
            VALUES (?, 'OUT', ?, ?, ?);
          ''', [variantId, -line.quantity, 'Vendita $orderNumber', nowText]);
        }
      }

      if (draft.giftCardId != null && draft.giftCardAppliedCents > 0) {
        db.execute('''
          UPDATE gift_cards
          SET spent_value_cents = spent_value_cents + ?, updated_at_utc = ?
          WHERE id=?;
        ''', [draft.giftCardAppliedCents, nowText, draft.giftCardId]);
        if (db.updatedRows != 1) {
          throw StateError('Impossibile aggiornare il buono regalo.');
        }
      }

      db.execute('COMMIT;');
      return getOrder(orderId)!.summary;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  void attachReceipt(int orderId, String filename, Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError('Il file dello scontrino è vuoto.');
    if (bytes.length > 25 * 1024 * 1024) {
      throw ArgumentError('Lo scontrino supera il limite di 25 MB.');
    }
    final safeName = filename.trim().replaceAll(RegExp(r'[\\/]'), '_');
    database.db.execute(
      'UPDATE sales_orders SET receipt_filename=?, receipt_blob=? WHERE id=?;',
      [safeName.isEmpty ? 'scontrino' : safeName, bytes, orderId],
    );
    if (database.db.updatedRows == 0) throw StateError('Ordine non trovato.');
  }

  ReceiptAttachment? getReceipt(int orderId) {
    final rows = database.db.select(
      'SELECT receipt_filename, receipt_blob FROM sales_orders WHERE id=? LIMIT 1;',
      [orderId],
    );
    if (rows.isEmpty || rows.first['receipt_blob'] == null) return null;
    final bytes = rows.first['receipt_blob'];
    if (bytes is! Uint8List) return null;
    return ReceiptAttachment(
      filename: (rows.first['receipt_filename'] as String?) ?? 'scontrino',
      bytes: bytes,
    );
  }

  Customer _customerFromRow(dynamic row) => Customer(
        id: row['id'] as int,
        customerCode: row['customer_code'] as int,
        fiscalCode: row['fiscal_code'] as String?,
        firstName: row['first_name'] as String,
        lastName: row['last_name'] as String,
        birthDate: row['birth_date'] == null
            ? null
            : DateTime.parse(row['birth_date'] as String),
        sex: row['sex'] as String?,
        birthPlaceCode: row['birth_place_code'] as String?,
        notes: row['notes'] as String?,
        createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
        updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String).toUtc(),
      );

  GiftCard _giftCardFromRow(dynamic row) => GiftCard(
        id: row['id'] as int,
        code: row['code'] as String,
        customerId: row['customer_id'] as int?,
        totalValueCents: row['total_value_cents'] as int,
        spentValueCents: row['spent_value_cents'] as int,
        expiresAtUtc: row['expires_at_utc'] == null
            ? null
            : DateTime.parse(row['expires_at_utc'] as String).toUtc(),
        createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
        updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String).toUtc(),
      );

  SalesOrderSummary _orderSummaryFromRow(dynamic row) => SalesOrderSummary(
        id: row['id'] as int,
        orderNumber: row['order_number'] as String,
        customerId: row['customer_id'] as int?,
        customerCode: row['customer_code'] as int?,
        customerDisplayName: row['customer_display_name'] as String?,
        customerFiscalCode: row['customer_fiscal_code'] as String?,
        itemCount: row['item_count'] as int,
        grossTotalCents: row['gross_total_cents'] as int,
        itemDiscountCents: row['item_discount_cents'] as int,
        orderDiscountBasisPoints: row['order_discount_basis_points'] as int,
        orderPercentDiscountCents: row['order_percent_discount_cents'] as int,
        fixedDiscountCents: row['fixed_discount_cents'] as int,
        finalTotalCents: row['final_total_cents'] as int,
        giftCardId: row['gift_card_id'] as int?,
        giftCardCode: row['gift_card_code'] as String?,
        giftCardAppliedCents: (row['gift_card_applied_cents'] as int?) ?? 0,
        receiptFilename: row['receipt_filename'] as String?,
        cancelledAtUtc: row['cancelled_at_utc'] == null
            ? null
            : DateTime.parse(row['cancelled_at_utc'] as String).toUtc(),
        createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
      );

  SalesOrderItem _orderItemFromRow(dynamic row) => SalesOrderItem(
        id: row['id'] as int,
        orderId: row['order_id'] as int,
        variantId: row['variant_id'] as int?,
        sku: row['sku'] as String,
        barcode: row['barcode'] as String?,
        productName: row['product_name'] as String,
        variantDisplay: row['variant_display'] as String,
        quantity: row['quantity'] as int,
        unitPriceCents: row['unit_price_cents'] as int,
        discountBasisPoints: row['discount_basis_points'] as int,
        grossTotalCents: row['gross_total_cents'] as int,
        finalTotalCents: row['final_total_cents'] as int,
      );

  void _ensureColumn(String table, String column, String definition) {
    if (_hasColumn(table, column)) return;
    database.db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
  }

  bool _hasColumn(String table, String column) => database.db
      .select('PRAGMA table_info($table);')
      .any((row) =>
          (row['name'] as String).toLowerCase() == column.toLowerCase());

  bool _tableExists(String table) => database.db.select(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;",
        [table],
      ).isNotEmpty;

  int _nextAvailableCustomerCode() {
    var candidate = 1;
    final rows = database.db.select(
      'SELECT customer_code FROM customers ORDER BY customer_code;',
    );
    for (final row in rows) {
      final current = row['customer_code'] as int;
      if (current < candidate) continue;
      if (current == candidate) {
        candidate++;
        continue;
      }
      break;
    }
    return candidate;
  }

  int _nextAvailableGiftCardId() {
    var candidate = 1;
    final rows = database.db.select('SELECT id FROM gift_cards ORDER BY id;');
    for (final row in rows) {
      final current = row['id'] as int;
      if (current < candidate) continue;
      if (current == candidate) {
        candidate++;
        continue;
      }
      break;
    }
    return candidate;
  }

  int _nextOrderSerial() {
    final rows = database.db.select(
      "SELECT seq FROM sqlite_sequence WHERE name='sales_orders' LIMIT 1;",
    );
    return rows.isEmpty ? 1 : (rows.first['seq'] as int) + 1;
  }

  String _newUniqueOrderNumber(DateTime utc) {
    var serial = _nextOrderSerial();
    while (true) {
      final candidate = _newOrderNumber(utc, serial);
      final exists = database.db.select(
        'SELECT 1 FROM sales_orders WHERE order_number=? LIMIT 1;',
        [candidate],
      ).isNotEmpty;
      if (!exists) return candidate;
      serial++;
    }
  }

  String _newUniqueGiftCardCode() {
    for (var attempt = 0; attempt < 1024; attempt++) {
      final candidate = _newGiftCardCode();
      final exists = database.db.select(
        'SELECT 1 FROM gift_cards WHERE code=? COLLATE NOCASE LIMIT 1;',
        [candidate],
      ).isNotEmpty;
      if (!exists) return candidate;
    }
    throw StateError('Impossibile generare un codice univoco per il buono regalo.');
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _newOrderNumber(DateTime utc, int serial) {
    final local = utc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final suffix = serial.toString().padLeft(6, '0');
    return 'ORD-${local.year}${two(local.month)}${two(local.day)}-${two(local.hour)}${two(local.minute)}${two(local.second)}-$suffix';
  }

  static String _newGiftCardCode() {
    const digits = '0123456789ABCDEF';
    return List.generate(
      8,
      (_) => digits[_giftCardRandom.nextInt(digits.length)],
      growable: false,
    ).join();
  }

  static String? _optional(String? value) =>
      value?.trim().isNotEmpty == true ? value!.trim() : null;
}
