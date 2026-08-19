class LabelPrinterProfile {
  const LabelPrinterProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 9100,
    this.protocol = 'bpl-z',
    this.dpi = 203,
    this.defaultWidthMm = 40,
    this.defaultHeightMm = 30,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final int dpi;
  final double defaultWidthMm;
  final double defaultHeightMm;
  final bool enabled;

  static const supportedProtocols = ['bpl-z'];

  static const legacyApiX110 = LabelPrinterProfile(
    id: 'apix110-default',
    name: 'BIXOLON ApiX110 (rete)',
    host: '192.168.1.63',
    port: 9100,
    protocol: 'bpl-z',
    dpi: 203,
    defaultWidthMm: 40,
    defaultHeightMm: 30,
  );

  String get url =>
      'tcp://$host:$port?profile=${Uri.encodeQueryComponent(id)}';

  String get protocolLabel => protocol == 'bpl-z' ? 'BPL-Z / ZPL' : protocol;

  factory LabelPrinterProfile.fromJson(Map<String, dynamic> json) {
    final rawProtocol = (json['Protocol'] as String?)?.trim().toLowerCase();
    final protocol = supportedProtocols.contains(rawProtocol)
        ? rawProtocol!
        : 'bpl-z';
    final rawPort = (json['Port'] as num?)?.toInt() ?? 9100;
    final rawDpi = (json['Dpi'] as num?)?.toInt() ?? 203;
    final rawWidth = (json['DefaultWidthMm'] as num?)?.toDouble() ?? 40;
    final rawHeight = (json['DefaultHeightMm'] as num?)?.toDouble() ?? 30;
    final host = (json['Host'] as String?)?.trim() ?? '';
    final name = (json['Name'] as String?)?.trim() ?? '';
    final id = (json['Id'] as String?)?.trim();

    return LabelPrinterProfile(
      id: id?.isNotEmpty == true
          ? id!
          : 'tcp-${host.toLowerCase()}-$rawPort',
      name: name.isEmpty ? host : name,
      host: host,
      port: rawPort.clamp(1, 65535),
      protocol: protocol,
      dpi: rawDpi.clamp(100, 600),
      defaultWidthMm: rawWidth.clamp(20, 120),
      defaultHeightMm: rawHeight.clamp(15, 200),
      enabled: json['Enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'Host': host,
        'Port': port,
        'Protocol': protocol,
        'Dpi': dpi,
        'DefaultWidthMm': defaultWidthMm,
        'DefaultHeightMm': defaultHeightMm,
        'Enabled': enabled,
      };

  LabelPrinterProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? protocol,
    int? dpi,
    double? defaultWidthMm,
    double? defaultHeightMm,
    bool? enabled,
  }) =>
      LabelPrinterProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
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
    this.labelPrinterProfiles = const [LabelPrinterProfile.legacyApiX110],
    this.currencyCode = 'EUR',
    this.themeMode = 'system',
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
  final String currencyCode;
  final String themeMode;
  final String languageCode;

  static const supportedCurrencies = ['EUR', 'USD', 'GBP', 'CHF'];
  static const supportedThemeModes = ['system', 'light', 'dark'];
  static const supportedLanguages = ['it', 'en'];

  static const defaults = AppSettings(shopName: 'Negozio');

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final currency = (json['CurrencyCode'] as String?)?.trim().toUpperCase();
    final theme = (json['ThemeMode'] as String?)?.trim().toLowerCase();
    final language = (json['LanguageCode'] as String?)?.trim().toLowerCase();

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
            .where((profile) => profile.host.trim().isNotEmpty)
            .toList(growable: false)
        : defaults.labelPrinterProfiles;

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
      currencyCode: supportedCurrencies.contains(currency) ? currency! : 'EUR',
      themeMode: supportedThemeModes.contains(theme) ? theme! : 'system',
      languageCode: supportedLanguages.contains(language) ? language! : 'it',
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
        'LabelPrinters': labelPrinterProfiles.map((profile) => profile.toJson()).toList(),
        'CurrencyCode': currencyCode,
        'ThemeMode': themeMode,
        'LanguageCode': languageCode,
      };

  LabelPrinterProfile? labelPrinterForUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'tcp') return null;

    final profileId = uri.queryParameters['profile'];
    if (profileId != null && profileId.isNotEmpty) {
      for (final profile in labelPrinterProfiles) {
        if (profile.id == profileId) return profile;
      }
    }

    for (final profile in labelPrinterProfiles) {
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
    String? currencyCode,
    String? themeMode,
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
        currencyCode: currencyCode ?? this.currencyCode,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
      );
}
