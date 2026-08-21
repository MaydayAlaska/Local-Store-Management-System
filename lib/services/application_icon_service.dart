import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../core/app_paths.dart';
import '../models/app_settings.dart';
import 'settings_service.dart';

class ApplicationIconService {
  ApplicationIconService(this.settings);
  final SettingsService settings;

  Future<void> apply(AppSettings appSettings) async {
    try {
      await windowManager.setTitle('Local Store Management System');
    } catch (_) {
      // Il titolo nativo è accessorio alla barra Flutter.
    }

    if (Platform.isLinux) {
      final customIconPath = settings.resolveIconPreviewPath(appSettings);
      final iconPath = customIconPath ?? await _defaultLinuxIconPath();
      if (iconPath == null) return;

      try {
        await windowManager.setIcon(iconPath);
      } catch (_) {
        // L'icona non deve impedire il funzionamento dell'app.
      }
      return;
    }

    if (!Platform.isWindows) return;

    final customIconPath = settings.resolveWindowsShellIconPath(appSettings);
    if (customIconPath != null) {
      try {
        await windowManager.setIcon(customIconPath);
      } catch (_) {
        // L'icona non deve impedire il funzionamento dell'app.
      }
      await _updateWindowsShortcuts(customIconPath);
      return;
    }

    // L'icona predefinita è incorporata nell'eseguibile dal workflow di build.
    // Evitiamo di rigenerarla a runtime: la shell Windows deve poter scegliere
    // direttamente la risoluzione corretta dalla ICO multi-size dell'EXE.
    final executable = Platform.resolvedExecutable;
    if (File(executable).existsSync()) {
      await _updateWindowsShortcuts(executable);
    }
  }

  Future<String?> _defaultLinuxIconPath() async {
    try {
      final encoded = await rootBundle.loadString('assets/app-icon.base64');
      final bytes = base64Decode(encoded.trim());
      final directory = Directory(AppPaths.assetsDirectory)
        ..createSync(recursive: true);
      final iconPath = p.join(directory.path, 'app-default.png');
      File(iconPath).writeAsBytesSync(bytes, flush: true);
      return iconPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateWindowsShortcuts(String iconPath) async {
    final target = Platform.resolvedExecutable;
    if (!File(target).existsSync()) return;

    final script = File(
      p.join(Directory.systemTemp.path, 'lsms-update-shortcuts-$pid.ps1'),
    );
    try {
      script.writeAsStringSync(r'''
param([string]$Target, [string]$Icon)
$ErrorActionPreference = 'SilentlyContinue'
$wsh = New-Object -ComObject WScript.Shell
$dirs = @(
  [Environment]::GetFolderPath('Desktop'),
  [IO.Path]::Combine([Environment]::GetFolderPath('StartMenu'), 'Programs'),
  [IO.Path]::Combine([Environment]::GetFolderPath('ApplicationData'), 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
foreach ($dir in $dirs) {
  Get-ChildItem -Path $dir -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $shortcut = $wsh.CreateShortcut($_.FullName)
    if ($shortcut.TargetPath -and ([IO.Path]::GetFullPath($shortcut.TargetPath) -ieq [IO.Path]::GetFullPath($Target))) {
      $shortcut.IconLocation = "$Icon,0"
      $shortcut.Save()
    }
  }
}
''', flush: true);
      await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          '-Target',
          target,
          '-Icon',
          iconPath,
        ],
      );
      try {
        await Process.run('ie4uinit.exe', ['-show']);
      } catch (_) {
        // Refresh cache best effort.
      }
    } catch (_) {
      // Alcuni collegamenti possono essere protetti: l'aggiornamento resta best effort.
    } finally {
      try {
        if (script.existsSync()) script.deleteSync();
      } catch (_) {}
    }
  }
}
