import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/core/vat_calculator.dart';

void main() {
  test('VAT is extracted from a VAT-inclusive total', () {
    expect(calculateVatCents(10000, 22), 1803);
    expect(calculateVatCents(20000, 22), 3607);
  });

  test('VAT calculation handles zero and clamps invalid percentages', () {
    expect(calculateVatCents(0, 22), 0);
    expect(calculateVatCents(10000, -5), 0);
    expect(calculateVatCents(10000, 120), 5000);
  });
}
