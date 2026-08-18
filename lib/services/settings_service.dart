import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
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
    File(AppPaths.settingsPath).writeAsStringSync(encoder.convert(settings.toJson()), flush: true);
    if (icon != null) _ensureDerivedIconFiles(settings);
    return settings;
  }

  String? resolveIconPath([AppSettings? settings]) => _resolveAsset((settings ?? load()).iconFileName);
  String? resolveLogoPath([AppSettings? settings]) => _resolveAsset((settings ?? load()).logoFileName);

  String? resolveIconPreviewPath([AppSettings? settings]) {
    final value = settings ?? load();
    final source = resolveIconPath(value);
    if (source == null) return null;
    try {
      return _ensureDerivedIconFiles(value).previewPath;
    } catch (_) {
      return source.toLowerCase().endsWith('.ico') ? null : source;
    }
  }

  String? resolveWindowsShellIconPath([AppSettings? settings]) {
    final value = settings ?? load();
    final source = resolveIconPath(value);
    if (source == null) return null;
    try {
      return _ensureDerivedIconFiles(value).shellIconPath;
    } catch (_) {
      return source.toLowerCase().endsWith('.ico') ? source : null;
    }
  }

  ({String previewPath, String shellIconPath}) _ensureDerivedIconFiles(AppSettings settings) {
    final sourcePath = resolveIconPath(settings);
    if (sourcePath == null) throw StateError('Icona applicazione non disponibile.');
    final source = File(sourcePath);
    final stamp = source.lastModifiedSync().millisecondsSinceEpoch;
    final previewPath = p.join(AppPaths.assetsDirectory, 'app-icon-preview-$stamp.png');
    final shellIconPath = p.join(AppPaths.assetsDirectory, 'app-shell-$stamp.ico');

    final needsPreview = !File(previewPath).existsSync();
    final needsShell = !File(shellIconPath).existsSync();
    if (needsPreview || needsShell) {
      final decoded = img.decodeImage(source.readAsBytesSync());
      if (decoded == null) throw StateError('Il file scelto non contiene un’immagine valida.');
      final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
      final normalized = longest > 256
          ? img.copyResize(decoded, width: decoded.width >= decoded.height ? 256 : null, height: decoded.height > decoded.width ? 256 : null)
          : decoded;
      if (needsPreview) File(previewPath).writeAsBytesSync(img.encodePng(normalized), flush: true);
      if (needsShell) File(shellIconPath).writeAsBytesSync(img.encodeIco(normalized), flush: true);
    }

    _cleanDerivedIcons(previewPath, shellIconPath);
    return (previewPath: previewPath, shellIconPath: shellIconPath);
  }

  void _cleanDerivedIcons(String keepPreview, String keepShell) {
    try {
      for (final entity in Directory(AppPaths.assetsDirectory).listSync()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        final derived = name.startsWith('app-icon-preview-') || name.startsWith('app-shell-');
        if (derived && entity.path != keepPreview && entity.path != keepShell) {
          entity.deleteSync();
        }
      }
    } catch (_) {
      // Pulizia best effort.
    }
  }

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
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final relative = p.join('assets', '$baseName-$stamp$extension');
    final destination = File(p.join(AppPaths.dataDirectory, relative));
    File(sourcePath).copySync(destination.path);
    _cleanSourceAssets(baseName, destination.path);
    return relative;
  }

  void _cleanSourceAssets(String baseName, String keepPath) {
    try {
      for (final entity in Directory(AppPaths.assetsDirectory).listSync()) {
        if (entity is! File || p.equals(entity.path, keepPath)) continue;
        final name = p.basenameWithoutExtension(entity.path).toLowerCase();
        final base = baseName.toLowerCase();
        if (name == base || name.startsWith('$base-')) {
          entity.deleteSync();
        }
      }
    } catch (_) {
      // Pulizia best effort: il nuovo asset è comunque già stato salvato.
    }
  }
}
