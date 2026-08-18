import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'pages/shell_page.dart';
import 'services/app_services.dart';

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
  Widget build(BuildContext context) {
    final light = ColorScheme.fromSeed(seedColor: const Color(0xFF355C7D), brightness: Brightness.light);
    final dark = ColorScheme.fromSeed(seedColor: const Color(0xFF7EA6C4), brightness: Brightness.dark);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: _settings.shopName,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorScheme: light, useMaterial3: true, visualDensity: VisualDensity.compact),
      darkTheme: ThemeData(colorScheme: dark, useMaterial3: true, visualDensity: VisualDensity.compact),
      home: ShellPage(
        services: widget.services,
        settings: _settings,
        onSettingsChanged: (settings) => setState(() => _settings = settings),
      ),
    );
  }
}
