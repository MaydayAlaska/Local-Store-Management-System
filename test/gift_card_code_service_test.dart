import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';
import 'package:local_store_management/services/gift_card_code_service.dart';

void main() {
  test('new gift cards use purchase timestamp codes', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-code-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      final repository = CustomerRepository(service);
      GiftCardCodeService.ensureTimestampCodes(service);
      final customer = repository.save(const CustomerDraft(
        firstName: 'Mario',
        lastName: 'Rossi',
      ));

      final card = repository.createGiftCard(customer.id, 5000);

      expect(
        card.code,
        matches(RegExp(r'^GIFT-\d{8}-\d{6}-\d{6}$')),
      );
      final localPurchase = card.createdAtUtc.toLocal();
      String two(int value) => value.toString().padLeft(2, '0');
      final timestamp = '${localPurchase.year}'
          '${two(localPurchase.month)}'
          '${two(localPurchase.day)}-'
          '${two(localPurchase.hour)}'
          '${two(localPurchase.minute)}'
          '${two(localPurchase.second)}';
      expect(card.code, startsWith('GIFT-$timestamp-'));
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
