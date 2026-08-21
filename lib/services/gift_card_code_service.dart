import '../core/database_service.dart';

class GiftCardCodeService {
  const GiftCardCodeService._();

  static void ensureTimestampCodes(DatabaseService database) {
    database.db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_gift_cards_timestamp_code
      AFTER INSERT ON gift_cards
      BEGIN
        UPDATE gift_cards
        SET code = 'GIFT-' ||
          strftime('%Y%m%d-%H%M%S', NEW.created_at_utc, 'localtime') || '-' ||
          printf('%06d', NEW.id)
        WHERE id = NEW.id;
      END;
    ''');
  }
}
