import 'customer_repository.dart';

extension CustomerGiftCardExpirationRepository on CustomerRepository {
  void updateGiftCardExpiration(
    int giftCardId, {
    DateTime? expiresAtUtc,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
      '''
        UPDATE gift_cards
        SET expires_at_utc=?, updated_at_utc=?
        WHERE id=?;
      ''',
      [expiresAtUtc?.toUtc().toIso8601String(), now, giftCardId],
    );
    if (database.db.updatedRows == 0) {
      throw StateError('Buono regalo non trovato.');
    }
  }
}
