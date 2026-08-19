import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/app_paths.dart';
import '../core/database_service.dart';

class BackupService {
  BackupService(this.database);
  final DatabaseService database;

  Future<String> createAutomaticBackup() async {
    Directory(AppPaths.backupsDirectory).createSync(recursive: true);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final base = 'store-backup-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    var destination = p.join(AppPaths.backupsDirectory, '$base.db');
    var suffix = 1;
    while (File(destination).existsSync()) {
      destination = p.join(AppPaths.backupsDirectory, '$base-${suffix.toString().padLeft(2, '0')}.db');
      suffix++;
    }
    await _backupTo(destination);
    return destination;
  }

  Future<String?> saveBackupAs() async {
    final location = await getSaveLocation(
      suggestedName: 'store-backup.db',
      acceptedTypeGroups: const [XTypeGroup(label: 'Database SQLite', extensions: ['db'])],
    );
    if (location == null) return null;
    await _backupTo(location.path);
    return location.path;
  }

  Future<void> _backupTo(String destinationPath) async {
    final targetFile = File(destinationPath);
    targetFile.parent.createSync(recursive: true);
    if (targetFile.existsSync()) targetFile.deleteSync();

    final destination = sqlite3.open(destinationPath);
    var completed = false;
    try {
      await for (final _ in database.db.backup(destination)) {
        // La lettura dello stream fa avanzare l'API sqlite3_backup fino al completamento.
      }
      completed = true;
    } finally {
      destination.dispose();
      if (!completed) {
        try {
          if (targetFile.existsSync()) targetFile.deleteSync();
        } catch (_) {
          // Pulizia best effort del backup incompleto.
        }
      }
    }
  }
}
