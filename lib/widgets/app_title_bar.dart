import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key, required this.settings, required this.settingsService});

  final AppSettings settings;
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconPath = settingsService.resolveIconPath(settings);
    return ColoredBox(
      color: colors.surfaceContainer,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _AppIcon(path: iconPath),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          settings.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
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
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path != null && !path!.toLowerCase().endsWith('.ico')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(path!), width: 24, height: 24, fit: BoxFit.cover),
      );
    }
    return Icon(Icons.storefront_rounded, size: 22, color: Theme.of(context).colorScheme.primary);
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({required this.tooltip, required this.icon, required this.onPressed, this.danger = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 46,
        height: 42,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          hoverColor: danger ? Theme.of(context).colorScheme.errorContainer : null,
          icon: Icon(icon, size: 18),
        ),
      );
}
