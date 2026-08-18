import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static const applicationFolderName = 'Local Store Management System';
  static const legacyApplicationFolderName = 'LocalStoreManagementSystem';

  static late final String dataDirectory;
  static late final String databasePath;
  static late final String settingsPath;
  static late final String assetsDirectory;
  static late final String backupsDirectory;

  static Future<void> initialize() async {
    final override = Platform.environment['LSMS_DATA_DIRECTORY_OVERRIDE']?.trim();
    late final Directory directory;

    if (override != null && override.isNotEmpty) {
      directory = Directory(p.normalize(p.absolute(override)));
    } else {
      final documents = await getApplicationDocumentsDirectory();
      directory = Directory(p.join(documents.path, applicationFolderName));
    }

    final alreadyExisted = await directory.exists();
    await directory.create(recursive: true);

    dataDirectory = directory.path;
    databasePath = p.join(dataDirectory, 'store.db');
    settingsPath = p.join(dataDirectory, 'settings.json');
    assetsDirectory = p.join(dataDirectory, 'assets');
    backupsDirectory = p.join(dataDirectory, 'Backups');

    await Directory(assetsDirectory).create(recursive: true);
    await Directory(backupsDirectory).create(recursive: true);

    if (!await File(databasePath).exists()) {
      await _tryDelete('$databasePath-wal');
      await _tryDelete('$databasePath-shm');
    }

    if (!alreadyExisted) {
      await _migrateLegacyDatabaseIfNeeded();
    }
  }

  static Future<void> _migrateLegacyDatabaseIfNeeded() async {
    final destination = File(databasePath);
    if (await destination.exists()) return;

    final legacyRoot = _legacyDataRoot();
    if (legacyRoot == null) return;

    final sourcePath = p.join(legacyRoot, legacyApplicationFolderName, 'store.db');
    final source = File(sourcePath);
    if (!await source.exists()) return;

    await source.copy(databasePath);
    await _copySidecarIfPresent('$sourcePath-wal', '$databasePath-wal');
    await _copySidecarIfPresent('$sourcePath-shm', '$databasePath-shm');
  }

  static String? _legacyDataRoot() {
    if (Platform.isWindows) {
      return Platform.environment['LOCALAPPDATA'];
    }
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_DATA_HOME']?.trim();
      if (xdg != null && xdg.isNotEmpty) return xdg;
      final home = Platform.environment['HOME'];
      return home == null ? null : p.join(home, '.local', 'share');
    }
    return null;
  }

  static Future<void> _copySidecarIfPresent(String source, String destination) async {
    final sourceFile = File(source);
    if (await sourceFile.exists() && !await File(destination).exists()) {
      await sourceFile.copy(destination);
    }
  }

  static Future<void> _tryDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort: l'errore reale verrà mostrato all'apertura del database.
    }
  }
}
