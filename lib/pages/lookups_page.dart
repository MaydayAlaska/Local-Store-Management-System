import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/catalog.dart';
import '../repositories/lookup_repository.dart';
import '../services/app_services.dart';
import '../widgets/glass_dropdown.dart';

class LookupsPage extends StatefulWidget {
  const LookupsPage({super.key, required this.services});
  final AppServices services;

  @override
  State<LookupsPage> createState() => _LookupsPageState();
}

class _LookupsPageState extends State<LookupsPage> {
  String _kindLabel(LookupKind kind) => kind == LookupKind.brand
      ? AppStrings.pair('marca', 'brand')
      : AppStrings.pair('categoria', 'category');

  Future<void> _edit(LookupKind kind, [LookupItem? item]) async {
    final controller = TextEditingController(text: item?.name ?? '');
    final label = _kindLabel(kind);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item == null
              ? AppStrings.pair('Nuova $label', 'New $label')
              : AppStrings.pair('Rinomina $label', 'Rename $label'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: InputDecoration(
            labelText: AppStrings.pair('Nome $label', '$label name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppStrings.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      if (item == null) {
        widget.services.lookups.create(kind, value);
      } else {
        widget.services.lookups.rename(kind, item.id, value);
      }
      setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _delete(LookupKind kind, LookupItem item) async {
    final all = widget.services.lookups
        .getAll(kind)
        .where((entry) => entry.id != item.id)
        .toList();
    int? target;
    var assignNone = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            AppStrings.pair(
              'Elimina «${item.name}»',
              'Delete “${item.name}”',
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.pair(
                    '${item.productCount} prodotti usano questa voce. Puoi lasciarli senza assegnazione oppure riassegnarli.',
                    '${item.productCount} products use this entry. You can leave them unassigned or reassign them.',
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<bool>(
                  groupValue: assignNone,
                  onChanged: (value) =>
                      setLocal(() => assignNone = value ?? true),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        title: Text(
                          AppStrings.pair(
                            'Lascia senza assegnazione',
                            'Leave unassigned',
                          ),
                        ),
                      ),
                      RadioListTile<bool>(
                        value: false,
                        title: Text(
                          AppStrings.pair('Riassegna a:', 'Reassign to:'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!assignNone)
                  GlassDropdown<int>(
                    value: target,
                    labelText: AppStrings.pair('Destinazione', 'Destination'),
                    hintText: AppStrings.pair(
                      'Seleziona destinazione',
                      'Select destination',
                    ),
                    items: all
                        .map(
                          (entry) => GlassDropdownItem<int>(
                            value: entry.id,
                            label: entry.name,
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocal(() => target = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.t('cancel')),
            ),
            FilledButton(
              onPressed: !assignNone && target == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(AppStrings.pair('Elimina', 'Delete')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      widget.services.lookups.deleteAndReassign(
        kind,
        item.id,
        assignNone ? null : target,
      );
      setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              AppStrings.t('lookups'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            TabBar(
              tabs: [
                Tab(
                  text: AppStrings.t('brands'),
                  icon: const Icon(Icons.sell_outlined),
                ),
                Tab(
                  text: AppStrings.t('categories'),
                  icon: const Icon(Icons.category_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _LookupList(
                    kind: LookupKind.brand,
                    items: widget.services.lookups.getAll(LookupKind.brand),
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                  _LookupList(
                    kind: LookupKind.category,
                    items: widget.services.lookups.getAll(LookupKind.category),
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _LookupList extends StatelessWidget {
  const _LookupList({
    required this.kind,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final LookupKind kind;
  final List<LookupItem> items;
  final Future<void> Function(LookupKind, [LookupItem?]) onEdit;
  final Future<void> Function(LookupKind, LookupItem) onDelete;

  String get _label => kind == LookupKind.brand
      ? AppStrings.pair('marca', 'brand')
      : AppStrings.pair('categoria', 'category');

  @override
  Widget build(BuildContext context) {
    final label = _label;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => onEdit(kind),
              icon: const Icon(Icons.add),
              label: Text(
                AppStrings.pair('Nuova $label', 'New $label'),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.pair('Nessuna $label.', 'No $label entries.'),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.productCount} ${item.productCount == 1 ? AppStrings.pair('prodotto', 'product') : AppStrings.pair('prodotti', 'products')}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onEdit(kind, item),
                            tooltip: AppStrings.pair('Rinomina', 'Rename'),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => onDelete(kind, item),
                            tooltip: AppStrings.pair(
                              'Elimina / riassegna',
                              'Delete / reassign',
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
