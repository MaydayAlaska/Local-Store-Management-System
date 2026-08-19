import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_runtime.dart';
import 'models/app_settings.dart';
import 'pages/shell_page.dart';
import 'services/app_services.dart';
import 'theme/glass_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    AppRuntime.apply(_settings);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Store Management System',
      themeMode: _themeMode,
      theme: GlassTheme.light(),
      darkTheme: GlassTheme.dark(),
      locale: Locale(_settings.languageCode),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ShellPage(
        services: widget.services,
        settings: _settings,
        onSettingsChanged: (settings) => setState(() => _settings = settings),
      ),
    );
  }
}
