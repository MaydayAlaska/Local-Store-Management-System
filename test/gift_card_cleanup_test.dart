import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  test('deleting a gift card is logical and keeps its code reserved', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-soft-delete-',
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
      final card = repository.createGiftCard(customer.id, 5000);

      expect(repository.deleteGiftCard(card.id), isTrue);
      expect(repository.getGiftCard(card.id), isNull);
      expect(repository.giftCardsForCustomer(customer.id), isEmpty);

      final stored = service.db.select(
        'SELECT code, deleted_at_utc FROM gift_cards WHERE id=? LIMIT 1;',
        [card.id],
      );
      expect(stored, hasLength(1));
      expect(stored.first['code'], card.code);
      expect(stored.first['deleted_at_utc'], isNotNull);

      final registry = service.db.select(
        'SELECT code FROM gift_card_code_registry WHERE code=? LIMIT 1;',
        [card.code],
      );
      expect(registry, hasLength(1));
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('gift card cleanup matches age, exhausted or expired criteria', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-cleanup-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      final customer = repository.save(const CustomerDraft(
        firstName: 'Luigi',
        lastName: 'Verdi',
      ));
      final now = DateTime.utc(2026, 8, 22, 12);

      final oldCard = repository.createGiftCard(customer.id, 1000);
      final exhaustedCard = repository.createGiftCard(customer.id, 2000);
      final expiredCard = repository.createGiftCard(
        customer.id,
        3000,
        expiresAtUtc: now.subtract(const Duration(days: 1)),
      );
      final activeCard = repository.createGiftCard(customer.id, 4000);

      service.db.execute(
        'UPDATE gift_cards SET created_at_utc=? WHERE id=?;',
        [DateTime.utc(2020, 1, 1).toIso8601String(), oldCard.id],
      );
      service.db.execute(
        'UPDATE gift_cards SET spent_value_cents=total_value_cents WHERE id=?;',
        [exhaustedCard.id],
      );

      final count = repository.countGiftCardsForCleanup(
        olderThanYears: 5,
        exhausted: true,
        expired: true,
        nowUtc: now,
      );
      expect(count, 3);

      final deleted = repository.deleteGiftCardsForCleanup(
        olderThanYears: 5,
        exhausted: true,
        expired: true,
        nowUtc: now,
      );
      expect(deleted, 3);

      final remaining = repository.giftCardsForCustomer(customer.id);
      expect(remaining.map((card) => card.code).toList(), [activeCard.code]);

      final deletedRows = service.db.select(
        'SELECT COUNT(*) AS count FROM gift_cards WHERE deleted_at_utc IS NOT NULL;',
      ).first['count'] as int;
      expect(deletedRows, 3);

      final registryCount = service.db.select(
        'SELECT COUNT(*) AS count FROM gift_card_code_registry;',
      ).first['count'] as int;
      expect(registryCount, 4);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
