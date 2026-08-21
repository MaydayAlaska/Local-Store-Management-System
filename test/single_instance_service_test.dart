import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/single_instance_service.dart';

void main() {
  test('a second process guard is rejected and activates the first', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lsms-single-instance-test-',
    );

    SingleInstanceGuard? primary;
    SingleInstanceGuard? reacquired;
    addTearDown(() async {
      if (reacquired != null) {
        await reacquired.close();
      }
      if (primary != null) {
        await primary.close();
      }
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    var activationCount = 0;
    primary = await SingleInstanceGuard.tryAcquire(
      directory.path,
      onActivate: () {
        activationCount++;
      },
    );
    expect(primary, isNotNull);

    final secondary = await SingleInstanceGuard.tryAcquire(directory.path);
    expect(secondary, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(activationCount, 1);

    await primary!.close();
    primary = null;

    reacquired = await SingleInstanceGuard.tryAcquire(directory.path);
    expect(reacquired, isNotNull);
  });
}
