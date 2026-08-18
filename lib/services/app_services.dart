import '../core/database_service.dart';
import '../repositories/lookup_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/stock_repository.dart';
import 'settings_service.dart';

class AppServices {
  AppServices(this.database)
      : products = ProductRepository(database),
        lookups = LookupRepository(database),
        stock = StockRepository(database),
        settings = SettingsService();

  final DatabaseService database;
  final ProductRepository products;
  final LookupRepository lookups;
  final StockRepository stock;
  final SettingsService settings;
}
