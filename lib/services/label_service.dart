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

  Future<Uint8List> buildLabels({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    final code = product.barcode ?? product.sku;
    final document = pw.Document();
    final pageFormat = PdfPageFormat(widthMm * PdfPageFormat.mm, heightMm * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
    for (var i = 0; i < copies; i++) {
      document.addPage(pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(product.name, maxLines: 1, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            if (product.variantDisplay != 'Variante base')
              pw.Text(product.variantDisplay, maxLines: 1, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 2 * PdfPageFormat.mm),
            pw.Expanded(
              child: pw.BarcodeWidget(
                barcode: barcodeFor(code),
                data: code,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            pw.Text(code, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
            if (product.salePriceCents != null)
              pw.Text(formatMoney(product.salePriceCents), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ],
        ),
      ));
    }
    return document.save();
  }

  Future<bool> printLabels({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    final bytes = await buildLabels(product: product, copies: copies, widthMm: widthMm, heightMm: heightMm);
    return Printing.layoutPdf(
      name: 'Etichette-${product.sku}.pdf',
      onLayout: (_) async => bytes,
    );
  }
}
