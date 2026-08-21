import 'dart:io';

import 'package:path/path.dart' as p;

class SingleInstanceGuard {
  SingleInstanceGuard._(this._file);

  static final Set<SingleInstanceGuard> _activeGuards = <SingleInstanceGuard>{};

  final RandomAccessFile _file;
  bool _closed = false;

  static String pathFor(String dataDirectory) =>
      p.join(dataDirectory, '.local-store-management.instance');

  static Future<SingleInstanceGuard?> tryAcquire(String dataDirectory) async {
    final path = pathFor(dataDirectory);
    final file = File(path);
    await file.parent.create(recursive: true);
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
      final guard = SingleInstanceGuard._(handle);
      _activeGuards.add(guard);
      return guard;
    } on FileSystemException {
      await handle.close();
      return null;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _activeGuards.remove(this);
    try {
      await _file.unlock();
    } finally {
      await _file.close();
    }
  }
}
