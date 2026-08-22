import 'fiscal_register.dart';

class LabelPrinterProfile {
  const LabelPrinterProfile({
    required this.id,
    required this.name,
    this.connectionType = 'tcp',
    this.host = '',
    this.port = 9100,
    this.systemPrinterUrl,
    this.systemPrinterName,
    this.protocol = 'bpl-z',
    this.dpi = 203,
    this.defaultWidthMm = 40,
    this.defaultHeightMm = 30,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String connectionType;
  final String host;
  final int port;
  final String? systemPrinterUrl;
  final String? systemPrinterName;
  final String protocol;
  final int dpi;
  final double defaultWidthMm;
  final double defaultHeightMm;
  final bool enabled;

  static const supportedConnectionTypes = ['tcp', 'system'];
  static const supportedProtocols = ['bpl-z'];

  static const legacyApiX110 = LabelPrinterProfile(
    id: 'apix110-default',
    name: 'BIXOLON ApiX110 (rete)',
    connectionType: 'tcp',
    host: '192.168.1.63',
    port: 9100,
    protocol: 'bpl-z',
    dpi: 203,
    defaultWidthMm: 40,
    defaultHeightMm: 30,
  );

  bool get isTcp => connectionType == 'tcp';
  bool get isSystem => connectionType == 'system';

  String get url => isTcp
      ? 'tcp://$host:$port?profile=${Uri.encodeQueryComponent(id)}'
      : (systemPrinterUrl ??
          'system-profile://${Uri.encodeComponent(id)}');

  String get protocolLabel => protocol == 'bpl-z' ? 'BPL-Z / ZPL' : protocol;

  String get connectionLabel => isTcp ? 'TCP/IP' : 'USB / sistema';

  factory LabelPrinterProfile.fromJson(Map<String, dynamic> json) {
    final rawConnection =
        (json['ConnectionType'] as String?)?.trim().toLowerCase();
    final connectionType = supportedConnectionTypes.contains(rawConnection)
        ? rawConnection!
        : 'tcp';
    final rawProtocol = (json['Protocol'] as String?)?.trim().toLowerCase();
    final protocol = supportedProtocols.contains(rawProtocol)
        ? rawProtocol!
        : 'bpl-z';
    final rawPort = (json['Port'] as num?)?.toInt() ?? 9100;
    final rawDpi = (json['Dpi'] as num?)?.toInt() ?? 203;
    final rawWidth = (json['DefaultWidthMm'] as num?)?.toDouble() ?? 40;
    final rawHeight = (json['DefaultHeightMm'] as num?)?.toDouble() ?? 30;
    final host = (json['Host'] as String?)?.trim() ?? '';
    final systemPrinterUrl =
        (json['SystemPrinterUrl'] as String?)?.trim().isNotEmpty == true
            ? (json['SystemPrinterUrl'] as String).trim()
            : null;
    final systemPrinterName =
        (json['SystemPrinterName'] as String?)?.trim().isNotEmpty == true
            ? (json['SystemPrinterName'] as String).trim()
            : null;
    final name = (json['Name'] as String?)?.trim() ?? '';
    final id = (json['Id'] as String?)?.trim();
    final fallbackKey = connectionType == 'tcp'
        ? '${host.toLowerCase()}-$rawPort'
        : (systemPrinterName ?? systemPrinterUrl ?? 'system').toLowerCase();

    return LabelPrinterProfile(
      id: id?.isNotEmpty == true ? id! : '$connectionType-$fallbackKey',
      name: name.isEmpty
          ? (connectionType == 'tcp'
              ? host
              : (systemPrinterName ?? 'Stampante USB'))
          : name,
      connectionType: connectionType,
      host: connectionType == 'tcp' ? host : '',
      port: rawPort.clamp(1, 65535).toInt(),
      systemPrinterUrl: connectionType == 'system' ? systemPrinterUrl : null,
      systemPrinterName: connectionType == 'system' ? systemPrinterName : null,
      protocol: protocol,
      dpi: rawDpi.clamp(100, 600).toInt(),
      defaultWidthMm: rawWidth.clamp(20, 120).toDouble(),
      defaultHeightMm: rawHeight.clamp(15, 200).toDouble(),
      enabled: json['Enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'ConnectionType': connectionType,
        'Host': host,
        'Port': port,
        'SystemPrinterUrl': systemPrinterUrl,
        'SystemPrinterName': systemPrinterName,
        'Protocol': protocol,
        'Dpi': dpi,
        'DefaultWidthMm': defaultWidthMm,
        'DefaultHeightMm': defaultHeightMm,
        'Enabled': enabled,
      };

  LabelPrinterProfile copyWith({
    String? id,
    String? name,
    String? connectionType,
    String? host,
    int? port,
    String? systemPrinterUrl,
    String? systemPrinterName,
    String? protocol,
    int? dpi,
    double? defaultWidthMm,
    double? defaultHeightMm,
    bool? enabled,
  }) =>
      LabelPrinterProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        connectionType: connectionType ?? this.connectionType,
        host: host ?? this.host,
        port: port ?? this.port,
        systemPrinterUrl: systemPrinterUrl ?? this.systemPrinterUrl,
        systemPrinterName: systemPrinterName ?? this.systemPrinterName,
        protocol: protocol ?? this.protocol,
        dpi: dpi ?? this.dpi,
        defaultWidthMm: defaultWidthMm ?? this.defaultWidthMm,
        defaultHeightMm: defaultHeightMm ?? this.defaultHeightMm,
        enabled: enabled ?? this.enabled,
      );
}

class AppSettings {
  const AppSettings({
    required this.shopName,
    this.iconFileName,
    this.logoFileName,
    this.showShopNameInMenu = true,
    this.showLogoInMenu = false,
    this.lastLabelPrinterUrl,
    this.lastLabelPrinterName,
    this.labelPrinterProfiles = const [],
    this.fiscalRegisterProfiles = const [],
    this.currencyCode = 'EUR',
    this.vatPercent = 22,
    this.themeMode = 'system',
    this.uiStyle = 'glassmorphism',
    this.languageCode = 'it',
  });

  final String shopName;
  final String? iconFileName;
  final String? logoFileName;
  final bool showShopNameInMenu;
  final bool showLogoInMenu;
  final String? lastLabelPrinterUrl;
  final String? lastLabelPrinterName;
  final List<LabelPrinterProfile> labelPrinterProfiles;
  final List<FiscalRegisterProfile> fiscalRegisterProfiles;
  final String currencyCode;
  final double vatPercent;
  final String themeMode;
  final String uiStyle;
  final String languageCode;

  static const supportedCurrencies = ['EUR', 'USD', 'GBP', 'CHF'];
  static const supportedThemeModes = ['system', 'light', 'dark'];

  static bool isSafeUiStyleId(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null &&
        RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(normalized);
  }

  static const defaults = AppSettings(shopName: 'Negozio');

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final currency = (json['CurrencyCode'] as String?)?.trim().toUpperCase();
    final rawVatPercent =
        (json['VatPercent'] as num?)?.toDouble() ?? defaults.vatPercent;
    final theme = (json['ThemeMode'] as String?)?.trim().toLowerCase();
    final uiStyle = (json['UiStyle'] as String?)?.trim().toLowerCase();
    final language = (json['LanguageCode'] as String?)
        ?.trim()
        .replaceAll('_', '-')
        .toLowerCase();

    final hasPrinterProfiles = json.containsKey('LabelPrinters');
    final rawProfiles = json['LabelPrinters'];
    final profiles = hasPrinterProfiles && rawProfiles is List
        ? rawProfiles
            .whereType<Map>()
            .map(
              (item) => LabelPrinterProfile.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where(
              (profile) => profile.isTcp
                  ? profile.host.trim().isNotEmpty
                  : (profile.systemPrinterUrl?.trim().isNotEmpty == true ||
                      profile.systemPrinterName?.trim().isNotEmpty == true),
            )
            .toList(growable: false)
        : const <LabelPrinterProfile>[LabelPrinterProfile.legacyApiX110];

    final rawFiscalRegisters = json['FiscalRegisters'];
    final fiscalRegisters = rawFiscalRegisters is List
        ? rawFiscalRegisters
            .whereType<Map>()
            .map(
              (item) => FiscalRegisterProfile.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((profile) => profile.name.trim().isNotEmpty)
            .toList(growable: false)
        : const <FiscalRegisterProfile>[];

    return AppSettings(
      shopName: (json['ShopName'] as String?)?.trim().isNotEmpty == true
          ? (json['ShopName'] as String).trim()
          : defaults.shopName,
      iconFileName: json['IconFileName'] as String?,
      logoFileName: json['LogoFileName'] as String?,
      showShopNameInMenu: json['ShowShopNameInMenu'] as bool? ?? true,
      showLogoInMenu: json['ShowLogoInMenu'] as bool? ?? false,
      lastLabelPrinterUrl:
          (json['LastLabelPrinterUrl'] as String?)?.trim().isNotEmpty == true
              ? (json['LastLabelPrinterUrl'] as String).trim()
              : null,
      lastLabelPrinterName:
          (json['LastLabelPrinterName'] as String?)?.trim().isNotEmpty == true
              ? (json['LastLabelPrinterName'] as String).trim()
              : null,
      labelPrinterProfiles: profiles,
      fiscalRegisterProfiles: fiscalRegisters,
      currencyCode: supportedCurrencies.contains(currency) ? currency! : 'EUR',
      vatPercent: rawVatPercent.clamp(0, 100).toDouble(),
      themeMode: supportedThemeModes.contains(theme) ? theme! : 'system',
      uiStyle: isSafeUiStyleId(uiStyle) ? uiStyle! : defaults.uiStyle,
      languageCode:
          language?.isNotEmpty == true ? language! : defaults.languageCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'ShopName': shopName,
        'IconFileName': iconFileName,
        'LogoFileName': logoFileName,
        'ShowShopNameInMenu': showShopNameInMenu,
        'ShowLogoInMenu': showLogoInMenu,
        'LastLabelPrinterUrl': lastLabelPrinterUrl,
        'LastLabelPrinterName': lastLabelPrinterName,
        'LabelPrinters':
            labelPrinterProfiles.map((profile) => profile.toJson()).toList(),
        'FiscalRegisters':
            fiscalRegisterProfiles.map((profile) => profile.toJson()).toList(),
        'CurrencyCode': currencyCode,
        'VatPercent': vatPercent,
        'ThemeMode': themeMode,
        'UiStyle': uiStyle,
        'LanguageCode': languageCode,
      };

  LabelPrinterProfile? labelPrinterForUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();

    for (final profile in labelPrinterProfiles.where((item) => item.isSystem)) {
      if (profile.systemPrinterUrl == normalized || profile.url == normalized) {
        return profile;
      }
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'tcp') return null;

    final profileId = uri.queryParameters['profile'];
    if (profileId != null && profileId.isNotEmpty) {
      for (final profile in labelPrinterProfiles.where((item) => item.isTcp)) {
        if (profile.id == profileId) return profile;
      }
    }

    for (final profile in labelPrinterProfiles.where((item) => item.isTcp)) {
      if (profile.host.toLowerCase() == uri.host.toLowerCase() &&
          profile.port == uri.port) {
        return profile;
      }
    }
    return null;
  }

  AppSettings copyWith({
    String? shopName,
    String? iconFileName,
    String? logoFileName,
    bool? showShopNameInMenu,
    bool? showLogoInMenu,
    String? lastLabelPrinterUrl,
    String? lastLabelPrinterName,
    List<LabelPrinterProfile>? labelPrinterProfiles,
    List<FiscalRegisterProfile>? fiscalRegisterProfiles,
    String? currencyCode,
    double? vatPercent,
    String? themeMode,
    String? uiStyle,
    String? languageCode,
  }) =>
      AppSettings(
        shopName: shopName ?? this.shopName,
        iconFileName: iconFileName ?? this.iconFileName,
        logoFileName: logoFileName ?? this.logoFileName,
        showShopNameInMenu: showShopNameInMenu ?? this.showShopNameInMenu,
        showLogoInMenu: showLogoInMenu ?? this.showLogoInMenu,
        lastLabelPrinterUrl: lastLabelPrinterUrl ?? this.lastLabelPrinterUrl,
        lastLabelPrinterName: lastLabelPrinterName ?? this.lastLabelPrinterName,
        labelPrinterProfiles: labelPrinterProfiles ?? this.labelPrinterProfiles,
        fiscalRegisterProfiles:
            fiscalRegisterProfiles ?? this.fiscalRegisterProfiles,
        currencyCode: currencyCode ?? this.currencyCode,
        vatPercent: vatPercent ?? this.vatPercent,
        themeMode: themeMode ?? this.themeMode,
        uiStyle: uiStyle ?? this.uiStyle,
        languageCode: languageCode ?? this.languageCode,
      );
}
