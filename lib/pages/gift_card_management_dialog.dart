import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../repositories/customer_repository.dart';

Future<int?> showGiftCardManagementDialog(
  BuildContext context, {
  required CustomerRepository repository,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _GiftCardManagementDialog(
      repository: repository,
    ),
  );
}

class _GiftCardManagementDialog extends StatefulWidget {
  const _GiftCardManagementDialog({required this.repository});

  final CustomerRepository repository;

  @override
  State<_GiftCardManagementDialog> createState() =>
      _GiftCardManagementDialogState();
}

class _GiftCardManagementDialogState
    extends State<_GiftCardManagementDialog> {
  final _yearsController = TextEditingController(text: '5');
  bool _olderThanYears = false;
  bool _exhausted = false;
  bool _expired = false;
  int _deletedTotal = 0;
  String? _status;

  String _itEn(String it, String en) => AppStrings.isEnglish ? en : it;

  @override
  void dispose() {
    _yearsController.dispose();
    super.dispose();
  }

  int? get _years {
    if (!_olderThanYears) return null;
    final value = int.tryParse(_yearsController.text.trim());
    return value != null && value > 0 ? value : null;
  }

  bool get _hasCriteria => _olderThanYears || _exhausted || _expired;
  bool get _validYears => !_olderThanYears || _years != null;

  int _matchingCount() {
    if (!_hasCriteria || !_validYears) return 0;
    return widget.repository.countGiftCardsForCleanup(
      olderThanYears: _years,
      exhausted: _exhausted,
      expired: _expired,
    );
  }

  Future<void> _deleteMatching() async {
    final count = _matchingCount();
    if (count <= 0) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmContext) => AlertDialog(
            title: Text(_itEn(
              'Eliminare definitivamente i buoni selezionati?',
              'Permanently delete selected gift cards?',
            )),
            content: Text(_itEn(
              'Verranno eliminati definitivamente $count buoni regalo dal database. '
                  'I loro codici resteranno riservati in modo permanente e non potranno essere riutilizzati.',
              '$count gift cards will be permanently deleted from the database. '
                  'Their codes will remain permanently reserved and cannot be reused.',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirmContext).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(confirmContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(confirmContext).pop(true),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(_itEn('Elimina $count buoni', 'Delete $count cards')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      final deleted = widget.repository.deleteGiftCardsForCleanup(
        olderThanYears: _years,
        exhausted: _exhausted,
        expired: _expired,
      );
      if (!mounted) return;
      setState(() {
        _deletedTotal += deleted;
        _status = _itEn(
          '$deleted buoni regalo eliminati definitivamente. I codici restano riservati.',
          '$deleted gift cards permanently deleted. Their codes remain reserved.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _itEn(
            'Impossibile eliminare i buoni regalo: $error',
            'Unable to delete gift cards: $error',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _matchingCount();
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_itEn('Gestione buoni regalo', 'Gift card management')),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_itEn(
              'Seleziona uno o più criteri. I criteri sono combinati con “oppure”: '
                  'un buono viene eliminato se soddisfa almeno uno dei criteri selezionati.',
              'Select one or more criteria. Criteria are combined with “or”: '
                  'a gift card is deleted when it matches at least one selected criterion.',
            )),
            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _olderThanYears,
              onChanged: (value) => setState(() {
                _olderThanYears = value ?? false;
                _status = null;
              }),
              title: Text(_itEn(
                'Più vecchi di un numero di anni',
                'Older than a number of years',
              )),
              subtitle: Text(_itEn(
                'Il confronto usa la data di creazione del buono.',
                'The comparison uses the gift card creation date.',
              )),
            ),
            if (_olderThanYears)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _yearsController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() => _status = null),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _itEn('Anni', 'Years'),
                      errorText: _validYears
                          ? null
                          : _itEn(
                              'Inserisci almeno 1 anno.',
                              'Enter at least 1 year.',
                            ),
                    ),
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _exhausted,
              onChanged: (value) => setState(() {
                _exhausted = value ?? false;
                _status = null;
              }),
              title: Text(_itEn('Buoni esauriti', 'Used-up gift cards')),
              subtitle: Text(_itEn(
                'Totale speso maggiore o uguale al valore iniziale del buono.',
                'Spent value greater than or equal to the original gift card value.',
              )),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _expired,
              onChanged: (value) => setState(() {
                _expired = value ?? false;
                _status = null;
              }),
              title: Text(_itEn('Buoni scaduti', 'Expired gift cards')),
              subtitle: Text(_itEn(
                'Buoni con una data di scadenza già trascorsa.',
                'Gift cards whose expiration date has already passed.',
              )),
            ),
            const Divider(height: 24),
            if (!_hasCriteria)
              Text(
                _itEn(
                  'Seleziona almeno un criterio per vedere quanti buoni verranno eliminati.',
                  'Select at least one criterion to see how many gift cards will be deleted.',
                ),
                style: theme.textTheme.bodyMedium,
              )
            else if (_validYears)
              Text(
                _itEn(
                  '$count buoni regalo corrispondono ai criteri selezionati.',
                  '$count gift cards match the selected criteria.',
                ),
                style: theme.textTheme.titleMedium,
              ),
            const SizedBox(height: 8),
            Text(
              _itEn(
                'L’eliminazione è fisica e definitiva: i buoni verranno rimossi dalla tabella gift_cards. '
                    'Il solo codice esadecimale resterà nel registro permanente dei codici emessi.',
                'Deletion is physical and permanent: gift cards are removed from the gift_cards table. '
                    'Only the hexadecimal code remains in the permanent issued-code registry.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_deletedTotal),
          child: Text(_itEn('Chiudi', 'Close')),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: _hasCriteria && _validYears && count > 0
              ? _deleteMatching
              : null,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(_itEn('Elimina corrispondenti', 'Delete matching')),
        ),
      ],
    );
  }
}
