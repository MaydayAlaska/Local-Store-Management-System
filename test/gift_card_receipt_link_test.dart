import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  SalesOrderDraft giftCardSale(int customerId, int valueCents) =>
      SalesOrderDraft(
        customerId: customerId,
        lines: [
          SalesOrderDraftLine(
            variantId: null,
            sku: 'GIFT-CARD',
            productName: 'Buono regalo',
            variantDisplay: 'Nessuna scadenza',
            quantity: 1,
            unitPriceCents: valueCents,
            discountBasisPoints: 0,
            grossTotalCents: valueCents,
            finalTotalCents: valueCents,
          ),
        ],
        grossTotalCents: valueCents,
        itemDiscountCents: 0,
        orderDiscountBasisPoints: 0,
        orderPercentDiscountCents: 0,
        fixedDiscountCents: 0,
        finalTotalCents: valueCents,
      );

  test('gift card purchase automatically links to its order receipt', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-receipt-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      final customer = repository.save(const CustomerDraft(
        firstName: 'Mario',
        lastName: 'Rossi',
      ));

      final order = repository.recordSale(giftCardSale(customer.id, 5000));
      final card = repository.createGiftCard(customer.id, 5000);

      final linkedBeforeReceipt = repository.purchaseOrderForGiftCard(card.id);
      expect(linkedBeforeReceipt, isNotNull);
      expect(linkedBeforeReceipt!.id, order.id);
      expect(linkedBeforeReceipt.hasReceipt, isFalse);
      expect(repository.getGiftCardReceipt(card.id), isNull);

      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      repository.attachReceipt(order.id, 'scontrino.pdf', bytes);

      final linkedAfterReceipt = repository.purchaseOrderForGiftCard(card.id);
      expect(linkedAfterReceipt, isNotNull);
      expect(linkedAfterReceipt!.hasReceipt, isTrue);
      expect(linkedAfterReceipt.receiptFilename, 'scontrino.pdf');

      final receipt = repository.getGiftCardReceipt(card.id);
      expect(receipt, isNotNull);
      expect(receipt!.filename, 'scontrino.pdf');
      expect(receipt.bytes, bytes);

      expect(repository.deleteOrder(order.id), isTrue);
      expect(repository.getGiftCard(card.id), isNotNull);
      expect(repository.purchaseOrderForGiftCard(card.id), isNull);
      expect(repository.getGiftCardReceipt(card.id), isNull);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('existing purchased gift cards are backfilled to matching orders', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-receipt-backfill-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      var repository = CustomerRepository(service);
      final customer = repository.save(const CustomerDraft(
        firstName: 'Anna',
        lastName: 'Verdi',
      ));
      final order = repository.recordSale(giftCardSale(customer.id, 2500));

      final createdAt = order.createdAtUtc
          .add(const Duration(seconds: 1))
          .toIso8601String();
      service.db.execute('''
        INSERT INTO gift_cards (
          code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, created_at_utc, updated_at_utc)
        VALUES (?, ?, ?, 0, NULL, NULL, ?, ?);
      ''', [
        'GIFT-BACKFILL-1',
        customer.id,
        2500,
        createdAt,
        createdAt,
      ]);
      final giftCardId = service.db.lastInsertRowId;

      repository = CustomerRepository(service);
      expect(repository.purchaseOrderForGiftCard(giftCardId)?.id, order.id);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
