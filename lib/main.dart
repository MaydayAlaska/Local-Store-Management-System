import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_log.dart';
import 'core/app_paths.dart';
import 'core/database_service.dart';
import 'l10n/app_strings.dart';
import 'pages/startup_error_page.dart';
import 'services/app_services.dart';
import 'services/birth_place_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      AppLog.error('Flutter framework error', details.exception, details.stack);
      FlutterError.presentError(details);
    };
    await _bootstrap();
  }, (error, stackTrace) {
    AppLog.error('Unhandled asynchronous error', error, stackTrace);
  });
}

Future<void> _bootstrap() async {
  DatabaseService? database;
  try {
    await windowManager.ensureInitialized();
    await AppPaths.initialize();
    await AppStrings.initialize();
    await BirthPlaceService.initialize();

    database = DatabaseService(AppPaths.databasePath);
    await database.initialize();
    final services = AppServices(database);
    final settings = services.settings.load();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(1000, 650),
      center: true,
      title: 'Local Store Management System',
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await services.applicationIcon.apply(settings);
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(StoreApp(services: services));
    AppLog.info('Startup', 'Applicazione Flutter avviata correttamente.');
  } catch (error, stackTrace) {
    AppLog.error('Application startup failed', error, stackTrace);
    try {
      database?.dispose();
    } catch (_) {}

    try {
      await windowManager.ensureInitialized();
      const errorOptions = WindowOptions(
        size: Size(760, 480),
        minimumSize: Size(640, 400),
        center: true,
        title: 'Local Store Management System — Errore',
        titleBarStyle: TitleBarStyle.normal,
      );
      await windowManager.waitUntilReadyToShow(errorOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Se il window manager non è disponibile, Flutter prova comunque a mostrare l'errore.
    }

    runApp(StartupErrorApp(message: error.toString(), logPath: AppLog.logPath));
  }
}
