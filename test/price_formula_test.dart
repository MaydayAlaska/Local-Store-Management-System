import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/formatters.dart';

void main() {
  test('purchase price formula applies percentage discount', () {
    expect(parsePriceFormulaCents('200-40%'), 12000);
    expect(parsePriceFormulaCents('200,00 - 40%'), 12000);
  });

  test('purchase price formula supports chained percentages', () {
    expect(parsePriceFormulaCents('200-40%-10%'), 10800);
    expect(parsePriceFormulaCents('100+20%'), 12000);
  });

  test('purchase price formula honors arithmetic precedence', () {
    expect(parsePriceFormulaCents('10+5*2'), 2000);
    expect(parsePriceFormulaCents('100/4'), 2500);
  });

  test('purchase price formula rejects invalid expressions', () {
    expect(() => parsePriceFormulaCents('200-abc'), throwsFormatException);
    expect(() => parsePriceFormulaCents('100/0'), throwsFormatException);
  });
}
