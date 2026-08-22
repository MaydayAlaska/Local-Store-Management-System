import 'dart:io';

import '../l10n/app_strings.dart';
import '../models/catalog.dart';
import '../models/fiscal_register.dart';
import 'settings_service.dart';

class FiscalRegisterDriverDescriptor {
  const FiscalRegisterDriverDescriptor({
    required this.id,
    required this.name,
    required this.supportedConnectionTypes,
    required this.supportsReceiptIssuing,
  });

  final String id;
  final String name;
  final List<String> supportedConnectionTypes;
  final bool supportsReceiptIssuing;
}

abstract interface class FiscalRegisterDriver {
  FiscalRegisterDriverDescriptor get descriptor;

  Future<void> testConnection(FiscalRegisterProfile profile);

  Future<FiscalReceiptResult> issueReceipt(
    FiscalRegisterProfile profile,
    FiscalReceiptRequest request,
  );
}

class FiscalRegisterService {
  FiscalRegisterService(this._settings)
      : _drivers = {
          _GenericFiscalRegisterDriver.driverId:
              const _GenericFiscalRegisterDriver(),
        };

  final SettingsService _settings;
  final Map<String, FiscalRegisterDriver> _drivers;

  static const genericDriverId = _GenericFiscalRegisterDriver.driverId;

  List<FiscalRegisterDriverDescriptor> get driverDescriptors =>
      _drivers.values.map((driver) => driver.descriptor).toList(growable: false);

  List<FiscalRegisterProfile> get profiles =>
      _settings.load().fiscalRegisterProfiles;

  List<FiscalRegisterProfile> get enabledProfiles =>
      profiles.where((profile) => profile.enabled).toList(growable: false);

  FiscalRegisterProfile? get defaultProfile {
    final enabled = enabledProfiles;
    if (enabled.isEmpty) return null;
    for (final profile in enabled) {
      if (profile.isDefault) return profile;
    }
    return enabled.first;
  }

  FiscalRegisterDriverDescriptor? descriptorFor(String driverId) =>
      _drivers[driverId.trim().toLowerCase()]?.descriptor;

  bool canIssueReceipt(FiscalRegisterProfile profile) =>
      _drivers[profile.driverId]?.descriptor.supportsReceiptIssuing == true;

  Future<void> testConnection(FiscalRegisterProfile profile) async {
    final driver = _drivers[profile.driverId];
    if (driver == null) {
      throw StateError(AppStrings.pair(
        'Driver RT “${profile.driverId}” non disponibile.',
        'Cash-register driver “${profile.driverId}” is not available.',
      ));
    }
    await driver.testConnection(profile);
  }

  Future<FiscalReceiptResult> issueReceipt(
    FiscalRegisterProfile profile,
    FiscalReceiptRequest request,
  ) async {
    final driver = _drivers[profile.driverId];
    if (driver == null) {
      throw StateError(AppStrings.pair(
        'Driver RT “${profile.driverId}” non disponibile.',
        'Cash-register driver “${profile.driverId}” is not available.',
      ));
    }
    if (!driver.descriptor.supportsReceiptIssuing) {
      throw UnsupportedError(AppStrings.pair(
        'Il profilo “${profile.name}” usa un driver di configurazione generico: serve il driver fiscale specifico del modello per emettere documenti commerciali.',
        'Profile “${profile.name}” uses the generic configuration driver: a model-specific fiscal driver is required to issue fiscal receipts.',
      ));
    }
    return driver.issueReceipt(profile, request);
  }

  FiscalReceiptLine productLine({
    required FiscalRegisterProfile profile,
    required ProductVariant product,
    required int quantity,
    required int unitPriceCents,
    required int grossTotalCents,
    required int finalTotalCents,
    required double vatPercent,
  }) =>
      FiscalReceiptLine(
        description: product.fiscalReceiptDescription,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        grossTotalCents: grossTotalCents,
        finalTotalCents: finalTotalCents,
        vatPercent: vatPercent,
        department: profile.departmentForVat(vatPercent),
      );
}

class _GenericFiscalRegisterDriver implements FiscalRegisterDriver {
  const _GenericFiscalRegisterDriver();

  static const driverId = 'generic';

  @override
  FiscalRegisterDriverDescriptor get descriptor =>
      const FiscalRegisterDriverDescriptor(
        id: driverId,
        name: 'Generic RT profile',
        supportedConnectionTypes: ['tcp', 'serial'],
        supportsReceiptIssuing: false,
      );

  @override
  Future<void> testConnection(FiscalRegisterProfile profile) async {
    if (profile.isTcp) {
      final host = profile.host.trim();
      if (host.isEmpty) {
        throw StateError(AppStrings.pair(
          'Indirizzo IP/hostname non configurato.',
          'IP address/hostname is not configured.',
        ));
      }
      Socket? socket;
      try {
        socket = await Socket.connect(
          host,
          profile.port,
          timeout: const Duration(seconds: 4),
        );
      } finally {
        socket?.destroy();
      }
      return;
    }

    throw UnsupportedError(AppStrings.pair(
      'Il test della porta seriale sarà disponibile con il driver specifico del registratore.',
      'Serial-port testing will be available with the register-specific driver.',
    ));
  }

  @override
  Future<FiscalReceiptResult> issueReceipt(
    FiscalRegisterProfile profile,
    FiscalReceiptRequest request,
  ) =>
      throw UnsupportedError(AppStrings.pair(
        'Il driver generico non emette documenti fiscali.',
        'The generic driver does not issue fiscal receipts.',
      ));
}
