import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'ui_style.dart';
import 'ui_style_tokens.dart';

class ExternalUiStylePack implements AppUiStyle {
  const ExternalUiStylePack._({
    required this.id,
    required this.label,
    required this.directoryPath,
    required _ExternalStyleVariant light,
    required _ExternalStyleVariant dark,
  })  : _light = light,
        _dark = dark;

  static const schemaVersion = 1;

  @override
  final String id;
  @override
  final String label;
  final String directoryPath;
  final _ExternalStyleVariant _light;
  final _ExternalStyleVariant _dark;

  factory ExternalUiStylePack.load(Directory directory) {
    final metadataFile = File(p.join(directory.path, 'style.json'));
    final lightFile = File(p.join(directory.path, 'light.json'));
    final darkFile = File(p.join(directory.path, 'dark.json'));
    if (!metadataFile.existsSync()) {
      throw const FormatException('style.json mancante.');
    }
    if (!lightFile.existsSync() || !darkFile.existsSync()) {
      throw const FormatException(
        'Ogni stile deve contenere sia light.json sia dark.json.',
      );
    }

    final metadata = _readObject(metadataFile);
    final rawSchema = metadata['schemaVersion'];
    if (rawSchema is! num || rawSchema.toInt() != schemaVersion) {
      throw FormatException(
        'schemaVersion non supportato: ${rawSchema ?? 'assente'}.',
      );
    }
    final rawId = metadata['id'];
    final rawName = metadata['name'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('id stile mancante o non valido.');
    }
    final id = rawId.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id)) {
      throw const FormatException(
        'id stile non valido: usa solo lettere minuscole, numeri, - e _.',
      );
    }
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('name stile mancante o non valido.');
    }

    return ExternalUiStylePack._(
      id: id,
      label: rawName.trim(),
      directoryPath: p.normalize(p.absolute(directory.path)),
      light: _ExternalStyleVariant.parse(
        lightFile,
        directory,
        Brightness.light,
      ),
      dark: _ExternalStyleVariant.parse(
        darkFile,
        directory,
        Brightness.dark,
      ),
    );
  }

  @override
  ThemeData lightTheme() => _buildTheme(Brightness.light, _light);

  @override
  ThemeData darkTheme() => _buildTheme(Brightness.dark, _dark);

  ThemeData _buildTheme(Brightness brightness, _ExternalStyleVariant variant) {
    final tokens = variant.tokens;
    final c = variant.components;
    final scheme = ColorScheme.fromSeed(
      seedColor: variant.seedColor,
      brightness: brightness,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(c.inputRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(c.menuRadius),
      side: BorderSide(color: tokens.menuBorder),
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.menuSurface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(tokens.menuShadow),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(menuShape),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: tokens.strongSurface,
      visualDensity: VisualDensity.compact,
      extensions: <ThemeExtension<dynamic>>[tokens],
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.cardRadius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.subtleSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: inputBorder(tokens.softBorder),
        enabledBorder: inputBorder(tokens.softBorder),
        focusedBorder: inputBorder(
          scheme.primary.withValues(alpha: 0.7),
          width: 1.5,
        ),
        errorBorder: inputBorder(scheme.error.withValues(alpha: 0.75)),
        focusedErrorBorder: inputBorder(scheme.error, width: 1.5),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor:
            scheme.primary.withValues(alpha: c.railIndicatorOpacity),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.softBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.strongSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.tooltipShadow,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.dialogRadius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.menuSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: tokens.menuShadow,
        shape: menuShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.strongSurface,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.snackBarRadius),
          side: BorderSide(color: tokens.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.34)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(c.iconButtonRadius),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(c.listTileRadius),
        ),
        selectedTileColor:
            scheme.primary.withValues(alpha: c.selectedTileOpacity),
      ),
    );
  }
}

class _ExternalStyleVariant {
  const _ExternalStyleVariant({
    required this.seedColor,
    required this.tokens,
    required this.components,
  });

  final Color seedColor;
  final UiStyleTokens tokens;
  final _ExternalComponentTokens components;

  factory _ExternalStyleVariant.parse(
    File file,
    Directory styleDirectory,
    Brightness brightness,
  ) {
    final json = _readObject(file);
    final tokenJson = _object(json, 'tokens');
    final componentJson = json['components'] is Map
        ? Map<String, dynamic>.from(json['components'] as Map)
        : const <String, dynamic>{};
    final backgroundImagePath = _backgroundImagePath(
      styleDirectory,
      json['backgroundImage'],
    );

    return _ExternalStyleVariant(
      seedColor: _color(json['seedColor'], 'seedColor'),
      tokens: UiStyleTokens(
        backgroundStart: _color(tokenJson['backgroundStart'], 'backgroundStart'),
        backgroundMiddle:
            _color(tokenJson['backgroundMiddle'], 'backgroundMiddle'),
        backgroundEnd: _color(tokenJson['backgroundEnd'], 'backgroundEnd'),
        glowPrimary: _color(tokenJson['glowPrimary'], 'glowPrimary'),
        glowSecondary: _color(tokenJson['glowSecondary'], 'glowSecondary'),
        glowTertiary: _color(tokenJson['glowTertiary'], 'glowTertiary'),
        cardSurface: _color(tokenJson['cardSurface'], 'cardSurface'),
        strongSurface: _color(tokenJson['strongSurface'], 'strongSurface'),
        subtleSurface: _color(tokenJson['subtleSurface'], 'subtleSurface'),
        surfaceBase: _color(tokenJson['surfaceBase'], 'surfaceBase'),
        surfaceOpacity:
            _number(tokenJson['surfaceOpacity'], 'surfaceOpacity', 0, 1),
        contentSurfaceOpacity: _number(
          tokenJson['contentSurfaceOpacity'],
          'contentSurfaceOpacity',
          0,
          1,
        ),
        notificationSurfaceOpacity: _number(
          tokenJson['notificationSurfaceOpacity'],
          'notificationSurfaceOpacity',
          0,
          1,
        ),
        border: _color(tokenJson['border'], 'border'),
        softBorder: _color(tokenJson['softBorder'], 'softBorder'),
        shadow: _color(tokenJson['shadow'], 'shadow'),
        menuSurface: _color(tokenJson['menuSurface'], 'menuSurface'),
        menuBorder: _color(tokenJson['menuBorder'], 'menuBorder'),
        menuShadow: _color(tokenJson['menuShadow'], 'menuShadow'),
        tooltipSurface:
            _color(tokenJson['tooltipSurface'], 'tooltipSurface'),
        tooltipBorder: _color(tokenJson['tooltipBorder'], 'tooltipBorder'),
        tooltipShadow: _color(tokenJson['tooltipShadow'], 'tooltipShadow'),
        imagePreviewSurface:
            _color(tokenJson['imagePreviewSurface'], 'imagePreviewSurface'),
        captionHover: _color(tokenJson['captionHover'], 'captionHover'),
        surfaceBlur: _number(tokenJson['surfaceBlur'], 'surfaceBlur', 0, 100),
        menuBlur: _number(tokenJson['menuBlur'], 'menuBlur', 0, 100),
        backgroundImagePath: backgroundImagePath,
        backgroundImageOpacity: json['backgroundImageOpacity'] == null
            ? 1
            : _number(
                json['backgroundImageOpacity'],
                'backgroundImageOpacity',
                0,
                1,
              ),
      ),
      components: _ExternalComponentTokens.fromJson(
        componentJson,
        brightness,
      ),
    );
  }
}

class _ExternalComponentTokens {
  const _ExternalComponentTokens({
    required this.cardRadius,
    required this.inputRadius,
    required this.menuRadius,
    required this.dialogRadius,
    required this.snackBarRadius,
    required this.buttonRadius,
    required this.iconButtonRadius,
    required this.listTileRadius,
    required this.railIndicatorOpacity,
    required this.selectedTileOpacity,
  });

  final double cardRadius;
  final double inputRadius;
  final double menuRadius;
  final double dialogRadius;
  final double snackBarRadius;
  final double buttonRadius;
  final double iconButtonRadius;
  final double listTileRadius;
  final double railIndicatorOpacity;
  final double selectedTileOpacity;

  factory _ExternalComponentTokens.fromJson(
    Map<String, dynamic> json,
    Brightness brightness,
  ) {
    double value(String key, double fallback, double min, double max) =>
        json[key] == null ? fallback : _number(json[key], key, min, max);
    final dark = brightness == Brightness.dark;
    return _ExternalComponentTokens(
      cardRadius: value('cardRadius', 20, 0, 64),
      inputRadius: value('inputRadius', 16, 0, 64),
      menuRadius: value('menuRadius', 16, 0, 64),
      dialogRadius: value('dialogRadius', 24, 0, 64),
      snackBarRadius: value('snackBarRadius', 16, 0, 64),
      buttonRadius: value('buttonRadius', 14, 0, 64),
      iconButtonRadius: value('iconButtonRadius', 12, 0, 64),
      listTileRadius: value('listTileRadius', 14, 0, 64),
      railIndicatorOpacity:
          value('railIndicatorOpacity', dark ? 0.24 : 0.16, 0, 1),
      selectedTileOpacity:
          value('selectedTileOpacity', dark ? 0.16 : 0.10, 0, 1),
    );
  }
}

Map<String, dynamic> _readObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw FormatException('${p.basename(file.path)} deve contenere un oggetto JSON.');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _object(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! Map) {
    throw FormatException('$key mancante o non valido.');
  }
  return Map<String, dynamic>.from(value);
}

Color _color(Object? raw, String key) {
  if (raw is num) return Color(raw.toInt());
  if (raw is! String) throw FormatException('$key deve essere un colore.');
  var value = raw.trim().toLowerCase();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.startsWith('0x')) value = value.substring(2);
  if (value.length == 6) value = 'ff$value';
  if (value.length != 8 || !RegExp(r'^[0-9a-f]{8}$').hasMatch(value)) {
    throw FormatException('$key: colore non valido ($raw).');
  }
  return Color(int.parse(value, radix: 16));
}

double _number(Object? raw, String key, double min, double max) {
  if (raw is! num) throw FormatException('$key deve essere numerico.');
  final value = raw.toDouble();
  if (!value.isFinite || value < min || value > max) {
    throw FormatException('$key deve essere compreso tra $min e $max.');
  }
  return value;
}

String? _backgroundImagePath(Directory directory, Object? raw) {
  if (raw == null) return null;
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('backgroundImage non valido.');
  }
  final relative = raw.trim();
  if (p.isAbsolute(relative)) {
    throw const FormatException('backgroundImage deve essere un percorso relativo.');
  }
  final root = p.normalize(p.absolute(directory.path));
  final full = p.normalize(p.absolute(p.join(root, relative)));
  if (!p.isWithin(root, full)) {
    throw const FormatException('backgroundImage deve restare nella cartella dello stile.');
  }
  final extension = p.extension(full).toLowerCase();
  if (!const {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}.contains(extension)) {
    throw const FormatException('Formato backgroundImage non supportato.');
  }
  if (!File(full).existsSync()) {
    throw FormatException('backgroundImage non trovato: $relative.');
  }
  return full;
}
