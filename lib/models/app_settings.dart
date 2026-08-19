class AppSettings {
  const AppSettings({
    required this.shopName,
    this.iconFileName,
    this.logoFileName,
    this.showShopNameInMenu = true,
    this.showLogoInMenu = false,
    this.lastLabelPrinterUrl,
    this.lastLabelPrinterName,
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
        'CurrencyCode': currencyCode,
        'ThemeMode': themeMode,
        'LanguageCode': languageCode,
      };

  AppSettings copyWith({
    String? shopName,
    String? iconFileName,
    String? logoFileName,
    bool? showShopNameInMenu,
    bool? showLogoInMenu,
    String? lastLabelPrinterUrl,
    String? lastLabelPrinterName,
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
        currencyCode: currencyCode ?? this.currencyCode,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
      );
}
