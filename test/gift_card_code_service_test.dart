import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  test('new gift cards use unique eight-character hexadecimal codes', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-code-',
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

      final codes = <String>{};
      for (var i = 0; i < 250; i++) {
        final card = repository.createGiftCard(customer.id, 5000);
        expect(card.code, matches(RegExp(r'^[0-9A-F]{8}$')));
        expect(codes.add(card.code), isTrue);
      }

      expect(codes, hasLength(250));
      expect(
        service.db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='gift_card_code_registry';",
        ),
        isEmpty,
      );
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });
}
