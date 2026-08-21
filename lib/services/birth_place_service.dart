import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/app_paths.dart';

class BirthPlaceUpdateResult {
  const BirthPlaceUpdateResult._({required this.updated});

  const BirthPlaceUpdateResult.current() : this._(updated: false);
  const BirthPlaceUpdateResult.updated() : this._(updated: true);

  final bool updated;
}

class BirthPlaceService {
  const BirthPlaceService._();

  static const String assetPath = 'assets/data/birth_places.json';
  static const String manifestAssetPath =
      'assets/data/birth_places_manifest.json';
  static const String _owner = 'MaydayAlaska';
  static const String _repository = 'Local-Store-Management-System';
  static const String _buildBranch = String.fromEnvironment('BUILD_BRANCH');
  static const Duration _networkTimeout = Duration(seconds: 20);

  static Map<String, List<_BirthPlaceRecord>> _records = const {};
  static bool _initialized = false;
  static String _activeSourceSha256 = '';

  static String get _updateBranch =>
      _buildBranch.trim().toLowerCase() == 'flutter' ? 'Flutter' : 'main';

  static String get _cachedDatasetPath =>
      p.join(AppPaths.assetsDirectory, 'birth_places.json');

  static String get _cachedManifestPath =>
      p.join(AppPaths.assetsDirectory, 'birth_places_manifest.json');

  static Uri _remoteUri(String fileName) => Uri.parse(
        'https://raw.githubusercontent.com/$_owner/$_repository/'
        '$_updateBranch/assets/data/$fileName',
      );

  static Future<void> initialize({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final embeddedRaw = await assetBundle.loadString(assetPath);
    final embeddedManifestRaw = await assetBundle.loadString(manifestAssetPath);
    final embeddedManifest = _BirthPlaceManifest.parse(embeddedManifestRaw);
    _validateDataset(embeddedRaw, embeddedManifest);
    _load(embeddedRaw);
    _activeSourceSha256 = embeddedManifest.sourceSha256;

    // Nei test con un AssetBundle esplicito non accediamo ai percorsi runtime.
    if (bundle == null) {
      try {
        await _loadCachedDatasetIfValid();
      } catch (error, stackTrace) {
        AppLog.error(
          'ANPR cached dataset ignored',
          error,
          stackTrace,
        );
        await _deleteCachedDataset();
      }
    }

    _initialized = true;
  }

  static void loadForTesting(String raw) {
    _load(raw);
    _initialized = true;
  }

  static Future<BirthPlaceUpdateResult> checkForUpdates({
    void Function()? onUpdateStarted,
  }) async {
    if (!_initialized) {
      throw StateError('BirthPlaceService non inizializzato.');
    }

    final remoteManifestRaw = await _downloadText(
      _remoteUri('birth_places_manifest.json'),
    );
    final remoteManifest = _BirthPlaceManifest.parse(remoteManifestRaw);
    if (remoteManifest.sourceSha256 == _activeSourceSha256) {
      return const BirthPlaceUpdateResult.current();
    }

    onUpdateStarted?.call();

    final remoteDatasetRaw = await _downloadText(
      _remoteUri('birth_places.json'),
    );
    _validateDataset(remoteDatasetRaw, remoteManifest);

    await _writeCachedDataset(
      datasetRaw: remoteDatasetRaw,
      manifestRaw: remoteManifestRaw,
    );

    // _load assegna la nuova mappa solo dopo aver completato il parsing, quindi
    // le risoluzioni già in corso continuano a vedere un dataset consistente.
    _load(remoteDatasetRaw);
    _activeSourceSha256 = remoteManifest.sourceSha256;

    AppLog.info(
      'ANPR',
      'Dataset luoghi di nascita aggiornato a runtime dal branch '
          '$_updateBranch (${remoteManifest.sourceSha256}).',
    );
    return const BirthPlaceUpdateResult.updated();
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

  static Future<void> _loadCachedDatasetIfValid() async {
    final datasetFile = File(_cachedDatasetPath);
    final manifestFile = File(_cachedManifestPath);
    if (!await datasetFile.exists() || !await manifestFile.exists()) return;

    final manifestRaw = await manifestFile.readAsString();
    final manifest = _BirthPlaceManifest.parse(manifestRaw);
    final datasetRaw = await datasetFile.readAsString();
    _validateDataset(datasetRaw, manifest);
    _load(datasetRaw);
    _activeSourceSha256 = manifest.sourceSha256;

    AppLog.info(
      'ANPR',
      'Caricato dataset ANPR aggiornato dalla cache locale '
          '(${manifest.sourceSha256}).',
    );
  }

  static Future<String> _downloadText(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(uri).timeout(_networkTimeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LocalStoreManagementSystem ANPR updater',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/plain');
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException(
          'Download ANPR fallito: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return await response.transform(utf8.decoder).join().timeout(
            _networkTimeout,
          );
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _writeCachedDataset({
    required String datasetRaw,
    required String manifestRaw,
  }) async {
    final datasetFile = File(_cachedDatasetPath);
    final manifestFile = File(_cachedManifestPath);
    final datasetTemp = File('${datasetFile.path}.tmp');
    final manifestTemp = File('${manifestFile.path}.tmp');

    await datasetTemp.writeAsString(datasetRaw, flush: true);
    await manifestTemp.writeAsString(manifestRaw, flush: true);

    if (await datasetFile.exists()) await datasetFile.delete();
    await datasetTemp.rename(datasetFile.path);
    if (await manifestFile.exists()) await manifestFile.delete();
    await manifestTemp.rename(manifestFile.path);
  }

  static Future<void> _deleteCachedDataset() async {
    for (final path in [
      _cachedDatasetPath,
      _cachedManifestPath,
      '$_cachedDatasetPath.tmp',
      '$_cachedManifestPath.tmp',
    ]) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Best effort: il dataset incorporato resta comunque disponibile.
      }
    }
  }

  static void _validateDataset(
    String raw,
    _BirthPlaceManifest manifest,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Archivio luoghi di nascita non valido.');
    }

    var recordCount = 0;
    var hasRoma = false;
    for (final entry in decoded.entries) {
      final code = entry.key.trim().toUpperCase();
      final values = entry.value;
      if (!RegExp(r'^[A-Z][0-9]{3}$').hasMatch(code) || values is! List) {
        throw FormatException('Codice catastale ANPR non valido: ${entry.key}');
      }
      if (values.isEmpty) {
        throw FormatException('Nessun record ANPR per il codice $code.');
      }

      for (final item in values) {
        if (item is! List || item.length < 3) {
          throw FormatException('Record ANPR non valido per il codice $code.');
        }
        final name = item[2]?.toString().trim() ?? '';
        if (name.isEmpty) {
          throw FormatException('Nome luogo ANPR vuoto per il codice $code.');
        }
        if (code == 'H501' && name.toUpperCase() == 'ROMA') hasRoma = true;
        recordCount += 1;
      }
    }

    if (decoded.length != manifest.codeCount ||
        recordCount != manifest.recordCount) {
      throw FormatException(
        'Conteggi ANPR non coerenti: '
        '${decoded.length}/${manifest.codeCount} codici, '
        '$recordCount/${manifest.recordCount} record.',
      );
    }
    if (!hasRoma) {
      throw const FormatException('Controllo ANPR fallito: H501 non risolve ROMA.');
    }
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

class _BirthPlaceManifest {
  const _BirthPlaceManifest({
    required this.sourceSha256,
    required this.recordCount,
    required this.codeCount,
  });

  factory _BirthPlaceManifest.parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest ANPR non valido.');
    }

    final sourceSha256 = decoded['source_sha256']?.toString().trim() ?? '';
    final recordCount = decoded['record_count'];
    final codeCount = decoded['code_count'];
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sourceSha256) ||
        recordCount is! int ||
        recordCount < 10000 ||
        codeCount is! int ||
        codeCount < 7000) {
      throw const FormatException('Manifest ANPR incompleto o non valido.');
    }

    return _BirthPlaceManifest(
      sourceSha256: sourceSha256.toLowerCase(),
      recordCount: recordCount,
      codeCount: codeCount,
    );
  }

  final String sourceSha256;
  final int recordCount;
  final int codeCount;
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
