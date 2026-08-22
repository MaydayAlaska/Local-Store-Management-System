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

  static Future<void> initialize() async {
    await _seedBundledGlassmorphism();
    await reload();
  }

  static Future<void> reload() => reloadFromDirectory(AppPaths.stylesDirectory);

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
        // Glassmorphism is bundled as the reference pack, while the compiled
        // implementation remains the exact, always-available fallback.
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
}
