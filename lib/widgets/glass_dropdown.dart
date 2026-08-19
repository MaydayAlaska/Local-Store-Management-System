import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GlassDropdownItem<T> {
  const GlassDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T? value;
  final String label;
  final IconData? icon;
}

class GlassDropdown<T> extends StatefulWidget {
  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
    this.enabled = true,
    this.hintText,
    this.maxMenuHeight = 280,
  });

  final T? value;
  final List<GlassDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String labelText;
  final bool enabled;
  final String? hintText;
  final double maxMenuHeight;

  @override
  State<GlassDropdown<T>> createState() => _GlassDropdownState<T>();
}

class _GlassDropdownState<T> extends State<GlassDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  OverlayEntry? _entry;

  bool get _enabled => widget.enabled && widget.onChanged != null && widget.items.isNotEmpty;

  @override
  void dispose() {
    _close(notify: false);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GlassDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry != null && (!_enabled || oldWidget.items != widget.items || oldWidget.value != widget.value)) {
      _close();
    }
  }

  GlassDropdownItem<T>? _selectedItem() {
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  void _toggle() {
    if (!_enabled) return;
    if (_entry == null) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    final targetBox = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;

    final targetSize = targetBox.size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: targetSize.width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xE0212836) : const Color(0xE8FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0x55FFFFFF) : const Color(0xB8FFFFFF),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(6),
                        children: widget.items.map((item) {
                          final selected = item.value == widget.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: selected
                                  ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  widget.onChanged?.call(item.value);
                                  _close();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        Icon(
                                          item.icon,
                                          size: 18,
                                          color: selected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.check_rounded, size: 18, color: theme.colorScheme.primary),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);
    setState(() {});
  }

  void _close({bool notify = true}) {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    if (notify && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem();
    return CompositedTransformTarget(
      key: _targetKey,
      link: _layerLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _enabled ? _toggle : null,
        child: InputDecorator(
          isEmpty: selected == null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: widget.labelText,
            suffixIcon: Icon(
              _entry == null ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
            ),
          ),
          child: Text(
            selected?.label ?? widget.hintText ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _enabled
                ? null
                : Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
          ),
        ),
      ),
    );
  }
}
