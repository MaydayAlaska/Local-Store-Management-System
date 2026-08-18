import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_services.dart';
import '../widgets/app_title_bar.dart';
import 'cash_page.dart';
import 'dashboard_page.dart';
import 'export_page.dart';
import 'labels_page.dart';
import 'lookups_page.dart';
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(services: widget.services),
      ProductsPage(services: widget.services),
      StockPage(services: widget.services),
      CashPage(services: widget.services),
      LabelsPage(services: widget.services, settings: widget.settings),
      ExportPage(services: widget.services, settings: widget.settings),
      LookupsPage(services: widget.services),
      SettingsPage(
        services: widget.services,
        current: widget.settings,
        onSaved: widget.onSettingsChanged,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          AppTitleBar(settings: widget.settings, settingsService: widget.services.settings),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: _MenuBrand(settings: widget.settings, services: widget.services),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Prodotti')),
                    NavigationRailDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: Text('Magazzino')),
                    NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('Cassa')),
                    NavigationRailDestination(icon: Icon(Icons.label_outline), selectedIcon: Icon(Icons.label), label: Text('Etichette')),
                    NavigationRailDestination(icon: Icon(Icons.archive_outlined), selectedIcon: Icon(Icons.archive), label: Text('Export')),
                    NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Anagrafiche')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Impostazioni')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: IndexedStack(index: _index, children: pages)),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: 116,
        child: Column(
          children: [
            if (showLogo) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(logo), width: 48, height: 48, fit: BoxFit.contain)),
            if (showLogo && showName) const SizedBox(height: 6),
            if (showName) Text(settings.shopName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
