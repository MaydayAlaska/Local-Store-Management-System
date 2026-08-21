import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  test('legacy gift card table gains optional expiration column', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-expiration-migration-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      service.db.execute('''
        CREATE TABLE customers (
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
        CREATE TABLE gift_cards (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL COLLATE NOCASE UNIQUE,
          customer_id INTEGER NOT NULL,
          total_value_cents INTEGER NOT NULL,
          spent_value_cents INTEGER NOT NULL DEFAULT 0,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        );
      ''');

      CustomerRepository(service);

      final columns = service.db.select('PRAGMA table_info(gift_cards);');
      expect(
        columns.any((row) => row['name'] == 'expires_at_utc'),
        isTrue,
      );
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('gift card stores purchase date and optional expiration', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-expiration-',
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

      final futureExpiration = DateTime.now().toUtc().add(
            const Duration(days: 30),
          );
      final beforePurchase = DateTime.now().toUtc();
      final futureCard = repository.createGiftCard(
        customer.id,
        5000,
        expiresAtUtc: futureExpiration,
      );
      final afterPurchase = DateTime.now().toUtc();

      expect(futureCard.purchasedAtUtc.isBefore(beforePurchase), isFalse);
      expect(futureCard.purchasedAtUtc.isAfter(afterPurchase), isFalse);
      expect(futureCard.expiresAtUtc, futureExpiration);
      expect(futureCard.isExpired, isFalse);
      expect(futureCard.isUsable, isTrue);
      expect(
        repository.availableGiftCardsForCustomer(customer.id)
            .map((card) => card.id),
        contains(futureCard.id),
      );

      final noExpiration = repository.createGiftCard(customer.id, 2500);
      expect(noExpiration.expiresAtUtc, isNull);
      expect(noExpiration.isExpired, isFalse);
      expect(noExpiration.isUsable, isTrue);

      final expiredCard = repository.createGiftCard(
        customer.id,
        1000,
        expiresAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      expect(expiredCard.isExpired, isTrue);
      expect(expiredCard.isUsable, isFalse);
      expect(
        repository.availableGiftCardsForCustomer(customer.id)
            .map((card) => card.id),
        isNot(contains(expiredCard.id)),
      );

      expect(
        () => repository.recordSale(
          SalesOrderDraft(
            customerId: customer.id,
            giftCardId: expiredCard.id,
            giftCardAppliedCents: 500,
            lines: const [
              SalesOrderDraftLine(
                variantId: null,
                sku: 'GENERIC',
                productName: 'Articolo generico',
                variantDisplay: '',
                quantity: 1,
                unitPriceCents: 500,
                discountBasisPoints: 0,
                grossTotalCents: 500,
                finalTotalCents: 500,
              ),
            ],
            grossTotalCents: 500,
            itemDiscountCents: 0,
            orderDiscountBasisPoints: 0,
            orderPercentDiscountCents: 0,
            fixedDiscountCents: 0,
            finalTotalCents: 500,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
