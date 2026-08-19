import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/catalog.dart';
import '../services/app_services.dart';
import '../widgets/hid_barcode_listener.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    super.key,
    required this.services,
    required this.settings,
    required this.isActive,
  });
  final AppServices services;
  final AppSettings settings;
  final bool isActive;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  final _search = TextEditingController();
  final _copies = TextEditingController(text: '1');
  final _width = TextEditingController(text: '40');
  final _height = TextEditingController(text: '30');
  ProductVariant? _selected;
  List<Printer> _printers = const [];
  Printer? _printer;
  String? _status;
  bool _printing = false;
  bool _loadingPrinters = false;

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void initState() {
    super.initState();
    _refreshPrinters();
  }

  @override
  void didUpdateWidget(covariant LabelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.settings, oldWidget.settings)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshPrinters();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _copies.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  String _dimensionText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  void _applyProfileDefaults(Printer? printer) {
    final profile = widget.services.labels.profileForPrinter(printer);
    if (profile == null) return;
    _width.text = _dimensionText(profile.defaultWidthMm);
    _height.text = _dimensionText(profile.defaultHeightMm);
  }

  Future<void> _refreshPrinters() async {
    if (_loadingPrinters) return;
    setState(() => _loadingPrinters = true);
    try {
      final printers = await widget.services.labels.getPrinters();
      if (!mounted) return;

      final persisted = widget.services.settings.load();
      final preferredUrl = _printer?.url ?? persisted.lastLabelPrinterUrl;
      final preferredName = _printer?.name ?? persisted.lastLabelPrinterName;
      Printer? selected;

      if (preferredUrl?.trim().isNotEmpty == true) {
        for (final printer in printers) {
          if (printer.url == preferredUrl) {
            selected = printer;
            break;
          }
        }

        if (selected == null) {
          final profile = widget.services.labels.profileForUrl(preferredUrl);
          if (profile != null) {
            for (final printer in printers) {
              if (printer.url == profile.url) {
                selected = printer;
                break;
              }
            }
          }
        }
      }
      if (selected == null && preferredName?.trim().isNotEmpty == true) {
        for (final printer in printers) {
          if (printer.name.toLowerCase() == preferredName!.toLowerCase()) {
            selected = printer;
            break;
          }
        }
      }

      final chosen = selected ?? (printers.isEmpty ? null : printers.first);
      _applyProfileDefaults(chosen);
      setState(() {
        _printers = printers;
        _printer = chosen;
        _status = printers.isEmpty
            ? _itEn('Nessuna stampante rilevata.', 'No printers detected.')
            : selected != null
                ? _itEn(
                    'Ultima stampante ripristinata: ${selected.name}.',
                    'Last printer restored: ${selected.name}.',
                  )
                : _itEn(
                    'Stampante pronta: ${_printer!.name}.',
                    'Printer ready: ${_printer!.name}.',
                  );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = _itEn(
              'Impossibile leggere le stampanti: $error',
              'Unable to read printers: $error',
            ));
      }
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  void _selectPrinter(Printer printer) {
    _applyProfileDefaults(printer);
    setState(() {
      _printer = printer;
      _status = _itEn(
        'Stampante selezionata: ${printer.name}.',
        'Printer selected: ${printer.name}.',
      );
    });
    try {
      widget.services.settings.saveLastLabelPrinter(
        url: printer.url,
        name: printer.name,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _status = _itEn(
              'Stampante selezionata, ma non è stato possibile salvarla: $error',
              'Printer selected, but it could not be saved: $error',
            ));
      }
    }
  }

  void _scan(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    final product = widget.services.products.findByBarcode(code);
    _search.text = code;
    setState(() {
      _selected = product;
      _status = product == null
          ? _itEn(
              'Nessun prodotto trovato per «$code».',
              'No product found for “$code”.',
            )
          : _itEn(
              'Etichetta pronta per ${product.name} · ${product.variantDisplay}.',
              'Label ready for ${product.name} · ${product.variantDisplay}.',
            );
    });
  }

  Future<void> _print() async {
    final product = _selected;
    final printer = _printer;
    if (product == null) return;
    if (printer == null) {
      setState(() => _status = _itEn(
            'Seleziona una stampante.',
            'Select a printer.',
          ));
      return;
    }
    final copies = int.tryParse(_copies.text) ?? 0;
    final width = double.tryParse(_width.text.replaceAll(',', '.')) ?? 0;
    final height = double.tryParse(_height.text.replaceAll(',', '.')) ?? 0;
    if (copies <= 0 || width <= 0 || height <= 0) {
      setState(() => _status = _itEn(
            'Copie e dimensioni devono essere maggiori di zero.',
            'Copies and dimensions must be greater than zero.',
          ));
      return;
    }
    setState(() => _printing = true);
    try {
      final ok = await widget.services.labels.printLabels(
        printer: printer,
        product: product,
        copies: copies,
        widthMm: width,
        heightMm: height,
      );
      if (mounted) {
        setState(() => _status = ok
            ? _itEn(
                'Stampa inviata a ${printer.name}: $copies ${copies == 1 ? 'copia' : 'copie'}.',
                'Print sent to ${printer.name}: $copies ${copies == 1 ? 'copy' : 'copies'}.',
              )
            : _itEn('Stampa annullata.', 'Print cancelled.'));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = _itEn(
              'Errore di stampa: $error',
              'Print error: $error',
            ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.services.products.search(_search.text).take(100).toList();
    final code = _selected?.barcode ?? _selected?.sku;
    final widthMm = double.tryParse(_width.text.replaceAll(',', '.')) ?? 40;
    final heightMm = double.tryParse(_height.text.replaceAll(',', '.')) ?? 30;
    final configuredProfile = widget.services.labels.profileForPrinter(_printer);

    return HidBarcodeListener(
      enabled: widget.isActive,
      onBarcode: _scan,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            AppStrings.t('labels'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _scan,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Cerca prodotto / SKU / barcode',
                        'Search product / SKU / barcode',
                      ),
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      hintText: _itEn(
                        'Puoi scansionare anche senza cliccare questo campo',
                        'You can scan without clicking this field',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ListTile(
                            selected: _selected?.id == product.id,
                            title: Text(product.name),
                            subtitle: Text(
                              '${product.variantDisplay} · ${product.sku}',
                            ),
                            trailing: Text(
                              product.barcode ??
                                  _itEn('Code 128 da SKU', 'Code 128 from SKU'),
                            ),
                            onTap: () => setState(() => _selected = product),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 450,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              _itEn('Anteprima', 'Preview'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: _itEn(
                              'Aggiorna stampanti',
                              'Refresh printers',
                            ),
                            onPressed:
                                _loadingPrinters ? null : _refreshPrinters,
                            icon: _loadingPrinters
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _PrinterPicker(
                          printers: _printers,
                          selected: _printer,
                          enabled: !_printing &&
                              !_loadingPrinters &&
                              _printers.isNotEmpty,
                          onChanged: _selectPrinter,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: widthMm > 0 && heightMm > 0
                                  ? widthMm / heightMm
                                  : 4 / 3,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _selected == null
                                    ? Center(
                                        child: Text(
                                          _itEn(
                                            'Seleziona una variante.',
                                            'Select a variant.',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    : _LabelPreview(
                                        product: _selected!,
                                        code: code!,
                                        barcode: widget.services.labels
                                            .barcodeFor(code),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _copies,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: _itEn('Copie', 'Copies'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _width,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: _itEn('Larghezza mm', 'Width mm'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _height,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: _itEn('Altezza mm', 'Height mm'),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _selected == null ||
                                  _printer == null ||
                                  _printing
                              ? null
                              : _print,
                          icon: const Icon(Icons.print),
                          label: Text(
                            _printing
                                ? _itEn('Stampa…', 'Printing…')
                                : _itEn('Stampa etichette', 'Print labels'),
                          ),
                        ),
                        if (_status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_status!),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          configuredProfile?.isTcp == true
                              ? _itEn(
                                  'Stampa diretta TCP/${configuredProfile!.protocolLabel}: ${configuredProfile.host}:${configuredProfile.port}, ${configuredProfile.dpi} dpi. La misura impostata qui viene inviata direttamente alla stampante. Non è necessario alcun driver Windows.',
                                  'Direct TCP/${configuredProfile.protocolLabel} printing: ${configuredProfile.host}:${configuredProfile.port}, ${configuredProfile.dpi} dpi. The size set here is sent directly to the printer. No Windows printer driver is required.',
                                )
                              : configuredProfile?.isSystem == true
                                  ? _itEn(
                                      'Stampa USB/sistema tramite driver: il gestionale usa la stampante installata nel sistema operativo e applica ${_dimensionText(configuredProfile!.defaultWidthMm)}×${_dimensionText(configuredProfile.defaultHeightMm)} mm come misura predefinita del profilo.',
                                      'USB/system printing through the printer driver: the app uses the printer installed in the operating system and applies ${_dimensionText(configuredProfile!.defaultWidthMm)}×${_dimensionText(configuredProfile.defaultHeightMm)} mm as the profile default size.',
                                    )
                                  : _itEn(
                                      'Stampa tramite sistema: configura nel driver della stampante la stessa misura impostata qui.',
                                      'System printing: configure the printer driver with the same size set here.',
                                    ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PrinterPicker extends StatefulWidget {
  const _PrinterPicker({
    required this.printers,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<Printer> printers;
  final Printer? selected;
  final bool enabled;
  final ValueChanged<Printer> onChanged;

  @override
  State<_PrinterPicker> createState() => _PrinterPickerState();
}

class _PrinterPickerState extends State<_PrinterPicker> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    final targetBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;
    final targetSize = targetBox.size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: targetSize.width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xE0212836)
                            : const Color(0xE8FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x55FFFFFF)
                              : const Color(0xB8FFFFFF),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.38 : 0.16,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(6),
                        children: widget.printers.map((printer) {
                          final selected = widget.selected?.url == printer.url;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: selected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.25 : 0.14,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  widget.onChanged(printer);
                                  _close();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.print
                                            : Icons.print_outlined,
                                        size: 18,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          printer.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
        key: _targetKey,
        link: _layerLink,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.enabled ? _toggle : null,
          child: InputDecorator(
            isEmpty: widget.selected == null,
            decoration: InputDecoration(
              labelText: AppStrings.isEnglish ? 'Printer' : 'Stampante',
              suffixIcon: Icon(
                _entry == null
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
              ),
            ),
            child: Text(
              widget.selected?.name ??
                  (widget.printers.isEmpty
                      ? (AppStrings.isEnglish
                          ? 'No printers available'
                          : 'Nessuna stampante disponibile')
                      : (AppStrings.isEnglish
                          ? 'Select printer'
                          : 'Seleziona stampante')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({
    required this.product,
    required this.code,
    required this.barcode,
  });
  final ProductVariant product;
  final String code;
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (product.variant?.trim().isNotEmpty == true) product.variant!.trim(),
      if (product.size?.trim().isNotEmpty == true) product.size!.trim(),
    ].join(' | ');

    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      final margin = constraints.maxWidth * 0.055;
      return Stack(children: [
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.055,
          height: h * 0.145,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (details.isNotEmpty)
          Positioned(
            left: margin,
            right: margin,
            top: h * 0.20,
            height: h * 0.09,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 11),
              ),
            ),
          ),
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.30,
          height: h * 0.37,
          child: BarcodeWidget(
            barcode: barcode,
            data: code,
            drawText: false,
            color: Colors.black,
            backgroundColor: Colors.white,
          ),
        ),
        Positioned(
          left: margin,
          right: margin,
          top: h * 0.67,
          height: h * 0.13,
          child: Center(
            child: Text(
              code,
              maxLines: 1,
              style: const TextStyle(color: Colors.black, fontSize: 11),
            ),
          ),
        ),
        Positioned(
          left: margin,
          right: constraints.maxWidth * 0.50,
          top: h * 0.80,
          bottom: h * 0.045,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              product.sku,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        if (product.salePriceCents != null)
          Positioned(
            left: constraints.maxWidth * 0.48,
            right: margin,
            top: h * 0.80,
            bottom: h * 0.035,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                product.salePriceDisplay,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
