import '../core/formatters.dart';

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
  final int? purchasePriceCents;
  final int? salePriceCents;
  final String? notes;
  final bool isActive;
  final int stockQuantity;
  final String? barcodesDisplay;

  String get salePriceDisplay => formatMoney(salePriceCents);
  String get purchasePriceDisplay => formatMoney(purchasePriceCents);
  String get statusDisplay => isActive ? 'Attivo' : 'Disattivato';

  String get variantDisplay {
    final parts = <String>[];
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) parts.add('Taglia ${size!.trim()}');
    return parts.isEmpty ? 'Variante base' : parts.join(' · ');
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
  final String? notes;
  final bool isActive;
  final int variantCount;
  final int stockQuantity;
  final int? minimumSalePriceCents;
  final int? maximumSalePriceCents;

  String get variantCountDisplay => '$variantCount ${variantCount == 1 ? 'variante' : 'varianti'}';
  String get salePriceDisplay => formatMoneyRange(minimumSalePriceCents, maximumSalePriceCents);
}

class ProductDraft {
  const ProductDraft({
    this.id,
    required this.name,
    this.categoryId,
    this.brandId,
    this.notes,
    required this.isActive,
    required this.variants,
  });
  final int? id;
  final String name;
  final int? categoryId;
  final int? brandId;
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
  final int? purchasePriceCents;
  final int? salePriceCents;
  final bool isActive;
  final List<String> barcodes;
  final int stockQuantity;

  String get variantDisplay {
    final parts = <String>[];
    if (variant?.trim().isNotEmpty == true) parts.add(variant!.trim());
    if (size?.trim().isNotEmpty == true) parts.add('Taglia ${size!.trim()}');
    return parts.isEmpty ? 'Variante base' : parts.join(' · ');
  }
}
