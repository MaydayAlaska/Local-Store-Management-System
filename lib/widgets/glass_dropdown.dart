import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

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
  late List<GlassDropdownItem<T>> _items;
  bool _refreshingLanguages = false;

  bool get _enabled =>
      widget.enabled && widget.onChanged != null && _items.isNotEmpty;

  bool get _isLanguagePicker => widget.labelText == AppStrings.t('language');

  @override
  void initState() {
    super.initState();
    _items = List<GlassDropdownItem<T>>.of(widget.items);
  }

  @override
  void dispose() {
    _close(notify: false);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GlassDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = oldWidget.items != widget.items;
    if (itemsChanged) {
      _items = List<GlassDropdownItem<T>>.of(widget.items);
    }
    if (_entry != null &&
        (!_enabled ||
            itemsChanged ||
            oldWidget.value != widget.value)) {
      _close();
    }
  }

  GlassDropdownItem<T>? _selectedItem() {
    for (final item in _items) {
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

  Future<void> _refreshLanguages() async {
    if (_refreshingLanguages) return;
    setState(() => _refreshingLanguages = true);
    try {
      await AppStrings.reload();
      if (!mounted) return;

      final refreshedItems = AppStrings.languages
          .map(
            (language) => GlassDropdownItem<T>(
              value: language.code as T,
              label: language.nativeName,
            ),
          )
          .toList(growable: false);

      _items = refreshedItems;
      final selectedStillExists =
          _items.any((item) => item.value == widget.value);
      if (!selectedStillExists) {
        widget.onChanged?.call(AppStrings.fallbackLanguageCode as T);
      }
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.t('error')}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshingLanguages = false);
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    final targetBox =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
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
                      constraints:
                          BoxConstraints(maxHeight: widget.maxMenuHeight),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xE0212836)
                            : const Color(0xE8FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x55FFFFFF)
                              : const Color(0xB8FFFFFF),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.38 : 0.16,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(6),
                        children: _items.map((item) {
                          final selected = item.value == widget.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: selected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: isDark ? 0.25 : 0.14,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  widget.onChanged?.call(item.value);
                                  _close();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      if (item.icon != null) ...[
                                        Icon(
                                          item.icon,
                                          size: 18,
                                          color: selected
                                              ? theme.colorScheme.primary
                                              : theme
                                                  .colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
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

  Widget _buildDropdown(BuildContext context) {
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
              _entry == null
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
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

  @override
  Widget build(BuildContext context) {
    final dropdown = _buildDropdown(context);
    if (!_isLanguagePicker) return dropdown;

    return Row(
      children: [
        Expanded(child: dropdown),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: AppStrings.pair('Aggiorna lingue', 'Refresh languages'),
          onPressed: _refreshingLanguages ? null : _refreshLanguages,
          icon: _refreshingLanguages
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
      ],
    );
  }
}
