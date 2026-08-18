import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Local Store Management System',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
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
      );
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.tooltip, required this.icon, required this.onPressed, this.danger = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 42,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        hoverColor: danger
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: theme.brightness == Brightness.dark ? 0.10 : 0.34),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
