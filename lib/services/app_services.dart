import '../core/database_service.dart';
import '../repositories/customer_repository.dart';
import '../repositories/lookup_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/stock_repository.dart';
import 'application_icon_service.dart';
import 'backup_service.dart';
import 'export_service.dart';
import 'label_service.dart';
import 'settings_service.dart';
import 'update_service.dart';

class AppServices {
  AppServices(this.database)
      : products = ProductRepository(database),
        lookups = LookupRepository(database),
        stock = StockRepository(database),
        customers = CustomerRepository(database),
        settings = SettingsService() {
    applicationIcon = ApplicationIconService(settings);
    backup = BackupService(database);
    labels = LabelService();
    export = ExportService(products, settings);
    updates = UpdateService();
  }

  final DatabaseService database;
  final ProductRepository products;
  final LookupRepository lookups;
  final StockRepository stock;
  final CustomerRepository customers;
  final SettingsService settings;
  late final ApplicationIconService applicationIcon;
  late final BackupService backup;
  late final LabelService labels;
  late final ExportService export;
  late final UpdateService updates;
}
