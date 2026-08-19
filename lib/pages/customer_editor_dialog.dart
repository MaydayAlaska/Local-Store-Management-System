import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../services/birth_place_service.dart';
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

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

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
      setState(() => _error = _itEn(
            'Nome e cognome sono obbligatori.',
            'First name and last name are required.',
          ));
      return;
    }

    final data = _preview;
    if (data == null) {
      setState(() => _error = _itEn(
            'Il codice fiscale non è valido. Controlla la scansione o il valore inserito.',
            'The tax code is invalid. Check the scan or the entered value.',
          ));
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
      setState(() => _error = _itEn(
            'Impossibile salvare il cliente: $error',
            'Unable to save customer: $error',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final birthPlaceName = preview == null
        ? null
        : BirthPlaceService.resolve(
            preview.birthPlaceCode,
            preview.birthDate,
          );
    final lockedFiscalCode = widget.customer != null || widget.scanned != null;
    return AlertDialog(
      title: Text(
        widget.customer == null
            ? _itEn('Nuovo cliente', 'New customer')
            : _itEn('Modifica cliente', 'Edit customer'),
      ),
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
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: _itEn('Codice fiscale', 'Tax code'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _lastName,
                    autofocus: widget.scanned != null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn('Cognome *', 'Last name *'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _firstName,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn('Nome *', 'First name *'),
                    ),
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
                        Text('${_itEn('Nascita', 'Birth date')}: ${preview.birthDateDisplay}'),
                        Text('${_itEn('Sesso', 'Sex')}: ${preview.sex}'),
                        Text(
                          '${_itEn('Luogo di nascita', 'Birth place')}: '
                          '${birthPlaceName ?? _itEn('Non disponibile', 'Not available')}',
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  _itEn(
                    'Inserisci un codice fiscale valido per ricavare automaticamente i dati disponibili.',
                    'Enter a valid tax code to automatically extract the available data.',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppStrings.t('notes'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.t('cancel')),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_itEn('Salva cliente', 'Save customer')),
        ),
      ],
    );
  }
}
