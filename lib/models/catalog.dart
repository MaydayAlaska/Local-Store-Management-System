import '../core/formatters.dart';
import '../l10n/app_strings.dart';

class LookupItem {
  const LookupItem({required this.id, required this.name, required this.productCount});
  final int id;
  final String name;
  final int productCount;
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    this.barcode,
    required this.name,
    this.categoryId,
    this.category,
    this.brandId,
    this.brand,
    this.variant,
    this.size,
    this.purchasePriceCents,
    this.salePriceCents,
    this.notes,
    required this.isActive,
    required this.stockQuantity,
    this.barcodesDisplay,
  });

  final int id;
  final int productId;
  final String sku;
  final String? barcode;
  final String name;
  final int? categoryId;
  final String? category;
  final int? brandId;
  final String? brand;
  final String? variant;
  final String? size;

  /// Prezzi effettivi: il repository applica l'override variante quando
  /// presente, altrimenti restituisce il prezzo del prodotto.
  final int? purchasePriceCents;
  final int? salePriceCents;
  final String? notes;
  final bool isActive;
  final int stockQuantity;
  final String? barcodesDisplay;

  String get salePriceDisplay => formatMoney(salePriceCents);
  String get purchasePriceDisplay => formatMoney(purchasePriceCents);
  String get statusDisplay => isActive
      ? AppStrings.pair('Attivo', 'Active')
      : AppStrings.pair('Disattivato', 'Disabled');

  String get cartTitleDisplay {
    final parts = <String>[];
    if (brand?.trim().isNotEmpty == true) parts.add(brand!.trim());
    if (name.trim().isNotEmpty) parts.add(name.trim());
    return parts.join(' ');
  }

  String get cartVariantSizeDisplay {
    final parts = <String>[];
    if (category?.trim().isNotEmpty == true) parts.add(category!.trim());
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) {
      parts.add('${AppStrings.t('size')} ${size!.trim()}');
    }
    return parts.isEmpty
        ? AppStrings.pair('Variante base', 'Base variant')
        : parts.join(' · ');
  }

  /// Descrizione commerciale standard consegnata ai driver dei registratori
  /// telematici: Categoria Brand Articolo - Variante - Taglia.
  String get fiscalReceiptDescription {
    final head = <String>[];
    if (category?.trim().isNotEmpty == true) head.add(category!.trim());
    if (brand?.trim().isNotEmpty == true) head.add(brand!.trim());
    if (name.trim().isNotEmpty) head.add(name.trim());

    final details = <String>[];
    if (variant?.trim().isNotEmpty == true) details.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) details.add(size!.trim());

    final base = head.join(' ');
    if (details.isEmpty) return base;
    return '$base - ${details.join(' - ')}';
  }

  String get variantDisplay {
    final parts = <String>[];
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) {
      parts.add('${AppStrings.t('size')} ${size!.trim()}');
    }
    return parts.isEmpty
        ? AppStrings.pair('Variante base', 'Base variant')
        : parts.join(' · ');
  }
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    this.categoryId,
    this.category,
    this.brandId,
    this.brand,
    this.purchasePriceCents,
    this.salePriceCents,
    this.notes,
    required this.isActive,
    required this.variantCount,
    required this.stockQuantity,
    this.minimumSalePriceCents,
    this.maximumSalePriceCents,
  });

  final int id;
  final String name;
  final int? categoryId;
  final String? category;
  final int? brandId;
  final String? brand;
  final int? purchasePriceCents;
  final int? salePriceCents;
  final String? notes;
  final bool isActive;
  final int variantCount;
  final int stockQuantity;
  final int? minimumSalePriceCents;
  final int? maximumSalePriceCents;

  String get variantCountDisplay => '$variantCount ${variantCount == 1
      ? AppStrings.pair('variante', 'variant')
      : AppStrings.pair('varianti', 'variants')}';

  String get salePriceDisplay =>
      formatMoneyRange(minimumSalePriceCents, maximumSalePriceCents);
}

class ProductDraft {
  const ProductDraft({
    this.id,
    required this.name,
    this.categoryId,
    this.brandId,
    this.purchasePriceCents,
    this.salePriceCents,
    this.notes,
    required this.isActive,
    required this.variants,
  });
  final int? id;
  final String name;
  final int? categoryId;
  final int? brandId;
  final int? purchasePriceCents;
  final int? salePriceCents;
  final String? notes;
  final bool isActive;
  final List<ProductVariantDraft> variants;
}

class ProductVariantDraft {
  const ProductVariantDraft({
    this.id,
    required this.sku,
    this.variant,
    this.size,
    this.purchasePriceCents,
    this.salePriceCents,
    required this.isActive,
    required this.barcodes,
    this.stockQuantity = 0,
  });
  final int? id;
  final String sku;
  final String? variant;
  final String? size;

  /// Override opzionali. Se null vengono usati i prezzi del prodotto.
  final int? purchasePriceCents;
  final int? salePriceCents;
  final bool isActive;
  final List<String> barcodes;
  final int stockQuantity;

  String get variantDisplay {
    final parts = <String>[];
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) {
      parts.add('${AppStrings.t('size')} ${size!.trim()}');
    }
    return parts.isEmpty
        ? AppStrings.pair('Variante base', 'Base variant')
        : parts.join(' · ');
  }
}
