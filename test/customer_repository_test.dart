import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';
import 'package:local_store_management/repositories/sales_order_search.dart';
import 'package:local_store_management/services/fiscal_code_service.dart';

void main() {
  test('codice fiscale scanner derives birth data and validates checksum', () {
    final data = FiscalCodeService.parse('RSSMRA85T10A562S', now: DateTime(2026, 8, 19));
    expect(data.fiscalCode, 'RSSMRA85T10A562S');
    expect(data.birthDate, DateTime(1985, 12, 10));
    expect(data.sex, 'M');
    expect(data.birthPlaceCode, 'A562');
    expect(FiscalCodeService.tryParse('RSSMRA85T10A562X'), isNull);
  });

  test('customer order stores immutable sale snapshot, is globally searchable and survives customer deletion', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-customers-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      final fiscal = FiscalCodeService.parse('RSSMRA85T10A562S', now: DateTime(2026, 8, 19));
      final customer = repository.save(CustomerDraft(
        fiscalCodeData: fiscal,
        firstName: 'Mario',
        lastName: 'Rossi',
      ));

      const now = '2026-08-19T00:00:00.000Z';
      service.db.execute(
        'INSERT INTO products (name, sale_price_cents, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
        ['Maglietta', 2500, now, now],
      );
      final productId = service.db.lastInsertRowId;
      service.db.execute(
        'INSERT INTO product_variants (product_id, sku, variant, size, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, ?, ?, 1, ?, ?);',
        [productId, 'MAG-001', 'Blu', 'M', now, now],
      );
      final variantId = service.db.lastInsertRowId;
      service.db.execute(
        'INSERT INTO product_barcodes (variant_id, barcode, is_primary) VALUES (?, ?, 1);',
        [variantId, '8000000000001'],
      );
      service.db.execute(
        "INSERT INTO stock_movements (variant_id, movement_type, quantity_delta, note, created_at_utc) VALUES (?, 'IN', 5, 'Test', ?);",
        [variantId, now],
      );

      final order = repository.recordSale(SalesOrderDraft(
        customerId: customer.id,
        lines: [
          SalesOrderDraftLine(
            variantId: variantId,
            sku: 'MAG-001',
            barcode: '8000000000001',
            productName: 'Maglietta',
            variantDisplay: 'Blu · Taglia M',
            quantity: 2,
            unitPriceCents: 2500,
            discountBasisPoints: 1000,
            grossTotalCents: 5000,
            finalTotalCents: 4500,
          ),
        ],
        grossTotalCents: 5000,
        itemDiscountCents: 500,
        orderDiscountBasisPoints: 500,
        orderPercentDiscountCents: 225,
        fixedDiscountCents: 275,
        finalTotalCents: 4000,
      ));

      final stock = service.db.select(
        'SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements WHERE variant_id=?;',
        [variantId],
      ).first['stock'] as int;
      expect(stock, 3);

      final detail = repository.getOrder(order.id)!;
      expect(detail.summary.customerId, customer.id);
      expect(detail.summary.customerDisplayName, 'Rossi Mario');
      expect(detail.summary.customerFiscalCode, 'RSSMRA85T10A562S');
      expect(detail.summary.finalTotalCents, 4000);
      expect(detail.items.single.productName, 'Maglietta');
      expect(detail.items.single.unitPriceCents, 2500);
      expect(detail.items.single.discountBasisPoints, 1000);

      expect(repository.searchOrders('Rossi').single.id, order.id);
      expect(repository.searchOrders('RSSMRA85T10A562S').single.id, order.id);
      expect(repository.searchOrders('Maglietta').single.id, order.id);
      expect(repository.searchOrders('MAG-001').single.id, order.id);
      expect(repository.searchOrders('8000000000001').single.id, order.id);

      expect(repository.searchOrdersMatching('Maglietta Blu M').single.id, order.id);
      expect(repository.searchOrdersMatching('Maglietta Taglia M').single.id, order.id);
      expect(repository.searchOrdersMatching('Maglietta Rosso M'), isEmpty);
      expect(repository.ordersForCustomerMatching(customer.id, 'Maglietta Blu M').single.id, order.id);
      expect(repository.ordersForCustomerMatching(customer.id, 'MAG-001 Blu').single.id, order.id);
      expect(repository.ordersForCustomerMatching(customer.id, 'Maglietta Rosso'), isEmpty);

      service.db.execute('UPDATE products SET name=?, sale_price_cents=? WHERE id=?;', ['Nome nuovo', 9999, productId]);
      final unchanged = repository.getOrder(order.id)!;
      expect(unchanged.items.single.productName, 'Maglietta');
      expect(unchanged.items.single.unitPriceCents, 2500);

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      repository.attachReceipt(order.id, 'scontrino.pdf', bytes);
      final receipt = repository.getReceipt(order.id)!;
      expect(receipt.filename, 'scontrino.pdf');
      expect(receipt.bytes, orderedEquals(bytes));
      expect(repository.ordersForCustomer(customer.id).single.hasReceipt, isTrue);

      expect(repository.deleteCustomer(customer.id), isTrue);
      expect(repository.getById(customer.id), isNull);
      expect(repository.ordersForCustomer(customer.id), isEmpty);

      final preserved = repository.getOrder(order.id)!;
      expect(preserved.summary.customerId, isNull);
      expect(preserved.summary.customerDisplayName, 'Rossi Mario');
      expect(preserved.summary.customerFiscalCode, 'RSSMRA85T10A562S');
      expect(preserved.items.single.productName, 'Maglietta');
      expect(repository.searchOrders('Rossi').single.id, order.id);
      expect(repository.searchOrdersMatching('Maglietta Blu M').single.id, order.id);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
