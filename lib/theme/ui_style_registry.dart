import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import 'external_ui_style_pack.dart';
import 'styles/glassmorphism/glassmorphism_style.dart';
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
        // Glassmorphism remains compiled as the exact always-available fallback.
        if (style.id == fallbackId) continue;
        if (loaded.containsKey(style.id)) {
          throw FormatException('id stile duplicato: ${style.id}.');
        }
        loaded[style.id] = style;
      } catch (error) {
        invalid[folderName] = error.toString();
      }
    }

    _external
      ..clear()
      ..addAll(loaded);
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

  static Future<void> _seedBundledGlassmorphism() async {
    final root = Directory(AppPaths.stylesDirectory);
    await root.create(recursive: true);
    final destination = Directory(p.join(root.path, 'Glassmorphism'));
    if (await destination.exists()) return;
    await destination.create(recursive: true);
    for (final entry in _bundledGlassmorphismFiles.entries) {
      final content = await rootBundle.loadString(entry.key);
      await File(p.join(destination.path, entry.value)).writeAsString(
        content,
        flush: true,
      );
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
      if (folder is! String ||
          folder.trim().isEmpty ||
          style is! Map ||
          light is! Map ||
          dark is! Map) {
        throw FormatException('$assetPath è un pacchetto stile integrato non valido.');
      }
      final safeFolder = folder.trim();
      if (p.basename(safeFolder) != safeFolder) {
        throw FormatException('$assetPath contiene un nome cartella non valido.');
      }

      final destination = Directory(p.join(root.path, safeFolder));
      if (await destination.exists()) {
        // Non sovrascrivere mai uno stile locale eventualmente personalizzato.
        continue;
      }
      await destination.create(recursive: true);
      await File(p.join(destination.path, 'style.json')).writeAsString(
        encoder.convert(style),
        flush: true,
      );
      await File(p.join(destination.path, 'light.json')).writeAsString(
        encoder.convert(light),
        flush: true,
      );
      await File(p.join(destination.path, 'dark.json')).writeAsString(
        encoder.convert(dark),
        flush: true,
      );
    }
  }
}
