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
    _currencyCode = widget.current.currencyCode;
    _themeMode = widget.current.themeMode;
    _languageCode = widget.current.languageCode;
    _update = widget.initialUpdate;
    _status = widget.initialUpdate?.message;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUpdate != null && widget.initialUpdate != oldWidget.initialUpdate) {
      _update = widget.initialUpdate;
      _status = widget.initialUpdate!.message;
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
        iconSourcePath: _iconSource,
        logoSourcePath: _logoSource,
      );
      await widget.services.applicationIcon.apply(settings);
      widget.onSaved(settings);
      if (!mounted) return;
      setState(() {
        _iconSource = null;
        _logoSource = null;
        _status = AppStrings.t('settings_saved');
      });
    } catch (error) {
      if (mounted) setState(() => _status = '${AppStrings.t('error')}: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
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
                            GlassDropdownItem(value: 'system', label: AppStrings.t('theme_system')),
                            GlassDropdownItem(value: 'light', label: AppStrings.t('theme_light')),
                            GlassDropdownItem(value: 'dark', label: AppStrings.t('theme_dark')),
                          ],
                          onChanged: (value) => setState(() => _themeMode = value ?? 'system'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GlassDropdown<String>(
                          value: _languageCode,
                          labelText: AppStrings.t('language'),
                          items: [
                            GlassDropdownItem(value: 'it', label: AppStrings.t('italian')),
                            GlassDropdownItem(value: 'en', label: AppStrings.t('english')),
                          ],
                          onChanged: (value) => setState(() => _languageCode = value ?? 'it'),
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
                          onChanged: (value) => setState(() => _currencyCode = value ?? 'EUR'),
                        ),
                      ),
                    ],
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
