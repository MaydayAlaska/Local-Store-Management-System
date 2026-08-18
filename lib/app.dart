import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Local Store Management System',
        themeMode: ThemeMode.system,
        theme: GlassTheme.light(),
        darkTheme: GlassTheme.dark(),
        home: ShellPage(
          services: widget.services,
          settings: _settings,
          onSettingsChanged: (settings) => setState(() => _settings = settings),
        ),
      );
}
