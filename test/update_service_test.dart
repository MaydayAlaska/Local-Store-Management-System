import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/update_service.dart';

void main() {
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
}
