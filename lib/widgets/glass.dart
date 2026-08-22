import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ui_layout_tokens.dart';
import '../theme/ui_style_tokens.dart';

enum GlassSurfaceRole { standard, content, notification }

class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiStyleTokens.of(context);
    final layout = UiLayoutTokens.of(context);
    final backgroundImagePath = tokens.backgroundImagePath;
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
          if (backgroundImagePath != null)
            IgnorePointer(
              child: Opacity(
                opacity: tokens.backgroundImageOpacity,
                child: Image.file(
                  File(backgroundImagePath),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          if (layout.backgroundPattern != 'none' &&
              layout.patternOpacity > 0)
            IgnorePointer(
              child: CustomPaint(
                painter: _StylePatternPainter(
                  pattern: layout.backgroundPattern,
                  color: tokens.softBorder.withValues(
                    alpha: layout.patternOpacity,
                  ),
                ),
              ),
            ),
          if (layout.surfaceStyle == 'glass') ...[
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
          ] else if (layout.surfaceStyle == 'neon') ...[
            _GlowOrb(
              alignment: const Alignment(-1.1, -0.9),
              size: 320,
              color: tokens.glowPrimary,
            ),
            _GlowOrb(
              alignment: const Alignment(1.1, 1.0),
              size: 300,
              color: tokens.glowTertiary,
            ),
          ],
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
    final theme = Theme.of(context);
    final tokens = UiStyleTokens.of(context);
    final layout = UiLayoutTokens.of(context);
    final effectiveOpacity = opacity ?? _roleOpacity(tokens);
    final effectiveBlur = blur ?? tokens.surfaceBlur;
    final effectiveRadius = layout.surfaceStyle == 'glass'
        ? borderRadius
        : BorderRadius.circular(layout.panelRadius);
    final surfaceColor =
        tokens.surfaceBase.withValues(alpha: effectiveOpacity);
    final border = layout.surfaceStyle == 'flat' || layout.borderWidth == 0
        ? null
        : Border.all(color: tokens.border, width: layout.borderWidth);

    final shadows = switch (layout.surfaceStyle) {
      'raised' => <BoxShadow>[
          BoxShadow(
            color: tokens.shadow,
            blurRadius: layout.surfaceElevation,
            offset: Offset(
              layout.surfaceElevation * 0.35,
              layout.surfaceElevation * 0.45,
            ),
          ),
          BoxShadow(
            color: tokens.border.withValues(alpha: 0.30),
            blurRadius: layout.surfaceElevation * 0.75,
            offset: Offset(
              -layout.surfaceElevation * 0.22,
              -layout.surfaceElevation * 0.28,
            ),
          ),
        ],
      'paper' => <BoxShadow>[
          BoxShadow(
            color: tokens.shadow,
            blurRadius: math.max(4.0, layout.surfaceElevation),
            offset: const Offset(0, 4),
          ),
        ],
      'neon' => <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: math.max(8.0, layout.surfaceElevation),
          ),
          BoxShadow(
            color: tokens.shadow,
            blurRadius: math.max(6.0, layout.surfaceElevation * 0.7),
            offset: const Offset(0, 5),
          ),
        ],
      'outlined' => const <BoxShadow>[],
      'flat' => const <BoxShadow>[],
      _ => <BoxShadow>[
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
    };

    Widget decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: effectiveRadius,
        border: border,
        boxShadow: shadows,
      ),
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );

    if (layout.surfaceStyle == 'glass') {
      decorated = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: decorated,
      );
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: decorated,
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

class _StylePatternPainter extends CustomPainter {
  const _StylePatternPainter({
    required this.pattern,
    required this.color,
  });

  final String pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    switch (pattern) {
      case 'grid':
        const step = 28.0;
        for (double x = 0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 'dots':
        const step = 24.0;
        for (double x = 12; x <= size.width; x += step) {
          for (double y = 12; y <= size.height; y += step) {
            canvas.drawCircle(Offset(x, y), 1.2, paint);
          }
        }
        break;
      case 'stripes':
        const step = 32.0;
        for (double x = -size.height; x <= size.width; x += step) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height, 0),
            paint,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StylePatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.color != color;
}
