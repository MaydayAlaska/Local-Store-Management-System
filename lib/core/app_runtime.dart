import '../models/app_settings.dart';

class AppRuntime {
  static String currencyCode = AppSettings.defaults.currencyCode;
  static double vatPercent = AppSettings.defaults.vatPercent;
  static String languageCode = AppSettings.defaults.languageCode;

  static String get currencySymbol => switch (currencyCode) {
        'USD' => r'$',
        'GBP' => '£',
        'CHF' => 'CHF',
        _ => '€',
      };

  static void apply(AppSettings settings) {
    currencyCode = settings.currencyCode;
    vatPercent = settings.vatPercent;
    languageCode = settings.languageCode;
  }
}
