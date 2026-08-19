import 'dart:typed_data';

import '../core/database_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this.database) {
    _ensureSchema();
  }

  final DatabaseService database;

  void _ensureSchema() {
    database.db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fiscal_code TEXT NOT NULL COLLATE NOCASE UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        birth_date TEXT NOT NULL,
        sex TEXT NOT NULL,
        birth_place_code TEXT NOT NULL,
        notes TEXT,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sales_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        gross_total_cents INTEGER NOT NULL,
        item_discount_cents INTEGER NOT NULL DEFAULT 0,
        order_discount_basis_points INTEGER NOT NULL DEFAULT 0,
        order_percent_discount_cents INTEGER NOT NULL DEFAULT 0,
        fixed_discount_cents INTEGER NOT NULL DEFAULT 0,
        final_total_cents INTEGER NOT NULL,
        receipt_filename TEXT,
        receipt_blob BLOB,
        created_at_utc TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT
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
      CREATE INDEX IF NOT EXISTS ix_customers_name ON customers(last_name COLLATE NOCASE, first_name COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_customers_fiscal_code ON customers(fiscal_code COLLATE NOCASE);
      CREATE INDEX IF NOT EXISTS ix_sales_orders_customer_date ON sales_orders(customer_id, created_at_utc DESC, id DESC);
      CREATE INDEX IF NOT EXISTS ix_sales_order_items_order ON sales_order_items(order_id, id);
    ''');

    _ensureColumn('sales_orders', 'customer_display_name', 'TEXT');
    _ensureColumn('sales_orders', 'customer_fiscal_code', 'TEXT');
    _backfillCustomerSnapshots();
  }

  void _backfillCustomerSnapshots() {
    database.db.execute('''
      UPDATE sales_orders
      SET customer_display_name = (
            SELECT TRIM(c.last_name || ' ' || c.first_name)
            FROM customers c WHERE c.id = sales_orders.customer_id
          ),
          customer_fiscal_code = (
            SELECT c.fiscal_code
            FROM customers c WHERE c.id = sales_orders.customer_id
          )
      WHERE customer_id IS NOT NULL
        AND (customer_display_name IS NULL OR TRIM(customer_display_name) = ''
          OR customer_fiscal_code IS NULL OR TRIM(customer_fiscal_code) = '');
    ''');
  }

  List<Customer> search([String? query, int limit = 500]) {
    final q = query?.trim() ?? '';
    final pattern = '%$q%';
    final rows = database.db.select('''
      SELECT * FROM customers
      WHERE ?=''
         OR fiscal_code LIKE ? COLLATE NOCASE
         OR first_name LIKE ? COLLATE NOCASE
         OR last_name LIKE ? COLLATE NOCASE
         OR (last_name || ' ' || first_name) LIKE ? COLLATE NOCASE
         OR COALESCE(notes, '') LIKE ? COLLATE NOCASE
      ORDER BY last_name COLLATE NOCASE, first_name COLLATE NOCASE, id
      LIMIT ?;
    ''', [q, pattern, pattern, pattern, pattern, pattern, limit.clamp(1, 5000)]);
    return rows.map(_customerFromRow).toList();
  }

  Customer? getById(int id) {
    final rows = database.db.select('SELECT * FROM customers WHERE id=? LIMIT 1;', [id]);
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  Customer? findByFiscalCode(String fiscalCode) {
    final value = fiscalCode.trim().toUpperCase();
    final rows = database.db.select(
      'SELECT * FROM customers WHERE fiscal_code=? COLLATE NOCASE LIMIT 1;',
      [value],
    );
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  Customer save(CustomerDraft draft) {
    final firstName = draft.firstName.trim();
    final lastName = draft.lastName.trim();
    if (firstName.isEmpty) throw ArgumentError('Il nome è obbligatorio.');
    if (lastName.isEmpty) throw ArgumentError('Il cognome è obbligatorio.');

    final data = draft.fiscalCodeData;
    final now = DateTime.now().toUtc().toIso8601String();
    final birthDate = _dateOnly(data.birthDate);
    final notes = _optional(draft.notes);

    if (draft.id == null) {
      database.db.execute('''
        INSERT INTO customers (
          fiscal_code, first_name, last_name, birth_date, sex, birth_place_code,
          notes, created_at_utc, updated_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        data.fiscalCode,
        firstName,
        lastName,
        birthDate,
        data.sex,
        data.birthPlaceCode,
        notes,
        now,
        now,
      ]);
      return getById(database.db.lastInsertRowId)!;
    }

    database.db.execute('''
      UPDATE customers
      SET fiscal_code=?, first_name=?, last_name=?, birth_date=?, sex=?, birth_place_code=?, notes=?, updated_at_utc=?
      WHERE id=?;
    ''', [
      data.fiscalCode,
      firstName,
      lastName,
      birthDate,
      data.sex,
      data.birthPlaceCode,
      notes,
      now,
      draft.id,
    ]);
    final updated = getById(draft.id!);
    if (updated == null) throw StateError('Cliente non trovato.');
    return updated;
  }

  bool deleteCustomer(int customerId) {
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      final rows = db.select(
        'SELECT first_name, last_name, fiscal_code FROM customers WHERE id=? LIMIT 1;',
        [customerId],
      );
      if (rows.isEmpty) {
        db.execute('ROLLBACK;');
        return false;
      }

      final row = rows.first;
      final displayName = '${row['last_name']} ${row['first_name']}'.trim();
      final fiscalCode = row['fiscal_code'] as String;
      db.execute('''
        UPDATE sales_orders
        SET customer_display_name = CASE
              WHEN customer_display_name IS NULL OR TRIM(customer_display_name) = '' THEN ?
              ELSE customer_display_name
            END,
            customer_fiscal_code = CASE
              WHEN customer_fiscal_code IS NULL OR TRIM(customer_fiscal_code) = '' THEN ?
              ELSE customer_fiscal_code
            END,
            customer_id = NULL
        WHERE customer_id=?;
      ''', [displayName, fiscalCode, customerId]);
      db.execute('DELETE FROM customers WHERE id=?;', [customerId]);
      db.execute('COMMIT;');
      return true;
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
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

  SalesOrderSummary recordSale(SalesOrderDraft draft) {
    if (draft.lines.isEmpty) throw ArgumentError('La vendita non contiene articoli.');
    final db = database.db;
    db.execute('BEGIN IMMEDIATE;');
    try {
      String? customerDisplayName;
      String? customerFiscalCode;
      if (draft.customerId != null) {
        final customers = db.select(
          'SELECT first_name, last_name, fiscal_code FROM customers WHERE id=? LIMIT 1;',
          [draft.customerId],
        );
        if (customers.isEmpty) throw StateError('Il cliente selezionato non esiste più.');
        final customer = customers.first;
        customerDisplayName = '${customer['last_name']} ${customer['first_name']}'.trim();
        customerFiscalCode = customer['fiscal_code'] as String;
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
          throw StateError('${line.productName}: giacenza insufficiente. Disponibili: $available.');
        }
      }

      final now = DateTime.now().toUtc();
      final orderNumber = _newOrderNumber(now);
      db.execute('''
        INSERT INTO sales_orders (
          order_number, customer_id, customer_display_name, customer_fiscal_code,
          gross_total_cents, item_discount_cents, order_discount_basis_points,
          order_percent_discount_cents, fixed_discount_cents, final_total_cents,
          created_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        orderNumber,
        draft.customerId,
        customerDisplayName,
        customerFiscalCode,
        draft.grossTotalCents,
        draft.itemDiscountCents,
        draft.orderDiscountBasisPoints,
        draft.orderPercentDiscountCents,
        draft.fixedDiscountCents,
        draft.finalTotalCents,
        now.toIso8601String(),
      ]);
      final orderId = db.lastInsertRowId;

      for (final line in draft.lines) {
        db.execute('''
          INSERT INTO sales_order_items (
            order_id, variant_id, sku, barcode, product_name, variant_display,
            quantity, unit_price_cents, discount_basis_points, gross_total_cents, final_total_cents)
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
            INSERT INTO stock_movements (variant_id, movement_type, quantity_delta, note, created_at_utc)
            VALUES (?, 'OUT', ?, ?, ?);
          ''', [variantId, -line.quantity, 'Vendita $orderNumber', now.toIso8601String()]);
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
        fiscalCode: row['fiscal_code'] as String,
        firstName: row['first_name'] as String,
        lastName: row['last_name'] as String,
        birthDate: DateTime.parse(row['birth_date'] as String),
        sex: row['sex'] as String,
        birthPlaceCode: row['birth_place_code'] as String,
        notes: row['notes'] as String?,
        createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
        updatedAtUtc: DateTime.parse(row['updated_at_utc'] as String).toUtc(),
      );

  SalesOrderSummary _orderSummaryFromRow(dynamic row) => SalesOrderSummary(
        id: row['id'] as int,
        orderNumber: row['order_number'] as String,
        customerId: row['customer_id'] as int?,
        customerDisplayName: row['customer_display_name'] as String?,
        customerFiscalCode: row['customer_fiscal_code'] as String?,
        itemCount: row['item_count'] as int,
        grossTotalCents: row['gross_total_cents'] as int,
        itemDiscountCents: row['item_discount_cents'] as int,
        orderDiscountBasisPoints: row['order_discount_basis_points'] as int,
        orderPercentDiscountCents: row['order_percent_discount_cents'] as int,
        fixedDiscountCents: row['fixed_discount_cents'] as int,
        finalTotalCents: row['final_total_cents'] as int,
        receiptFilename: row['receipt_filename'] as String?,
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
      .any((row) => (row['name'] as String).toLowerCase() == column.toLowerCase());

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _newOrderNumber(DateTime utc) {
    final local = utc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final micros = local.microsecond.toString().padLeft(6, '0');
    return 'ORD-${local.year}${two(local.month)}${two(local.day)}-${two(local.hour)}${two(local.minute)}${two(local.second)}-$micros';
  }

  static String? _optional(String? value) => value?.trim().isNotEmpty == true ? value!.trim() : null;
}