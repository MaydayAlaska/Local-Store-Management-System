import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import '../services/birth_place_service.dart';
import '../services/fiscal_code_service.dart';
import 'gift_card_expiration_dialog.dart';

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
  bool _giftCardsChanged = false;

  String _itEn(String it, String en) => AppStrings.pair(it, en);

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
    final value = _fiscalCode.text.trim();
    if (value.isEmpty) return null;
    return FiscalCodeService.tryParse(value);
  }

  Future<void> _manageGiftCardExpirations() async {
    final customer = widget.customer;
    if (customer == null) return;
    await showGiftCardExpirationManagerDialog(
      context,
      customer: customer,
      repository: widget.repository,
    );
    if (!mounted) return;
    setState(() => _giftCardsChanged = true);
  }

  void _cancel() {
    Navigator.of(context).pop(
      _giftCardsChanged && widget.customer != null ? widget.customer : null,
    );
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

    final fiscalValue = _fiscalCode.text.trim();
    final data = fiscalValue.isEmpty ? null : FiscalCodeService.tryParse(fiscalValue);
    if (fiscalValue.isNotEmpty && data == null) {
      setState(() => _error = _itEn(
            'Il codice fiscale inserito non è valido. Puoi correggerlo oppure lasciarlo vuoto e aggiungerlo successivamente.',
            'The tax code is invalid. Correct it or leave it empty and add it later.',
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
    final fiscalValue = _fiscalCode.text.trim();
    final fiscalIsInvalid = fiscalValue.isNotEmpty && preview == null;

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
              if (widget.customer != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.badge_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_itEn('Codice cliente', 'Customer code')}: ${widget.customer!.customerCodeDisplay}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _manageGiftCardExpirations,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(AppStrings.t('manage_gift_card_expirations')),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _fiscalCode,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: _itEn(
                    'Codice fiscale (facoltativo)',
                    'Tax code (optional)',
                  ),
                  helperText: _itEn(
                    'Può essere aggiunto o modificato anche in seguito.',
                    'It can be added or changed later.',
                  ),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  errorText: fiscalIsInvalid
                      ? _itEn('Codice fiscale non valido.', 'Invalid tax code.')
                      : null,
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
                        Text(
                          '${_itEn('Nascita', 'Birth date')}: ${preview.birthDateDisplay}',
                        ),
                        Text('${_itEn('Sesso', 'Sex')}: ${preview.sex}'),
                        Text(
                          '${_itEn('Luogo di nascita', 'Birth place')}: '
                          '${birthPlaceName ?? _itEn('Non disponibile', 'Not available')}',
                        ),
                      ],
                    ),
                  ),
                )
              else if (fiscalValue.isEmpty)
                Text(
                  _itEn(
                    'Il cliente può essere salvato senza codice fiscale. I dati di nascita verranno compilati automaticamente quando verrà aggiunto un codice fiscale valido.',
                    'The customer can be saved without a tax code. Birth data will be filled automatically when a valid tax code is added.',
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
          onPressed: _cancel,
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
