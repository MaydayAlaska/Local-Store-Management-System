import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/catalog.dart';
import '../repositories/product_repository.dart';
import 'settings_service.dart';

enum InventoryExportField {
  product,
  variant,
  sku,
  barcode,
  category,
  stock,
  purchase,
  sale,
}

String inventoryExportFieldLabel(InventoryExportField field) => switch (field) {
      InventoryExportField.product => AppStrings.t('product'),
      InventoryExportField.variant => AppStrings.t('variant'),
      InventoryExportField.sku => AppStrings.t('sku'),
      InventoryExportField.barcode => AppStrings.t('barcode'),
      InventoryExportField.category => AppStrings.t('category'),
      InventoryExportField.stock => AppStrings.t('quantity'),
      InventoryExportField.purchase =>
        AppStrings.pair('Prezzo di Acquisto', 'Purchase Price'),
      InventoryExportField.sale =>
        AppStrings.pair('Prezzo di Vendita', 'Sale Price'),
    };

class ExportService {
  ExportService(this.products, this.settingsService);
  final ProductRepository products;
  final SettingsService settingsService;

  List<ProductVariant> filteredInventory(Set<int> brandIds, Set<int> categoryIds) {
    return products.search().where((product) {
      final brandOk = brandIds.isEmpty ||
          (product.brandId != null && brandIds.contains(product.brandId));
      final categoryOk = categoryIds.isEmpty ||
          (product.categoryId != null && categoryIds.contains(product.categoryId));
      return product.stockQuantity > 0 && brandOk && categoryOk;
    }).toList();
  }

  Future<String?> exportExcel({
    required Set<int> brandIds,
    required Set<int> categoryIds,
    required Set<InventoryExportField> fields,
    required AppSettings settings,
  }) async {
    if (fields.isEmpty) {
      throw StateError(
        AppStrings.pair(
          'Seleziona almeno un campo da esportare.',
          'Select at least one field to export.',
        ),
      );
    }
    final inventory = filteredInventory(brandIds, categoryIds);
    final workbook = Excel.createExcel();
    final sheet = workbook[AppStrings.t('inventory')];
    if (workbook.sheets.keys.contains('Sheet1')) workbook.delete('Sheet1');
    final orderedFields = InventoryExportField.values.where(fields.contains).toList();

    sheet.appendRow([TextCellValue(settings.shopName)]);
    sheet.appendRow([
      TextCellValue(
        '${AppStrings.t('inventory')} · ${formatLocalDateTime(DateTime.now().toUtc())}',
      ),
    ]);
    sheet.appendRow([]);

    for (final entry in _groupByBrand(inventory).entries) {
      sheet.appendRow([TextCellValue(entry.key)]);
      sheet.appendRow([
        for (final field in orderedFields)
          TextCellValue(_headerFor(field, settings.currencyCode)),
      ]);
      for (final product in entry.value) {
        sheet.appendRow([
          for (final field in orderedFields) _excelValue(field, product),
        ]);
      }
      sheet.appendRow([]);
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw StateError(
        AppStrings.pair(
          'Impossibile generare il file Excel.',
          'Unable to generate the Excel file.',
        ),
      );
    }
    final location = await getSaveLocation(
      suggestedName: 'Inventario - ${exportTimestamp()}.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  Future<String?> exportPdf({
    required Set<int> brandIds,
    required Set<int> categoryIds,
    required Set<InventoryExportField> fields,
    required AppSettings settings,
  }) async {
    if (fields.isEmpty) {
      throw StateError(
        AppStrings.pair(
          'Seleziona almeno un campo da esportare.',
          'Select at least one field to export.',
        ),
      );
    }
    final inventory = filteredInventory(brandIds, categoryIds);
    final document = pw.Document(theme: _loadPdfTheme());
    final logoPath = settingsService.resolveLogoPath(settings);
    final orderedFields = InventoryExportField.values.where(fields.contains).toList();
    pw.MemoryImage? logo;
    if (logoPath != null && !logoPath.toLowerCase().endsWith('.ico')) {
      logo = pw.MemoryImage(File(logoPath).readAsBytesSync());
    }

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Row(children: [
        if (logo != null) ...[
          pw.Image(logo, width: 34, height: 34),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(
          child: pw.Text(
            settings.shopName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(AppStrings.t('inventory')),
      ]),
      build: (_) {
        final widgets = <pw.Widget>[];
        for (final entry in _groupByBrand(inventory).entries) {
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
            child: pw.Text(
              entry.key,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ));
          widgets.add(_inventoryTable(
            entry.value,
            orderedFields,
            settings.currencyCode,
          ));
        }
        if (widgets.isEmpty) widgets.add(pw.Text(AppStrings.t('no_inventory_rows')));
        return widgets;
      },
    ));

    final bytes = await document.save();
    final location = await getSaveLocation(
      suggestedName: 'Inventario - ${exportTimestamp()}.pdf',
      acceptedTypeGroups: const [XTypeGroup(label: 'PDF', extensions: ['pdf'])],
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  String _headerFor(InventoryExportField field, String currencyCode) {
    final label = inventoryExportFieldLabel(field);
    if (field == InventoryExportField.purchase || field == InventoryExportField.sale) {
      return '$label ($currencyCode)';
    }
    return label;
  }

  CellValue _excelValue(InventoryExportField field, ProductVariant product) =>
      switch (field) {
        InventoryExportField.product => TextCellValue(product.name),
        InventoryExportField.variant => TextCellValue(product.variantDisplay),
        InventoryExportField.sku => TextCellValue(product.sku),
        InventoryExportField.barcode => TextCellValue(product.barcode ?? ''),
        InventoryExportField.category => TextCellValue(product.category ?? ''),
        InventoryExportField.stock => IntCellValue(product.stockQuantity),
        InventoryExportField.purchase => product.purchasePriceCents == null
            ? TextCellValue('')
            : DoubleCellValue(product.purchasePriceCents! / 100),
        InventoryExportField.sale => product.salePriceCents == null
            ? TextCellValue('')
            : DoubleCellValue(product.salePriceCents! / 100),
      };

  String _pdfValue(InventoryExportField field, ProductVariant product) =>
      switch (field) {
        InventoryExportField.product => product.name,
        InventoryExportField.variant => product.variantDisplay,
        InventoryExportField.sku => product.sku,
        InventoryExportField.barcode => product.barcode ?? '',
        InventoryExportField.category => product.category ?? '',
        InventoryExportField.stock => '${product.stockQuantity}',
        InventoryExportField.purchase => formatMoney(product.purchasePriceCents),
        InventoryExportField.sale => formatMoney(product.salePriceCents),
      };

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

  pw.Widget _inventoryTable(
    List<ProductVariant> rows,
    List<InventoryExportField> fields,
    String currencyCode,
  ) {
    pw.Widget cell(String value, {bool header = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fields.length > 7 ? 6.0 : 7.0,
              fontWeight: header ? pw.FontWeight.bold : null,
            ),
          ),
        );
    final allRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          for (final field in fields) cell(_headerFor(field, currencyCode), header: true),
        ],
      ),
      ...rows.map(
        (product) => pw.TableRow(
          children: [
            for (final field in fields) cell(_pdfValue(field, product)),
          ],
        ),
      ),
    ];
    return pw.Table(
      border: pw.TableBorder.all(width: .3, color: PdfColors.grey500),
      children: allRows,
    );
  }

  Map<String, List<ProductVariant>> _groupByBrand(List<ProductVariant> inventory) {
    final groups = <String, List<ProductVariant>>{};
    for (final product in inventory) {
      final key = product.brand?.trim().isNotEmpty == true
          ? product.brand!.trim()
          : AppStrings.t('without_brand');
      groups.putIfAbsent(key, () => []).add(product);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final key in keys) key: groups[key]!};
  }
}
