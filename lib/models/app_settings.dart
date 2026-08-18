class AppSettings {
  const AppSettings({
    required this.shopName,
    this.iconFileName,
    this.logoFileName,
    this.showShopNameInMenu = true,
    this.showLogoInMenu = false,
  });

  final String shopName;
  final String? iconFileName;
  final String? logoFileName;
  final bool showShopNameInMenu;
  final bool showLogoInMenu;

  static const defaults = AppSettings(shopName: 'Negozio');

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        shopName: (json['ShopName'] as String?)?.trim().isNotEmpty == true
            ? (json['ShopName'] as String).trim()
            : defaults.shopName,
        iconFileName: json['IconFileName'] as String?,
        logoFileName: json['LogoFileName'] as String?,
        showShopNameInMenu: json['ShowShopNameInMenu'] as bool? ?? true,
        showLogoInMenu: json['ShowLogoInMenu'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'ShopName': shopName,
        'IconFileName': iconFileName,
        'LogoFileName': logoFileName,
        'ShowShopNameInMenu': showShopNameInMenu,
        'ShowLogoInMenu': showLogoInMenu,
      };

  AppSettings copyWith({
    String? shopName,
    String? iconFileName,
    String? logoFileName,
    bool? showShopNameInMenu,
    bool? showLogoInMenu,
  }) => AppSettings(
        shopName: shopName ?? this.shopName,
        iconFileName: iconFileName ?? this.iconFileName,
        logoFileName: logoFileName ?? this.logoFileName,
        showShopNameInMenu: showShopNameInMenu ?? this.showShopNameInMenu,
        showLogoInMenu: showLogoInMenu ?? this.showLogoInMenu,
      );
}
