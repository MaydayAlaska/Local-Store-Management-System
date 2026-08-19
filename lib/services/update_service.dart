import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:path/path.dart' as p;

String updateArchitectureForAbi(Abi abi) => switch (abi) {
      Abi.windowsX64 || Abi.linuxX64 => 'x64',
      Abi.windowsArm64 || Abi.linuxArm64 => 'arm64',
      _ => throw UnsupportedError(
          'Architettura non supportata per gli aggiornamenti OTA: $abi'),
    };

String updateAssetNameFor({
  required String operatingSystem,
  required Abi abi,
}) {
  final arch = updateArchitectureForAbi(abi);
  return switch (operatingSystem) {
    'windows' => 'LocalStoreManagement-Setup-win-$arch.exe',
    'linux' => 'LocalStoreManagement-linux-$arch.AppImage',
    _ => throw UnsupportedError(
        'Aggiornamento automatico disponibile solo su Windows e Linux.'),
  };
}

String betaUpdateAssetSuffixFor({
  required String operatingSystem,
  required Abi abi,
}) {
  final arch = updateArchitectureForAbi(abi);
  return switch (operatingSystem) {
    'windows' => '-BETA-Setup-win-$arch.exe',
    'linux' => '-BETA-linux-$arch.AppImage',
    _ => throw UnsupportedError(
        'Aggiornamento automatico disponibile solo su Windows e Linux.'),
  };
}

bool isBetaBranch(String branch) => branch.trim().toLowerCase() == 'flutter';

String betaReleaseTagFor(String branch) =>
    isBetaBranch(branch) ? 'beta-latest' : '';

String normalizeAppVersion(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  normalized = normalized.replaceFirst('-b', '.b');

  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\.b(\d+))?$')
      .firstMatch(normalized);
  if (match == null) {
    throw FormatException('Versione applicazione non valida: $value');
  }

  final major = int.parse(match.group(1)!);
  final minor = int.parse(match.group(2)!);
  final patch = int.parse(match.group(3)!);
  final beta = match.group(4);
  return beta == null
      ? '$major.$minor.$patch'
      : '$major.$minor.$patch.b${int.parse(beta)}';
}

int compareAppVersions(String left, String right) {
  final a = _ParsedAppVersion.parse(left);
  final b = _ParsedAppVersion.parse(right);

  var comparison = a.major.compareTo(b.major);
  if (comparison != 0) return comparison;
  comparison = a.minor.compareTo(b.minor);
  if (comparison != 0) return comparison;
  comparison = a.patch.compareTo(b.patch);
  if (comparison != 0) return comparison;

  if (a.beta == null && b.beta == null) return 0;
  if (a.beta == null) return 1;
  if (b.beta == null) return -1;
  return a.beta!.compareTo(b.beta!);
}

String? releaseVersionFromMetadata(Map<String, dynamic> release) {
  final candidates = <String>[
    if (release['name'] is String) release['name'] as String,
    if (release['tag_name'] is String) release['tag_name'] as String,
    for (final raw in (release['assets'] as List<dynamic>? ?? const []))
      if (raw is Map<String, dynamic> && raw['name'] is String)
        raw['name'] as String,
  ];

  final pattern = RegExp(
    r'(\d+\.\d+\.\d+(?:[.-]b\d+)?)',
    caseSensitive: false,
  );
  for (final candidate in candidates) {
    final match = pattern.firstMatch(candidate);
    if (match == null) continue;
    try {
      return normalizeAppVersion(match.group(1)!);
    } on FormatException {
      continue;
    }
  }
  return null;
}

class _ParsedAppVersion {
  const _ParsedAppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.beta,
  });

  factory _ParsedAppVersion.parse(String value) {
    final normalized = normalizeAppVersion(value);
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\.b(\d+))?$')
        .firstMatch(normalized)!;
    return _ParsedAppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      beta: match.group(4) == null ? null : int.parse(match.group(4)!),
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int? beta;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    required this.canInstall,
    required this.latestCommit,
    this.assetUrl,
    required this.message,
  });

  final bool updateAvailable;
  final bool canInstall;
  final String latestCommit;
  final String? assetUrl;
  final String message;
}

class UpdateService {
  static const owner = 'MaydayAlaska';
  static const repository = 'Local-Store-Management-System';
  static const stableBranch = 'main';
  static const currentVersion = '0.1.5.b1';
  static const currentCommit = String.fromEnvironment('GIT_COMMIT');
  static const currentBranch = String.fromEnvironment('BUILD_BRANCH');
  static const tokenEnvironmentVariable = 'LOCAL_STORE_GITHUB_TOKEN';

  static bool get isBetaBuild => isBetaBranch(currentBranch);

  static String get betaReleaseTag => betaReleaseTagFor(currentBranch);

  static bool get isInstalledBuild => currentCommit.isNotEmpty;

  Future<UpdateCheckResult> check() =>
      isBetaBuild ? _checkBeta() : _checkStable();

  Future<UpdateCheckResult> _checkStable() async {
    final latestCommit = await _readCommit(stableBranch);
    final release = await _readRelease('ota-$latestCommit');
    if (release == null) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: false,
        latestCommit: latestCommit,
        message:
            'Nessun aggiornamento stabile pubblicato più recente. Una revisione di main potrebbe essere ancora in compilazione.',
      );
    }

    final onlineVersion = releaseVersionFromMetadata(release);
    if (onlineVersion == null) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: false,
        latestCommit: latestCommit,
        message:
            'Impossibile determinare la versione della release stabile pubblicata: aggiornamento automatico non proposto.',
      );
    }

    final versionComparison =
        compareAppVersions(onlineVersion, currentVersion);
    if (versionComparison <= 0) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: _canInstall(),
        latestCommit: latestCommit,
        message: versionComparison == 0
            ? 'Hai già l’ultima versione stabile pubblicata ($onlineVersion).'
            : 'La versione stabile pubblicata ($onlineVersion) è precedente alla versione installata ($currentVersion).',
      );
    }

    final asset = _findAssetInRelease(release);
    return _buildAvailableResult(
      latest: latestCommit,
      latestVersion: onlineVersion,
      asset: asset,
      channelName: 'stabile',
    );
  }

  Future<UpdateCheckResult> _checkBeta() async {
    final release = await _readRelease(betaReleaseTag);
    if (release == null) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: false,
        latestCommit: currentCommit,
        message:
            'Canale BETA attivo. Non è ancora disponibile una prerelease $betaReleaseTag.',
      );
    }

    final onlineVersion = releaseVersionFromMetadata(release);
    if (onlineVersion == null) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: false,
        latestCommit: currentCommit,
        message:
            'Impossibile determinare la versione della BETA pubblicata: aggiornamento automatico non proposto.',
      );
    }

    final versionComparison =
        compareAppVersions(onlineVersion, currentVersion);
    if (versionComparison <= 0) {
      final latestCommit = await _resolveReleaseCommit(release);
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: _canInstall(),
        latestCommit: latestCommit,
        message: versionComparison == 0
            ? 'Hai già l’ultima versione BETA pubblicata ($onlineVersion).'
            : 'La BETA pubblicata ($onlineVersion) è precedente alla versione installata ($currentVersion).',
      );
    }

    final latestCommit = await _resolveReleaseCommit(release);
    final asset = _findAssetInRelease(release, beta: true);
    return _buildAvailableResult(
      latest: latestCommit,
      latestVersion: onlineVersion,
      asset: asset,
      channelName: 'BETA',
    );
  }

  UpdateCheckResult _buildAvailableResult({
    required String latest,
    required String latestVersion,
    required String? asset,
    required String channelName,
  }) {
    if (asset == null) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        message:
            'È disponibile la versione $latestVersion $channelName, ma il pacchetto OTA per questa piattaforma non è presente.',
      );
    }

    if (currentCommit.isEmpty) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message:
            'È disponibile la versione $latestVersion $channelName. Questa è una build di sviluppo: installa una release per usare l’OTA.',
      );
    }

    if (!_canInstall()) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message: Platform.isLinux
            ? 'Aggiornamento $channelName $latestVersion disponibile, ma l’app non è stata avviata da AppImage.'
            : 'Aggiornamento $channelName $latestVersion disponibile, ma il formato di installazione corrente non è aggiornabile automaticamente.',
      );
    }

    return UpdateCheckResult(
      updateAvailable: true,
      canInstall: true,
      latestCommit: latest,
      assetUrl: asset,
      message:
          'Aggiornamento $channelName $latestVersion disponibile. Puoi scaricarlo e riavviare l’applicazione.',
    );
  }

  Future<void> install(UpdateCheckResult update) async {
    if (!update.updateAvailable ||
        !update.canInstall ||
        update.assetUrl == null) {
      throw StateError('Nessun aggiornamento installabile selezionato.');
    }

    final root = Directory(p.join(
      Directory.systemTemp.path,
      'LocalStoreManagementSystem',
      'updates',
      update.latestCommit,
    ));
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final assetName = _expectedAssetName();

    if (Platform.isWindows) {
      final destination = p.join(root.path, assetName);
      await _download(update.assetUrl!, destination);
      await Process.start(
        destination,
        const [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    if (Platform.isLinux) {
      final current = Platform.environment['APPIMAGE'];
      if (current == null || current.trim().isEmpty) {
        throw StateError('L’applicazione non è stata avviata da AppImage.');
      }
      final next = p.join(root.path, assetName);
      await _download(update.assetUrl!, next);
      await Process.run('chmod', ['+x', next]);
      final processId = pid;
      final script = File(p.join(root.path, 'apply-update.sh'));
      script.writeAsStringSync('''#!/bin/sh
while kill -0 $processId 2>/dev/null; do sleep 1; done
mv ${_shell(next)} ${_shell(current)}
chmod +x ${_shell(current)}
exec ${_shell(current)}
''');
      await Process.run('chmod', ['+x', script.path]);
      await Process.start(
        '/bin/sh',
        [script.path],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    throw UnsupportedError(
        'Aggiornamento automatico disponibile solo su Windows e Linux.');
  }

  bool _canInstall() =>
      Platform.isWindows ||
      (Platform.isLinux &&
          (Platform.environment['APPIMAGE']?.isNotEmpty ?? false));

  String _expectedAssetName() => updateAssetNameFor(
        operatingSystem: Platform.operatingSystem,
        abi: Abi.current(),
      );

  String _expectedBetaAssetSuffix() => betaUpdateAssetSuffixFor(
        operatingSystem: Platform.operatingSystem,
        abi: Abi.current(),
      );

  Future<String> _readCommit(String ref) async {
    final encodedRef = Uri.encodeComponent(ref);
    final json = await _getJson(
      'https://api.github.com/repos/$owner/$repository/commits/$encodedRef',
    );
    final sha = json['sha'] as String?;
    if (sha == null || sha.isEmpty) {
      throw StateError('GitHub non ha restituito il commit di $ref.');
    }
    return sha;
  }

  Future<Map<String, dynamic>?> _readRelease(String tag) async {
    final response = await _request(
      Uri.parse(
        'https://api.github.com/repos/$owner/$repository/releases/tags/$tag',
      ),
    );
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain();
      return null;
    }
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GitHub: ${response.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<String> _resolveReleaseCommit(Map<String, dynamic> release) async {
    final target = (release['target_commitish'] as String?)?.trim();
    if (target == null || target.isEmpty) {
      throw StateError(
          'GitHub non ha restituito il commit della release BETA.');
    }
    if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(target)) return target;
    return _readCommit(target);
  }

  String? _findAssetInRelease(
    Map<String, dynamic> release, {
    bool beta = false,
  }) {
    final expected = _expectedAssetName();
    final betaSuffix = beta ? _expectedBetaAssetSuffix() : null;

    for (final raw in (release['assets'] as List<dynamic>? ?? const [])) {
      final asset = raw as Map<String, dynamic>;
      final name = asset['name'] as String? ?? '';
      final matches = beta ? name.endsWith(betaSuffix!) : name == expected;
      if (matches) return asset['url'] as String?;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _request(Uri.parse(url));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GitHub: ${response.statusCode} $body');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<HttpClientResponse> _request(
    Uri uri, {
    String accept = 'application/vnd.github+json',
  }) async {
    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'LocalStoreManagementSystem-Flutter-Updater/1.0',
    );
    request.headers.set(HttpHeaders.acceptHeader, accept);
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    final token = Platform.environment[tokenEnvironmentVariable]?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return request.close();
  }

  Future<void> _download(String url, String destination) async {
    final response = await _request(
      Uri.parse(url),
      accept: 'application/octet-stream',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException(
        'Download aggiornamento fallito: ${response.statusCode} $body',
      );
    }
    final sink = File(destination).openWrite();
    await response.pipe(sink);
  }

  String _shell(String value) => "'${value.replaceAll("'", "'\\''")}'";
}
