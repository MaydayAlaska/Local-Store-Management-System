import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import '../models/app_settings.dart';

class SettingsService {
  AppSettings load() {
    final file = File(AppPaths.settingsPath);
    if (!file.existsSync()) return AppSettings.defaults;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return AppSettings.defaults;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  AppSettings save({
    required String shopName,
    required bool showShopNameInMenu,
    required bool showLogoInMenu,
    String? iconSourcePath,
    String? logoSourcePath,
  }) {
    final current = load();
    final name = shopName.trim().isEmpty ? AppSettings.defaults.shopName : shopName.trim();
    final icon = iconSourcePath == null ? current.iconFileName : _saveAsset(iconSourcePath, 'app-icon');
    final logo = logoSourcePath == null ? current.logoFileName : _saveAsset(logoSourcePath, 'shop-logo');
    final settings = AppSettings(
      shopName: name,
      iconFileName: icon,
      logoFileName: logo,
      showShopNameInMenu: showShopNameInMenu,
      showLogoInMenu: showLogoInMenu,
    );
    const encoder = JsonEncoder.withIndent('  ');
    File(AppPaths.settingsPath).writeAsStringSync(encoder.convert(settings.toJson()));
    return settings;
  }

  String? resolveIconPath([AppSettings? settings]) => _resolveAsset((settings ?? load()).iconFileName);
  String? resolveLogoPath([AppSettings? settings]) => _resolveAsset((settings ?? load()).logoFileName);

  String? _resolveAsset(String? relative) {
    if (relative == null || relative.trim().isEmpty) return null;
    final root = p.normalize(p.absolute(AppPaths.dataDirectory));
    final full = p.normalize(p.absolute(p.join(root, relative)));
    if (!p.isWithin(root, full) || !File(full).existsSync()) return null;
    return full;
  }

  String _saveAsset(String sourcePath, String baseName) {
    final extension = p.extension(sourcePath).toLowerCase();
    if (!const {'.png', '.jpg', '.jpeg', '.bmp', '.ico'}.contains(extension)) {
      throw StateError('Formato immagine non supportato. Usa PNG, JPG, BMP o ICO.');
    }
    Directory(AppPaths.assetsDirectory).createSync(recursive: true);
    final relative = p.join('assets', '$baseName$extension');
    File(sourcePath).copySync(p.join(AppPaths.dataDirectory, relative));
    return relative;
  }
}
