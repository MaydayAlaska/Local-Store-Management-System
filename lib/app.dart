import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_runtime.dart';
import 'l10n/app_strings.dart';
import 'models/app_settings.dart';
import 'pages/shell_page.dart';
import 'services/app_services.dart';
import 'theme/ui_style_registry.dart';

class StoreApp extends StatefulWidget {
  const StoreApp({super.key, required this.services});
  final AppServices services;

  @override
  State<StoreApp> createState() => _StoreAppState();
}

class _StoreAppState extends State<StoreApp> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.services.settings.load();
  }

  ThemeMode get _themeMode => switch (_settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Locale _localeForLanguage(String value) {
    final normalized = AppStrings.normalizeLanguageCode(value);
    final parts = normalized.split('-');
    final requested = parts.length > 1
        ? Locale(parts.first, parts[1].toUpperCase())
        : Locale(parts.first);
    return GlobalMaterialLocalizations.delegate.isSupported(requested)
        ? requested
        : const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    AppRuntime.apply(_settings);
    final materialLocale = _localeForLanguage(_settings.languageCode);
    final uiStyle = UiStyleRegistry.resolve(_settings.uiStyle);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Store Management System',
      themeMode: _themeMode,
      theme: uiStyle.lightTheme(),
      darkTheme: uiStyle.darkTheme(),
      locale: materialLocale,
      supportedLocales: [materialLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ShellPage(
        services: widget.services,
        settings: _settings,
        onSettingsChanged: (settings) => setState(() => _settings = settings),
      ),
    );
  }
}
