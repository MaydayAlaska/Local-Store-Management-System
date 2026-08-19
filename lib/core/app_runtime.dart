import '../models/app_settings.dart';

class AppRuntime {
  static String currencyCode = AppSettings.defaults.currencyCode;
  static String languageCode = AppSettings.defaults.languageCode;

  static void apply(AppSettings settings) {
    currencyCode = settings.currencyCode;
    languageCode = settings.languageCode;
  }
}
