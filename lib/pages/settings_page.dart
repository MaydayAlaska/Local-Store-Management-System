import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/fiscal_register.dart';
import '../services/app_services.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../widgets/fiscal_register_settings_section.dart';
import '../widgets/glass_dropdown.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.services,
    required this.current,
    required this.onSaved,
    this.initialUpdate,
  });

  final AppServices services;
  final AppSettings current;
  final ValueChanged<AppSettings> onSaved;
  final UpdateCheckResult? initialUpdate;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _shopName;
  late final TextEditingController _vatPercent;
  late final TextEditingController _databasePath;
  late bool _showName;
  late bool _showLogo;
  late String _currencyCode;
  late String _themeMode;
  late String _languageCode;
  late List<LabelPrinterProfile> _labelPrinters;
  late List<FiscalRegisterProfile> _fiscalRegisters;
  final Map<String, String> _printerTestMessages = {};
  final Set<String> _printerTestSuccess = {};
  final Set<String> _testingPrinterIds = {};
  String? _iconSource;
  String? _logoSource;
  String? _status;
  UpdateCheckResult? _update;
  bool _checking = false;
  bool _saving = false;

  String _itEn(String it, String en) => AppStrings.pair(it, en);

  String _formatPercent(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  void initState() {
    super.initState();
    _shopName = TextEditingController(text: widget.current.shopName);
    _vatPercent = TextEditingController(
      text: _formatPercent(widget.current.vatPercent),
    );
    _databasePath = TextEditingController(
      text: widget.services.databaseLocation.load(),
    );
    _showName = widget.current.showShopNameInMenu;
    _showLogo = widget.current.showLogoInMenu;
    _currencyCode = widget.current.currencyCode;
    _themeMode = widget.current.themeMode;
    _languageCode = AppStrings.hasLanguage(widget.current.languageCode)
        ? AppStrings.normalizeLanguageCode(widget.current.languageCode)
        : AppStrings.fallbackLanguageCode;
    _labelPrinters = List<LabelPrinterProfile>.of(
      widget.current.labelPrinterProfiles,
    );
    _fiscalRegisters = List<FiscalRegisterProfile>.of(
      widget.current.fiscalRegisterProfiles,
    );
    _update = widget.initialUpdate;
    _status = widget.initialUpdate?.message;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUpdate != null &&
        widget.initialUpdate != oldWidget.initialUpdate) {
      _update = widget.initialUpdate;
      _status = widget.initialUpdate!.message;
    }
    if (!identical(widget.current, oldWidget.current)) {
      _vatPercent.text = _formatPercent(widget.current.vatPercent);
      _labelPrinters = List<LabelPrinterProfile>.of(
        widget.current.labelPrinterProfiles,
      );
      _fiscalRegisters = List<FiscalRegisterProfile>.of(
        widget.current.fiscalRegisterProfiles,
      );
    }
  }

  @override
  void dispose() {
    _shopName.dispose();
    _vatPercent.dispose();
    _databasePath.dispose();
    super.dispose();
  }

  Future<String?> _pickImage({required bool allowIco}) async {
    final extensions = allowIco
        ? ['png', 'jpg', 'jpeg', 'bmp', 'ico']
        : ['png', 'jpg', 'jpeg', 'bmp'];
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: AppStrings.t('labels'), extensions: extensions),
      ],
    );
    return file?.path;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final parsedVat = double.tryParse(
            _vatPercent.text.trim().replaceAll(',', '.'),
          ) ??
          widget.current.vatPercent;
      final configuredDatabasePath =
          widget.services.databaseLocation.save(_databasePath.text);
      final databasePathChanged =
          configuredDatabasePath != widget.services.database.path;
      final settings = widget.services.settings.save(
        shopName: _shopName.text,
        showShopNameInMenu: _showName,
        showLogoInMenu: _showLogo,
        currencyCode: _currencyCode,
        vatPercent: parsedVat,
        themeMode: _themeMode,
        languageCode: _languageCode,
        labelPrinterProfiles: _labelPrinters,
        fiscalRegisterProfiles: _fiscalRegisters,
        iconSourcePath: _iconSource,
        logoSourcePath: _logoSource,
      );
      await widget.services.applicationIcon.apply(settings);
      widget.onSaved(settings);
      if (!mounted) return;
      setState(() {
        _iconSource = null;
        _logoSource = null;
        _databasePath.text = configuredDatabasePath;
        _vatPercent.text = _formatPercent(settings.vatPercent);
        _labelPrinters = List<LabelPrinterProfile>.of(
          settings.labelPrinterProfiles,
        );
        _fiscalRegisters = List<FiscalRegisterProfile>.of(
          settings.fiscalRegisterProfiles,
        );
        _status = AppStrings.t(
          databasePathChanged
              ? 'database_restart_required'
              : 'settings_saved',
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = '${AppStrings.t('error')}: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _systemPrinterLabel(dynamic printer) {
    final model = printer.model?.toString().trim() ?? '';
    final location = printer.location?.toString().trim() ?? '';
    final suffix = <String>[
      if (model.isNotEmpty) model,
      if (location.isNotEmpty) location,
    ].join(' · ');
    return suffix.isEmpty ? printer.name : '${printer.name} · $suffix';
  }

  Future<void> _editPrinter([LabelPrinterProfile? existing]) async {
    final systemPrinters = await widget.services.labels.getSystemPrinters();
    if (!mounted) return;

    final name = TextEditingController(text: existing?.name ?? '');
    final host = TextEditingController(text: existing?.host ?? '');
    final port = TextEditingController(
      text: (existing?.port ?? 9100).toString(),
    );
    final dpi = TextEditingController(
      text: (existing?.dpi ?? 203).toString(),
    );
    final width = TextEditingController(
      text: _dimensionText(existing?.defaultWidthMm ?? 40),
    );
    final height = TextEditingController(
      text: _dimensionText(existing?.defaultHeightMm ?? 30),
    );
    var connectionType = existing?.connectionType ?? 'tcp';
    var protocol = existing?.protocol ?? 'bpl-z';
    var selectedSystemUrl = existing?.systemPrinterUrl;
    var enabled = existing?.enabled ?? true;
    String? validationError;

    final systemItems = <GlassDropdownItem<String>>[
      for (final printer in systemPrinters)
        GlassDropdownItem(
          value: printer.url,
          label: _systemPrinterLabel(printer),
          icon: Icons.usb_rounded,
        ),
    ];
    if (existing?.isSystem == true &&
        existing?.systemPrinterUrl?.trim().isNotEmpty == true &&
        !systemItems.any((item) => item.value == existing!.systemPrinterUrl)) {
      systemItems.insert(
        0,
        GlassDropdownItem(
          value: existing!.systemPrinterUrl,
          label: _itEn(
            '${existing.systemPrinterName ?? existing.name} · non rilevata',
            '${existing.systemPrinterName ?? existing.name} · not detected',
          ),
          icon: Icons.usb_off_rounded,
        ),
      );
    }

    final result = await showDialog<LabelPrinterProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? _itEn(
                      'Aggiungi stampante etichette',
                      'Add label printer',
                    )
                  : _itEn(
                      'Modifica stampante etichette',
                      'Edit label printer',
                    ),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: _itEn('Nome profilo', 'Profile name'),
                        hintText: _itEn(
                          'Es. Stampante negozio',
                          'E.g. Shop printer',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassDropdown<String>(
                      value: connectionType,
                      labelText: _itEn('Connessione', 'Connection'),
                      items: [
                        GlassDropdownItem(
                          value: 'tcp',
                          label: _itEn('TCP/IP diretto', 'Direct TCP/IP'),
                          icon: Icons.lan_outlined,
                        ),
                        GlassDropdownItem(
                          value: 'system',
                          label: _itEn(
                            'USB / stampante di sistema',
                            'USB / system printer',
                          ),
                          icon: Icons.usb_rounded,
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            connectionType = value;
                            validationError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    if (connectionType == 'tcp') ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: host,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: _itEn(
                                  'IP / hostname',
                                  'IP / hostname',
                                ),
                                hintText: '192.168.1.63',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: port,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: _itEn('Porta', 'Port'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GlassDropdown<String>(
                              value: protocol,
                              labelText: _itEn('Protocollo', 'Protocol'),
                              items: const [
                                GlassDropdownItem(
                                  value: 'bpl-z',
                                  label: 'BPL-Z / ZPL',
                                  icon: Icons.code_rounded,
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => protocol = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: dpi,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'DPI',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      GlassDropdown<String>(
                        value: selectedSystemUrl,
                        labelText: _itEn(
                          'Stampante USB / sistema',
                          'USB / system printer',
                        ),
                        hintText: systemItems.isEmpty
                            ? _itEn(
                                'Nessuna stampante rilevata',
                                'No printer detected',
                              )
                            : _itEn(
                                'Seleziona una stampante',
                                'Select a printer',
                              ),
                        items: systemItems,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSystemUrl = value;
                            validationError = null;
                          });
                          if (value != null && name.text.trim().isEmpty) {
                            for (final printer in systemPrinters) {
                              if (printer.url == value) {
                                name.text = printer.name;
                                break;
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _itEn(
                          'Le stampanti USB vengono gestite tramite il sistema operativo. Devono quindi essere installate e visibili a Windows/macOS/Linux; il gestionale userà il relativo driver di stampa.',
                          'USB printers are managed through the operating system. They must be installed and visible to Windows/macOS/Linux; the app will use the corresponding printer driver.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: width,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: _itEn(
                                'Larghezza predefinita mm',
                                'Default width mm',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: height,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: _itEn(
                                'Altezza predefinita mm',
                                'Default height mm',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (value) =>
                          setDialogState(() => enabled = value),
                      title: Text(_itEn('Profilo attivo', 'Profile enabled')),
                    ),
                    if (validationError != null)
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  final normalizedName = name.text.trim();
                  final normalizedHost = host.text.trim();
                  final parsedPort = int.tryParse(port.text.trim());
                  final parsedDpi = int.tryParse(dpi.text.trim());
                  final parsedWidth = double.tryParse(
                    width.text.trim().replaceAll(',', '.'),
                  );
                  final parsedHeight = double.tryParse(
                    height.text.trim().replaceAll(',', '.'),
                  );

                  String? error;
                  if (normalizedName.isEmpty) {
                    error = _itEn(
                      'Inserisci un nome per il profilo.',
                      'Enter a profile name.',
                    );
                  } else if (connectionType == 'tcp' &&
                      (normalizedHost.isEmpty || normalizedHost.contains(' '))) {
                    error = _itEn(
                      'Inserisci un IP o hostname valido.',
                      'Enter a valid IP or hostname.',
                    );
                  } else if (connectionType == 'tcp' &&
                      (parsedPort == null ||
                          parsedPort < 1 ||
                          parsedPort > 65535)) {
                    error = _itEn(
                      'La porta deve essere compresa tra 1 e 65535.',
                      'Port must be between 1 and 65535.',
                    );
                  } else if (connectionType == 'tcp' &&
                      (parsedDpi == null ||
                          parsedDpi < 100 ||
                          parsedDpi > 600)) {
                    error = _itEn(
                      'I DPI devono essere compresi tra 100 e 600.',
                      'DPI must be between 100 and 600.',
                    );
                  } else if (connectionType == 'system' &&
                      selectedSystemUrl?.trim().isNotEmpty != true) {
                    error = _itEn(
                      'Seleziona una stampante USB o di sistema.',
                      'Select a USB or system printer.',
                    );
                  } else if (parsedWidth == null ||
                      parsedWidth < 20 ||
                      parsedWidth > 120) {
                    error = _itEn(
                      'La larghezza deve essere tra 20 e 120 mm.',
                      'Width must be between 20 and 120 mm.',
                    );
                  } else if (parsedHeight == null ||
                      parsedHeight < 15 ||
                      parsedHeight > 200) {
                    error = _itEn(
                      'L’altezza deve essere tra 15 e 200 mm.',
                      'Height must be between 15 and 200 mm.',
                    );
                  }

                  if (error != null) {
                    setDialogState(() => validationError = error);
                    return;
                  }

                  String? selectedSystemName = existing?.systemPrinterName;
                  if (connectionType == 'system') {
                    for (final printer in systemPrinters) {
                      if (printer.url == selectedSystemUrl) {
                        selectedSystemName = printer.name;
                        break;
                      }
                    }
                  }

                  Navigator.pop(
                    dialogContext,
                    LabelPrinterProfile(
                      id: existing?.id ??
                          'printer-${DateTime.now().microsecondsSinceEpoch}',
                      name: normalizedName,
                      connectionType: connectionType,
                      host: connectionType == 'tcp' ? normalizedHost : '',
                      port: connectionType == 'tcp' ? parsedPort! : 9100,
                      systemPrinterUrl:
                          connectionType == 'system' ? selectedSystemUrl : null,
                      systemPrinterName:
                          connectionType == 'system' ? selectedSystemName : null,
                      protocol: protocol,
                      dpi: connectionType == 'tcp' ? parsedDpi! : 203,
                      defaultWidthMm: parsedWidth!,
                      defaultHeightMm: parsedHeight!,
                      enabled: enabled,
                    ),
                  );
                },
                child: Text(AppStrings.t('save')),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
    host.dispose();
    port.dispose();
    dpi.dispose();
    width.dispose();
    height.dispose();

    if (result == null || !mounted) return;

    final duplicate = _labelPrinters.any((profile) {
      if (profile.id == result.id ||
          profile.connectionType != result.connectionType) {
        return false;
      }
      if (result.isTcp) {
        return profile.host.toLowerCase() == result.host.toLowerCase() &&
            profile.port == result.port;
      }
      return profile.systemPrinterUrl?.trim().isNotEmpty == true &&
          profile.systemPrinterUrl == result.systemPrinterUrl;
    });
    if (duplicate) {
      setState(
        () => _status = result.isTcp
            ? _itEn(
                'Esiste già un profilo per ${result.host}:${result.port}.',
                'A profile for ${result.host}:${result.port} already exists.',
              )
            : _itEn(
                'Questa stampante USB/sistema è già configurata.',
                'This USB/system printer is already configured.',
              ),
      );
      return;
    }

    setState(() {
      final index = _labelPrinters.indexWhere(
        (profile) => profile.id == result.id,
      );
      if (index >= 0) {
        _labelPrinters[index] = result;
      } else {
        _labelPrinters.add(result);
      }
      _printerTestMessages.remove(result.id);
      _printerTestSuccess.remove(result.id);
      _status = _itEn(
        'Profilo stampante modificato. Premi “Salva impostazioni” per applicare le modifiche.',
        'Printer profile changed. Press “Save settings” to apply the changes.',
      );
    });
  }

  String _dimensionText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Future<void> _deletePrinter(LabelPrinterProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_itEn('Rimuovi stampante', 'Remove printer')),
        content: Text(
          _itEn(
            'Rimuovere il profilo “${profile.name}”?',
            'Remove the “${profile.name}” profile?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _labelPrinters.removeWhere((item) => item.id == profile.id);
      _printerTestMessages.remove(profile.id);
      _printerTestSuccess.remove(profile.id);
      _testingPrinterIds.remove(profile.id);
      _status = _itEn(
        'Profilo rimosso. Premi “Salva impostazioni” per applicare le modifiche.',
        'Profile removed. Press “Save settings” to apply the changes.',
      );
    });
  }

  Future<void> _testPrinter(LabelPrinterProfile profile) async {
    setState(() {
      _testingPrinterIds.add(profile.id);
      _printerTestSuccess.remove(profile.id);
      _printerTestMessages[profile.id] = profile.isTcp
          ? _itEn(
              'Test connessione a ${profile.host}:${profile.port}…',
              'Testing connection to ${profile.host}:${profile.port}…',
            )
          : _itEn(
              'Verifica stampante USB/sistema…',
              'Checking USB/system printer…',
            );
    });
    try {
      await widget.services.labels.testConnection(profile);
      if (mounted) {
        setState(() {
          _printerTestSuccess.add(profile.id);
          _printerTestMessages[profile.id] = profile.isTcp
              ? _itEn(
                  'Connessione riuscita a ${profile.name} (${profile.host}:${profile.port}).',
                  'Connection successful to ${profile.name} (${profile.host}:${profile.port}).',
                )
              : _itEn(
                  'Stampante ${profile.name} rilevata e disponibile.',
                  'Printer ${profile.name} detected and available.',
                );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _printerTestSuccess.remove(profile.id);
          _printerTestMessages[profile.id] = _itEn(
            'Test connessione fallito: $error',
            'Connection test failed: $error',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _testingPrinterIds.remove(profile.id));
      }
    }
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      final result = await widget.services.updates.check();
      if (mounted) {
        setState(() {
          _update = result;
          _status = result.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = '${AppStrings.t('check_updates')}: $error');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _installUpdate() async {
    final update = _update;
    if (update == null) return;
    setState(() => _checking = true);
    try {
      await widget.services.updates.install(update);
    } catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _status = '${AppStrings.t('install_update')}: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  AppStrings.t('settings'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(AppStrings.t(_saving ? 'saving' : 'save_settings')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.t('shop_interface'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _shopName,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppStrings.t('shop_name'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showName,
                    onChanged: (v) => setState(() => _showName = v),
                    title: Text(AppStrings.t('show_shop_name')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showLogo,
                    onChanged: (v) => setState(() => _showLogo = v),
                    title: Text(AppStrings.t('show_logo')),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final path = await _pickImage(allowIco: true);
                                if (path != null && mounted) {
                                  setState(() => _iconSource = path);
                                }
                              },
                        icon: const Icon(Icons.app_shortcut),
                        label: Text(
                          AppStrings.t(
                            _iconSource == null ||
                                    _iconSource ==
                                        SettingsService.defaultIconSourceToken
                                ? 'change_app_icon'
                                : 'app_icon_selected',
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () => setState(
                                  () => _iconSource =
                                      SettingsService.defaultIconSourceToken,
                                ),
                        icon: const Icon(Icons.restore),
                        label: Text(
                          AppStrings.t(
                            _iconSource == SettingsService.defaultIconSourceToken
                                ? 'app_icon_default_selected'
                                : 'reset_app_icon',
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                final path = await _pickImage(allowIco: false);
                                if (path != null && mounted) {
                                  setState(() => _logoSource = path);
                                }
                              },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          AppStrings.t(
                            _logoSource == null
                                ? 'change_shop_logo'
                                : 'shop_logo_selected',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.t('database_settings'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.t('data_path')}: ${AppPaths.dataDirectory}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _databasePath,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppStrings.t('database_path'),
                      helperText: AppStrings.t('database_path_help'),
                      helperMaxLines: 3,
                      prefixIcon: const Icon(Icons.storage_rounded),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.t('database_active_path')}: ${widget.services.database.path}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.t('appearance_language'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassDropdown<String>(
                          value: _themeMode,
                          labelText: AppStrings.t('theme'),
                          items: [
                            GlassDropdownItem(
                              value: 'system',
                              label: AppStrings.t('theme_system'),
                            ),
                            GlassDropdownItem(
                              value: 'light',
                              label: AppStrings.t('theme_light'),
                            ),
                            GlassDropdownItem(
                              value: 'dark',
                              label: AppStrings.t('theme_dark'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _themeMode = value ?? 'system'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GlassDropdown<String>(
                          value: _languageCode,
                          labelText: AppStrings.t('language'),
                          items: [
                            for (final language in AppStrings.languages)
                              GlassDropdownItem(
                                value: language.code,
                                label: language.nativeName,
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _languageCode =
                                value ?? AppStrings.fallbackLanguageCode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GlassDropdown<String>(
                          value: _currencyCode,
                          labelText: AppStrings.t('currency'),
                          items: const [
                            GlassDropdownItem(value: 'EUR', label: 'EUR · €'),
                            GlassDropdownItem(value: 'USD', label: 'USD · \$'),
                            GlassDropdownItem(value: 'GBP', label: 'GBP · £'),
                            GlassDropdownItem(value: 'CHF', label: 'CHF'),
                          ],
                          onChanged: (value) =>
                              setState(() => _currencyCode = value ?? 'EUR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.t('translation_folder')}: ${AppPaths.translationsDirectory}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.t('translation_help'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _vatPercent,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _itEn('VAT / IVA (%)', 'VAT (%)'),
                          suffixText: '%',
                          helperText: _itEn(
                            'Aliquota inclusa nei prezzi di vendita.',
                            'Rate included in sale prices.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FiscalRegisterSettingsSection(
            service: widget.services.fiscalRegisters,
            profiles: _fiscalRegisters,
            enabled: !_saving,
            onChanged: (profiles) =>
                setState(() => _fiscalRegisters = List.of(profiles)),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _itEn(
                                'Stampanti etichette',
                                'Label printers',
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _itEn(
                                'Configura profili TCP/IP diretti oppure stampanti USB e di sistema. Le stampanti di sistema non configurate restano comunque disponibili nella pagina Etichette.',
                                'Configure direct TCP/IP profiles or USB and system printers. Unconfigured system printers remain available on the Labels page.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _editPrinter(),
                        icon: const Icon(Icons.add),
                        label: Text(_itEn('Aggiungi', 'Add')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_labelPrinters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _itEn(
                          'Nessun profilo stampante configurato.',
                          'No printer profiles configured.',
                        ),
                      ),
                    )
                  else
                    ..._labelPrinters.map((profile) {
                      final testMessage = _printerTestMessages[profile.id];
                      final testing = _testingPrinterIds.contains(profile.id);
                      final testSuccess =
                          _printerTestSuccess.contains(profile.id);
                      final subtitle = profile.isTcp
                          ? '${profile.host}:${profile.port} · ${profile.protocolLabel} · ${profile.dpi} dpi · ${_dimensionText(profile.defaultWidthMm)}×${_dimensionText(profile.defaultHeightMm)} mm'
                          : '${_itEn('USB / sistema', 'USB / system')} · ${profile.systemPrinterName ?? _itEn('stampante configurata', 'configured printer')} · ${_dimensionText(profile.defaultWidthMm)}×${_dimensionText(profile.defaultHeightMm)} mm';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                leading: Icon(
                                  profile.enabled
                                      ? (profile.isTcp
                                          ? Icons.lan_outlined
                                          : Icons.usb_rounded)
                                      : Icons.print_disabled_outlined,
                                ),
                                title: Text(profile.name),
                                subtitle: Text(subtitle),
                                trailing: Wrap(
                                  spacing: 2,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Switch(
                                      value: profile.enabled,
                                      onChanged: _saving
                                          ? null
                                          : (value) {
                                              setState(() {
                                                final index = _labelPrinters
                                                    .indexWhere(
                                                  (item) =>
                                                      item.id == profile.id,
                                                );
                                                if (index >= 0) {
                                                  _labelPrinters[index] =
                                                      profile.copyWith(
                                                    enabled: value,
                                                  );
                                                }
                                              });
                                            },
                                    ),
                                    IconButton(
                                      tooltip: _itEn(
                                        'Test connessione',
                                        'Test connection',
                                      ),
                                      onPressed: _saving || testing
                                          ? null
                                          : () => _testPrinter(profile),
                                      icon: const Icon(Icons.network_check),
                                    ),
                                    IconButton(
                                      tooltip: _itEn('Modifica', 'Edit'),
                                      onPressed: _saving
                                          ? null
                                          : () => _editPrinter(profile),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: AppStrings.t('remove'),
                                      onPressed: _saving
                                          ? null
                                          : () => _deletePrinter(profile),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                              if (testMessage != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (testing)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          testSuccess
                                              ? Icons.check_circle_outline
                                              : Icons.error_outline,
                                          size: 18,
                                          color: testSuccess
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          testMessage,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: !testing && !testSuccess
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : null,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_status!),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.t('updates'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${AppStrings.t('version')} v${UpdateService.currentVersion}${UpdateService.isBetaBuild ? ' BETA' : ''}',
                  ),
                  if (UpdateService.isBetaBuild &&
                      UpdateService.currentCommit.isNotEmpty)
                    Text(
                      '${AppStrings.t('commit')}: ${UpdateService.currentCommit.substring(0, 7)}',
                    ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.t(
                      UpdateService.isBetaBuild
                          ? 'beta_channel'
                          : UpdateService.isInstalledBuild
                              ? 'stable_channel'
                              : 'dev_channel',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _checking ? null : _checkUpdates,
                        icon: const Icon(Icons.system_update),
                        label: Text(
                          AppStrings.t(
                            _checking ? 'checking' : 'check_updates',
                          ),
                        ),
                      ),
                      if (_update?.updateAvailable == true &&
                          _update?.canInstall == true)
                        FilledButton.icon(
                          onPressed: _checking ? null : _installUpdate,
                          icon: const Icon(Icons.download),
                          label: Text(AppStrings.t('install_update')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
