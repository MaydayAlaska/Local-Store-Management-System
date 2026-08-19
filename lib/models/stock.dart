import '../core/formatters.dart';
import '../l10n/app_strings.dart';

enum StockMovementKind { incoming, outgoing, adjustment }

class StockMovement {
  const StockMovement({
    required this.id,
    required this.variantId,
    required this.sku,
    this.barcode,
    required this.productName,
    this.brand,
    this.category,
    required this.kind,
    required this.quantityDelta,
    this.note,
    required this.createdAtUtc,
    required this.stockAfter,
  });

  final int id;
  final int variantId;
  final String sku;
  final String? barcode;
  final String productName;
  final String? brand;
  final String? category;
  final StockMovementKind kind;
  final int quantityDelta;
  final String? note;
  final DateTime createdAtUtc;
  final int stockAfter;

  String get typeDisplay => switch (kind) {
        StockMovementKind.incoming =>
          AppStrings.isEnglish ? 'Incoming' : 'Carico',
        StockMovementKind.outgoing =>
          AppStrings.isEnglish ? 'Outgoing' : 'Scarico',
        StockMovementKind.adjustment =>
          AppStrings.isEnglish ? 'Adjustment' : 'Rettifica',
      };
  String get quantityDisplay => quantityDelta > 0 ? '+$quantityDelta' : '$quantityDelta';
  String get createdAtDisplay => formatLocalDateTime(createdAtUtc);
}
