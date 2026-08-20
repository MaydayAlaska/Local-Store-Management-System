import 'package:flutter/material.dart';

class GlassTheme {
  const GlassTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xFF8EBBFF) : const Color(0xFF315FCE),
      brightness: brightness,
    );

    final glass = isDark ? const Color(0x1FFFFFFF) : const Color(0x8FFFFFFF);
    final glassStrong = isDark ? const Color(0xF2232936) : const Color(0xFAFFFFFF);
    final glassSubtle = isDark ? const Color(0x14FFFFFF) : const Color(0x70FFFFFF);
    final border = isDark ? const Color(0x38FFFFFF) : const Color(0xA8FFFFFF);
    final softBorder = isDark ? const Color(0x24FFFFFF) : const Color(0x72FFFFFF);

    OutlineInputBorder inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border),
    );
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(glassStrong),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(
        Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
      ),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(menuShape),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      // DropdownButton/DropdownButtonFormField usano ancora canvasColor per
      // la superficie del menu. Non deve quindi essere trasparente.
      canvasColor: glassStrong,
      visualDensity: VisualDensity.compact,
      cardTheme: CardThemeData(
        color: glass,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: glassSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: inputBorder(softBorder),
        enabledBorder: inputBorder(softBorder),
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
        color: softBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFA1E2430) : const Color(0xFAFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border),
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: glassStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.18),
        shape: menuShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xE9232936) : const Color(0xF7FFFFFF),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
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
        selectedTileColor: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
      ),
    );
  }
}
