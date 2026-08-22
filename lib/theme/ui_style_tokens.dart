import 'package:flutter/material.dart';

@immutable
class UiStyleTokens extends ThemeExtension<UiStyleTokens> {
  const UiStyleTokens({
    required this.backgroundStart,
    required this.backgroundMiddle,
    required this.backgroundEnd,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.glowTertiary,
    required this.cardSurface,
    required this.strongSurface,
    required this.subtleSurface,
    required this.surfaceBase,
    required this.surfaceOpacity,
    required this.contentSurfaceOpacity,
    required this.notificationSurfaceOpacity,
    required this.border,
    required this.softBorder,
    required this.shadow,
    required this.menuSurface,
    required this.menuBorder,
    required this.menuShadow,
    required this.tooltipSurface,
    required this.tooltipBorder,
    required this.tooltipShadow,
    required this.imagePreviewSurface,
    required this.captionHover,
    required this.surfaceBlur,
    required this.menuBlur,
    this.backgroundImagePath,
    this.backgroundImageOpacity = 1,
  });

  final Color backgroundStart;
  final Color backgroundMiddle;
  final Color backgroundEnd;
  final Color glowPrimary;
  final Color glowSecondary;
  final Color glowTertiary;
  final Color cardSurface;
  final Color strongSurface;
  final Color subtleSurface;
  final Color surfaceBase;
  final double surfaceOpacity;
  final double contentSurfaceOpacity;
  final double notificationSurfaceOpacity;
  final Color border;
  final Color softBorder;
  final Color shadow;
  final Color menuSurface;
  final Color menuBorder;
  final Color menuShadow;
  final Color tooltipSurface;
  final Color tooltipBorder;
  final Color tooltipShadow;
  final Color imagePreviewSurface;
  final Color captionHover;
  final double surfaceBlur;
  final double menuBlur;
  final String? backgroundImagePath;
  final double backgroundImageOpacity;

  List<Color> get backgroundGradient => [
        backgroundStart,
        backgroundMiddle,
        backgroundEnd,
      ];

  static UiStyleTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<UiStyleTokens>();
    assert(tokens != null, 'UiStyleTokens non installati nel ThemeData corrente.');
    return tokens!;
  }

  @override
  UiStyleTokens copyWith({
    Color? backgroundStart,
    Color? backgroundMiddle,
    Color? backgroundEnd,
    Color? glowPrimary,
    Color? glowSecondary,
    Color? glowTertiary,
    Color? cardSurface,
    Color? strongSurface,
    Color? subtleSurface,
    Color? surfaceBase,
    double? surfaceOpacity,
    double? contentSurfaceOpacity,
    double? notificationSurfaceOpacity,
    Color? border,
    Color? softBorder,
    Color? shadow,
    Color? menuSurface,
    Color? menuBorder,
    Color? menuShadow,
    Color? tooltipSurface,
    Color? tooltipBorder,
    Color? tooltipShadow,
    Color? imagePreviewSurface,
    Color? captionHover,
    double? surfaceBlur,
    double? menuBlur,
    String? backgroundImagePath,
    double? backgroundImageOpacity,
  }) =>
      UiStyleTokens(
        backgroundStart: backgroundStart ?? this.backgroundStart,
        backgroundMiddle: backgroundMiddle ?? this.backgroundMiddle,
        backgroundEnd: backgroundEnd ?? this.backgroundEnd,
        glowPrimary: glowPrimary ?? this.glowPrimary,
        glowSecondary: glowSecondary ?? this.glowSecondary,
        glowTertiary: glowTertiary ?? this.glowTertiary,
        cardSurface: cardSurface ?? this.cardSurface,
        strongSurface: strongSurface ?? this.strongSurface,
        subtleSurface: subtleSurface ?? this.subtleSurface,
        surfaceBase: surfaceBase ?? this.surfaceBase,
        surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
        contentSurfaceOpacity:
            contentSurfaceOpacity ?? this.contentSurfaceOpacity,
        notificationSurfaceOpacity:
            notificationSurfaceOpacity ?? this.notificationSurfaceOpacity,
        border: border ?? this.border,
        softBorder: softBorder ?? this.softBorder,
        shadow: shadow ?? this.shadow,
        menuSurface: menuSurface ?? this.menuSurface,
        menuBorder: menuBorder ?? this.menuBorder,
        menuShadow: menuShadow ?? this.menuShadow,
        tooltipSurface: tooltipSurface ?? this.tooltipSurface,
        tooltipBorder: tooltipBorder ?? this.tooltipBorder,
        tooltipShadow: tooltipShadow ?? this.tooltipShadow,
        imagePreviewSurface: imagePreviewSurface ?? this.imagePreviewSurface,
        captionHover: captionHover ?? this.captionHover,
        surfaceBlur: surfaceBlur ?? this.surfaceBlur,
        menuBlur: menuBlur ?? this.menuBlur,
        backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
        backgroundImageOpacity:
            backgroundImageOpacity ?? this.backgroundImageOpacity,
      );

  @override
  UiStyleTokens lerp(covariant UiStyleTokens? other, double t) {
    if (other == null) return this;
    double lerpDouble(double a, double b) => a + (b - a) * t;
    return UiStyleTokens(
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t)!,
      backgroundMiddle:
          Color.lerp(backgroundMiddle, other.backgroundMiddle, t)!,
      backgroundEnd: Color.lerp(backgroundEnd, other.backgroundEnd, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowSecondary: Color.lerp(glowSecondary, other.glowSecondary, t)!,
      glowTertiary: Color.lerp(glowTertiary, other.glowTertiary, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      strongSurface: Color.lerp(strongSurface, other.strongSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceOpacity: lerpDouble(surfaceOpacity, other.surfaceOpacity),
      contentSurfaceOpacity:
          lerpDouble(contentSurfaceOpacity, other.contentSurfaceOpacity),
      notificationSurfaceOpacity: lerpDouble(
        notificationSurfaceOpacity,
        other.notificationSurfaceOpacity,
      ),
      border: Color.lerp(border, other.border, t)!,
      softBorder: Color.lerp(softBorder, other.softBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      menuSurface: Color.lerp(menuSurface, other.menuSurface, t)!,
      menuBorder: Color.lerp(menuBorder, other.menuBorder, t)!,
      menuShadow: Color.lerp(menuShadow, other.menuShadow, t)!,
      tooltipSurface: Color.lerp(tooltipSurface, other.tooltipSurface, t)!,
      tooltipBorder: Color.lerp(tooltipBorder, other.tooltipBorder, t)!,
      tooltipShadow: Color.lerp(tooltipShadow, other.tooltipShadow, t)!,
      imagePreviewSurface:
          Color.lerp(imagePreviewSurface, other.imagePreviewSurface, t)!,
      captionHover: Color.lerp(captionHover, other.captionHover, t)!,
      surfaceBlur: lerpDouble(surfaceBlur, other.surfaceBlur),
      menuBlur: lerpDouble(menuBlur, other.menuBlur),
      backgroundImagePath:
          t < 0.5 ? backgroundImagePath : other.backgroundImagePath,
      backgroundImageOpacity:
          lerpDouble(backgroundImageOpacity, other.backgroundImageOpacity),
    );
  }
}
