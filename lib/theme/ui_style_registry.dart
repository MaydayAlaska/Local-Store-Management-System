import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import 'external_ui_style_pack.dart';
import 'styles/glassmorphism/glassmorphism_style.dart';
import 'ui_layout_tokens.dart';
import 'ui_style.dart';

class UiStyleRegistry {
  const UiStyleRegistry._();

  static const fallbackId = GlassmorphismStyle.styleId;
  static const _fallback = GlassmorphismStyle();
  static const _bundledGlassmorphismFiles = <String, String>{
    'assets/styles/glassmorphism/style.json': 'style.json',
    'assets/styles/glassmorphism/light.json': 'light.json',
    'assets/styles/glassmorphism/dark.json': 'dark.json',
  };
  static const _bundledStyleAssets = <String>[
    'assets/styles/bundled/flutiger-aero.json',
    'assets/styles/bundled/brutalism.json',
    'assets/styles/bundled/neumorphism.json',
    'assets/styles/bundled/material-design.json',
    'assets/styles/bundled/astractmorphism.json',
    'assets/styles/bundled/skeumorphism.json',
    'assets/styles/bundled/flat-design.json',
    'assets/styles/bundled/retrofuturism.json',
    'assets/styles/bundled/monochromatic-design.json',
    'assets/styles/bundled/minimal-vintage.json',
    'assets/styles/bundled/glassmorphism-2.json',
  ];

  static final Map<String, AppUiStyle> _external = {};
  static final Map<String, UiLayoutTokens> _layouts = {};
  static final Map<String, String> _invalidPacks = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<AppUiStyle> get all {
    final values = <AppUiStyle>[_fallback, ..._external.values]
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return List<AppUiStyle>.unmodifiable(values);
  }

  static Map<String, String> get invalidPacks =>
      Map<String, String>.unmodifiable(_invalidPacks);

  static Future<void> initialize() => reload();

  static Future<void> reload() async {
    await _seedBundledGlassmorphism();
    await _seedBundledStyles();
    await reloadFromDirectory(AppPaths.stylesDirectory);
  }

  static Future<void> reloadFromDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);
    final loaded = <String, AppUiStyle>{};
    final layouts = <String, UiLayoutTokens>{};
    final invalid = <String, String>{};
    final folders = directory
        .listSync()
        .whereType<Directory>()
        .toList(growable: false)
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    for (final folder in folders) {
      final folderName = p.basename(folder.path);
      try {
        final style = ExternalUiStylePack.load(folder);
        if (style.id == fallbackId) continue;
        if (loaded.containsKey(style.id)) {
          throw FormatException('id stile duplicato: ${style.id}.');
        }
        loaded[style.id] = style;
        layouts[style.id] = _readLayout(folder);
      } catch (error) {
        invalid[folderName] = error.toString();
      }
    }

    _external
      ..clear()
      ..addAll(loaded);
    _layouts
      ..clear()
      ..addAll(layouts);
    _invalidPacks
      ..clear()
      ..addAll(invalid);
    revision.value += 1;
  }

  static bool hasStyle(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized == fallbackId || _external.containsKey(normalized);
  }

  static AppUiStyle resolve(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == fallbackId) return _fallback;
    if (normalized != null) {
      final external = _external[normalized];
      if (external != null) return external;
    }
    return _fallback;
  }

  static UiLayoutTokens layoutFor(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == null || normalized == fallbackId) {
      return UiLayoutTokens.glassmorphism;
    }
    return _layouts[normalized] ?? UiLayoutTokens.glassmorphism;
  }

  static UiLayoutTokens _readLayout(Directory folder) {
    final metadataFile = File(p.join(folder.path, 'style.json'));
    final decoded = jsonDecode(metadataFile.readAsStringSync());
    if (decoded is! Map) return UiLayoutTokens.glassmorphism;
    final metadata = Map<String, dynamic>.from(decoded);
    final raw = metadata['layout'];
    if (raw is! Map) return UiLayoutTokens.glassmorphism;
    final json = Map<String, dynamic>.from(raw);

    String enumValue(String key, Set<String> allowed, String fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! String || !allowed.contains(value.trim().toLowerCase())) {
        throw FormatException('$key non valido nello style.json.');
      }
      return value.trim().toLowerCase();
    }

    double number(String key, double fallback, double min, double max) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! num ||
          !value.toDouble().isFinite ||
          value.toDouble() < min ||
          value.toDouble() > max) {
        throw FormatException('$key non valido nello style.json.');
      }
      return value.toDouble();
    }

    bool boolean(String key, bool fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is! bool) {
        throw FormatException('$key non valido nello style.json.');
      }
      return value;
    }

    return UiLayoutTokens(
      navigation: enumValue('navigation', const {'rail', 'sidebar', 'top', 'dock'}, 'rail'),
      surfaceStyle: enumValue('surfaceStyle', const {'glass', 'flat', 'outlined', 'raised', 'paper', 'neon'}, 'glass'),
      backgroundPattern: enumValue('backgroundPattern', const {'none', 'grid', 'dots', 'stripes'}, 'none'),
      shellPadding: number('shellPadding', 10, 0, 40),
      shellGap: number('shellGap', 10, 0, 40),
      navigationExtent: number('navigationExtent', 116, 52, 280),
      pageRadius: number('pageRadius', 24, 0, 64),
      panelRadius: number('panelRadius', 22, 0, 64),
      navItemRadius: number('navItemRadius', 14, 0, 64),
      borderWidth: number('borderWidth', 1, 0, 6),
      surfaceElevation: number('surfaceElevation', 12, 0, 40),
      patternOpacity: number('patternOpacity', 0, 0, 0.45),
      showPageFrame: boolean('showPageFrame', true),
      compactBrand: boolean('compactBrand', false),
      dense: boolean('dense', true),
      monochrome: boolean('monochrome', false),
    );
  }

  static Future<void> _seedBundledGlassmorphism() async {
    final root = Directory(AppPaths.stylesDirectory);
    await root.create(recursive: true);
    final destination = Directory(p.join(root.path, 'Glassmorphism'));
    if (await destination.exists()) return;
    await destination.create(recursive: true);
    for (final entry in _bundledGlassmorphismFiles.entries) {
      final content = await rootBundle.loadString(entry.key);
      await File(p.join(destination.path, entry.value)).writeAsString(content, flush: true);
    }
  }

  static Future<void> _seedBundledStyles() async {
    final root = Directory(AppPaths.stylesDirectory);
    await root.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');

    for (final assetPath in _bundledStyleAssets) {
      final decoded = jsonDecode(await rootBundle.loadString(assetPath));
      if (decoded is! Map) {
        throw FormatException('$assetPath non contiene un oggetto JSON.');
      }
      final bundle = Map<String, dynamic>.from(decoded);
      final folder = bundle['folder'];
      final style = bundle['style'];
      final light = bundle['light'];
      final dark = bundle['dark'];
      if (folder is! String || folder.trim().isEmpty || style is! Map || light is! Map || dark is! Map) {
        throw FormatException('$assetPath è un pacchetto stile integrato non valido.');
      }
      final safeFolder = folder.trim();
      if (p.basename(safeFolder) != safeFolder) {
        throw FormatException('$assetPath contiene un nome cartella non valido.');
      }

      final bundledStyle = Map<String, dynamic>.from(style);
      final bundledId = (bundledStyle['id'] as String?)?.trim().toLowerCase();
      final bundledVersion = (bundledStyle['version'] as String?)?.trim() ?? '0';
      final destination = Directory(p.join(root.path, safeFolder));

      if (await destination.exists()) {
        final metadataFile = File(p.join(destination.path, 'style.json'));
        var shouldUpdate = false;
        if (await metadataFile.exists()) {
          try {
            final installed = jsonDecode(await metadataFile.readAsString());
            if (installed is Map) {
              final installedMap = Map<String, dynamic>.from(installed);
              final installedId = (installedMap['id'] as String?)?.trim().toLowerCase();
              final installedVersion = (installedMap['version'] as String?)?.trim() ?? '0';
              shouldUpdate = installedId == bundledId &&
                  _comparePackVersions(bundledVersion, installedVersion) > 0;
            }
          } catch (_) {
            shouldUpdate = false;
          }
        }
        if (!shouldUpdate) continue;
      }

      await destination.create(recursive: true);
      await File(p.join(destination.path, 'style.json')).writeAsString(encoder.convert(style), flush: true);
      await File(p.join(destination.path, 'light.json')).writeAsString(encoder.convert(light), flush: true);
      await File(p.join(destination.path, 'dark.json')).writeAsString(encoder.convert(dark), flush: true);
    }
  }

  static int _comparePackVersions(String left, String right) {
    List<int> parse(String value) => value.split('.').map((part) => int.tryParse(part.trim()) ?? 0).toList(growable: false);
    final a = parse(left);
    final b = parse(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final comparison = (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
