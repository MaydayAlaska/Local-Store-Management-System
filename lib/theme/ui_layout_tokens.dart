import 'package:flutter/material.dart';

@immutable
class UiLayoutTokens extends ThemeExtension<UiLayoutTokens> {
  const UiLayoutTokens({
    this.navigation = 'rail',
    this.surfaceStyle = 'glass',
    this.backgroundPattern = 'none',
    this.shellPadding = 10,
    this.shellGap = 10,
    this.navigationExtent = 116,
    this.pageRadius = 24,
    this.panelRadius = 22,
    this.navItemRadius = 14,
    this.borderWidth = 1,
    this.surfaceElevation = 12,
    this.patternOpacity = 0,
    this.showPageFrame = true,
    this.compactBrand = false,
    this.dense = true,
    this.monochrome = false,
  });

  final String navigation;
  final String surfaceStyle;
  final String backgroundPattern;
  final double shellPadding;
  final double shellGap;
  final double navigationExtent;
  final double pageRadius;
  final double panelRadius;
  final double navItemRadius;
  final double borderWidth;
  final double surfaceElevation;
  final double patternOpacity;
  final bool showPageFrame;
  final bool compactBrand;
  final bool dense;
  final bool monochrome;

  static const glassmorphism = UiLayoutTokens();

  static UiLayoutTokens of(BuildContext context) =>
      Theme.of(context).extension<UiLayoutTokens>() ?? glassmorphism;

  @override
  UiLayoutTokens copyWith({
    String? navigation,
    String? surfaceStyle,
    String? backgroundPattern,
    double? shellPadding,
    double? shellGap,
    double? navigationExtent,
    double? pageRadius,
    double? panelRadius,
    double? navItemRadius,
    double? borderWidth,
    double? surfaceElevation,
    double? patternOpacity,
    bool? showPageFrame,
    bool? compactBrand,
    bool? dense,
    bool? monochrome,
  }) =>
      UiLayoutTokens(
        navigation: navigation ?? this.navigation,
        surfaceStyle: surfaceStyle ?? this.surfaceStyle,
        backgroundPattern: backgroundPattern ?? this.backgroundPattern,
        shellPadding: shellPadding ?? this.shellPadding,
        shellGap: shellGap ?? this.shellGap,
        navigationExtent: navigationExtent ?? this.navigationExtent,
        pageRadius: pageRadius ?? this.pageRadius,
        panelRadius: panelRadius ?? this.panelRadius,
        navItemRadius: navItemRadius ?? this.navItemRadius,
        borderWidth: borderWidth ?? this.borderWidth,
        surfaceElevation: surfaceElevation ?? this.surfaceElevation,
        patternOpacity: patternOpacity ?? this.patternOpacity,
        showPageFrame: showPageFrame ?? this.showPageFrame,
        compactBrand: compactBrand ?? this.compactBrand,
        dense: dense ?? this.dense,
        monochrome: monochrome ?? this.monochrome,
      );

  @override
  UiLayoutTokens lerp(covariant UiLayoutTokens? other, double t) {
    if (other == null) return this;
    double lerpDouble(double a, double b) => a + (b - a) * t;
    return UiLayoutTokens(
      navigation: t < 0.5 ? navigation : other.navigation,
      surfaceStyle: t < 0.5 ? surfaceStyle : other.surfaceStyle,
      backgroundPattern: t < 0.5 ? backgroundPattern : other.backgroundPattern,
      shellPadding: lerpDouble(shellPadding, other.shellPadding),
      shellGap: lerpDouble(shellGap, other.shellGap),
      navigationExtent:
          lerpDouble(navigationExtent, other.navigationExtent),
      pageRadius: lerpDouble(pageRadius, other.pageRadius),
      panelRadius: lerpDouble(panelRadius, other.panelRadius),
      navItemRadius: lerpDouble(navItemRadius, other.navItemRadius),
      borderWidth: lerpDouble(borderWidth, other.borderWidth),
      surfaceElevation: lerpDouble(surfaceElevation, other.surfaceElevation),
      patternOpacity: lerpDouble(patternOpacity, other.patternOpacity),
      showPageFrame: t < 0.5 ? showPageFrame : other.showPageFrame,
      compactBrand: t < 0.5 ? compactBrand : other.compactBrand,
      dense: t < 0.5 ? dense : other.dense,
      monochrome: t < 0.5 ? monochrome : other.monochrome,
    );
  }
}
