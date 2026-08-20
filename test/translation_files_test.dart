import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/l10n/app_strings.dart';

Map<String, dynamic> _readCatalog(String code) {
  final file = File('assets/translations/$code.json');
  expect(file.existsSync(), isTrue, reason: 'Missing translation file: ${file.path}');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<Map<String, dynamic>>());
  return Map<String, dynamic>.from(decoded as Map);
}

Set<String> _keys(Map<String, dynamic> catalog) =>
    Map<String, dynamic>.from(catalog['strings'] as Map).keys.toSet();

void main() {
  test('Flutter bundle always includes the fallback translation', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'(?m)^\s*-\s*assets/translations/\s*$').hasMatch(pubspec),
      isTrue,
      reason:
          'pubspec.yaml must bundle assets/translations/ or installed builds may start without a language catalog.',
    );

    final fallbackCode = AppStrings.fallbackLanguageCode;
    final fallback = _readCatalog(fallbackCode);
    expect(fallback['languageCode'], fallbackCode);
    expect(_keys(fallback), isNotEmpty);
  });

  test('bundled translations expose valid native language metadata', () {
    final italian = _readCatalog('it');
    final english = _readCatalog('en');

    expect(italian['schemaVersion'], 1);
    expect(italian['languageCode'], 'it');
    expect(italian['languageName'], 'Italiano');

    expect(english['schemaVersion'], 1);
    expect(english['languageCode'], 'en');
    expect(english['languageName'], 'English');
  });

  test('Italian and English contain exactly the same translation keys', () {
    final italian = _readCatalog('it');
    final english = _readCatalog('en');

    final italianKeys = _keys(italian);
    final englishKeys = _keys(english);

    expect(italianKeys, isNotEmpty);
    expect(englishKeys, italianKeys);
  });

  test('bundled translation values are strings', () {
    for (final code in const ['it', 'en']) {
      final catalog = _readCatalog(code);
      final strings = Map<Object?, Object?>.from(catalog['strings'] as Map);
      for (final entry in strings.entries) {
        expect(entry.key, isA<String>());
        expect(entry.value, isA<String>(), reason: '$code: ${entry.key}');
      }
    }
  });
}
