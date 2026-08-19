import '../models/app_settings.dart';

class AppRuntime {
  static String currencyCode = AppSettings.defaults.currencyCode;
  static String languageCode = AppSettings.defaults.languageCode;

  static String get currencySymbol => switch (currencyCode) {
        'USD' => r'$',
        'GBP' => '£',
        'CHF' => 'CHF',
        _ => '€',
      };

  static void apply(AppSettings settings) {
    currencyCode = settings.currencyCode;
    languageCode = settings.languageCode;
  }
}
