import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/theme/external_ui_style_pack.dart';
import 'package:local_store_management/theme/ui_layout_tokens.dart';
import 'package:local_store_management/theme/ui_style_registry.dart';
import 'package:local_store_management/theme/ui_style_tokens.dart';

const _bundledStyleIds = <String>[
  'flutiger-aero',
  'brutalism',
  'neumorphism',
  'material-design',
  'flat-design',
  'retrofuturism',
  'monochromatic-design',
  'minimal-vintage',
];

void main() {
  test('glassmorphism installs style tokens', () {
    final style = UiStyleRegistry.resolve('glassmorphism');
    final light = style.lightTheme();
    final dark = style.darkTheme();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<UiStyleTokens>(), isNotNull);
    expect(dark.extension<UiStyleTokens>(), isNotNull);
  });

  test('every bundled style contains light, dark and UI composition', () {
    final root = Directory.systemTemp.createTempSync('lsms-bundled-styles-');
    addTearDown(() => root.deleteSync(recursive: true));

    for (final id in _bundledStyleIds) {
      final file = File('assets/styles/bundled/$id.json');
      expect(file.existsSync(), isTrue, reason: '$id bundle is missing');
      final bundle = Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );
      final metadata = Map<String, dynamic>.from(bundle['style'] as Map);
      expect(metadata['id'], id);
      expect(metadata['version'], isA<String>());
      expect(
        metadata['version'] as String,
        startsWith('2.'),
        reason: '$id must use the current bundled style schema generation',
      );
      expect(metadata['layout'], isA<Map>());
      expect(bundle['light'], isA<Map>());
      expect(bundle['dark'], isA<Map>());

      final styleDirectory = Directory('${root.path}/$id')..createSync();
      File('${styleDirectory.path}/style.json')
          .writeAsStringSync(jsonEncode(bundle['style']));
      File('${styleDirectory.path}/light.json')
          .writeAsStringSync(jsonEncode(bundle['light']));
      File('${styleDirectory.path}/dark.json')
          .writeAsStringSync(jsonEncode(bundle['dark']));

      final style = ExternalUiStylePack.load(styleDirectory);
      expect(style.id, id);
      expect(style.lightTheme().brightness, Brightness.light);
      expect(style.darkTheme().brightness, Brightness.dark);
      expect(style.lightTheme().extension<UiStyleTokens>(), isNotNull);
      expect(style.darkTheme().extension<UiStyleTokens>(), isNotNull);

      final layout = Map<String, dynamic>.from(metadata['layout'] as Map);
      final dark = Map<String, dynamic>.from(bundle['dark'] as Map);
      final tokens = Map<String, dynamic>.from(dark['tokens'] as Map);
      if (layout['surfaceStyle'] != 'glass' &&
          (tokens['surfaceOpacity'] as num).toDouble() == 1) {
        expect(
          (tokens['surfaceBase'] as String).toUpperCase(),
          isNot('#FFFFFFFF'),
          reason: '$id dark opaque surface must not be white',
        );
      }
    }
  });

  test('monochromatic design is explicitly monochrome', () {
    final bundle = Map<String, dynamic>.from(
      jsonDecode(
        File('assets/styles/bundled/monochromatic-design.json')
            .readAsStringSync(),
      ) as Map,
    );
    final metadata = Map<String, dynamic>.from(bundle['style'] as Map);
    final layout = Map<String, dynamic>.from(metadata['layout'] as Map);
    expect(layout['monochrome'], isTrue);
  });

  test('runtime pack loads only with both light and dark themes', () async {
    final root = Directory.systemTemp.createTempSync('lsms-style-registry-');
    addTearDown(() => root.deleteSync(recursive: true));

    final valid = Directory('${root.path}/Community')..createSync();
    File('${valid.path}/style.json').writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'community',
      'name': 'Community',
      'layout': {
        'navigation': 'top',
        'surfaceStyle': 'flat',
      },
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
    expect(UiStyleRegistry.layoutFor('community').navigation, 'top');
    expect(UiStyleRegistry.layoutFor('community').surfaceStyle, 'flat');
    expect(UiStyleRegistry.invalidPacks, contains('MissingDark'));
  });

  test('unknown style falls back to built-in glassmorphism', () {
    expect(
      UiStyleRegistry.resolve('unknown-style').id,
      UiStyleRegistry.fallbackId,
    );
    expect(
      UiStyleRegistry.layoutFor('unknown-style'),
      isA<UiLayoutTokens>(),
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
