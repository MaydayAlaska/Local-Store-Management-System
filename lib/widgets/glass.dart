import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ui_style_tokens.dart';

enum GlassSurfaceRole { standard, content, notification }

class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiStyleTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.backgroundGradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GlowOrb(
            alignment: const Alignment(-1.15, -1.05),
            size: 430,
            color: tokens.glowPrimary,
          ),
          _GlowOrb(
            alignment: const Alignment(1.10, -0.65),
            size: 360,
            color: tokens.glowSecondary,
          ),
          _GlowOrb(
            alignment: const Alignment(0.55, 1.15),
            size: 430,
            color: tokens.glowTertiary,
          ),
          child,
        ],
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.padding,
    this.blur,
    this.opacity,
    this.role = GlassSurfaceRole.standard,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? blur;
  final double? opacity;
  final GlassSurfaceRole role;

  double _roleOpacity(UiStyleTokens tokens) => switch (role) {
        GlassSurfaceRole.standard => tokens.surfaceOpacity,
        GlassSurfaceRole.content => tokens.contentSurfaceOpacity,
        GlassSurfaceRole.notification => tokens.notificationSurfaceOpacity,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = UiStyleTokens.of(context);
    final effectiveOpacity = opacity ?? _roleOpacity(tokens);
    final effectiveBlur = blur ?? tokens.surfaceBlur;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surfaceBase.withValues(alpha: effectiveOpacity),
            borderRadius: borderRadius,
            border: Border.all(color: tokens.border),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      );
}
