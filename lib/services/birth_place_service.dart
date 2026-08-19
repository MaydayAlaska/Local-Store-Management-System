import 'dart:convert';

import 'package:flutter/services.dart';

class BirthPlaceService {
  const BirthPlaceService._();

  static const String assetPath = 'assets/data/birth_places.json';

  static Map<String, List<_BirthPlaceRecord>> _records = const {};
  static bool _initialized = false;

  static Future<void> initialize({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    _load(raw);
    _initialized = true;
  }

  static void loadForTesting(String raw) {
    _load(raw);
    _initialized = true;
  }

  static String? resolve(String birthPlaceCode, DateTime birthDate) {
    if (!_initialized) {
      throw StateError('BirthPlaceService non inizializzato.');
    }

    final code = birthPlaceCode.trim().toUpperCase();
    final candidates = _records[code];
    if (candidates == null || candidates.isEmpty) return null;

    final date = _dateOnly(birthDate);
    for (final record in candidates) {
      if (record.contains(date)) return _displayName(record.name);
    }

    // Dataset storici possono avere piccoli buchi nelle date: in quel caso
    // preferiamo comunque una denominazione nota al posto del codice grezzo.
    return _displayName(candidates.last.name);
  }

  static void _load(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Archivio luoghi di nascita non valido.');
    }

    final records = <String, List<_BirthPlaceRecord>>{};
    for (final entry in decoded.entries) {
      final code = entry.key.trim().toUpperCase();
      final value = entry.value;
      if (!RegExp(r'^[A-Z][0-9]{3}$').hasMatch(code) || value is! List) {
        continue;
      }

      final parsed = <_BirthPlaceRecord>[];
      for (final item in value) {
        if (item is! List || item.length < 3) continue;
        final start = item[0]?.toString() ?? '';
        final end = item[1]?.toString() ?? '';
        final name = item[2]?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        parsed.add(_BirthPlaceRecord(start: start, end: end, name: name));
      }
      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a.start.compareTo(b.start));
        records[code] = List.unmodifiable(parsed);
      }
    }

    if (records.isEmpty) {
      throw const FormatException('Archivio luoghi di nascita vuoto.');
    }
    _records = Map.unmodifiable(records);
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _displayName(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return raw.trim();

    const lowercaseWords = {
      'a',
      'ai',
      'al',
      'alla',
      'alle',
      'con',
      'da',
      'dal',
      'dalla',
      'dalle',
      'de',
      'dei',
      'del',
      'della',
      'delle',
      'di',
      'e',
      'in',
      'nel',
      'nella',
      'nelle',
      'sul',
      'sulla',
      'sulle',
    };

    final words = normalized.split(RegExp(r'\s+'));
    return [
      for (var index = 0; index < words.length; index++)
        if (index > 0 && lowercaseWords.contains(words[index]))
          words[index]
        else
          _capitalizeCompound(
            words[index],
            lowercaseApostrophePrefix: index > 0,
          ),
    ].join(' ');
  }

  static String _capitalizeCompound(
    String value, {
    bool lowercaseApostrophePrefix = false,
  }) {
    if (value.isEmpty) return value;

    final apostropheIndex = value.indexOf("'");
    if (apostropheIndex > 0 && apostropheIndex < value.length - 1) {
      final prefix = value.substring(0, apostropheIndex);
      final suffix = value.substring(apostropheIndex + 1);
      const lowercasePrefixes = {
        'd',
        'l',
        'all',
        'dall',
        'dell',
        'nell',
        'sull',
      };
      final formattedPrefix =
          lowercaseApostrophePrefix && lowercasePrefixes.contains(prefix)
              ? prefix
              : _capitalizeSimple(prefix);
      return "$formattedPrefix'${_capitalizeCompound(suffix)}";
    }

    for (final separator in ['-', '/']) {
      if (value.contains(separator)) {
        return value
            .split(separator)
            .map((part) => _capitalizeCompound(part))
            .join(separator);
      }
    }
    return _capitalizeSimple(value);
  }

  static String _capitalizeSimple(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _BirthPlaceRecord {
  const _BirthPlaceRecord({
    required this.start,
    required this.end,
    required this.name,
  });

  final String start;
  final String end;
  final String name;

  bool contains(String date) {
    final afterStart = start.isEmpty || date.compareTo(start) >= 0;
    final beforeEnd = end.isEmpty || date.compareTo(end) <= 0;
    return afterStart && beforeEnd;
  }
}
