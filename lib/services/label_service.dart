import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';
import '../models/app_settings.dart';
import '../models/catalog.dart';
import 'settings_service.dart';

class LabelService {
  LabelService(this._settings);

  final SettingsService _settings;

  Barcode barcodeFor(String code) => isValidEan13(code)
      ? Barcode.ean13()
      : Barcode.code128(
          useCode128A: false,
          useCode128B: true,
          useCode128C: false,
        );

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

  LabelPrinterProfile? profileForUrl(String? url) =>
      _settings.load().labelPrinterForUrl(url);

  LabelPrinterProfile? profileForPrinter(Printer? printer) {
    if (printer == null) return null;
    final settings = _settings.load();
    final byUrl = settings.labelPrinterForUrl(printer.url);
    if (byUrl != null) return byUrl;

    final printerName = printer.name.trim().toLowerCase();
    for (final profile in settings.labelPrinterProfiles) {
      if (!profile.isSystem) continue;
      if (profile.systemPrinterName?.trim().toLowerCase() == printerName ||
          profile.name.trim().toLowerCase() == printerName) {
        return profile;
      }
    }
    return null;
  }

  bool isDirectPrinter(Printer? printer) =>
      profileForPrinter(printer)?.isTcp == true;

  Future<List<Printer>> getSystemPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return const <Printer>[];
    }
  }

  Future<List<Printer>> getPrinters() async {
    final settings = _settings.load();
    final network = settings.labelPrinterProfiles
        .where((profile) => profile.enabled && profile.isTcp)
        .map(
          (profile) => Printer(
            url: profile.url,
            name: profile.name,
            model: '${profile.protocolLabel} · ${profile.dpi} dpi',
            location: '${profile.host}:${profile.port}',
            isDefault: false,
            isAvailable: true,
          ),
        )
        .toList(growable: false);

    final system = await getSystemPrinters();
    if (system.isEmpty) return network;

    final configuredSystem = <Printer>[];
    final claimedSystemUrls = <String>{};
    for (final profile in settings.labelPrinterProfiles) {
      if (!profile.enabled || !profile.isSystem) continue;

      Printer? match;
      final configuredUrl = profile.systemPrinterUrl?.trim();
      if (configuredUrl?.isNotEmpty == true) {
        for (final printer in system) {
          if (printer.url == configuredUrl) {
            match = printer;
            break;
          }
        }
      }
      if (match == null &&
          profile.systemPrinterName?.trim().isNotEmpty == true) {
        final target = profile.systemPrinterName!.trim().toLowerCase();
        for (final printer in system) {
          if (printer.name.trim().toLowerCase() == target) {
            match = printer;
            break;
          }
        }
      }
      if (match == null) continue;

      claimedSystemUrls.add(match.url);
      configuredSystem.add(
        Printer(
          url: match.url,
          name: profile.name,
          model: match.model,
          location: match.location,
          comment: match.comment,
          isDefault: match.isDefault,
          isAvailable: match.isAvailable,
        ),
      );
    }

    return <Printer>[
      ...network,
      ...configuredSystem,
      ...system.where((printer) => !claimedSystemUrls.contains(printer.url)),
    ];
  }

  Future<void> testConnection(LabelPrinterProfile profile) async {
    if (profile.isSystem) {
      final printers = await getSystemPrinters();
      Printer? match;
      final configuredUrl = profile.systemPrinterUrl?.trim();
      if (configuredUrl?.isNotEmpty == true) {
        for (final printer in printers) {
          if (printer.url == configuredUrl) {
            match = printer;
            break;
          }
        }
      }
      if (match == null &&
          profile.systemPrinterName?.trim().isNotEmpty == true) {
        final target = profile.systemPrinterName!.trim().toLowerCase();
        for (final printer in printers) {
          if (printer.name.trim().toLowerCase() == target) {
            match = printer;
            break;
          }
        }
      }
      if (match == null) {
        throw StateError(
          'Stampante USB/sistema non rilevata. Verifica il collegamento USB e che la stampante sia installata nel sistema operativo.',
        );
      }
      if (!match.isAvailable) {
        throw StateError(
          'La stampante «${match.name}» è installata ma al momento non risulta disponibile.',
        );
      }
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 3),
      );
      await socket.close();
    } on SocketException catch (error) {
      socket?.destroy();
      throw StateError(
        'Impossibile raggiungere ${profile.host}:${profile.port}. '
        'Dettagli: ${error.message}',
      );
    } catch (_) {
      socket?.destroy();
      rethrow;
    }
  }

  Future<Uint8List> buildLabels({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    _validateJob(
      product: product,
      copies: copies,
      widthMm: widthMm,
      heightMm: heightMm,
    );

    final code = _printableCode(product);
    final pageWidth = widthMm * PdfPageFormat.mm;
    final pageHeight = heightMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);
    final document = pw.Document();

    for (var i = 0; i < copies; i++) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => _buildLabel(
            product,
            code,
            pageWidth,
            pageHeight,
          ),
        ),
      );
    }
    return document.save();
  }

  pw.Widget _buildLabel(
    ProductVariant product,
    String code,
    double width,
    double height,
  ) {
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
          bottom: height * 0.80,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              product.name,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: titleSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        if (details.isNotEmpty)
          pw.Positioned(
            left: marginX,
            right: marginX,
            top: height * 0.20,
            bottom: height * 0.71,
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                details,
                maxLines: 1,
                style: pw.TextStyle(fontSize: smallSize),
              ),
            ),
          ),
        pw.Positioned(
          left: marginX,
          right: marginX,
          top: height * 0.30,
          bottom: height * 0.33,
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
          bottom: height * 0.20,
          child: pw.Center(
            child: pw.Text(
              code,
              maxLines: 1,
              style: pw.TextStyle(fontSize: barcodeTextSize),
            ),
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
              style: pw.TextStyle(
                fontSize: smallSize,
                fontWeight: pw.FontWeight.bold,
              ),
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
                style: pw.TextStyle(
                  fontSize: priceSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Costruisce il payload BPL-Z/ZPL per una stampante termica compatibile.
  String buildBplZ({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
    int dpi = 203,
  }) {
    _validateJob(
      product: product,
      copies: copies,
      widthMm: widthMm,
      heightMm: heightMm,
    );

    final dotsPerMm = dpi / 25.4;
    final scale = dpi / 203.0;
    final width = (widthMm * dotsPerMm).round();
    final height = (heightMm * dotsPerMm).round();
    final marginMin = (12 * scale).round().clamp(1, width).toInt();
    final marginMax = (36 * scale).round().clamp(marginMin, width).toInt();
    final margin = (width * 0.055)
        .round()
        .clamp(marginMin, marginMax)
        .toInt();
    final contentWidth = width - (margin * 2);
    final titleCharWidth = (27 * scale).round().clamp(1, 1000).toInt();
    final detailCharWidth = (18 * scale).round().clamp(1, 1000).toInt();
    final code = _bplText(_printableCode(product), maxLength: 40);
    final ean13 = isValidEan13(code);
    final title = _bplText(
      product.name,
      maxLength: _maxChars(contentWidth, titleCharWidth),
    );
    final details = _bplText(
      <String>[
        if (product.variant?.trim().isNotEmpty == true) product.variant!.trim(),
        if (product.size?.trim().isNotEmpty == true) product.size!.trim(),
      ].join(' | '),
      maxLength: _maxChars(contentWidth, detailCharWidth),
    );
    final sku = _bplText(
      product.sku,
      maxLength: _maxChars(
        (contentWidth * 0.55).round(),
        detailCharWidth,
      ),
    );
    final price = product.salePriceCents == null
        ? ''
        : _formatBplPrice(product.salePriceCents!);

    int scaled(int value) => (value * scale).round().clamp(1, 10000).toInt();

    final titleY = (height * 0.06).round();
    final detailsY = (height * 0.21).round();
    final barcodeY = details.isEmpty
        ? (height * 0.28).round()
        : (height * 0.32).round();
    final barcodeHeight = (height * 0.30)
        .round()
        .clamp(scaled(48), scaled(120))
        .toInt();
    final footerY = (height * 0.82).round();
    final titleFont = (height * 0.105)
        .round()
        .clamp(scaled(22), scaled(34))
        .toInt();
    final detailsFont = (height * 0.07)
        .round()
        .clamp(scaled(15), scaled(22))
        .toInt();
    final footerFont = (height * 0.075)
        .round()
        .clamp(scaled(16), scaled(24))
        .toInt();
    final priceFont = (height * 0.11)
        .round()
        .clamp(scaled(22), scaled(34))
        .toInt();
    final barcode = _barcodeLayout(
      code: code,
      labelWidth: width,
      ean13: ean13,
      edgePadding: scaled(24),
      maxModuleWidth: scaled(3),
    );

    // Gli EAN-13 hanno guard bar più lunghi a sinistra, al centro e a destra.
    final codeClearance = scaled(8) + (ean13 ? barcode.moduleWidth * 6 : 0);
    final codeY = barcodeY + barcodeHeight + codeClearance;

    final out = StringBuffer()
      ..writeln('^XA')
      ..writeln('^PW$width')
      ..writeln('^LL$height')
      ..writeln('^LH0,0')
      ..writeln(
        '^FO$margin,$titleY^A0N,$titleFont,$titleFont^FD$title^FS',
      );

    if (details.isNotEmpty) {
      out.writeln(
        '^FO$margin,$detailsY^A0N,$detailsFont,$detailsFont^FD$details^FS',
      );
    }

    out.writeln('^BY${barcode.moduleWidth},2,$barcodeHeight');
    if (ean13) {
      // ^BE riceve le 12 cifre dati e calcola automaticamente il check digit EAN-13.
      out.writeln(
        '^FO${barcode.x},$barcodeY^BEN,$barcodeHeight,N,N^FD${code.substring(0, 12)}^FS',
      );
    } else {
      out.writeln(
        '^FO${barcode.x},$barcodeY^BCN,$barcodeHeight,N,N,N,N^FD$code^FS',
      );
    }

    out
      ..writeln(
        '^FO$margin,$codeY^A0N,$detailsFont,$detailsFont^FB$contentWidth,1,0,C,0^FD$code^FS',
      )
      ..writeln(
        '^FO$margin,$footerY^A0N,$footerFont,$footerFont^FD$sku^FS',
      );

    if (price.isNotEmpty) {
      final priceX = (width * 0.57).round();
      out.writeln(
        '^FO$priceX,$footerY^A0N,$priceFont,$priceFont^FD$price^FS',
      );
    }

    out
      ..writeln('^PQ$copies,0,1,N')
      ..writeln('^XZ');
    return out.toString();
  }

  Future<bool> printLabels({
    required Printer printer,
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) async {
    final profile = profileForPrinter(printer);
    if (profile != null && !profile.enabled) {
      throw StateError('Il profilo stampante «${profile.name}» è disattivato.');
    }

    if (profile?.isTcp == true) {
      if (profile!.protocol != 'bpl-z') {
        throw StateError(
          'Protocollo ${profile.protocol} non ancora supportato per la stampa diretta.',
        );
      }
      final payload = buildBplZ(
        product: product,
        copies: copies,
        widthMm: widthMm,
        heightMm: heightMm,
        dpi: profile.dpi,
      );
      await _sendTcp(profile.url, payload);
      return true;
    }

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

  Future<void> _sendTcp(String printerUrl, String payload) async {
    final uri = Uri.parse(printerUrl);
    if (uri.scheme != 'tcp' || uri.host.isEmpty || uri.port <= 0) {
      throw StateError('Indirizzo stampante di rete non valido: $printerUrl');
    }

    Socket? socket;
    try {
      final connection = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 4),
      );
      socket = connection;
      connection.add(ascii.encode(payload));
      await connection.flush();
      await connection.close();
    } on SocketException catch (error) {
      socket?.destroy();
      throw StateError(
        'Impossibile raggiungere ${uri.host}:${uri.port}. '
        'Verifica che la stampante sia accesa e collegata alla rete. '
        'Dettagli: ${error.message}',
      );
    } catch (_) {
      socket?.destroy();
      rethrow;
    }
  }

  void _validateJob({
    required ProductVariant product,
    required int copies,
    required double widthMm,
    required double heightMm,
  }) {
    if (widthMm < 20 || widthMm > 120) {
      throw ArgumentError(
        'La larghezza etichetta deve essere compresa tra 20 e 120 mm.',
      );
    }
    if (heightMm < 15 || heightMm > 200) {
      throw ArgumentError(
        'L’altezza etichetta deve essere compresa tra 15 e 200 mm.',
      );
    }
    if (copies < 1 || copies > 100) {
      throw ArgumentError(
        'Il numero di copie deve essere compreso tra 1 e 100.',
      );
    }
    if (_printableCode(product).isEmpty) {
      throw ArgumentError(
        'Il prodotto non ha un barcode o SKU stampabile.',
      );
    }
  }

  String _printableCode(ProductVariant product) =>
      product.barcode?.trim().isNotEmpty == true
          ? product.barcode!.trim()
          : product.sku.trim();

  static ({int moduleWidth, int widthDots, int x}) _barcodeLayout({
    required String code,
    required int labelWidth,
    required bool ean13,
    int edgePadding = 24,
    int maxModuleWidth = 3,
  }) {
    // EAN-13 usa 95 moduli. Per Code 128 subset B: start + dati + check + stop.
    final modules = ean13 ? 95 : (code.length * 11) + 35;
    final usableWidth = (labelWidth - edgePadding)
        .clamp(1, labelWidth)
        .toInt();
    final moduleWidth = (usableWidth ~/ modules)
        .clamp(1, maxModuleWidth)
        .toInt();
    final widthDots = modules * moduleWidth;
    final x = ((labelWidth - widthDots) / 2)
        .round()
        .clamp(0, labelWidth)
        .toInt();
    return (moduleWidth: moduleWidth, widthDots: widthDots, x: x);
  }

  static int _maxChars(int availableDots, int fontWidth) {
    if (availableDots <= 0) return 1;
    final approximateCharacterWidth = fontWidth * 0.62;
    return (availableDots / approximateCharacterWidth)
        .floor()
        .clamp(1, 80)
        .toInt();
  }

  static String _bplText(String value, {int? maxLength}) {
    var text = value
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('À', 'A')
        .replaceAll('È', 'E')
        .replaceAll('É', 'E')
        .replaceAll('Ì', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('€', 'EUR')
        .replaceAll('£', 'GBP')
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[\^~\r\n\t]'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (maxLength != null && text.length > maxLength) {
      text = text.substring(0, maxLength).trimRight();
    }
    return text;
  }

  static String _formatBplPrice(int cents) => _bplText(formatMoney(cents));

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
