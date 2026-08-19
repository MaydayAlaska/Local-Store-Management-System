import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
                    tooltip: 'Riduci a icona',
                    icon: Icons.remove,
                    onPressed: () => windowManager.minimize(),
                  ),
                  _CaptionButton(
                    tooltip: 'Massimizza / ripristina',
                    icon: Icons.crop_square_rounded,
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  _CaptionButton(
                    tooltip: 'Chiudi',
                    icon: Icons.close,
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

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
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
        icon: Icon(icon, size: 17),
      ),
    );
  }
}
