import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/theme/external_ui_style_pack.dart';
import 'package:local_store_management/theme/ui_style_registry.dart';
import 'package:local_store_management/theme/ui_style_tokens.dart';

const _bundledStyleIds = <String>[
  'flutiger-aero',
  'brutalism',
  'neumorphism',
  'material-design',
  'astractmorphism',
  'skeumorphism',
  'flat-design',
  'retrofuturism',
  'monochromatic-design',
  'minimal-vintage',
  'glassmorphism-2',
];

void main() {
  test('glassmorphism installs style tokens in light and dark themes', () {
    final style = UiStyleRegistry.resolve('glassmorphism');
    final light = style.lightTheme();
    final dark = style.darkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<UiStyleTokens>(), isNotNull);
    expect(dark.extension<UiStyleTokens>(), isNotNull);
  });

  test('every bundled style contains valid light and dark themes', () {
    final root = Directory.systemTemp.createTempSync('lsms-bundled-styles-');
    addTearDown(() => root.deleteSync(recursive: true));

    for (final id in _bundledStyleIds) {
      final file = File('assets/styles/bundled/$id.json');
      expect(file.existsSync(), isTrue, reason: '$id bundle is missing');
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map>());
      final bundle = Map<String, dynamic>.from(decoded as Map);
      expect(bundle['style'], isA<Map>(), reason: '$id is missing style metadata');
      expect(bundle['light'], isA<Map>(), reason: '$id is missing light theme');
      expect(bundle['dark'], isA<Map>(), reason: '$id is missing dark theme');
      final metadata = Map<String, dynamic>.from(bundle['style'] as Map);
      expect(metadata['id'], id);

      final styleDirectory = Directory('${root.path}/$id')..createSync();
      File('${styleDirectory.path}/style.json')
          .writeAsStringSync(jsonEncode(bundle['style']));
      File('${styleDirectory.path}/light.json')
          .writeAsStringSync(jsonEncode(bundle['light']));
      File('${styleDirectory.path}/dark.json')
          .writeAsStringSync(jsonEncode(bundle['dark']));

      final style = ExternalUiStylePack.load(styleDirectory);
      final lightTheme = style.lightTheme();
      final darkTheme = style.darkTheme();
      expect(style.id, id);
      expect(lightTheme.brightness, Brightness.light);
      expect(darkTheme.brightness, Brightness.dark);
      expect(lightTheme.extension<UiStyleTokens>(), isNotNull);
      expect(darkTheme.extension<UiStyleTokens>(), isNotNull);
    }
  });

  test('runtime pack loads only with both light and dark themes', () async {
    final root = Directory.systemTemp.createTempSync('lsms-style-registry-');
    addTearDown(() => root.deleteSync(recursive: true));

    final valid = Directory('${root.path}/Community')..createSync();
    File('${valid.path}/style.json').writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'community',
      'name': 'Community',
    }));
    File('${valid.path}/light.json')
        .writeAsStringSync(jsonEncode(_variant(false)));
    File('${valid.path}/dark.json')
        .writeAsStringSync(jsonEncode(_variant(true)));

    final invalid = Directory('${root.path}/MissingDark')..createSync();
    File('${invalid.path}/style.json').writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'missing-dark',
      'name': 'Missing dark',
    }));
    File('${invalid.path}/light.json')
        .writeAsStringSync(jsonEncode(_variant(false)));

    await UiStyleRegistry.reloadFromDirectory(root.path);

    expect(UiStyleRegistry.hasStyle('community'), isTrue);
    expect(
      UiStyleRegistry.resolve('community').lightTheme().brightness,
      Brightness.light,
    );
    expect(
      UiStyleRegistry.resolve('community').darkTheme().brightness,
      Brightness.dark,
    );
    expect(UiStyleRegistry.invalidPacks, contains('MissingDark'));
  });

  test('unknown style falls back to built-in glassmorphism', () {
    expect(
      UiStyleRegistry.resolve('unknown-style').id,
      UiStyleRegistry.fallbackId,
    );
  });
}

Map<String, dynamic> _variant(bool dark) => {
      'seedColor': dark ? '#FF8EBBFF' : '#FF315FCE',
      'tokens': {
        'backgroundStart': dark ? '#FF101521' : '#FFE9F2FF',
        'backgroundMiddle': dark ? '#FF151A2B' : '#FFF5EEFF',
        'backgroundEnd': dark ? '#FF101821' : '#FFE8FAF7',
        'glowPrimary': '#553A86FF',
        'glowSecondary': '#44B95CFF',
        'glowTertiary': '#3D37D6B0',
        'cardSurface': dark ? '#1FFFFFFF' : '#8FFFFFFF',
        'strongSurface': dark ? '#F2232936' : '#FAFFFFFF',
        'subtleSurface': dark ? '#14FFFFFF' : '#70FFFFFF',
        'surfaceBase': '#FFFFFFFF',
        'surfaceOpacity': dark ? 0.10 : 0.42,
        'contentSurfaceOpacity': dark ? 0.055 : 0.24,
        'notificationSurfaceOpacity': dark ? 0.18 : 0.58,
        'border': dark ? '#38FFFFFF' : '#A8FFFFFF',
        'softBorder': dark ? '#24FFFFFF' : '#72FFFFFF',
        'shadow': dark ? '#2E000000' : '#0F000000',
        'menuSurface': dark ? '#E0212836' : '#E8FFFFFF',
        'menuBorder': dark ? '#55FFFFFF' : '#B8FFFFFF',
        'menuShadow': dark ? '#61000000' : '#29000000',
        'tooltipSurface': dark ? '#F2232936' : '#FAFFFFFF',
        'tooltipBorder': dark ? '#38FFFFFF' : '#A8FFFFFF',
        'tooltipShadow': dark ? '#6B000000' : '#2E000000',
        'imagePreviewSurface': dark ? '#57000000' : '#75FFFFFF',
        'captionHover': dark ? '#1AFFFFFF' : '#57FFFFFF',
        'surfaceBlur': 22,
        'menuBlur': 30,
      },
    };
