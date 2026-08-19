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
    final latest = await _readCommit(stableBranch);
    if (_isCurrentCommit(latest)) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: _canInstall(),
        latestCommit: latest,
        message: 'Hai già l’ultima versione stabile pubblicata su main.',
      );
    }

    final release = await _readRelease('ota-$latest');
    final asset = release == null ? null : _findAssetInRelease(release);
    return _buildAvailableResult(
      latest: latest,
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

    final latest = await _resolveReleaseCommit(release);
    if (_isCurrentCommit(latest)) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: _canInstall(),
        latestCommit: latest,
        message: 'Hai già l’ultima versione BETA pubblicata.',
      );
    }

    final asset = _findAssetInRelease(release, beta: true);
    return _buildAvailableResult(
      latest: latest,
      asset: asset,
      channelName: 'BETA',
    );
  }

  UpdateCheckResult _buildAvailableResult({
    required String latest,
    required String? asset,
    required String channelName,
  }) {
    if (asset == null) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        message:
            'È disponibile una revisione $channelName più recente, ma il pacchetto OTA per questa piattaforma non è presente.',
      );
    }

    if (currentCommit.isEmpty) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message:
            'È disponibile una versione $channelName più recente. Questa è una build di sviluppo: installa una release per usare l’OTA.',
      );
    }

    if (!_canInstall()) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message: Platform.isLinux
            ? 'Aggiornamento $channelName disponibile, ma l’app non è stata avviata da AppImage.'
            : 'Aggiornamento $channelName disponibile, ma il formato di installazione corrente non è aggiornabile automaticamente.',
      );
    }

    return UpdateCheckResult(
      updateAvailable: true,
      canInstall: true,
      latestCommit: latest,
      assetUrl: asset,
      message:
          'Aggiornamento $channelName disponibile. Puoi scaricarlo e riavviare l’applicazione.',
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

  bool _isCurrentCommit(String latest) =>
      currentCommit.isNotEmpty &&
      currentCommit.toLowerCase() == latest.toLowerCase();

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
