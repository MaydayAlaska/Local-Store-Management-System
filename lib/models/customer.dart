import 'dart:typed_data';

import '../core/formatters.dart';

class FiscalCodeData {
  const FiscalCodeData({
    required this.fiscalCode,
    required this.birthDate,
    required this.sex,
    required this.birthPlaceCode,
  });

  final String fiscalCode;
  final DateTime birthDate;
  final String sex;
  final String birthPlaceCode;

  String get birthDateDisplay =>
      '${birthDate.day.toString().padLeft(2, '0')}/${birthDate.month.toString().padLeft(2, '0')}/${birthDate.year}';
}

class Customer {
  const Customer({
    required this.id,
    required this.fiscalCode,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.sex,
    required this.birthPlaceCode,
    this.notes,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final int id;
  final String fiscalCode;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String sex;
  final String birthPlaceCode;
  final String? notes;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String get displayName => '$lastName $firstName'.trim();
  String get birthDateDisplay =>
      '${birthDate.day.toString().padLeft(2, '0')}/${birthDate.month.toString().padLeft(2, '0')}/${birthDate.year}';
}

class CustomerDraft {
  const CustomerDraft({
    this.id,
    required this.fiscalCodeData,
    required this.firstName,
    required this.lastName,
    this.notes,
  });

  final int? id;
  final FiscalCodeData fiscalCodeData;
  final String firstName;
  final String lastName;
  final String? notes;
}

class SalesOrderDraftLine {
  const SalesOrderDraftLine({
    required this.variantId,
    required this.sku,
    this.barcode,
    required this.productName,
    required this.variantDisplay,
    required this.quantity,
    required this.unitPriceCents,
    required this.discountBasisPoints,
    required this.grossTotalCents,
    required this.finalTotalCents,
  });

  final int? variantId;
  final String sku;
  final String? barcode;
  final String productName;
  final String variantDisplay;
  final int quantity;
  final int unitPriceCents;
  final int discountBasisPoints;
  final int grossTotalCents;
  final int finalTotalCents;
}

class SalesOrderDraft {
  const SalesOrderDraft({
    this.customerId,
    required this.lines,
    required this.grossTotalCents,
    required this.itemDiscountCents,
    required this.orderDiscountBasisPoints,
    required this.orderPercentDiscountCents,
    required this.fixedDiscountCents,
    required this.finalTotalCents,
  });

  final int? customerId;
  final List<SalesOrderDraftLine> lines;
  final int grossTotalCents;
  final int itemDiscountCents;
  final int orderDiscountBasisPoints;
  final int orderPercentDiscountCents;
  final int fixedDiscountCents;
  final int finalTotalCents;
}

class SalesOrderSummary {
  const SalesOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.customerDisplayName,
    this.customerFiscalCode,
    required this.itemCount,
    required this.grossTotalCents,
    required this.itemDiscountCents,
    required this.orderDiscountBasisPoints,
    required this.orderPercentDiscountCents,
    required this.fixedDiscountCents,
    required this.finalTotalCents,
    this.receiptFilename,
    required this.createdAtUtc,
  });

  final int id;
  final String orderNumber;
  final int? customerId;
  final String? customerDisplayName;
  final String? customerFiscalCode;
  final int itemCount;
  final int grossTotalCents;
  final int itemDiscountCents;
  final int orderDiscountBasisPoints;
  final int orderPercentDiscountCents;
  final int fixedDiscountCents;
  final int finalTotalCents;
  final String? receiptFilename;
  final DateTime createdAtUtc;

  String get totalDisplay => formatMoney(finalTotalCents);
  bool get hasReceipt => receiptFilename?.trim().isNotEmpty == true;
  bool get hasCustomerSnapshot => customerDisplayName?.trim().isNotEmpty == true;
}

class SalesOrderItem {
  const SalesOrderItem({
    required this.id,
    required this.orderId,
    this.variantId,
    required this.sku,
    this.barcode,
    required this.productName,
    required this.variantDisplay,
    required this.quantity,
    required this.unitPriceCents,
    required this.discountBasisPoints,
    required this.grossTotalCents,
    required this.finalTotalCents,
  });

  final int id;
  final int orderId;
  final int? variantId;
  final String sku;
  final String? barcode;
  final String productName;
  final String variantDisplay;
  final int quantity;
  final int unitPriceCents;
  final int discountBasisPoints;
  final int grossTotalCents;
  final int finalTotalCents;

  double get discountPercent => discountBasisPoints / 100;
}

class SalesOrderDetail {
  const SalesOrderDetail({required this.summary, required this.items});
  final SalesOrderSummary summary;
  final List<SalesOrderItem> items;
}

class ReceiptAttachment {
  const ReceiptAttachment({required this.filename, required this.bytes});
  final String filename;
  final Uint8List bytes;
}