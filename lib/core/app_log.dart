import 'dart:io';

import 'app_paths.dart';

class AppLog {
  static String get logPath {
    try {
      return '${AppPaths.logsDirectory}${Platform.pathSeparator}application.log';
    } catch (_) {
      final fallback = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}LocalStoreManagementSystem');
      fallback.createSync(recursive: true);
      return '${fallback.path}${Platform.pathSeparator}application.log';
    }
  }

  static void info(String context, String message) => _write(context, message, null, null);

  static void error(String context, Object error, [StackTrace? stackTrace]) =>
      _write(context, error.toString(), error, stackTrace);

  static void _write(String context, String message, Object? error, StackTrace? stackTrace) {
    try {
      final file = File(logPath);
      file.parent.createSync(recursive: true);
      String database;
      try {
        database = AppPaths.databasePath;
      } catch (_) {
        database = '(percorso database non ancora inizializzato)';
      }
      final buffer = StringBuffer()
        ..writeln('[${DateTime.now().toIso8601String()}] $context')
        ..writeln('Database: $database')
        ..writeln('Messaggio: $message');
      if (error != null) buffer.writeln('Errore: $error');
      if (stackTrace != null) buffer.writeln(stackTrace);
      buffer.writeln(List.filled(80, '-').join());
      file.writeAsStringSync(buffer.toString(), mode: FileMode.append, flush: true);
    } catch (_) {
      // Il logging non deve mai causare a sua volta la chiusura dell'applicazione.
    }
  }
}
