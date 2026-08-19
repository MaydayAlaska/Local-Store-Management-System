import 'package:flutter/material.dart';

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
  Future<void> _edit(LookupKind kind, [LookupItem? item]) async {
    final controller = TextEditingController(text: item?.name ?? '');
    final label = kind == LookupKind.brand ? 'marca' : 'categoria';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Nuova $label' : 'Rinomina $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
          decoration: InputDecoration(labelText: 'Nome $label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salva')),
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
    final all = widget.services.lookups.getAll(kind).where((e) => e.id != item.id).toList();
    int? target;
    var assignNone = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Elimina «${item.name}»'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${item.productCount} prodotti usano questa voce. Puoi lasciarli senza assegnazione oppure riassegnarli.',
                ),
                const SizedBox(height: 12),
                RadioGroup<bool>(
                  groupValue: assignNone,
                  onChanged: (v) => setLocal(() => assignNone = v ?? true),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: true, title: Text('Lascia senza assegnazione')),
                      RadioListTile<bool>(value: false, title: Text('Riassegna a:')),
                    ],
                  ),
                ),
                if (!assignNone)
                  GlassDropdown<int>(
                    value: target,
                    labelText: 'Destinazione',
                    hintText: 'Seleziona destinazione',
                    items: all
                        .map((e) => GlassDropdownItem<int>(value: e.id, label: e.name))
                        .toList(),
                    onChanged: (value) => setLocal(() => target = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: !assignNone && target == null ? null : () => Navigator.pop(context, true),
              child: const Text('Elimina'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      widget.services.lookups.deleteAndReassign(kind, item.id, assignNone ? null : target);
      setState(() {});
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Marche e categorie', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: 'Marche', icon: Icon(Icons.sell_outlined)),
                Tab(text: 'Categorie', icon: Icon(Icons.category_outlined)),
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

  @override
  Widget build(BuildContext context) {
    final label = kind == LookupKind.brand ? 'marca' : 'categoria';
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
              label: Text('Nuova $label'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('Nessuna $label.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.productCount} ${item.productCount == 1 ? 'prodotto' : 'prodotti'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => onEdit(kind, item),
                            tooltip: 'Rinomina',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => onDelete(kind, item),
                            tooltip: 'Elimina / riassegna',
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
