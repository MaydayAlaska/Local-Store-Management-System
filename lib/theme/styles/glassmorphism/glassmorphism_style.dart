import 'package:flutter/material.dart';

import '../../ui_style.dart';
import '../../ui_style_tokens.dart';

class GlassmorphismStyle implements AppUiStyle {
  const GlassmorphismStyle();

  static const styleId = 'glassmorphism';

  @override
  String get id => styleId;

  @override
  String get label => 'Glassmorphism';

  @override
  ThemeData lightTheme() => _build(Brightness.light, _lightTokens);

  @override
  ThemeData darkTheme() => _build(Brightness.dark, _darkTokens);

  static const _lightTokens = UiStyleTokens(
    backgroundStart: Color(0xFFE9F2FF),
    backgroundMiddle: Color(0xFFF5EEFF),
    backgroundEnd: Color(0xFFE8FAF7),
    glowPrimary: Color(0x553A86FF),
    glowSecondary: Color(0x44B95CFF),
    glowTertiary: Color(0x3D37D6B0),
    cardSurface: Color(0x8FFFFFFF),
    strongSurface: Color(0xFAFFFFFF),
    subtleSurface: Color(0x70FFFFFF),
    surfaceBase: Colors.white,
    surfaceOpacity: 0.42,
    contentSurfaceOpacity: 0.24,
    notificationSurfaceOpacity: 0.58,
    border: Color(0xA8FFFFFF),
    softBorder: Color(0x72FFFFFF),
    shadow: Color(0x0F000000),
    menuSurface: Color(0xE8FFFFFF),
    menuBorder: Color(0xB8FFFFFF),
    menuShadow: Color(0x29000000),
    tooltipSurface: Color(0xFAFFFFFF),
    tooltipBorder: Color(0xA8FFFFFF),
    tooltipShadow: Color(0x2E000000),
    imagePreviewSurface: Color(0x75FFFFFF),
    captionHover: Color(0x57FFFFFF),
    surfaceBlur: 22,
    menuBlur: 30,
  );

  static const _darkTokens = UiStyleTokens(
    backgroundStart: Color(0xFF101521),
    backgroundMiddle: Color(0xFF151A2B),
    backgroundEnd: Color(0xFF101821),
    glowPrimary: Color(0x553A86FF),
    glowSecondary: Color(0x44B95CFF),
    glowTertiary: Color(0x3D37D6B0),
    cardSurface: Color(0x1FFFFFFF),
    strongSurface: Color(0xF2232936),
    subtleSurface: Color(0x14FFFFFF),
    surfaceBase: Colors.white,
    surfaceOpacity: 0.10,
    contentSurfaceOpacity: 0.055,
    notificationSurfaceOpacity: 0.18,
    border: Color(0x38FFFFFF),
    softBorder: Color(0x24FFFFFF),
    shadow: Color(0x2E000000),
    menuSurface: Color(0xE0212836),
    menuBorder: Color(0x55FFFFFF),
    menuShadow: Color(0x61000000),
    tooltipSurface: Color(0xF2232936),
    tooltipBorder: Color(0x38FFFFFF),
    tooltipShadow: Color(0x6B000000),
    imagePreviewSurface: Color(0x57000000),
    captionHover: Color(0x1AFFFFFF),
    surfaceBlur: 22,
    menuBlur: 30,
  );

  ThemeData _build(Brightness brightness, UiStyleTokens tokens) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xFF8EBBFF) : const Color(0xFF315FCE),
      brightness: brightness,
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: tokens.border),
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(tokens.strongSurface),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(tokens.tooltipShadow),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(menuShape),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: tokens.strongSurface,
      visualDensity: VisualDensity.compact,
      extensions: <ThemeExtension<dynamic>>[tokens],
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.subtleSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: inputBorder(tokens.softBorder),
        enabledBorder: inputBorder(tokens.softBorder),
        focusedBorder: inputBorder(
          scheme.primary.withValues(alpha: 0.7),
          width: 1.5,
        ),
        errorBorder: inputBorder(scheme.error.withValues(alpha: 0.75)),
        focusedErrorBorder: inputBorder(scheme.error, width: 1.5),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
        ),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.softBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? const Color(0xFA1E2430) : const Color(0xFAFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.tooltipShadow,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: tokens.border),
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.strongSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: tokens.tooltipShadow,
        shape: menuShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xE9232936) : const Color(0xF7FFFFFF),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.34)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedTileColor:
            scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
      ),
    );
  }
}
