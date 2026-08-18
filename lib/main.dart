import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/app_paths.dart';
import 'core/database_service.dart';
import 'services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await AppPaths.initialize();

  final database = DatabaseService(AppPaths.databasePath);
  await database.initialize();
  final services = AppServices(database);

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1000, 650),
    center: true,
    title: 'Local Store Management System',
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(StoreApp(services: services));
}
