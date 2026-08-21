import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import '../core/app_runtime.dart';

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.filePath,
  });

  final String code;
  final String nativeName;
  final String filePath;
}

class AppStrings {
  static const fallbackLanguageCode = 'it';
  static const _schemaVersion = 1;
  static const _bundledLanguageAssets = <String>[
    'assets/translations/it.json',
    'assets/translations/en.json',
  ];

  static final Map<String, _TranslationCatalog> _catalogs = {};
  static final Map<String, String> _invalidFiles = {};
  static bool _initialized = false;

  static bool get isEnglish => AppRuntime.languageCode == 'en';
  static bool get isInitialized => _initialized;

  static List<AppLanguage> get languages {
    final values = _catalogs.values
        .map(
          (catalog) => AppLanguage(
            code: catalog.code,
            nativeName: catalog.nativeName,
            filePath: catalog.filePath,
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.nativeName.toLowerCase().compareTo(
              b.nativeName.toLowerCase(),
            ),
      );
    return values;
  }

  static Map<String, String> get invalidFiles =>
      Map<String, String>.unmodifiable(_invalidFiles);

  static Future<void> initialize() async {
    await _seedBundledLanguages();
    await reload();
    _initialized = true;
  }

  static Future<void> reload() async {
    final directory = Directory(AppPaths.translationsDirectory);
    await directory.create(recursive: true);

    final loaded = <String, _TranslationCatalog>{};
    final invalid = <String, String>{};
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      try {
        final catalog = _TranslationCatalog.parse(
          file.readAsStringSync(),
          file.path,
        );
        loaded[catalog.code] = catalog;
      } catch (error) {
        invalid[p.basename(file.path)] = error.toString();
      }
    }

    var fallback = loaded[fallbackLanguageCode];
    if (fallback == null) {
      final content = await rootBundle.loadString(
        'assets/translations/$fallbackLanguageCode.json',
      );
      fallback = _TranslationCatalog.parse(
        content,
        'assets/translations/$fallbackLanguageCode.json',
      );
      loaded[fallbackLanguageCode] = fallback;
    }

    final requiredKeys = fallback.strings.keys.toSet();
    loaded.removeWhere((code, catalog) {
      if (code == fallbackLanguageCode) return false;
      final missing = requiredKeys.difference(catalog.strings.keys.toSet());
      if (missing.isEmpty) return false;
      invalid[p.basename(catalog.filePath)] =
          'Mancano ${missing.length} chiavi: ${missing.take(8).join(', ')}'
          '${missing.length > 8 ? ', …' : ''}';
      return true;
    });

    _catalogs
      ..clear()
      ..addAll(loaded);
    _invalidFiles
      ..clear()
      ..addAll(invalid);
  }

  static bool hasLanguage(String code) =>
      _catalogs.containsKey(normalizeLanguageCode(code));

  static String normalizeLanguageCode(String value) =>
      value.trim().replaceAll('_', '-').toLowerCase();

  static String nativeNameFor(String code) {
    final normalized = normalizeLanguageCode(code);
    return _catalogs[normalized]?.nativeName ?? normalized;
  }

  static String t(
    String key, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) {
    final selected = normalizeLanguageCode(AppRuntime.languageCode);
    final value = _catalogs[selected]?.strings[key] ??
        _catalogs[fallbackLanguageCode]?.strings[key] ??
        key;
    return _interpolate(value, parameters);
  }

  /// Compatibility bridge for UI strings that have not yet been converted to
  /// stable translation keys. New code should always use [t]. Third-party
  /// language files can override these entries through the optional `legacy`
  /// object, using the English fallback text or an English template containing
  /// `{placeholder}` tokens as the key.
  static String pair(
    String italian,
    String english, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) {
    final selected = normalizeLanguageCode(AppRuntime.languageCode);
    String value;
    if (selected == 'it') {
      value = italian;
    } else if (selected == 'en') {
      value = english;
    } else {
      value = _legacyTranslation(_catalogs[selected], english) ?? italian;
    }
    return _interpolate(value, parameters);
  }

  static String? _legacyTranslation(
    _TranslationCatalog? catalog,
    String renderedEnglish,
  ) {
    if (catalog == null) return null;
    final exact = catalog.legacy[renderedEnglish];
    if (exact != null) return exact;

    for (final entry in catalog.legacy.entries) {
      final template = entry.key;
      if (!template.contains('{')) continue;
      final tokenPattern = RegExp(r'\{([A-Za-z0-9_]+)\}');
      final tokens = tokenPattern.allMatches(template).toList(growable: false);
      if (tokens.isEmpty) continue;

      final names = <String>[];
      final pattern = StringBuffer('^');
      var cursor = 0;
      for (final token in tokens) {
        pattern.write(RegExp.escape(template.substring(cursor, token.start)));
        pattern.write('(.+?)');
        names.add(token.group(1)!);
        cursor = token.end;
      }
      pattern.write(RegExp.escape(template.substring(cursor)));
      pattern.write(r'$');

      final match = RegExp(pattern.toString()).firstMatch(renderedEnglish);
      if (match == null) continue;
      final values = <String, Object?>{};
      for (var index = 0; index < names.length; index += 1) {
        values[names[index]] = match.group(index + 1) ?? '';
      }
      return _interpolate(entry.value, values);
    }
    return null;
  }

  static String _interpolate(
    String value,
    Map<String, Object?> parameters,
  ) {
    var result = value;
    for (final entry in parameters.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }

  static Future<void> _seedBundledLanguages() async {
    final directory = Directory(AppPaths.translationsDirectory);
    await directory.create(recursive: true);
    for (final asset in _bundledLanguageAssets) {
      final content = await rootBundle.loadString(asset);
      final destination = File(p.join(directory.path, p.basename(asset)));
      await destination.writeAsString(content, flush: true);
    }
  }
}

class _TranslationCatalog {
  const _TranslationCatalog({
    required this.code,
    required this.nativeName,
    required this.filePath,
    required this.strings,
    required this.legacy,
  });

  final String code;
  final String nativeName;
  final String filePath;
  final Map<String, String> strings;
  final Map<String, String> legacy;

  static _TranslationCatalog parse(String source, String filePath) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Il file di traduzione deve contenere un oggetto JSON.');
    }

    final rawSchema = decoded['schemaVersion'];
    if (rawSchema is! num || rawSchema.toInt() != AppStrings._schemaVersion) {
      throw FormatException(
        'schemaVersion non supportato: ${rawSchema ?? 'assente'}.',
      );
    }

    final rawCode = decoded['languageCode'];
    final rawName = decoded['languageName'];
    if (rawCode is! String || rawCode.trim().isEmpty) {
      throw const FormatException('languageCode mancante o non valido.');
    }
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('languageName mancante o non valido.');
    }

    final code = AppStrings.normalizeLanguageCode(rawCode);
    if (!RegExp(r'^[a-z]{2,8}(?:-[a-z0-9]{2,8})*$').hasMatch(code)) {
      throw FormatException('languageCode non valido: $rawCode.');
    }

    final rawStrings = decoded['strings'];
    if (rawStrings is! Map) {
      throw const FormatException('La sezione strings è obbligatoria.');
    }
    final strings = <String, String>{};
    for (final entry in rawStrings.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && key.trim().isNotEmpty && value is String) {
        strings[key] = value;
      }
    }
    if (strings.isEmpty) {
      throw const FormatException('La sezione strings non contiene traduzioni valide.');
    }

    final legacy = <String, String>{};
    final rawLegacy = decoded['legacy'];
    if (rawLegacy is Map) {
      for (final entry in rawLegacy.entries) {
        if (entry.key is String && entry.value is String) {
          legacy[entry.key as String] = entry.value as String;
        }
      }
    }

    return _TranslationCatalog(
      code: code,
      nativeName: rawName.trim(),
      filePath: filePath,
      strings: Map<String, String>.unmodifiable(strings),
      legacy: Map<String, String>.unmodifiable(legacy),
    );
  }
}
