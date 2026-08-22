import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/fiscal_register.dart';
import '../services/fiscal_register_service.dart';
import 'glass_dropdown.dart';

class FiscalRegisterSettingsSection extends StatefulWidget {
  const FiscalRegisterSettingsSection({
    super.key,
    required this.service,
    required this.profiles,
    required this.enabled,
    required this.onChanged,
  });

  final FiscalRegisterService service;
  final List<FiscalRegisterProfile> profiles;
  final bool enabled;
  final ValueChanged<List<FiscalRegisterProfile>> onChanged;

  @override
  State<FiscalRegisterSettingsSection> createState() =>
      _FiscalRegisterSettingsSectionState();
}

class _FiscalRegisterSettingsSectionState
    extends State<FiscalRegisterSettingsSection> {
  final Map<String, String> _testMessages = {};
  final Set<String> _testSuccess = {};
  final Set<String> _testingIds = {};

  String _itEn(String it, String en) => AppStrings.pair(it, en);

  String _driverName(String id) {
    if (id == FiscalRegisterService.genericDriverId) {
      return _itEn(
        'Generico · driver fiscale da associare',
        'Generic · fiscal driver to be added',
      );
    }
    return widget.service.descriptorFor(id)?.name ?? id;
  }

  String _connectionLabel(FiscalRegisterProfile profile) => profile.isTcp
      ? 'TCP/IP · ${profile.host}:${profile.port}'
      : '${_itEn('Seriale', 'Serial')} · ${profile.serialPort.isEmpty ? '—' : profile.serialPort} · ${profile.baudRate} baud';

  String _mappingText(Map<String, int> mappings) {
    final entries = mappings.entries.toList()
      ..sort((a, b) {
        final left = double.tryParse(a.key) ?? 0;
        final right = double.tryParse(b.key) ?? 0;
        return left.compareTo(right);
      });
    return entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  Map<String, int> _parseMappings(String raw) {
    final result = <String, int>{};
    final normalized = raw.trim();
    if (normalized.isEmpty) return result;

    for (final token in normalized.split(RegExp(r'[;,]'))) {
      final part = token.trim();
      if (part.isEmpty) continue;
      final separator = part.contains('=') ? '=' : ':';
      final pieces = part.split(separator);
      if (pieces.length != 2) {
        throw FormatException(_itEn(
          'Mappatura IVA non valida: usa ad esempio 22=1; 10=2.',
          'Invalid VAT mapping: use for example 22=1; 10=2.',
        ));
      }
      final rate = double.tryParse(pieces[0].trim().replaceAll(',', '.'));
      final department = int.tryParse(pieces[1].trim());
      if (rate == null || rate < 0 || rate > 100) {
        throw FormatException(_itEn(
          'Aliquota IVA non valida in “$part”.',
          'Invalid VAT rate in “$part”.',
        ));
      }
      if (department == null || department < 1 || department > 999) {
        throw FormatException(_itEn(
          'Reparto fiscale non valido in “$part”.',
          'Invalid fiscal department in “$part”.',
        ));
      }
      final rounded = rate.roundToDouble();
      final key = (rate - rounded).abs() < 0.000001
          ? rounded.toInt().toString()
          : rate
              .toStringAsFixed(4)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
      result[key] = department;
    }
    return result;
  }

  void _replaceProfiles(List<FiscalRegisterProfile> next) {
    widget.onChanged(List<FiscalRegisterProfile>.unmodifiable(next));
  }

  void _setDefault(FiscalRegisterProfile profile) {
    final next = widget.profiles
        .map((item) => item.copyWith(isDefault: item.id == profile.id))
        .toList(growable: false);
    _replaceProfiles(next);
  }

  void _setEnabled(FiscalRegisterProfile profile, bool enabled) {
    final next = widget.profiles
        .map((item) => item.id == profile.id
            ? item.copyWith(enabled: enabled)
            : item)
        .toList(growable: false);
    _replaceProfiles(next);
  }

  Future<void> _editProfile([FiscalRegisterProfile? existing]) async {
    final descriptors = widget.service.driverDescriptors;
    final name = TextEditingController(text: existing?.name ?? '');
    final manufacturer =
        TextEditingController(text: existing?.manufacturer ?? '');
    final model = TextEditingController(text: existing?.model ?? '');
    final host = TextEditingController(text: existing?.host ?? '');
    final port = TextEditingController(text: '${existing?.port ?? 9100}');
    final serialPort = TextEditingController(text: existing?.serialPort ?? '');
    final baudRate =
        TextEditingController(text: '${existing?.baudRate ?? 9600}');
    final mappings = TextEditingController(
      text: _mappingText(existing?.vatDepartments ?? const {}),
    );
    var driverId = existing?.driverId ?? FiscalRegisterService.genericDriverId;
    if (!descriptors.any((item) => item.id == driverId)) {
      driverId = FiscalRegisterService.genericDriverId;
    }
    var connectionType = existing?.connectionType ?? 'tcp';
    var enabled = existing?.enabled ?? true;
    var isDefault = existing?.isDefault ?? widget.profiles.isEmpty;
    String? validationError;

    final result = await showDialog<FiscalRegisterProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? _itEn('Aggiungi registratore di cassa', 'Add cash register')
              : _itEn('Modifica registratore di cassa', 'Edit cash register')),
          content: SizedBox(
            width: 620,
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
                      hintText: _itEn('Es. RT cassa principale', 'E.g. Main register'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: manufacturer,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _itEn('Produttore', 'Manufacturer'),
                          hintText: 'Custom, Epson, RCH…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: model,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _itEn('Modello', 'Model'),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GlassDropdown<String>(
                    value: driverId,
                    labelText: _itEn('Driver fiscale', 'Fiscal driver'),
                    items: [
                      for (final descriptor in descriptors)
                        GlassDropdownItem(
                          value: descriptor.id,
                          label: _driverName(descriptor.id),
                          icon: Icons.receipt_long_outlined,
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        driverId = value;
                        validationError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _itEn(
                      'Il profilo generico salva modello, connessione e reparti ma non invia documenti fiscali. L’emissione viene abilitata aggiungendo il driver specifico del protocollo del produttore.',
                      'The generic profile stores model, connection and departments but does not send fiscal documents. Issuing is enabled by adding the manufacturer protocol driver.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  GlassDropdown<String>(
                    value: connectionType,
                    labelText: _itEn('Connessione', 'Connection'),
                    items: [
                      GlassDropdownItem(
                        value: 'tcp',
                        label: 'TCP/IP',
                        icon: Icons.lan_outlined,
                      ),
                      GlassDropdownItem(
                        value: 'serial',
                        label: _itEn('Seriale / COM', 'Serial / COM'),
                        icon: Icons.usb_rounded,
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        connectionType = value;
                        validationError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (connectionType == 'tcp')
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: host,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'IP / hostname',
                            hintText: '192.168.1.100',
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
                    ])
                  else
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: serialPort,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: _itEn('Porta seriale', 'Serial port'),
                            hintText: _itEn('Es. COM3', 'E.g. COM3'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: baudRate,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Baud',
                          ),
                        ),
                      ),
                    ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mappings,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn(
                        'Mappatura IVA → reparto fiscale',
                        'VAT → fiscal department mapping',
                      ),
                      hintText: '22=1; 10=2; 4=3',
                      helperText: _itEn(
                        'Il gestionale passa il reparto al driver; l’RT mantiene la propria configurazione fiscale.',
                        'The app passes the department to the driver; the register keeps its own fiscal configuration.',
                      ),
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (value) =>
                        setDialogState(() => enabled = value),
                    title: Text(_itEn('Profilo attivo', 'Profile enabled')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDefault,
                    onChanged: (value) =>
                        setDialogState(() => isDefault = value),
                    title: Text(_itEn(
                      'Registratore predefinito',
                      'Default cash register',
                    )),
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
                final normalizedSerial = serialPort.text.trim();
                final parsedPort = int.tryParse(port.text.trim());
                final parsedBaud = int.tryParse(baudRate.text.trim());
                String? error;
                Map<String, int> parsedMappings = const {};

                if (normalizedName.isEmpty) {
                  error = _itEn(
                    'Inserisci un nome per il profilo.',
                    'Enter a profile name.',
                  );
                } else if (manufacturer.text.trim().isEmpty ||
                    model.text.trim().isEmpty) {
                  error = _itEn(
                    'Indica produttore e modello del registratore.',
                    'Enter the cash-register manufacturer and model.',
                  );
                } else if (connectionType == 'tcp' &&
                    (normalizedHost.isEmpty || normalizedHost.contains(' '))) {
                  error = _itEn(
                    'Inserisci un IP o hostname valido.',
                    'Enter a valid IP or hostname.',
                  );
                } else if (connectionType == 'tcp' &&
                    (parsedPort == null || parsedPort < 1 || parsedPort > 65535)) {
                  error = _itEn(
                    'La porta deve essere compresa tra 1 e 65535.',
                    'Port must be between 1 and 65535.',
                  );
                } else if (connectionType == 'serial' &&
                    normalizedSerial.isEmpty) {
                  error = _itEn(
                    'Inserisci la porta seriale/COM.',
                    'Enter the serial/COM port.',
                  );
                } else if (connectionType == 'serial' &&
                    (parsedBaud == null || parsedBaud < 300 || parsedBaud > 921600)) {
                  error = _itEn(
                    'Baud rate non valido.',
                    'Invalid baud rate.',
                  );
                }

                if (error == null) {
                  try {
                    parsedMappings = _parseMappings(mappings.text);
                  } on FormatException catch (exception) {
                    error = exception.message.toString();
                  }
                }

                if (error != null) {
                  setDialogState(() => validationError = error);
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  FiscalRegisterProfile(
                    id: existing?.id ??
                        'rt-${DateTime.now().microsecondsSinceEpoch}',
                    name: normalizedName,
                    manufacturer: manufacturer.text.trim(),
                    model: model.text.trim(),
                    driverId: driverId,
                    connectionType: connectionType,
                    host: connectionType == 'tcp' ? normalizedHost : '',
                    port: connectionType == 'tcp' ? parsedPort! : 9100,
                    serialPort:
                        connectionType == 'serial' ? normalizedSerial : '',
                    baudRate: connectionType == 'serial' ? parsedBaud! : 9600,
                    enabled: enabled,
                    isDefault: isDefault,
                    vatDepartments: parsedMappings,
                  ),
                );
              },
              child: Text(AppStrings.t('save')),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    manufacturer.dispose();
    model.dispose();
    host.dispose();
    port.dispose();
    serialPort.dispose();
    baudRate.dispose();
    mappings.dispose();

    if (result == null || !mounted) return;
    final next = List<FiscalRegisterProfile>.of(widget.profiles);
    final index = next.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      next[index] = result;
    } else {
      next.add(result);
    }
    if (result.isDefault) {
      for (var i = 0; i < next.length; i++) {
        if (next[i].id != result.id && next[i].isDefault) {
          next[i] = next[i].copyWith(isDefault: false);
        }
      }
    }
    _testMessages.remove(result.id);
    _testSuccess.remove(result.id);
    _replaceProfiles(next);
  }

  Future<void> _deleteProfile(FiscalRegisterProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_itEn(
          'Rimuovi registratore di cassa',
          'Remove cash register',
        )),
        content: Text(_itEn(
          'Rimuovere il profilo “${profile.name}”?',
          'Remove the “${profile.name}” profile?',
        )),
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
    _testMessages.remove(profile.id);
    _testSuccess.remove(profile.id);
    _testingIds.remove(profile.id);
    _replaceProfiles(
      widget.profiles.where((item) => item.id != profile.id).toList(),
    );
  }

  Future<void> _testProfile(FiscalRegisterProfile profile) async {
    setState(() {
      _testingIds.add(profile.id);
      _testSuccess.remove(profile.id);
      _testMessages[profile.id] = _itEn(
        'Verifica connessione a ${profile.connectionDisplay}…',
        'Testing connection to ${profile.connectionDisplay}…',
      );
    });
    try {
      await widget.service.testConnection(profile);
      if (!mounted) return;
      setState(() {
        _testSuccess.add(profile.id);
        _testMessages[profile.id] = _itEn(
          'Trasporto raggiungibile. Il test conferma la connessione, non l’emissione fiscale.',
          'Transport reachable. This confirms connectivity, not fiscal receipt issuing.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSuccess.remove(profile.id);
        _testMessages[profile.id] = _itEn(
          'Test connessione fallito: $error',
          'Connection test failed: $error',
        );
      });
    } finally {
      if (mounted) setState(() => _testingIds.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _itEn('Registratori di cassa RT', 'Fiscal cash registers'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _itEn(
                          'Configura più modelli e connessioni. La Cassa resta indipendente dall’hardware: ogni modello usa il proprio driver fiscale.',
                          'Configure multiple models and connections. Checkout stays hardware-independent: each model uses its own fiscal driver.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.enabled ? () => _editProfile() : null,
                  icon: const Icon(Icons.add),
                  label: Text(_itEn('Aggiungi', 'Add')),
                ),
              ]),
              const SizedBox(height: 10),
              if (widget.profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_itEn(
                    'Nessun registratore di cassa configurato.',
                    'No cash registers configured.',
                  )),
                )
              else
                ...widget.profiles.map((profile) {
                  final testing = _testingIds.contains(profile.id);
                  final success = _testSuccess.contains(profile.id);
                  final message = _testMessages[profile.id];
                  final model = profile.modelDisplay.isEmpty
                      ? _itEn('Modello non indicato', 'Model not specified')
                      : profile.modelDisplay;
                  final fiscalReady = widget.service.canIssueReceipt(profile);
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
                                  ? Icons.point_of_sale_outlined
                                  : Icons.money_off_csred_outlined,
                            ),
                            title: Row(children: [
                              Flexible(child: Text(profile.name)),
                              if (profile.isDefault) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: _itEn('Predefinito', 'Default'),
                                  child: const Icon(Icons.star, size: 18),
                                ),
                              ],
                            ]),
                            subtitle: Text(
                              '$model · ${_connectionLabel(profile)}\n'
                              '${_driverName(profile.driverId)} · '
                              '${fiscalReady ? _itEn('emissione disponibile', 'issuing available') : _itEn('emissione non ancora disponibile', 'issuing not available yet')}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Switch(
                                  value: profile.enabled,
                                  onChanged: widget.enabled
                                      ? (value) => _setEnabled(profile, value)
                                      : null,
                                ),
                                IconButton(
                                  tooltip: _itEn(
                                    'Imposta come predefinito',
                                    'Set as default',
                                  ),
                                  onPressed: widget.enabled && !profile.isDefault
                                      ? () => _setDefault(profile)
                                      : null,
                                  icon: Icon(profile.isDefault
                                      ? Icons.star
                                      : Icons.star_border),
                                ),
                                IconButton(
                                  tooltip: _itEn(
                                    'Test connessione',
                                    'Test connection',
                                  ),
                                  onPressed: widget.enabled && !testing
                                      ? () => _testProfile(profile)
                                      : null,
                                  icon: const Icon(Icons.network_check),
                                ),
                                IconButton(
                                  tooltip: _itEn('Modifica', 'Edit'),
                                  onPressed: widget.enabled
                                      ? () => _editProfile(profile)
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: AppStrings.t('remove'),
                                  onPressed: widget.enabled
                                      ? () => _deleteProfile(profile)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                          if (profile.vatDepartments.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(
                                '${_itEn('IVA → reparti', 'VAT → departments')}: ${_mappingText(profile.vatDepartments)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (message != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      success
                                          ? Icons.check_circle_outline
                                          : Icons.error_outline,
                                      size: 18,
                                      color: success
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.error,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: !testing && !success
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
      );
}
