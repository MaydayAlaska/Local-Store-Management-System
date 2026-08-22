import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/models/app_settings.dart';
import 'package:local_store_management/theme/ui_style_registry.dart';
import 'package:local_store_management/theme/ui_style_tokens.dart';

void main() {
  test('style registry matches settings supported styles', () {
    expect(
      UiStyleRegistry.all.map((style) => style.id).toList(),
      AppSettings.supportedUiStyles,
    );
  });

  test('glassmorphism installs style tokens in light and dark themes', () {
    final style = UiStyleRegistry.resolve('glassmorphism');
    final light = style.lightTheme();
    final dark = style.darkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<UiStyleTokens>(), isNotNull);
    expect(dark.extension<UiStyleTokens>(), isNotNull);
  });

  test('unknown style falls back to registered default', () {
    expect(
      UiStyleRegistry.resolve('unknown-style').id,
      UiStyleRegistry.fallbackId,
    );
  });
}
