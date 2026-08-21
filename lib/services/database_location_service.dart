import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_paths.dart';

class DatabaseLocationService {
  DatabaseLocationService({
    String? dataDirectory,
    String? defaultDatabasePath,
  })  : _dataDirectory = dataDirectory ?? AppPaths.dataDirectory,
        _defaultDatabasePath =
            defaultDatabasePath ?? AppPaths.defaultDatabasePath;

  static const _configurationFileName = 'database-location.json';
  static const _databasePathKey = 'DatabasePath';

  final String _dataDirectory;
  final String _defaultDatabasePath;

  String get configurationPath =>
      p.join(_dataDirectory, _configurationFileName);

  String get defaultPath => _defaultDatabasePath;

  String load() {
    final environmentOverride =
        Platform.environment['LSMS_DATABASE_PATH_OVERRIDE']?.trim();
    if (environmentOverride?.isNotEmpty == true) {
      return normalize(environmentOverride!);
    }

    final file = File(configurationPath);
    if (!file.existsSync()) return defaultPath;

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return defaultPath;
      final value = decoded[_databasePathKey];
      if (value is! String || value.trim().isEmpty) return defaultPath;
      return normalize(value);
    } catch (_) {
      return defaultPath;
    }
  }

  String normalize(String value) {
    var input = value.trim();
    if (input.isEmpty) return defaultPath;

    if (input.length >= 2 &&
        ((input.startsWith('"') && input.endsWith('"')) ||
            (input.startsWith("'") && input.endsWith("'")))) {
      input = input.substring(1, input.length - 1).trim();
    }
    if (input.isEmpty) return defaultPath;

    final looksLikeWindowsDrive = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(input);
    final looksLikeUnc = input.startsWith(r'\\');

    if (!looksLikeWindowsDrive && !looksLikeUnc) {
      final uri = Uri.tryParse(input);
      if (uri != null && uri.hasScheme) {
        if (uri.scheme.toLowerCase() == 'file') {
          return p.normalize(uri.toFilePath(windows: Platform.isWindows));
        }
        throw const FormatException(
          'SQLite richiede un percorso di file. Gli URL HTTP/HTTPS o TCP non '
          'possono essere usati direttamente come database. Usa una condivisione '
          'di rete, un percorso montato o una VPN.',
        );
      }
    }

    if (p.isAbsolute(input) || looksLikeWindowsDrive || looksLikeUnc) {
      return p.normalize(input);
    }
    return p.normalize(p.join(_dataDirectory, input));
  }

  String save(String value) {
    final normalized = normalize(value);
    final targetType = FileSystemEntity.typeSync(normalized, followLinks: true);
    if (targetType == FileSystemEntityType.directory) {
      throw FileSystemException(
        'Il percorso del database deve indicare un file, non una cartella.',
        normalized,
      );
    }

    final file = File(configurationPath);
    file.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');

    if (p.equals(normalized, defaultPath)) {
      if (file.existsSync()) file.deleteSync();
      return defaultPath;
    }

    file.writeAsStringSync(
      encoder.convert({_databasePathKey: normalized}),
      flush: true,
    );
    return normalized;
  }

  void reset() {
    final file = File(configurationPath);
    if (file.existsSync()) file.deleteSync();
  }
}
