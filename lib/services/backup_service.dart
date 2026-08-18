import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import '../core/database_service.dart';

class BackupService {
  BackupService(this.database);
  final DatabaseService database;

  String createAutomaticBackup() {
    Directory(AppPaths.backupsDirectory).createSync(recursive: true);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final name = 'store-backup-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}.db';
    final destination = p.join(AppPaths.backupsDirectory, name);
    database.db.execute('PRAGMA optimize;');
    File(AppPaths.databasePath).copySync(destination);
    return destination;
  }

  Future<String?> saveBackupAs() async {
    final location = await getSaveLocation(
      suggestedName: 'store-backup.db',
      acceptedTypeGroups: const [XTypeGroup(label: 'Database SQLite', extensions: ['db'])],
    );
    if (location == null) return null;
    database.db.execute('PRAGMA optimize;');
    File(AppPaths.databasePath).copySync(location.path);
    return location.path;
  }
}
