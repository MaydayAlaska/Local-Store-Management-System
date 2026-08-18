import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../models/catalog.dart';

class LabelService {
  Barcode barcodeFor(String code) => isValidEan13(code) ? Barcode.ean13() : Barcode.code128();

  bool isValidEan13(String value) {
    if (!RegExp(r'^\d{13}$').hasMatch(value)) return false;
    final digits = value.split('').map(int.parse).toList();
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += digits[i] * (i.isEven ? 1 : 3);
    }
    final check = (10 - (sum % 10)) % 10;
    return check == digits[12];
  }

  Future<List<Printer>> getPrinters() => Printing.listPrinters();

  Future<Uint8List> buildLabels({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    if (widthMm < 20 || widthMm > 120) {
      throw ArgumentError('La larghezza etichetta deve essere compresa tra 20 e 120 mm.');
    }
    if (heightMm < 15 || heightMm > 200) {
      throw ArgumentError('L’altezza etichetta deve essere compresa tra 15 e 200 mm.');
    }
    if (copies < 1 || copies > 100) {
      throw ArgumentError('Il numero di copie deve essere compreso tra 1 e 100.');
    }

    final code = (product.barcode?.trim().isNotEmpty == true ? product.barcode!.trim() : product.sku.trim());
    if (code.isEmpty) throw ArgumentError('Il prodotto non ha un barcode o SKU stampabile.');

    final pageWidth = widthMm * PdfPageFormat.mm;
    final pageHeight = heightMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);
    final document = pw.Document();

    for (var i = 0; i < copies; i++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildLabel(product, code, pageWidth, pageHeight),
        ),
      );
    }
    return document.save();
  }

  pw.Widget _buildLabel(ProductVariant product, String code, double width, double height) {
    final marginX = width * 0.055;
    final titleSize = _clamp(height * 0.105, 7.5, 13.5);
    final smallSize = _clamp(height * 0.065, 5.5, 9.5);
    final priceSize = _clamp(height * 0.12, 8.5, 15.5);
    final barcodeTextSize = _clamp(height * 0.065, 5.5, 9.0);
    final details = <String>[
      if (product.variant?.trim().isNotEmpty == true) product.variant!.trim(),
      if (product.size?.trim().isNotEmpty == true) product.size!.trim(),
    ].join(' | ');

    return pw.Stack(
      children: [
        pw.Positioned(
          left: marginX,
          right: marginX,
          top: height * 0.055,
          height: height * 0.145,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              product.name,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: titleSize, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        if (details.isNotEmpty)
          pw.Positioned(
            left: marginX,
            right: marginX,
            top: height * 0.20,
            height: height * 0.09,
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(details, maxLines: 1, style: pw.TextStyle(fontSize: smallSize)),
            ),
          ),
        pw.Positioned(
          left: marginX,
          right: marginX,
          top: height * 0.30,
          height: height * 0.37,
          child: pw.BarcodeWidget(
            barcode: barcodeFor(code),
            data: code,
            drawText: false,
          ),
        ),
        pw.Positioned(
          left: marginX,
          right: marginX,
          top: height * 0.67,
          height: height * 0.13,
          child: pw.Center(
            child: pw.Text(code, maxLines: 1, style: pw.TextStyle(fontSize: barcodeTextSize)),
          ),
        ),
        pw.Positioned(
          left: marginX,
          right: width * 0.50,
          top: height * 0.80,
          bottom: height * 0.045,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              product.sku,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(fontSize: smallSize, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        if (product.salePriceCents != null)
          pw.Positioned(
            left: width * 0.48,
            right: marginX,
            top: height * 0.80,
            bottom: height * 0.035,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                formatMoney(product.salePriceCents),
                maxLines: 1,
                style: pw.TextStyle(fontSize: priceSize, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Future<bool> printLabels({
    required Printer printer,
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    final bytes = await buildLabels(
      product: product,
      copies: copies,
      widthMm: widthMm,
      heightMm: heightMm,
    );
    return Printing.directPrintPdf(
      printer: printer,
      name: 'Etichette-${product.sku}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
