import 'dart:async';
import 'dart:io';

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
import 'services/database_location_service.dart';
import 'services/single_instance_service.dart';

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
  var primaryWindowReady = false;

  Future<void> activatePrimaryWindow() async {
    if (!primaryWindowReady) return;
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (error, stackTrace) {
      AppLog.error(
        'Unable to activate primary application window',
        error,
        stackTrace,
      );
    }
  }

  try {
    await AppPaths.initialize();

    final instanceGuard = await SingleInstanceGuard.tryAcquire(
      AppPaths.dataDirectory,
      onActivate: activatePrimaryWindow,
    );
    if (instanceGuard == null) {
      AppLog.info(
        'Startup',
        'Avvio ignorato: Local Store Management System è già in esecuzione. '
            'La finestra esistente è stata richiamata in primo piano.',
      );
      exit(0);
    }

    await windowManager.ensureInitialized();
    await AppStrings.initialize();
    await BirthPlaceService.initialize();

    final databaseLocation = DatabaseLocationService();
    final activeDatabasePath = databaseLocation.load();
    AppPaths.databasePath = activeDatabasePath;

    database = DatabaseService(activeDatabasePath);
    await database.initialize();
    final services = AppServices(
      database,
      databaseLocation: databaseLocation,
    );
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
      primaryWindowReady = true;
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(StoreApp(services: services));
    AppLog.info(
      'Startup',
      'Applicazione Flutter avviata correttamente. Database: $activeDatabasePath',
    );
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
        primaryWindowReady = true;
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Se il window manager non è disponibile, Flutter prova comunque a mostrare l'errore.
    }

    runApp(StartupErrorApp(message: error.toString(), logPath: AppLog.logPath));
  }
}
