import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:path/path.dart' as p;

String updateArchitectureForAbi(Abi abi) => switch (abi) {
      Abi.windowsX64 || Abi.linuxX64 => 'x64',
      Abi.windowsArm64 || Abi.linuxArm64 => 'arm64',
      _ => throw UnsupportedError('Architettura non supportata per gli aggiornamenti OTA: $abi'),
    };

String updateAssetNameFor({required String operatingSystem, required Abi abi}) {
  final arch = updateArchitectureForAbi(abi);
  return switch (operatingSystem) {
    'windows' => 'LocalStoreManagement-Setup-win-$arch.exe',
    'linux' => 'LocalStoreManagement-linux-$arch.AppImage',
    _ => throw UnsupportedError('Aggiornamento automatico disponibile solo su Windows e Linux.'),
  };
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
  static const currentVersion = '0.1.4';
  static const currentCommit = String.fromEnvironment('GIT_COMMIT');
  static const currentBranch = String.fromEnvironment('BUILD_BRANCH');
  static const tokenEnvironmentVariable = 'LOCAL_STORE_GITHUB_TOKEN';

  static bool get isBetaBuild {
    final branch = currentBranch.toLowerCase();
    return branch == 'flutter' || branch == 'test';
  }

  static String get betaReleaseTag =>
      currentBranch.toLowerCase() == 'flutter' ? 'flutter-latest' : 'test-latest';

  static bool get isInstalledBuild => currentCommit.isNotEmpty;

  Future<UpdateCheckResult> check() async {
    if (isBetaBuild) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: false,
        latestCommit: currentCommit,
        message: 'Build BETA: gli aggiornamenti OTA stabili sono disattivati. Usa la prerelease $betaReleaseTag.',
      );
    }

    final latest = await _readLatestCommit();
    if (currentCommit.isNotEmpty && currentCommit.toLowerCase() == latest.toLowerCase()) {
      return UpdateCheckResult(
        updateAvailable: false,
        canInstall: _canInstall(),
        latestCommit: latest,
        message: 'Hai già l’ultima versione pubblicata su main.',
      );
    }

    final asset = await _findReleaseAsset('ota-$latest');
    if (asset == null) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        message: currentCommit.isEmpty
            ? 'Build di sviluppo rilevata. L’aggiornamento automatico è disponibile sulle versioni pubblicate.'
            : 'È disponibile una revisione più recente, ma il pacchetto OTA per questa piattaforma non è ancora presente.',
      );
    }
    if (currentCommit.isEmpty) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message: 'È disponibile una versione più recente. Questa è una build di sviluppo: installa una release per usare l’OTA.',
      );
    }
    if (!_canInstall()) {
      return UpdateCheckResult(
        updateAvailable: true,
        canInstall: false,
        latestCommit: latest,
        assetUrl: asset,
        message: Platform.isLinux
            ? 'Aggiornamento disponibile, ma l’app non è stata avviata da AppImage.'
            : 'Aggiornamento disponibile, ma il formato di installazione corrente non è aggiornabile automaticamente.',
      );
    }
    return UpdateCheckResult(
      updateAvailable: true,
      canInstall: true,
      latestCommit: latest,
      assetUrl: asset,
      message: 'Aggiornamento disponibile da main. Puoi scaricarlo e riavviare l’applicazione.',
    );
  }

  Future<void> install(UpdateCheckResult update) async {
    if (isBetaBuild) throw StateError('Gli aggiornamenti OTA stabili sono disattivati nelle build BETA.');
    if (!update.updateAvailable || !update.canInstall || update.assetUrl == null) {
      throw StateError('Nessun aggiornamento installabile selezionato.');
    }
    final root = Directory(p.join(Directory.systemTemp.path, 'LocalStoreManagementSystem', 'updates', update.latestCommit));
    if (root.existsSync()) root.deleteSync(recursive: true);
    root.createSync(recursive: true);
    final assetName = _expectedAssetName();

    if (Platform.isWindows) {
      final destination = p.join(root.path, assetName);
      await _download(update.assetUrl!, destination);
      await Process.start(destination, const [], mode: ProcessStartMode.detached);
      exit(0);
    }

    if (Platform.isLinux) {
      final current = Platform.environment['APPIMAGE'];
      if (current == null || current.trim().isEmpty) throw StateError('L’applicazione non è stata avviata da AppImage.');
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
      await Process.start('/bin/sh', [script.path], mode: ProcessStartMode.detached);
      exit(0);
    }
    throw UnsupportedError('Aggiornamento automatico disponibile solo su Windows e Linux.');
  }

  bool _canInstall() => Platform.isWindows || (Platform.isLinux && (Platform.environment['APPIMAGE']?.isNotEmpty ?? false));

  String _expectedAssetName() => updateAssetNameFor(
        operatingSystem: Platform.operatingSystem,
        abi: Abi.current(),
      );

  Future<String> _readLatestCommit() async {
    final json = await _getJson('https://api.github.com/repos/$owner/$repository/commits/$stableBranch');
    final sha = json['sha'] as String?;
    if (sha == null || sha.isEmpty) throw StateError('GitHub non ha restituito il commit di main.');
    return sha;
  }

  Future<String?> _findReleaseAsset(String tag) async {
    final response = await _request(Uri.parse('https://api.github.com/repos/$owner/$repository/releases/tags/$tag'));
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain();
      return null;
    }
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('GitHub: ${response.statusCode} $body');
    final json = jsonDecode(body) as Map<String, dynamic>;
    final expected = _expectedAssetName();
    for (final raw in (json['assets'] as List<dynamic>? ?? const [])) {
      final asset = raw as Map<String, dynamic>;
      if (asset['name'] == expected) return asset['url'] as String?;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _request(Uri.parse(url));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('GitHub: ${response.statusCode} $body');
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<HttpClientResponse> _request(Uri uri, {String accept = 'application/vnd.github+json'}) async {
    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'LocalStoreManagementSystem-Flutter-Updater/1.0');
    request.headers.set(HttpHeaders.acceptHeader, accept);
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    final token = Platform.environment[tokenEnvironmentVariable]?.trim();
    if (token != null && token.isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    return request.close();
  }

  Future<void> _download(String url, String destination) async {
    final response = await _request(Uri.parse(url), accept: 'application/octet-stream');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException('Download aggiornamento fallito: ${response.statusCode} $body');
    }
    final sink = File(destination).openWrite();
    await response.pipe(sink);
  }

  String _shell(String value) => "'${value.replaceAll("'", "'\\''")}'";
}
