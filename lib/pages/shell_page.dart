import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../services/app_services.dart';
import '../services/birth_place_service.dart';
import '../services/update_service.dart';
import '../theme/ui_layout_tokens.dart';
import '../theme/ui_style_tokens.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/glass.dart';
import 'cash_page.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'export_page.dart';
import 'gift_cards_page.dart';
import 'labels_page.dart';
import 'lookups_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'settings_page.dart';
import 'stock_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    required this.services,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppServices services;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  static const _settingsIndex = 10;

  int _index = 0;
  UpdateCheckResult? _startupUpdate;
  OverlayEntry? _updateNotification;
  Timer? _updateNotificationTimer;
  OverlayEntry? _birthPlaceNotification;
  Timer? _birthPlaceNotificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupChecks());
  }

  @override
  void dispose() {
    _updateNotificationTimer?.cancel();
    _updateNotification?.remove();
    _birthPlaceNotificationTimer?.cancel();
    _birthPlaceNotification?.remove();
    super.dispose();
  }

  Future<void> _runStartupChecks() async {
    await _checkBirthPlaceUpdatesOnStartup();
    if (mounted) await _checkUpdatesOnStartup();
  }

  Future<void> _checkBirthPlaceUpdatesOnStartup() async {
    var updateStarted = false;
    try {
      final result = await BirthPlaceService.checkForUpdates(
        onUpdateStarted: () {
          updateStarted = true;
          if (mounted) {
            _showBirthPlaceNotification(
              title: AppStrings.t('anpr_update_in_progress_title'),
              message: AppStrings.t('anpr_update_in_progress'),
              loading: true,
            );
          }
        },
      );
      if (!mounted || !result.updated) return;
      _showBirthPlaceNotification(
        title: AppStrings.t('anpr_update_completed_title'),
        message: AppStrings.t('anpr_update_completed'),
      );
    } catch (error) {
      debugPrint('Controllo aggiornamento ANPR non riuscito: $error');
      if (!mounted || !updateStarted) return;
      _showBirthPlaceNotification(
        title: AppStrings.t('anpr_update_failed_title'),
        message: AppStrings.t('anpr_update_failed'),
        error: true,
      );
    }
  }

  Future<void> _checkUpdatesOnStartup() async {
    try {
      final result = await widget.services.updates.check();
      if (!mounted || !result.updateAvailable) return;
      setState(() => _startupUpdate = result);
      _showUpdateNotification(result);
    } catch (error) {
      debugPrint('Controllo aggiornamenti automatico non riuscito: $error');
    }
  }

  void _showBirthPlaceNotification({
    required String title,
    required String message,
    bool loading = false,
    bool error = false,
  }) {
    _dismissBirthPlaceNotification();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Positioned(
          right: 24,
          bottom: 24,
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassSurface(
                blur: 30,
                role: GlassSurfaceRole.notification,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Icon(
                          error
                              ? Icons.error_outline_rounded
                              : Icons.cloud_done_outlined,
                          color: error
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!loading)
                        IconButton(
                          tooltip: AppStrings.t('close'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _dismissBirthPlaceNotification,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _birthPlaceNotification = entry;
    overlay.insert(entry);
    if (!loading) {
      _birthPlaceNotificationTimer = Timer(
        const Duration(seconds: 6),
        _dismissBirthPlaceNotification,
      );
    }
  }

  void _dismissBirthPlaceNotification() {
    _birthPlaceNotificationTimer?.cancel();
    _birthPlaceNotificationTimer = null;
    _birthPlaceNotification?.remove();
    _birthPlaceNotification = null;
  }

  void _showUpdateNotification(UpdateCheckResult update) {
    _dismissUpdateNotification();
    final overlay = Overlay.of(context, rootOverlay: true);
    final bottomOffset = _birthPlaceNotification == null ? 24.0 : 150.0;
    final entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Positioned(
          right: 24,
          bottom: bottomOffset,
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassSurface(
                blur: 30,
                role: GlassSurfaceRole.notification,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openUpdateSettings,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.system_update_alt_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.t('update_available'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                update.message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppStrings.t('open_settings_update'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.t('close'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _dismissUpdateNotification,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _updateNotification = entry;
    overlay.insert(entry);
    _updateNotificationTimer = Timer(
      const Duration(seconds: 15),
      _dismissUpdateNotification,
    );
  }

  void _dismissUpdateNotification() {
    _updateNotificationTimer?.cancel();
    _updateNotificationTimer = null;
    _updateNotification?.remove();
    _updateNotification = null;
  }

  void _openUpdateSettings() {
    _dismissUpdateNotification();
    _selectPage(_settingsIndex);
  }

  void _selectPage(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = value);
  }

  List<_NavItem> _navItems() => [
        _NavItem(
          Icons.dashboard_outlined,
          Icons.dashboard,
          AppStrings.t('dashboard'),
        ),
        _NavItem(
          Icons.point_of_sale_outlined,
          Icons.point_of_sale,
          AppStrings.t('cash'),
        ),
        _NavItem(
          Icons.receipt_long_outlined,
          Icons.receipt_long,
          AppStrings.t('sales'),
        ),
        _NavItem(
          Icons.people_outline,
          Icons.people,
          AppStrings.t('customers'),
        ),
        _NavItem(
          Icons.card_giftcard_outlined,
          Icons.card_giftcard,
          AppStrings.pair('Buoni regalo', 'Gift cards'),
        ),
        _NavItem(
          Icons.label_outline,
          Icons.label,
          AppStrings.t('labels'),
        ),
        _NavItem(
          Icons.inventory_2_outlined,
          Icons.inventory_2,
          AppStrings.t('products'),
        ),
        _NavItem(
          Icons.warehouse_outlined,
          Icons.warehouse,
          AppStrings.t('stock'),
        ),
        _NavItem(
          Icons.category_outlined,
          Icons.category,
          AppStrings.t('lookups'),
        ),
        _NavItem(
          Icons.archive_outlined,
          Icons.archive,
          AppStrings.t('export'),
        ),
        _NavItem(
          Icons.settings_outlined,
          Icons.settings,
          AppStrings.t('settings'),
        ),
      ];

  List<Widget> _pages() => <Widget>[
        DashboardPage(
          services: widget.services,
          isActive: _index == 0,
        ),
        CashPage(
          services: widget.services,
          isActive: _index == 1,
        ),
        OrdersPage(services: widget.services),
        CustomersPage(
          services: widget.services,
          isActive: _index == 3,
        ),
        GiftCardsPage(services: widget.services),
        LabelsPage(
          services: widget.services,
          settings: widget.settings,
          isActive: _index == 5,
        ),
        ProductsPage(services: widget.services),
        StockPage(
          services: widget.services,
          isActive: _index == 7,
        ),
        LookupsPage(services: widget.services),
        ExportPage(
          services: widget.services,
          settings: widget.settings,
        ),
        SettingsPage(
          services: widget.services,
          current: widget.settings,
          onSaved: widget.onSettingsChanged,
          initialUpdate: _startupUpdate,
        ),
      ];

  Widget _pageFrame(UiLayoutTokens layout, List<Widget> pages) {
    final stack = IndexedStack(index: _index, children: pages);
    final radius = BorderRadius.circular(layout.pageRadius);
    if (!layout.showPageFrame) {
      return ClipRRect(borderRadius: radius, child: stack);
    }
    return GlassSurface(
      role: GlassSurfaceRole.content,
      borderRadius: radius,
      child: ClipRRect(borderRadius: radius, child: stack),
    );
  }

  Widget _railLayout(UiLayoutTokens layout, List<Widget> pages) {
    final items = _navItems();
    return Row(
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(layout.panelRadius),
          child: SizedBox(
            width: layout.navigationExtent,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: NavigationRail(
                minWidth: layout.navigationExtent,
                minExtendedWidth: layout.navigationExtent,
                selectedIndex: _index,
                onDestinationSelected: _selectPage,
                labelType: NavigationRailLabelType.all,
                scrollable: true,
                leading: _MenuBrand(
                  settings: widget.settings,
                  services: widget.services,
                  compact: layout.compactBrand,
                ),
                destinations: items
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ),
        SizedBox(width: layout.shellGap),
        Expanded(child: _pageFrame(layout, pages)),
      ],
    );
  }

  Widget _sidebarLayout(UiLayoutTokens layout, List<Widget> pages) {
    final theme = Theme.of(context);
    final items = _navItems();
    return Row(
      children: [
        SizedBox(
          width: layout.navigationExtent,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(layout.panelRadius),
            padding: EdgeInsets.symmetric(
              horizontal: layout.dense ? 8 : 10,
              vertical: 10,
            ),
            child: Column(
              children: [
                _MenuBrand(
                  settings: widget.settings,
                  services: widget.services,
                  compact: layout.compactBrand,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: layout.dense ? 2 : 5),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = index == _index;
                      return Material(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          layout.navItemRadius,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            layout.navItemRadius,
                          ),
                          onTap: () => _selectPage(index),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.dense ? 10 : 12,
                              vertical: layout.dense ? 9 : 11,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? item.selectedIcon
                                      : item.icon,
                                  size: 20,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: layout.shellGap),
        Expanded(child: _pageFrame(layout, pages)),
      ],
    );
  }

  Widget _horizontalNav(UiLayoutTokens layout, {required bool dock}) {
    final items = _navItems();
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _HorizontalNavButton(
            item: items[i],
            selected: i == _index,
            compact: dock || layout.dense,
            radius: layout.navItemRadius,
            onTap: () => _selectPage(i),
          ),
          if (i != items.length - 1)
            SizedBox(width: layout.dense ? 2 : 5),
        ],
      ],
    );
    return GlassSurface(
      borderRadius: BorderRadius.circular(layout.panelRadius),
      padding: EdgeInsets.symmetric(
        horizontal: layout.dense ? 6 : 10,
        vertical: layout.dense ? 5 : 8,
      ),
      child: SizedBox(
        height: layout.navigationExtent,
        child: Row(
          mainAxisSize: dock ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (!dock) ...[
              _HorizontalBrand(
                settings: widget.settings,
                services: widget.services,
              ),
              SizedBox(width: layout.shellGap),
            ],
            if (dock)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topLayout(UiLayoutTokens layout, List<Widget> pages) => Column(
        children: [
          _horizontalNav(layout, dock: false),
          SizedBox(height: layout.shellGap),
          Expanded(child: _pageFrame(layout, pages)),
        ],
      );

  Widget _dockLayout(UiLayoutTokens layout, List<Widget> pages) => Column(
        children: [
          Expanded(child: _pageFrame(layout, pages)),
          SizedBox(height: layout.shellGap),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width -
                    (layout.shellPadding * 2),
              ),
              child: _horizontalNav(layout, dock: true),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final layout = UiLayoutTokens.of(context);
    final pages = _pages();
    final body = switch (layout.navigation) {
      'sidebar' => _sidebarLayout(layout, pages),
      'top' => _topLayout(layout, pages),
      'dock' => _dockLayout(layout, pages),
      _ => _railLayout(layout, pages),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Padding(
          padding: EdgeInsets.all(layout.shellPadding),
          child: Column(
            children: [
              const AppTitleBar(),
              SizedBox(height: layout.shellGap * 0.6),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _HorizontalNavButton extends StatelessWidget {
  const _HorizontalNavButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.radius,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final bool compact;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = UiStyleTokens.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.18)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: selected
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.45),
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        hoverColor: tokens.captionHover,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 19,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (!compact) ...[
                const SizedBox(width: 7),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalBrand extends StatelessWidget {
  const _HorizontalBrand({
    required this.settings,
    required this.services,
  });
  final AppSettings settings;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final logo = services.settings.resolveLogoPath(settings);
    final showLogo = settings.showLogoInMenu && logo != null;
    final showName = settings.showShopNameInMenu;
    if (!showLogo && !showName) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo)
          Image.file(
            File(logo),
            key: ValueKey(logo),
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            gaplessPlayback: false,
          ),
        if (showLogo && showName) const SizedBox(width: 8),
        if (showName)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              settings.shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _MenuBrand extends StatelessWidget {
  const _MenuBrand({
    required this.settings,
    required this.services,
    this.compact = false,
  });
  final AppSettings settings;
  final AppServices services;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logo = services.settings.resolveLogoPath(settings);
    final showLogo = settings.showLogoInMenu && logo != null;
    final showName = settings.showShopNameInMenu;
    if (!showLogo && !showName) return SizedBox(height: compact ? 8 : 12);
    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? 8 : 14,
        top: compact ? 4 : 8,
      ),
      child: Column(
        children: [
          if (showLogo)
            Image.file(
              File(logo),
              key: ValueKey(logo),
              width: compact ? 46 : 84,
              height: compact ? 46 : 84,
              fit: BoxFit.contain,
              gaplessPlayback: false,
            ),
          if (showLogo && showName) SizedBox(height: compact ? 5 : 9),
          if (showName)
            Text(
              settings.shopName,
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : null,
              ),
            ),
        ],
      ),
    );
  }
}
