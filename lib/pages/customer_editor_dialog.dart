import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../services/fiscal_code_service.dart';

Future<Customer?> showCustomerEditorDialog(
  BuildContext context, {
  required CustomerRepository repository,
  Customer? customer,
  FiscalCodeData? scanned,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (_) => _CustomerEditorDialog(
      repository: repository,
      customer: customer,
      scanned: scanned,
    ),
  );
}

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({
    required this.repository,
    this.customer,
    this.scanned,
  });

  final CustomerRepository repository;
  final Customer? customer;
  final FiscalCodeData? scanned;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  late final TextEditingController _fiscalCode;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fiscalCode = TextEditingController(
      text: widget.customer?.fiscalCode ?? widget.scanned?.fiscalCode ?? '',
    );
    _firstName = TextEditingController(text: widget.customer?.firstName ?? '');
    _lastName = TextEditingController(text: widget.customer?.lastName ?? '');
    _notes = TextEditingController(text: widget.customer?.notes ?? '');
  }

  @override
  void dispose() {
    _fiscalCode.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _notes.dispose();
    super.dispose();
  }

  FiscalCodeData? get _preview {
    final existing = widget.customer;
    if (existing != null) {
      return FiscalCodeData(
        fiscalCode: existing.fiscalCode,
        birthDate: existing.birthDate,
        sex: existing.sex,
        birthPlaceCode: existing.birthPlaceCode,
      );
    }
    if (widget.scanned != null) return widget.scanned;
    return FiscalCodeService.tryParse(_fiscalCode.text);
  }

  void _save() {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Nome e cognome sono obbligatori.');
      return;
    }

    final data = _preview;
    if (data == null) {
      setState(() => _error = 'Il codice fiscale non è valido. Controlla la scansione o il valore inserito.');
      return;
    }

    try {
      final saved = widget.repository.save(CustomerDraft(
        id: widget.customer?.id,
        fiscalCodeData: data,
        firstName: firstName,
        lastName: lastName,
        notes: _notes.text,
      ));
      Navigator.of(context).pop(saved);
    } catch (error) {
      setState(() => _error = 'Impossibile salvare il cliente: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final lockedFiscalCode = widget.customer != null || widget.scanned != null;
    return AlertDialog(
      title: Text(widget.customer == null ? 'Nuovo cliente' : 'Modifica cliente'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _fiscalCode,
                readOnly: lockedFiscalCode,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Codice fiscale',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _lastName,
                    autofocus: widget.scanned != null,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cognome *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _firstName,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Nome *'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (preview != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      children: [
                        Text('Nascita: ${preview.birthDateDisplay}'),
                        Text('Sesso: ${preview.sex}'),
                        Text('Codice luogo: ${preview.birthPlaceCode}'),
                      ],
                    ),
                  ),
                )
              else
                const Text('Inserisci un codice fiscale valido per ricavare automaticamente i dati disponibili.'),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Note'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Salva cliente')),
      ],
    );
  }
}
