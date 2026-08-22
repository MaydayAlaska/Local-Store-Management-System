import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/database_service.dart';
import 'package:local_store_management/models/customer.dart';
import 'package:local_store_management/repositories/customer_repository.dart';

void main() {
  test('deleting a gift card physically removes it and frees its id', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-hard-delete-',
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
      final secondCard = repository.createGiftCard(customer.id, 3000);
      expect(secondCard.id, card.id + 1);

      expect(repository.deleteGiftCard(card.id), isTrue);
      expect(repository.getGiftCard(card.id), isNull);
      expect(
        repository.giftCardsForCustomer(customer.id).map((item) => item.id),
        contains(secondCard.id),
      );
      expect(
        service.db.select(
          'SELECT code FROM gift_cards WHERE id=? LIMIT 1;',
          [card.id],
        ),
        isEmpty,
      );

      final columns = service.db.select('PRAGMA table_info(gift_cards);');
      expect(columns.any((row) => row['name'] == 'deleted_at_utc'), isFalse);
      expect(
        service.db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='gift_card_code_registry';",
        ),
        isEmpty,
      );

      final replacement = repository.createGiftCard(customer.id, 2500);
      expect(
        replacement.id,
        card.id,
        reason: 'Il primo ID libero deve essere riutilizzato anche se esistono ID più alti.',
      );
      expect(repository.getGiftCard(secondCard.id)?.code, secondCard.code);
    } finally {
      service.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('gift card cleanup physically deletes age, exhausted or expired matches', () async {
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
      repository.createGiftCard(
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

      final storedCount = service.db.select(
        'SELECT COUNT(*) AS count FROM gift_cards;',
      ).first['count'] as int;
      expect(storedCount, 1);
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

  test('soft-delete beta schema and old code registry are removed', () async {
    final temp = await Directory.systemTemp.createTemp(
      'lsms-flutter-gift-card-hard-delete-migration-',
    );
    final path = '${temp.path}${Platform.pathSeparator}store.db';
    final service = DatabaseService(path);
    try {
      await service.initialize();
      const created = '2026-08-20T10:00:00.000Z';
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
          expires_at_utc TEXT,
          purchase_order_id INTEGER,
          deleted_at_utc TEXT,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        );
        CREATE TABLE gift_card_code_registry (
          code TEXT PRIMARY KEY COLLATE NOCASE,
          issued_at_utc TEXT NOT NULL
        );
      ''');
      service.db.execute('''
        INSERT INTO customers (
          id, customer_code, first_name, last_name, created_at_utc, updated_at_utc)
        VALUES (1, 1, 'Mario', 'Rossi', ?, ?);
      ''', [created, created]);
      service.db.execute('''
        INSERT INTO gift_cards (
          id, code, customer_id, total_value_cents, spent_value_cents,
          expires_at_utc, purchase_order_id, deleted_at_utc,
          created_at_utc, updated_at_utc)
        VALUES
          (1, 'AAAABBBB', 1, 1000, 0, NULL, NULL, NULL, ?, ?),
          (2, 'CCCCDDDD', 1, 2000, 0, NULL, NULL, ?, ?, ?);
      ''', [
        created,
        created,
        '2026-08-21T10:00:00.000Z',
        created,
        created,
      ]);
      service.db.execute('''
        INSERT INTO gift_card_code_registry (code, issued_at_utc)
        VALUES ('AAAABBBB', ?), ('CCCCDDDD', ?);
      ''', [created, created]);

      final repository = CustomerRepository(service);

      final columns = service.db.select('PRAGMA table_info(gift_cards);');
      expect(columns.any((row) => row['name'] == 'deleted_at_utc'), isFalse);
      expect(repository.getGiftCard(1)?.code, 'AAAABBBB');
      expect(repository.getGiftCard(2), isNull);
      final customerColumn =
          columns.firstWhere((row) => row['name'] == 'customer_id');
      expect(customerColumn['notnull'], 0);
      final customerFk = service.db
          .select('PRAGMA foreign_key_list(gift_cards);')
          .firstWhere((row) => row['from'] == 'customer_id');
      expect((customerFk['on_delete'] as String).toUpperCase(), 'SET NULL');
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
