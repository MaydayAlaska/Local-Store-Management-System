import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../repositories/lookup_repository.dart';
import '../services/app_services.dart';
import '../services/export_service.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key, required this.services, required this.settings});
  final AppServices services;
  final AppSettings settings;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final Set<int> _brands = {};
  final Set<int> _categories = {};
  final Set<InventoryExportField> _fields = InventoryExportField.values.toSet();
  bool _busy = false;
  String? _status;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final path = await action();
      if (mounted) {
        setState(() => _status = path == null
            ? AppStrings.t('operation_cancelled')
            : '${AppStrings.t('file_created')}: $path');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '${AppStrings.t('error')}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brands = widget.services.lookups.getAll(LookupKind.brand);
    final categories = widget.services.lookups.getAll(LookupKind.category);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          AppStrings.t('backup_export'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                AppStrings.t('backup_database'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () async => widget.services.backup.createAutomaticBackup(),
                          ),
                  icon: const Icon(Icons.backup),
                  label: Text(AppStrings.t('create_backup')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(widget.services.backup.saveBackupAs),
                  icon: const Icon(Icons.save_as),
                  label: Text(AppStrings.t('save_backup_as')),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.t('inventory_fields'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: InventoryExportField.values
                          .map(
                            (field) => FilterChip(
                              label: Text(inventoryExportFieldLabel(field)),
                              selected: _fields.contains(field),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _fields.add(field);
                                } else {
                                  _fields.remove(field);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      AppStrings.t('inventory_filters'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.t('brands'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: brands
                          .map(
                            (brand) => FilterChip(
                              label: Text(brand.name),
                              selected: _brands.contains(brand.id),
                              onSelected: (selected) => setState(() => selected
                                  ? _brands.add(brand.id)
                                  : _brands.remove(brand.id)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.t('categories'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: categories
                          .map(
                            (category) => FilterChip(
                              label: Text(category.name),
                              selected: _categories.contains(category.id),
                              onSelected: (selected) => setState(() => selected
                                  ? _categories.add(category.id)
                                  : _categories.remove(category.id)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(AppStrings.t('no_filter')),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: _busy || _fields.isEmpty
                            ? null
                            : () => _run(
                                  () => widget.services.export.exportExcel(
                                    brandIds: _brands,
                                    categoryIds: _categories,
                                    fields: _fields,
                                    settings: widget.settings,
                                  ),
                                ),
                        icon: const Icon(Icons.table_chart),
                        label: Text(AppStrings.t('export_excel')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy || _fields.isEmpty
                            ? null
                            : () => _run(
                                  () => widget.services.export.exportPdf(
                                    brandIds: _brands,
                                    categoryIds: _categories,
                                    fields: _fields,
                                    settings: widget.settings,
                                  ),
                                ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(AppStrings.t('export_pdf')),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _brands.clear();
                                  _categories.clear();
                                }),
                        child: Text(AppStrings.t('reset_filters')),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_status!),
          ),
      ]),
    );
  }
}
