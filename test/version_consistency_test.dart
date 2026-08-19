import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/update_service.dart';

void main() {
  test('runtime version matches pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'Versione non trovata in pubspec.yaml');
    expect(
      UpdateService.currentVersion,
      match!.group(1),
      reason:
          'UpdateService.currentVersion deve essere allineata alla versione del pubspec.',
    );
  });
}
