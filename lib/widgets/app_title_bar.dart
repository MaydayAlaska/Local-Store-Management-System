import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import 'glass.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key, required this.settings, required this.settingsService});

  final AppSettings settings;
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final iconPath = settingsService.resolveIconPreviewPath(settings);
    return GlassSurface(
      blur: 24,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    children: [
                      _AppIcon(path: iconPath),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          settings.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.file(File(path!), width: 25, height: 25, fit: BoxFit.cover),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: SizedBox(
        width: 40,
        height: 34,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          hoverColor: danger
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.78)
              : Colors.white.withValues(alpha: theme.brightness == Brightness.dark ? 0.10 : 0.38),
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
