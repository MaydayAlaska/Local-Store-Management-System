import 'package:flutter_test/flutter_test.dart';
import 'package:local_store_management/models/catalog.dart';
import 'package:local_store_management/models/fiscal_register.dart';

void main() {
  test('RT description uses category brand product variant and size', () {
    const product = ProductVariant(
      id: 1,
      productId: 10,
      sku: 'JACKET-BLK-XL',
      name: 'Admyre',
      category: 'Giacca',
      brand: 'Macna',
      variant: 'Black',
      size: 'XL',
      salePriceCents: 19990,
      isActive: true,
      stockQuantity: 2,
    );

    expect(product.cartTitleDisplay, 'Macna Admyre');
    expect(
      product.fiscalReceiptDescription,
      'Giacca Macna Admyre - Black - XL',
    );
  });

  test('RT description skips missing optional fields without stray separators', () {
    const product = ProductVariant(
      id: 2,
      productId: 20,
      sku: 'GENERIC-01',
      name: 'Admyre',
      brand: 'Macna',
      isActive: true,
      stockQuantity: 1,
    );

    expect(product.cartTitleDisplay, 'Macna Admyre');
    expect(product.fiscalReceiptDescription, 'Macna Admyre');
  });

  test('fiscal register profile round-trips and maps VAT departments', () {
    const profile = FiscalRegisterProfile(
      id: 'rt-main',
      name: 'RT principale',
      manufacturer: 'Custom',
      model: 'Example',
      driverId: 'generic',
      connectionType: 'tcp',
      host: '192.168.1.50',
      port: 9100,
      enabled: true,
      isDefault: true,
      vatDepartments: {'22': 1, '10': 2},
    );

    final restored = FiscalRegisterProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.modelDisplay, 'Custom Example');
    expect(restored.connectionDisplay, '192.168.1.50:9100');
    expect(restored.isDefault, isTrue);
    expect(restored.departmentForVat(22), 1);
    expect(restored.departmentForVat(10.0), 2);
    expect(restored.departmentForVat(4), isNull);
  });
}
