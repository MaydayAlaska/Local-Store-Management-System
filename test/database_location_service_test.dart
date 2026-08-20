import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/database_location_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDirectory;
  late String defaultPath;
  late DatabaseLocationService service;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('lsms-db-location-');
    defaultPath = p.join(tempDirectory.path, 'store.db');
    service = DatabaseLocationService(
      dataDirectory: tempDirectory.path,
      defaultDatabasePath: defaultPath,
    );
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('uses the existing application database path by default', () {
    expect(service.load(), defaultPath);
    expect(File(service.configurationPath).existsSync(), isFalse);
  });

  test('stores and reloads a custom database path', () {
    final customPath = p.join(tempDirectory.path, 'remote', 'shop.db');

    expect(service.save(customPath), p.normalize(customPath));
    expect(File(service.configurationPath).existsSync(), isTrue);
    expect(service.load(), p.normalize(customPath));
  });

  test('relative database paths are resolved inside the data directory', () {
    final expected = p.join(tempDirectory.path, 'shared', 'store.db');

    expect(service.save(p.join('shared', 'store.db')), p.normalize(expected));
    expect(service.load(), p.normalize(expected));
  });

  test('saving the default path removes the override', () {
    final customPath = p.join(tempDirectory.path, 'shared', 'shop.db');
    service.save(customPath);
    expect(File(service.configurationPath).existsSync(), isTrue);

    expect(service.save(defaultPath), defaultPath);
    expect(File(service.configurationPath).existsSync(), isFalse);
    expect(service.load(), defaultPath);
  });

  test('rejects HTTP and HTTPS URLs as direct SQLite database paths', () {
    expect(
      () => service.save('https://example.com/store.db'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.save('http://192.168.1.10/store.db'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a directory as database target', () {
    final directory = Directory(p.join(tempDirectory.path, 'folder'))
      ..createSync();

    expect(
      () => service.save(directory.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
