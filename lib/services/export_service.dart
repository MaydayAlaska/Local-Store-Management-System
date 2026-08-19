import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../models/app_settings.dart';
import '../models/catalog.dart';
import '../repositories/product_repository.dart';
import 'settings_service.dart';

class ExportService {
  ExportService(this.products, this.settingsService);
  final ProductRepository products;
  final SettingsService settingsService;

  List<ProductVariant> filteredInventory(Set<int> brandIds, Set<int> categoryIds) {
    return products.search().where((product) {
      final brandOk = brandIds.isEmpty || (product.brandId != null && brandIds.contains(product.brandId));
      final categoryOk = categoryIds.isEmpty || (product.categoryId != null && categoryIds.contains(product.categoryId));
      return brandOk && categoryOk;
    }).toList();
  }

  Future<String?> exportExcel({
    required Set<int> brandIds,
    required Set<int> categoryIds,
    required AppSettings settings,
  }) async {
    final inventory = filteredInventory(brandIds, categoryIds);
    final workbook = Excel.createExcel();
    final sheet = workbook['Inventario'];
    if (workbook.sheets.keys.contains('Sheet1')) workbook.delete('Sheet1');

    sheet.appendRow([TextCellValue(settings.shopName)]);
    sheet.appendRow([TextCellValue('Inventario esportato il ${formatLocalDateTime(DateTime.now().toUtc())}')]);
    sheet.appendRow([]);

    for (final entry in _groupByBrand(inventory).entries) {
      sheet.appendRow([TextCellValue(entry.key)]);
      sheet.appendRow([
        TextCellValue('Prodotto'), TextCellValue('Variante'), TextCellValue('SKU'), TextCellValue('Barcode'),
        TextCellValue('Categoria'), TextCellValue('Giacenza'), TextCellValue('Acquisto'), TextCellValue('Vendita'), TextCellValue('Stato'),
      ]);
      for (final product in entry.value) {
        sheet.appendRow([
          TextCellValue(product.name),
          TextCellValue(product.variantDisplay),
          TextCellValue(product.sku),
          TextCellValue(product.barcode ?? ''),
          TextCellValue(product.category ?? ''),
          IntCellValue(product.stockQuantity),
          product.purchasePriceCents == null ? TextCellValue('') : DoubleCellValue(product.purchasePriceCents! / 100),
          product.salePriceCents == null ? TextCellValue('') : DoubleCellValue(product.salePriceCents! / 100),
          TextCellValue(product.statusDisplay),
        ]);
      }
      sheet.appendRow([]);
    }

    final bytes = workbook.save();
    if (bytes == null) throw StateError('Impossibile generare il file Excel.');
    final location = await getSaveLocation(
      suggestedName: 'inventario.xlsx',
      acceptedTypeGroups: const [XTypeGroup(label: 'Excel', extensions: ['xlsx'])],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  Future<String?> exportPdf({
    required Set<int> brandIds,
    required Set<int> categoryIds,
    required AppSettings settings,
  }) async {
    final inventory = filteredInventory(brandIds, categoryIds);
    final document = pw.Document(theme: _loadPdfTheme());
    final logoPath = settingsService.resolveLogoPath(settings);
    pw.MemoryImage? logo;
    if (logoPath != null && !logoPath.toLowerCase().endsWith('.ico')) {
      logo = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Row(children: [
        if (logo != null) ...[pw.Image(logo, width: 34, height: 34), pw.SizedBox(width: 10)],
        pw.Expanded(child: pw.Text(settings.shopName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.Text('Inventario'),
      ]),
      build: (_) {
        final widgets = <pw.Widget>[];
        for (final entry in _groupByBrand(inventory).entries) {
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
            child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ));
          widgets.add(_inventoryTable(entry.value));
        }
        if (widgets.isEmpty) widgets.add(pw.Text('Nessun articolo corrisponde ai filtri selezionati.'));
        return widgets;
      },
    ));

    final bytes = await document.save();
    final location = await getSaveLocation(
      suggestedName: 'inventario.pdf',
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  pw.ThemeData _loadPdfTheme() {
    final regular = _firstExistingFont([
      if (Platform.isWindows) r'C:\Windows\Fonts\arial.ttf',
      if (Platform.isLinux) '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      if (Platform.isMacOS) '/System/Library/Fonts/Supplemental/Arial.ttf',
    ]);
    final bold = _firstExistingFont([
      if (Platform.isWindows) r'C:\Windows\Fonts\arialbd.ttf',
      if (Platform.isLinux) '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      if (Platform.isMacOS) '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ]);

    if (regular == null) return pw.ThemeData.base();
    final baseFont = pw.Font.ttf(ByteData.sublistView(File(regular).readAsBytesSync()));
    final boldFont = bold == null
        ? baseFont
        : pw.Font.ttf(ByteData.sublistView(File(bold).readAsBytesSync()));
    return pw.ThemeData.withFont(base: baseFont, bold: boldFont);
  }

  String? _firstExistingFont(List<String> candidates) {
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  pw.Widget _inventoryTable(List<ProductVariant> rows) {
    pw.Widget cell(String value, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(value, style: pw.TextStyle(fontSize: 6.5, fontWeight: header ? pw.FontWeight.bold : null)),
    );
    final allRows = <pw.TableRow>[
      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: [
        for (final title in ['Prodotto', 'Variante', 'SKU', 'Barcode', 'Categoria', 'Qtà', 'Acquisto', 'Vendita']) cell(title, header: true),
      ]),
      ...rows.map((p) => pw.TableRow(children: [
        cell(p.name), cell(p.variantDisplay), cell(p.sku), cell(p.barcode ?? ''), cell(p.category ?? ''),
        cell('${p.stockQuantity}'), cell(formatMoney(p.purchasePriceCents)), cell(formatMoney(p.salePriceCents)),
      ])),
    ];
    return pw.Table(border: pw.TableBorder.all(width: .3, color: PdfColors.grey500), children: allRows);
  }

  Map<String, List<ProductVariant>> _groupByBrand(List<ProductVariant> inventory) {
    final groups = <String, List<ProductVariant>>{};
    for (final product in inventory) {
      final key = product.brand?.trim().isNotEmpty == true ? product.brand!.trim() : 'Senza marca';
      groups.putIfAbsent(key, () => []).add(product);
    }
    final keys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in keys) key: groups[key]!};
  }
}
