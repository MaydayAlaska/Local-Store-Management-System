import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/vat_calculator.dart';

void main() {
  test('VAT is calculated as the configured percentage of the taxable total', () {
    expect(calculateVatCents(10000, 22), 2200);
    expect(calculateVatCents(20000, 22), 4400);
  });

  test('VAT calculation handles zero and clamps invalid percentages', () {
    expect(calculateVatCents(0, 22), 0);
    expect(calculateVatCents(10000, -5), 0);
    expect(calculateVatCents(10000, 120), 10000);
  });
}
