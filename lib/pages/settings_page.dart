import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../models/app_settings.dart';
import '../services/app_services.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.services,
    required this.current,
    required this.onSaved,
  });
  final AppServices services;
  final AppSettings current;
  final ValueChanged<AppSettings> onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _shopName;
  late bool _showName;
  late bool _showLogo;
  String? _iconSource;
  String? _logoSource;
  String? _status;
  UpdateCheckResult? _update;
  bool _checking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopName = TextEditingController(text: widget.current.shopName);
    _showName = widget.current.showShopNameInMenu;
    _showLogo = widget.current.showLogoInMenu;
  }

  @override
  void dispose() {
    _shopName.dispose();
    super.dispose();
  }

  Future<String?> _pickImage({required bool allowIco}) async {
    final extensions = allowIco ? ['png', 'jpg', 'jpeg', 'bmp', 'ico'] : ['png', 'jpg', 'jpeg', 'bmp'];
    final file = await openFile(acceptedTypeGroups: [XTypeGroup(label: 'Immagini', extensions: extensions)]);
    return file?.path;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = widget.services.settings.save(
        shopName: _shopName.text,
        showShopNameInMenu: _showName,
        showLogoInMenu: _showLogo,
        iconSourcePath: _iconSource,
        logoSourcePath: _logoSource,
      );
      await widget.services.applicationIcon.apply(settings);
      widget.onSaved(settings);
      if (!mounted) return;
      setState(() {
        _iconSource = null;
        _logoSource = null;
        _status = 'Impostazioni salvate. Icona e titolo finestra aggiornati.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Errore: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkUpdates() async {
    setState(() => _checking = true);
    try {
      final result = await widget.services.updates.check();
      if (mounted) setState(() { _update = result; _status = result.message; });
    } catch (error) {
      if (mounted) setState(() => _status = 'Controllo aggiornamenti fallito: $error');
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
      if (mounted) setState(() { _checking = false; _status = 'Installazione aggiornamento fallita: $error'; });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Impostazioni', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Negozio e interfaccia', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(controller: _shopName, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome negozio')),
                const SizedBox(height: 8),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _showName, onChanged: (v) => setState(() => _showName = v), title: const Text('Mostra nome negozio nel menu')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: _showLogo, onChanged: (v) => setState(() => _showLogo = v), title: const Text('Mostra logo nel menu')),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: _saving ? null : () async { final path = await _pickImage(allowIco: true); if (path != null && mounted) setState(() => _iconSource = path); }, icon: const Icon(Icons.app_shortcut), label: Text(_iconSource == null ? 'Cambia icona applicazione' : 'Icona selezionata')),
                  OutlinedButton.icon(onPressed: _saving ? null : () async { final path = await _pickImage(allowIco: false); if (path != null && mounted) setState(() => _logoSource = path); }, icon: const Icon(Icons.image_outlined), label: Text(_logoSource == null ? 'Cambia logo negozio' : 'Logo selezionato')),
                  FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Salvataggio…' : 'Salva impostazioni')),
                ]),
                const SizedBox(height: 8),
                Text('Dati: ${AppPaths.dataDirectory}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Aggiornamenti', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Versione v${UpdateService.currentVersion}${UpdateService.isBetaBuild ? ' BETA' : ''}'),
                if (UpdateService.currentCommit.isNotEmpty) Text('Commit: ${UpdateService.currentCommit.substring(0, 7)}'),
                const SizedBox(height: 6),
                Text(UpdateService.isBetaBuild
                    ? 'Build BETA dal branch ${UpdateService.currentBranch}. Gli aggiornamenti OTA stabili sono disattivati.'
                    : UpdateService.isInstalledBuild
                        ? 'Canale aggiornamenti: GitHub, branch main.'
                        : 'Build di sviluppo: il controllo è disponibile, l’installazione OTA richiede una release pubblicata.'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: _checking || UpdateService.isBetaBuild ? null : _checkUpdates,
                    icon: const Icon(Icons.system_update),
                    label: Text(_checking ? 'Controllo…' : 'Controlla aggiornamenti'),
                  ),
                  if (_update?.canInstall == true) FilledButton.icon(onPressed: _checking ? null : _installUpdate, icon: const Icon(Icons.download), label: const Text('Installa aggiornamento')),
                ]),
              ]),
            ),
          ),
          if (_status != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status!)),
        ],
      );
}
