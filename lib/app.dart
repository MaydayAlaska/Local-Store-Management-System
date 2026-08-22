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

  ThemeData _applyLayout(ThemeData theme) {
    final layout = UiStyleRegistry.layoutFor(_settings.uiStyle);
    if (layout.monochrome) {
      final dark = theme.brightness == Brightness.dark;
      final scheme = theme.colorScheme.copyWith(
        primary: dark ? const Color(0xFFE0E0E0) : const Color(0xFF3F3F3F),
        onPrimary: dark ? const Color(0xFF111111) : Colors.white,
        primaryContainer:
            dark ? const Color(0xFF343434) : const Color(0xFFE2E2E2),
        onPrimaryContainer:
            dark ? const Color(0xFFF2F2F2) : const Color(0xFF202020),
        secondary: dark ? const Color(0xFFC7C7C7) : const Color(0xFF595959),
        onSecondary: dark ? const Color(0xFF111111) : Colors.white,
        secondaryContainer:
            dark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8),
        onSecondaryContainer:
            dark ? const Color(0xFFEDEDED) : const Color(0xFF202020),
        tertiary: dark ? const Color(0xFFAAAAAA) : const Color(0xFF6A6A6A),
        onTertiary: dark ? const Color(0xFF101010) : Colors.white,
        surface: dark ? const Color(0xFF181818) : const Color(0xFFF5F5F5),
        onSurface: dark ? const Color(0xFFF1F1F1) : const Color(0xFF191919),
        onSurfaceVariant:
            dark ? const Color(0xFFC8C8C8) : const Color(0xFF555555),
        outline: dark ? const Color(0xFF5A5A5A) : const Color(0xFFB8B8B8),
      );
      theme = theme.copyWith(
        colorScheme: scheme,
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          indicatorColor: scheme.primary.withValues(alpha: dark ? 0.20 : 0.12),
          selectedIconTheme: IconThemeData(color: scheme.primary),
          selectedLabelTextStyle: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
          unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
          unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return theme.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ...theme.extensions.values,
        layout,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppRuntime.apply(_settings);
    final materialLocale = _localeForLanguage(_settings.languageCode);
    return ValueListenableBuilder<int>(
      valueListenable: UiStyleRegistry.revision,
      builder: (context, _, _) {
        final uiStyle = UiStyleRegistry.resolve(_settings.uiStyle);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Local Store Management System',
          themeMode: _themeMode,
          theme: _applyLayout(uiStyle.lightTheme()),
          darkTheme: _applyLayout(uiStyle.darkTheme()),
          locale: materialLocale,
          supportedLocales: [materialLocale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ShellPage(
            services: widget.services,
            settings: _settings,
            onSettingsChanged: (settings) =>
                setState(() => _settings = settings),
          ),
        );
      },
    );
  }
}
