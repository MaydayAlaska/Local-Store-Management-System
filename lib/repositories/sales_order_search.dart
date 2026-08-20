import '../models/customer.dart';
import 'customer_repository.dart';

extension SalesOrderSearchExtension on CustomerRepository {
  List<SalesOrderSummary> searchOrdersMatching([String? query, int limit = 1000]) {
    final q = query?.trim() ?? '';
    if (q.isEmpty) return searchOrders(null, limit);

    final terms = _searchTerms(q);
    final itemPredicates = List.filled(
      terms.length,
      "instr(lower(soi.product_name || ' ' || soi.variant_display || ' ' || soi.sku || ' ' || COALESCE(soi.barcode, '')), lower(?)) > 0",
    ).join(' AND ');

    final rows = database.db.select('''
      SELECT so.*,
        COALESCE((SELECT SUM(soi.quantity) FROM sales_order_items soi WHERE soi.order_id=so.id), 0) AS item_count
      FROM sales_orders so
      WHERE instr(lower(so.order_number), lower(?)) > 0
         OR instr(lower(COALESCE(so.customer_display_name, '')), lower(?)) > 0
         OR instr(lower(COALESCE(so.customer_fiscal_code, '')), lower(?)) > 0
         OR instr(lower(so.created_at_utc), lower(?)) > 0
         OR EXISTS (
           SELECT 1 FROM sales_order_items soi
           WHERE soi.order_id=so.id
             AND $itemPredicates
         )
      ORDER BY so.created_at_utc DESC, so.id DESC
      LIMIT ?;
    ''', [
      q,
      q,
      q,
      q,
      ...terms,
      limit.clamp(1, 10000),
    ]);
    return rows.map(_salesOrderSummaryFromRow).toList();
  }

  List<SalesOrderSummary> ordersForCustomerMatching(
    int customerId, [
    String? itemQuery,
    int limit = 500,
  ]) {
    final terms = _searchTerms(itemQuery?.trim() ?? '');
    if (terms.isEmpty) return ordersForCustomer(customerId, limit);

    final itemPredicates = List.filled(
      terms.length,
      "instr(lower(soi.product_name || ' ' || soi.variant_display || ' ' || soi.sku || ' ' || COALESCE(soi.barcode, '')), lower(?)) > 0",
    ).join(' AND ');

    final rows = database.db.select('''
      SELECT so.*,
        COALESCE((SELECT SUM(soi.quantity) FROM sales_order_items soi WHERE soi.order_id=so.id), 0) AS item_count
      FROM sales_orders so
      WHERE so.customer_id=?
        AND EXISTS (
          SELECT 1 FROM sales_order_items soi
          WHERE soi.order_id=so.id
            AND $itemPredicates
        )
      ORDER BY so.created_at_utc DESC, so.id DESC
      LIMIT ?;
    ''', [
      customerId,
      ...terms,
      limit.clamp(1, 5000),
    ]);
    return rows.map(_salesOrderSummaryFromRow).toList();
  }
}

List<String> _searchTerms(String query) => query
    .split(RegExp(r'\s+'))
    .map((term) => term.trim())
    .where((term) => term.isNotEmpty)
    .toList(growable: false);

SalesOrderSummary _salesOrderSummaryFromRow(dynamic row) => SalesOrderSummary(
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
      cancelledAtUtc: row['cancelled_at_utc'] == null
          ? null
          : DateTime.parse(row['cancelled_at_utc'] as String).toUtc(),
      createdAtUtc: DateTime.parse(row['created_at_utc'] as String).toUtc(),
    );