import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_gift_card_extensions.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  test('gift card expiration can be changed and removed after creation', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-expiration-update-',
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
      expect(card.expiresAtUtc, isNull);

      final expiration = DateTime.utc(2030, 12, 31, 22, 59, 59);
      repository.updateGiftCardExpiration(
        card.id,
        expiresAtUtc: expiration,
      );

      final updated = repository
          .giftCardsForCustomer(customer.id)
          .singleWhere((item) => item.id == card.id);
      expect(updated.expiresAtUtc, expiration);

      repository.updateGiftCardExpiration(card.id);
      final cleared = repository
          .giftCardsForCustomer(customer.id)
          .singleWhere((item) => item.id == card.id);
      expect(cleared.expiresAtUtc, isNull);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
