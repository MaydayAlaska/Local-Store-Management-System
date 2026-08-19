import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../services/app_services.dart';
import '../services/update_service.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/glass.dart';
import 'cash_page.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'export_page.dart';
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
  static const _settingsIndex = 9;

  int _index = 0;
  UpdateCheckResult? _startupUpdate;
  OverlayEntry? _updateNotification;
  Timer? _updateNotificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdatesOnStartup());
  }

  @override
  void dispose() {
    _updateNotificationTimer?.cancel();
    _updateNotification?.remove();
    _updateNotification = null;
    super.dispose();
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

  void _showUpdateNotification(UpdateCheckResult update) {
    _dismissUpdateNotification();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Positioned(
          right: 24,
          bottom: 24,
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: GlassSurface(
                blur: 30,
                opacity: isDark ? 0.18 : 0.58,
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

  List<NavigationRailDestination> _destinations() => [
        NavigationRailDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: Text(AppStrings.t('dashboard')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.point_of_sale_outlined),
          selectedIcon: const Icon(Icons.point_of_sale),
          label: Text(AppStrings.t('cash')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: Text(AppStrings.t('sales')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.people_outline),
          selectedIcon: const Icon(Icons.people),
          label: Text(AppStrings.t('customers')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.label_outline),
          selectedIcon: const Icon(Icons.label),
          label: Text(AppStrings.t('labels')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2),
          label: Text(AppStrings.t('products')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.warehouse_outlined),
          selectedIcon: const Icon(Icons.warehouse),
          label: Text(AppStrings.t('stock')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.category_outlined),
          selectedIcon: const Icon(Icons.category),
          label: Text(AppStrings.t('lookups')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.archive_outlined),
          selectedIcon: const Icon(Icons.archive),
          label: Text(AppStrings.t('export')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(AppStrings.t('settings')),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(services: widget.services, isActive: _index == 0),
      CashPage(services: widget.services, isActive: _index == 1),
      OrdersPage(services: widget.services),
      CustomersPage(services: widget.services, isActive: _index == 3),
      LabelsPage(
        services: widget.services,
        settings: widget.settings,
        isActive: _index == 4,
      ),
      ProductsPage(services: widget.services),
      StockPage(services: widget.services, isActive: _index == 6),
      LookupsPage(services: widget.services),
      ExportPage(services: widget.services, settings: widget.settings),
      SettingsPage(
        services: widget.services,
        current: widget.settings,
        onSaved: widget.onSettingsChanged,
        initialUpdate: _startupUpdate,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const AppTitleBar(),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    GlassSurface(
                      borderRadius: BorderRadius.circular(24),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: false,
                        ),
                        child: NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: _selectPage,
                          labelType: NavigationRailLabelType.all,
                          scrollable: true,
                          leading: _MenuBrand(
                            settings: widget.settings,
                            services: widget.services,
                          ),
                          destinations: _destinations(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassSurface(
                        opacity: Theme.of(context).brightness == Brightness.dark
                            ? 0.055
                            : 0.24,
                        borderRadius: BorderRadius.circular(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: IndexedStack(index: _index, children: pages),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuBrand extends StatelessWidget {
  const _MenuBrand({required this.settings, required this.services});
  final AppSettings settings;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final logo = services.settings.resolveLogoPath(settings);
    final showLogo = settings.showLogoInMenu && logo != null;
    final showName = settings.showShopNameInMenu;
    if (!showLogo && !showName) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: SizedBox(
        width: 136,
        child: Column(
          children: [
            if (showLogo)
              Image.file(
                File(logo),
                key: ValueKey(logo),
                width: 84,
                height: 84,
                fit: BoxFit.contain,
                gaplessPlayback: false,
              ),
            if (showLogo && showName) const SizedBox(height: 9),
            if (showName)
              Text(
                settings.shopName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}
