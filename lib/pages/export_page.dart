import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../repositories/lookup_repository.dart';
import '../services/app_services.dart';

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
  bool _busy = false;
  String? _status;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final path = await action();
      if (mounted) setState(() => _status = path == null ? 'Operazione annullata.' : 'File creato: $path');
    } catch (error) {
      if (mounted) setState(() => _status = 'Errore: $error');
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
        Text('Backup ed esportazione', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Backup database', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () {
                    try {
                      final path = widget.services.backup.createAutomaticBackup();
                      setState(() => _status = 'Backup creato: $path');
                    } catch (error) {
                      setState(() => _status = 'Errore backup: $error');
                    }
                  },
                  icon: const Icon(Icons.backup),
                  label: const Text('Crea backup in Backups'),
                ),
                OutlinedButton.icon(onPressed: _busy ? null : () => _run(widget.services.backup.saveBackupAs), icon: const Icon(Icons.save_as), label: const Text('Salva backup come…')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Filtri inventario', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Marche', style: Theme.of(context).textTheme.labelLarge),
                Wrap(spacing: 6, runSpacing: 4, children: brands.map((b) => FilterChip(
                  label: Text(b.name), selected: _brands.contains(b.id), onSelected: (v) => setState(() => v ? _brands.add(b.id) : _brands.remove(b.id)),
                )).toList()),
                const SizedBox(height: 10),
                Text('Categorie', style: Theme.of(context).textTheme.labelLarge),
                Wrap(spacing: 6, runSpacing: 4, children: categories.map((c) => FilterChip(
                  label: Text(c.name), selected: _categories.contains(c.id), onSelected: (v) => setState(() => v ? _categories.add(c.id) : _categories.remove(c.id)),
                )).toList()),
                const Spacer(),
                Text('Nessun filtro selezionato = inventario completo. I dati vengono raggruppati per marca in ordine alfabetico.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(() => widget.services.export.exportExcel(brandIds: _brands, categoryIds: _categories, settings: widget.settings)),
                    icon: const Icon(Icons.table_chart), label: const Text('Esporta Excel'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _run(() => widget.services.export.exportPdf(brandIds: _brands, categoryIds: _categories, settings: widget.settings)),
                    icon: const Icon(Icons.picture_as_pdf), label: const Text('Esporta PDF'),
                  ),
                  TextButton(onPressed: _busy ? null : () => setState(() { _brands.clear(); _categories.clear(); }), child: const Text('Azzera filtri')),
                ]),
              ]),
            ),
          ),
        ),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_status!)),
      ]),
    );
  }
}
