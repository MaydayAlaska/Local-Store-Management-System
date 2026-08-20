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

  test('generic sale item is stored without changing stock and order numbers stay unique', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-generic-sale-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      const draft = SalesOrderDraft(
        lines: [
          SalesOrderDraftLine(
            variantId: null,
            sku: 'GENERIC',
            productName: 'Articolo generico',
            variantDisplay: '',
            quantity: 1,
            unitPriceCents: 1234,
            discountBasisPoints: 0,
            grossTotalCents: 1234,
            finalTotalCents: 1234,
          ),
        ],
        grossTotalCents: 1234,
        itemDiscountCents: 0,
        orderDiscountBasisPoints: 0,
        orderPercentDiscountCents: 0,
        fixedDiscountCents: 0,
        finalTotalCents: 1234,
      );

      final order = repository.recordSale(draft);
      final secondOrder = repository.recordSale(draft);

      final detail = repository.getOrder(order.id)!;
      expect(detail.items, hasLength(1));
      expect(detail.items.single.variantId, isNull);
      expect(detail.items.single.productName, 'Articolo generico');
      expect(detail.items.single.unitPriceCents, 1234);
      expect(detail.summary.finalTotalCents, 1234);
      expect(secondOrder.orderNumber, isNot(order.orderNumber));
      expect(
        RegExp(r'^ORD-\d{8}-\d{6}-\d{6,}$').hasMatch(order.orderNumber),
        isTrue,
      );
      expect(order.orderNumber.endsWith(order.id.toString().padLeft(6, '0')), isTrue);
      expect(
        secondOrder.orderNumber.endsWith(secondOrder.id.toString().padLeft(6, '0')),
        isTrue,
      );

      final movements = service.db
          .select("SELECT COUNT(*) AS count FROM stock_movements WHERE movement_type='OUT';")
          .first['count'] as int;
      expect(movements, 0);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('cancel restores stock once while delete and age purge never restore stock', () async {
    final temp = await Directory.systemTemp.createTemp('lsms-flutter-order-lifecycle-');
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      const now = '2026-08-19T00:00:00.000Z';
      service.db.execute(
        'INSERT INTO products (name, sale_price_cents, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
        ['Test prodotto', 1000, now, now],
      );
      final productId = service.db.lastInsertRowId;
      service.db.execute(
        'INSERT INTO product_variants (product_id, sku, is_active, created_at_utc, updated_at_utc) VALUES (?, ?, 1, ?, ?);',
        [productId, 'TEST-001', now, now],
      );
      final variantId = service.db.lastInsertRowId;
      service.db.execute(
        "INSERT INTO stock_movements (variant_id, movement_type, quantity_delta, note, created_at_utc) VALUES (?, 'IN', 5, 'Test', ?);",
        [variantId, now],
      );

      SalesOrderDraft sale(int quantity) => SalesOrderDraft(
            lines: [
              SalesOrderDraftLine(
                variantId: variantId,
                sku: 'TEST-001',
                productName: 'Test prodotto',
                variantDisplay: '',
                quantity: quantity,
                unitPriceCents: 1000,
                discountBasisPoints: 0,
                grossTotalCents: 1000 * quantity,
                finalTotalCents: 1000 * quantity,
              ),
            ],
            grossTotalCents: 1000 * quantity,
            itemDiscountCents: 0,
            orderDiscountBasisPoints: 0,
            orderPercentDiscountCents: 0,
            fixedDiscountCents: 0,
            finalTotalCents: 1000 * quantity,
          );

      int stock() => service.db.select(
            'SELECT COALESCE(SUM(quantity_delta), 0) AS stock FROM stock_movements WHERE variant_id=?;',
            [variantId],
          ).first['stock'] as int;

      final cancelledOrder = repository.recordSale(sale(2));
      expect(stock(), 3);
      expect(repository.cancelOrder(cancelledOrder.id), isTrue);
      expect(stock(), 5);
      expect(repository.getOrder(cancelledOrder.id)!.summary.isCancelled, isTrue);
      expect(repository.cancelOrder(cancelledOrder.id), isFalse);
      expect(stock(), 5, reason: 'Un secondo annullamento non deve ricaricare di nuovo gli articoli.');
      expect(repository.deleteOrder(cancelledOrder.id), isTrue);
      expect(repository.getOrder(cancelledOrder.id), isNull);
      expect(stock(), 5);

      final deletedActiveOrder = repository.recordSale(sale(1));
      expect(stock(), 4);
      expect(repository.deleteOrder(deletedActiveOrder.id), isTrue);
      expect(stock(), 4, reason: 'Eliminare un ordine attivo non deve ripristinare il magazzino.');

      final oldOrder = repository.recordSale(sale(1));
      expect(stock(), 3);
      service.db.execute(
        'UPDATE sales_orders SET created_at_utc=? WHERE id=?;',
        ['2020-01-01T00:00:00.000Z', oldOrder.id],
      );
      final cutoff = DateTime.utc(2021, 1, 1);
      expect(repository.countOrdersOlderThan(cutoff), 1);
      expect(repository.deleteOrdersOlderThan(cutoff), 1);
      expect(repository.getOrder(oldOrder.id), isNull);
      expect(stock(), 3, reason: 'La pulizia per anzianità non deve modificare il magazzino.');
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
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
      expect(detail.summary.isCancelled, isFalse);
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