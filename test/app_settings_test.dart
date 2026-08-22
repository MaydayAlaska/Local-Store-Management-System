import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/app_runtime.dart';
import 'package:local_store_management/core/formatters.dart';
import 'package:local_store_management/models/app_settings.dart';

void main() {
  test('old settings files receive safe defaults', () {
    final settings = AppSettings.fromJson(<String, dynamic>{
      'ShopName': 'Negozio test',
    });

    expect(settings.shopName, 'Negozio test');
    expect(settings.currencyCode, 'EUR');
    expect(settings.vatPercent, 22);
    expect(settings.themeMode, 'system');
    expect(settings.uiStyle, 'glassmorphism');
    expect(settings.languageCode, 'it');
  });

  test('safe external UI style IDs survive settings parsing', () {
    final settings = AppSettings.fromJson(<String, dynamic>{
      'ShopName': 'Negozio test',
      'UiStyle': 'community-style',
    });

    expect(settings.uiStyle, 'community-style');
  });

  test('invalid UI style IDs fall back to glassmorphism', () {
    final settings = AppSettings.fromJson(<String, dynamic>{
      'ShopName': 'Negozio test',
      'UiStyle': '../bad/style',
    });

    expect(settings.uiStyle, 'glassmorphism');
  });

  test('new interface preferences round-trip through json', () {
    const settings = AppSettings(
      shopName: 'Shop',
      currencyCode: 'USD',
      vatPercent: 10.5,
      themeMode: 'dark',
      uiStyle: 'glassmorphism',
      languageCode: 'en',
    );

    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.currencyCode, 'USD');
    expect(restored.vatPercent, 10.5);
    expect(restored.themeMode, 'dark');
    expect(restored.uiStyle, 'glassmorphism');
    expect(restored.languageCode, 'en');
  });

  test('money formatting follows selected currency and language', () {
    const italianEuro = AppSettings(shopName: 'Shop');
    AppRuntime.apply(italianEuro);
    expect(formatMoney(123456), '€ 1.234,56');

    const englishUsd = AppSettings(
      shopName: 'Shop',
      currencyCode: 'USD',
      languageCode: 'en',
    );
    AppRuntime.apply(englishUsd);
    expect(formatMoney(123456), r'$ 1,234.56');
  });

  test('inventory export timestamp is file-system friendly', () {
    expect(
      exportTimestamp(DateTime(2026, 8, 19, 14, 23, 45)),
      '2026-08-19_14-23-45',
    );
  });
}
