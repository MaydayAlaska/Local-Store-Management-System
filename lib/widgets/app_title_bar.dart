import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_strings.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(child: const SizedBox.expand()),
            ),
            Transform.translate(
              offset: const Offset(0, -6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CaptionButton(
                    tooltip: AppStrings.t('minimize'),
                    glyph: _WindowGlyph.minimize,
                    onPressed: () => windowManager.minimize(),
                  ),
                  _CaptionButton(
                    tooltip: AppStrings.t('maximize_restore'),
                    glyph: _WindowGlyph.maximize,
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  _CaptionButton(
                    tooltip: AppStrings.t('close'),
                    glyph: _WindowGlyph.close,
                    danger: true,
                    onPressed: () => windowManager.close(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

enum _WindowGlyph { minimize, maximize, close }

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.tooltip,
    required this.glyph,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final _WindowGlyph glyph;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 40,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        hoverColor: danger
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.78)
            : Colors.white.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.10 : 0.34,
              ),
        icon: CustomPaint(
          size: const Size.square(18),
          painter: _WindowGlyphPainter(
            glyph: glyph,
            color: danger
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _WindowGlyphPainter extends CustomPainter {
  const _WindowGlyphPainter({required this.glyph, required this.color});

  final _WindowGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case _WindowGlyph.minimize:
        canvas.drawLine(
          Offset(size.width * 0.24, size.height * 0.58),
          Offset(size.width * 0.76, size.height * 0.58),
          paint,
        );
      case _WindowGlyph.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * 0.25,
              size.height * 0.23,
              size.width * 0.50,
              size.height * 0.50,
            ),
            const Radius.circular(1.6),
          ),
          paint,
        );
      case _WindowGlyph.close:
        canvas.drawLine(
          Offset(size.width * 0.29, size.height * 0.29),
          Offset(size.width * 0.71, size.height * 0.71),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.71, size.height * 0.29),
          Offset(size.width * 0.29, size.height * 0.71),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _WindowGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
