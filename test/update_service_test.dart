import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/update_service.dart';

void main() {
  test('current beta OTA version is aligned', () {
    expect(UpdateService.currentVersion, '0.1.6-b4');
  });

  test('OTA selects Windows x64 asset', () {
    expect(
      updateAssetNameFor(operatingSystem: 'windows', abi: Abi.windowsX64),
      'LocalStoreManagement-Setup-win-x64.exe',
    );
  });

  test('OTA selects Windows ARM64 asset', () {
    expect(
      updateAssetNameFor(operatingSystem: 'windows', abi: Abi.windowsArm64),
      'LocalStoreManagement-Setup-win-arm64.exe',
    );
  });

  test('OTA selects macOS x64 DMG', () {
    expect(
      updateAssetNameFor(operatingSystem: 'macos', abi: Abi.macosX64),
      'LocalStoreManagement-macos-x64.dmg',
    );
  });

  test('OTA selects macOS ARM64 DMG', () {
    expect(
      updateAssetNameFor(operatingSystem: 'macos', abi: Abi.macosArm64),
      'LocalStoreManagement-macos-arm64.dmg',
    );
  });

  test('OTA selects Linux x64 AppImage', () {
    expect(
      updateAssetNameFor(operatingSystem: 'linux', abi: Abi.linuxX64),
      'LocalStoreManagement-linux-x64.AppImage',
    );
  });

  test('OTA selects Linux ARM64 AppImage', () {
    expect(
      updateAssetNameFor(operatingSystem: 'linux', abi: Abi.linuxArm64),
      'LocalStoreManagement-linux-arm64.AppImage',
    );
  });

  test('beta OTA matches versioned Windows assets', () {
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'windows',
        abi: Abi.windowsX64,
      ),
      '-BETA-Setup-win-x64.exe',
    );
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'windows',
        abi: Abi.windowsArm64,
      ),
      '-BETA-Setup-win-arm64.exe',
    );
  });

  test('beta OTA matches versioned macOS DMGs', () {
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'macos',
        abi: Abi.macosX64,
      ),
      '-BETA-macos-x64.dmg',
    );
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'macos',
        abi: Abi.macosArm64,
      ),
      '-BETA-macos-arm64.dmg',
    );
  });

  test('beta OTA matches versioned Linux AppImages', () {
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'linux',
        abi: Abi.linuxX64,
      ),
      '-BETA-linux-x64.AppImage',
    );
    expect(
      betaUpdateAssetSuffixFor(
        operatingSystem: 'linux',
        abi: Abi.linuxArm64,
      ),
      '-BETA-linux-arm64.AppImage',
    );
  });

  test('only Flutter is the beta branch', () {
    expect(isBetaBranch('Flutter'), isTrue);
    expect(isBetaBranch('flutter'), isTrue);
    expect(isBetaBranch('test'), isFalse);
    expect(isBetaBranch('avalonia'), isFalse);
    expect(isBetaBranch('main'), isFalse);
    expect(betaReleaseTagFor('Flutter'), 'beta-latest');
  });

  test('beta and stable OTA channels reject each other versions', () {
    expect(versionBelongsToUpdateChannel('0.1.6-b4', beta: true), isTrue);
    expect(versionBelongsToUpdateChannel('0.1.6', beta: true), isFalse);
    expect(versionBelongsToUpdateChannel('0.1.6', beta: false), isTrue);
    expect(versionBelongsToUpdateChannel('0.1.6-b4', beta: false), isFalse);
    expect(versionBelongsToUpdateChannel('not-a-version', beta: true), isFalse);
    expect(versionBelongsToUpdateChannel('not-a-version', beta: false), isFalse);
  });

  test('beta version normalization keeps the hyphen format', () {
    expect(normalizeAppVersion('0.1.5-b1'), '0.1.5-b1');
    expect(normalizeAppVersion('v0.1.5-b12'), '0.1.5-b12');
    expect(normalizeAppVersion('v0.1.5'), '0.1.5');
  });

  test('OTA version comparison is monotonic', () {
    expect(compareAppVersions('0.1.5-b1', '0.1.5-b1'), 0);
    expect(compareAppVersions('0.1.5-b2', '0.1.5-b1'), greaterThan(0));
    expect(compareAppVersions('0.1.5-b1', '0.1.5-b2'), lessThan(0));
    expect(compareAppVersions('0.1.5', '0.1.5-b99'), greaterThan(0));
    expect(compareAppVersions('0.1.6-b1', '0.1.5'), greaterThan(0));
    expect(compareAppVersions('1.0.0-b1', '0.99.99'), greaterThan(0));
  });

  test('release version is read from beta release metadata', () {
    final release = <String, dynamic>{
      'name': 'Local Store Management v0.1.5-b2 BETA (abcdef0)',
      'tag_name': 'beta-latest',
      'assets': <dynamic>[
        <String, dynamic>{
          'name': 'LocalStoreManagement-0.1.5-b2-BETA-Setup-win-x64.exe',
        },
      ],
    };

    expect(releaseVersionFromMetadata(release), '0.1.5-b2');
  });

  test('release version falls back to asset name', () {
    final release = <String, dynamic>{
      'name': 'BETA latest',
      'tag_name': 'beta-latest',
      'assets': <dynamic>[
        <String, dynamic>{
          'name': 'LocalStoreManagement-0.1.5-b3-BETA-macos-arm64.dmg',
        },
      ],
    };

    expect(releaseVersionFromMetadata(release), '0.1.5-b3');
  });
}
