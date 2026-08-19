import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../services/app_services.dart';
import '../services/update_service.dart';
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
  late bool _showName;
  late bool _showLogo;
  late String _currencyCode;
  late String _themeMode;
  late String _languageCode;
  late List<LabelPrinterProfile> _labelPrinters;
  String? _iconSource;
  String? _logoSource;
  String? _status;
  UpdateCheckResult? _update;
  bool _checking = false;
  bool _saving = false;

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void initState() {
    super.initState();
    _shopName = TextEditingController(text: widget.current.shopName);
    _showName = widget.current.showShopNameInMenu;
    _showLogo = widget.current.showLogoInMenu;
    _currencyCode = widget.current.currencyCode;
    _themeMode = widget.current.themeMode;
    _languageCode = widget.current.languageCode;
    _labelPrinters = List<LabelPrinterProfile>.of(
      widget.current.labelPrinterProfiles,
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
      _labelPrinters = List<LabelPrinterProfile>.of(
        widget.current.labelPrinterProfiles,
      );
    }
  }

  @override
  void dispose() {
    _shopName.dispose();
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
      final settings = widget.services.settings.save(
        shopName: _shopName.text,
        showShopNameInMenu: _showName,
        showLogoInMenu: _showLogo,
        currencyCode: _currencyCode,
        themeMode: _themeMode,
        languageCode: _languageCode,
        labelPrinterProfiles: _labelPrinters,
        iconSourcePath: _iconSource,
        logoSourcePath: _logoSource,
      );
      await widget.services.applicationIcon.apply(settings);
      widget.onSaved(settings);
      if (!mounted) return;
      setState(() {
        _iconSource = null;
        _logoSource = null;
        _labelPrinters = List<LabelPrinterProfile>.of(
          settings.labelPrinterProfiles,
        );
        _status = AppStrings.t('settings_saved');
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = '${AppStrings.t('error')}: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPrinter([LabelPrinterProfile? existing]) async {
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
    var protocol = existing?.protocol ?? 'bpl-z';
    var enabled = existing?.enabled ?? true;
    String? validationError;

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
              width: 520,
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
                          child: DropdownButtonFormField<String>(
                            initialValue: protocol,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: _itEn('Protocollo', 'Protocol'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'bpl-z',
                                child: Text('BPL-Z / ZPL'),
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
                  } else if (normalizedHost.isEmpty ||
                      normalizedHost.contains(' ')) {
                    error = _itEn(
                      'Inserisci un IP o hostname valido.',
                      'Enter a valid IP or hostname.',
                    );
                  } else if (parsedPort == null ||
                      parsedPort < 1 ||
                      parsedPort > 65535) {
                    error = _itEn(
                      'La porta deve essere compresa tra 1 e 65535.',
                      'Port must be between 1 and 65535.',
                    );
                  } else if (parsedDpi == null ||
                      parsedDpi < 100 ||
                      parsedDpi > 600) {
                    error = _itEn(
                      'I DPI devono essere compresi tra 100 e 600.',
                      'DPI must be between 100 and 600.',
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

                  Navigator.pop(
                    dialogContext,
                    LabelPrinterProfile(
                      id: existing?.id ??
                          'printer-${DateTime.now().microsecondsSinceEpoch}',
                      name: normalizedName,
                      host: normalizedHost,
                      port: parsedPort!,
                      protocol: protocol,
                      dpi: parsedDpi!,
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

    final duplicate = _labelPrinters.any(
      (profile) =>
          profile.id != result.id &&
          profile.host.toLowerCase() == result.host.toLowerCase() &&
          profile.port == result.port,
    );
    if (duplicate) {
      setState(() => _status = _itEn(
            'Esiste già un profilo per ${result.host}:${result.port}.',
            'A profile for ${result.host}:${result.port} already exists.',
          ));
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
      _status = _itEn(
        'Profilo rimosso. Premi “Salva impostazioni” per applicare le modifiche.',
        'Profile removed. Press “Save settings” to apply the changes.',
      );
    });
  }

  Future<void> _testPrinter(LabelPrinterProfile profile) async {
    setState(() => _status = _itEn(
          'Test connessione a ${profile.host}:${profile.port}…',
          'Testing connection to ${profile.host}:${profile.port}…',
        ));
    try {
      await widget.services.labels.testConnection(profile);
      if (mounted) {
        setState(() => _status = _itEn(
              'Connessione riuscita a ${profile.name} (${profile.host}:${profile.port}).',
              'Connection successful to ${profile.name} (${profile.host}:${profile.port}).',
            ));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = _itEn(
              'Test connessione fallito: $error',
              'Connection test failed: $error',
            ));
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
                          AppStrings.t(_iconSource == null
                              ? 'change_app_icon'
                              : 'app_icon_selected'),
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
                          AppStrings.t(_logoSource == null
                              ? 'change_shop_logo'
                              : 'shop_logo_selected'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.t('data_path')}: ${AppPaths.dataDirectory}',
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
                            GlassDropdownItem(
                              value: 'it',
                              label: AppStrings.t('italian'),
                            ),
                            GlassDropdownItem(
                              value: 'en',
                              label: AppStrings.t('english'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _languageCode = value ?? 'it'),
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _itEn(
                                'Stampanti etichette di rete',
                                'Network label printers',
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _itEn(
                                'Configura più profili TCP. Le stampanti di sistema restano disponibili automaticamente nella pagina Etichette.',
                                'Configure multiple TCP profiles. System printers remain automatically available on the Labels page.',
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
                          'Nessun profilo TCP configurato.',
                          'No TCP profiles configured.',
                        ),
                      ),
                    )
                  else
                    ..._labelPrinters.map(
                      (profile) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              profile.enabled
                                  ? Icons.print_rounded
                                  : Icons.print_disabled_outlined,
                            ),
                            title: Text(profile.name),
                            subtitle: Text(
                              '${profile.host}:${profile.port} · ${profile.protocolLabel} · ${profile.dpi} dpi · ${_dimensionText(profile.defaultWidthMm)}×${_dimensionText(profile.defaultHeightMm)} mm',
                            ),
                            trailing: Wrap(
                              spacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Switch(
                                  value: profile.enabled,
                                  onChanged: _saving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            final index = _labelPrinters.indexWhere(
                                              (item) => item.id == profile.id,
                                            );
                                            if (index >= 0) {
                                              _labelPrinters[index] =
                                                  profile.copyWith(enabled: value);
                                            }
                                          });
                                        },
                                ),
                                IconButton(
                                  tooltip: _itEn(
                                    'Test connessione',
                                    'Test connection',
                                  ),
                                  onPressed: _saving
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
                        ),
                      ),
                    ),
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
                  if (UpdateService.currentCommit.isNotEmpty)
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
                          AppStrings.t(_checking ? 'checking' : 'check_updates'),
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
