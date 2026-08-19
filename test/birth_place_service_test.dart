import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/services/birth_place_service.dart';

void main() {
  test('risolve il nome in base al codice e alla data storica', () {
    BirthPlaceService.loadForTesting(
      '{"A001":['
      '["1866-11-19","1924-11-13","ABANO","PD"],'
      '["1924-11-14","9999-12-31","ABANO TERME","PD"]'
      '],"H501":[["","9999-12-31","ROMA","RM"]]}',
    );

    expect(
      BirthPlaceService.resolve('A001', DateTime(1910, 1, 1)),
      'Abano',
    );
    expect(
      BirthPlaceService.resolve('A001', DateTime(1990, 1, 1)),
      'Abano Terme',
    );
    expect(
      BirthPlaceService.resolve('H501', DateTime(1980, 1, 1)),
      'Roma',
    );
  });

  test('non espone il codice quando il luogo non e presente', () {
    BirthPlaceService.loadForTesting(
      '{"H501":[["","9999-12-31","ROMA","RM"]]}',
    );

    expect(
      BirthPlaceService.resolve('Z999', DateTime(1980, 1, 1)),
      isNull,
    );
  });
}
