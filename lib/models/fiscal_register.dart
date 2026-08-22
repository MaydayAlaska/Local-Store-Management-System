class FiscalRegisterProfile {
  const FiscalRegisterProfile({
    required this.id,
    required this.name,
    this.manufacturer = '',
    this.model = '',
    this.driverId = 'generic',
    this.connectionType = 'tcp',
    this.host = '',
    this.port = 9100,
    this.serialPort = '',
    this.baudRate = 9600,
    this.enabled = true,
    this.isDefault = false,
    this.vatDepartments = const {},
  });

  final String id;
  final String name;
  final String manufacturer;
  final String model;
  final String driverId;
  final String connectionType;
  final String host;
  final int port;
  final String serialPort;
  final int baudRate;
  final bool enabled;
  final bool isDefault;
  final Map<String, int> vatDepartments;

  static const supportedConnectionTypes = ['tcp', 'serial'];

  bool get isTcp => connectionType == 'tcp';
  bool get isSerial => connectionType == 'serial';

  String get modelDisplay {
    final parts = <String>[
      if (manufacturer.trim().isNotEmpty) manufacturer.trim(),
      if (model.trim().isNotEmpty) model.trim(),
    ];
    return parts.join(' ');
  }

  String get connectionDisplay => isTcp
      ? '${host.trim()}:$port'
      : serialPort.trim().isEmpty
          ? 'Seriale'
          : '${serialPort.trim()} · $baudRate baud';

  int? departmentForVat(double vatPercent) =>
      vatDepartments[_vatKey(vatPercent)];

  factory FiscalRegisterProfile.fromJson(Map<String, dynamic> json) {
    final rawConnection =
        (json['ConnectionType'] as String?)?.trim().toLowerCase();
    final connectionType = supportedConnectionTypes.contains(rawConnection)
        ? rawConnection!
        : 'tcp';
    final rawPort = (json['Port'] as num?)?.toInt() ?? 9100;
    final rawBaudRate = (json['BaudRate'] as num?)?.toInt() ?? 9600;
    final rawMappings = json['VatDepartments'];
    final mappings = <String, int>{};
    if (rawMappings is Map) {
      for (final entry in rawMappings.entries) {
        final key = entry.key.toString().trim();
        final department = entry.value is num
            ? (entry.value as num).toInt()
            : int.tryParse(entry.value.toString());
        final rate = double.tryParse(key.replaceAll(',', '.'));
        if (rate == null || rate < 0 || rate > 100) continue;
        if (department == null || department < 1) continue;
        mappings[_vatKey(rate)] = department;
      }
    }

    final name = (json['Name'] as String?)?.trim() ?? '';
    final manufacturer = (json['Manufacturer'] as String?)?.trim() ?? '';
    final model = (json['Model'] as String?)?.trim() ?? '';
    final host = (json['Host'] as String?)?.trim() ?? '';
    final serialPort = (json['SerialPort'] as String?)?.trim() ?? '';
    final id = (json['Id'] as String?)?.trim();
    final rawDriver = (json['DriverId'] as String?)?.trim().toLowerCase();

    return FiscalRegisterProfile(
      id: id?.isNotEmpty == true
          ? id!
          : 'rt-${DateTime.now().microsecondsSinceEpoch}',
      name: name.isEmpty
          ? [manufacturer, model].where((part) => part.isNotEmpty).join(' ')
          : name,
      manufacturer: manufacturer,
      model: model,
      driverId: rawDriver?.isNotEmpty == true ? rawDriver! : 'generic',
      connectionType: connectionType,
      host: connectionType == 'tcp' ? host : '',
      port: rawPort.clamp(1, 65535).toInt(),
      serialPort: connectionType == 'serial' ? serialPort : '',
      baudRate: rawBaudRate.clamp(300, 921600).toInt(),
      enabled: json['Enabled'] as bool? ?? true,
      isDefault: json['IsDefault'] as bool? ?? false,
      vatDepartments: Map.unmodifiable(mappings),
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Manufacturer': manufacturer,
        'Model': model,
        'DriverId': driverId,
        'ConnectionType': connectionType,
        'Host': host,
        'Port': port,
        'SerialPort': serialPort,
        'BaudRate': baudRate,
        'Enabled': enabled,
        'IsDefault': isDefault,
        'VatDepartments': vatDepartments,
      };

  FiscalRegisterProfile copyWith({
    String? id,
    String? name,
    String? manufacturer,
    String? model,
    String? driverId,
    String? connectionType,
    String? host,
    int? port,
    String? serialPort,
    int? baudRate,
    bool? enabled,
    bool? isDefault,
    Map<String, int>? vatDepartments,
  }) =>
      FiscalRegisterProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        manufacturer: manufacturer ?? this.manufacturer,
        model: model ?? this.model,
        driverId: driverId ?? this.driverId,
        connectionType: connectionType ?? this.connectionType,
        host: host ?? this.host,
        port: port ?? this.port,
        serialPort: serialPort ?? this.serialPort,
        baudRate: baudRate ?? this.baudRate,
        enabled: enabled ?? this.enabled,
        isDefault: isDefault ?? this.isDefault,
        vatDepartments: vatDepartments ?? this.vatDepartments,
      );

  static String _vatKey(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) return rounded.toInt().toString();
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class FiscalReceiptLine {
  const FiscalReceiptLine({
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.grossTotalCents,
    required this.finalTotalCents,
    required this.vatPercent,
    this.department,
  });

  final String description;
  final int quantity;
  final int unitPriceCents;
  final int grossTotalCents;
  final int finalTotalCents;
  final double vatPercent;
  final int? department;
}

class FiscalReceiptRequest {
  const FiscalReceiptRequest({
    required this.lines,
    required this.grossTotalCents,
    required this.finalTotalCents,
    required this.amountDueCents,
    this.giftCardAppliedCents = 0,
  });

  final List<FiscalReceiptLine> lines;
  final int grossTotalCents;
  final int finalTotalCents;
  final int amountDueCents;
  final int giftCardAppliedCents;
}

class FiscalReceiptResult {
  const FiscalReceiptResult({
    required this.emittedAtUtc,
    this.documentNumber,
    this.deviceSerialNumber,
    this.reference,
  });

  final DateTime emittedAtUtc;
  final String? documentNumber;
  final String? deviceSerialNumber;
  final String? reference;
}
