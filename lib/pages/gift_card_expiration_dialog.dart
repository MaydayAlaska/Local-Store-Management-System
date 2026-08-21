import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_gift_card_extensions.dart';
import '../repositories/customer_repository.dart';

class _GiftCardExpirationDraft {
  const _GiftCardExpirationDraft(this.expiresAtUtc);

  final DateTime? expiresAtUtc;
}

Future<void> showGiftCardExpirationManagerDialog(
  BuildContext context, {
  required Customer customer,
  required CustomerRepository repository,
}) async {
  String itEn(String it, String en) => AppStrings.pair(it, en);

  String dateText(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  DateTime endOfLocalDayUtc(DateTime value) => DateTime(
        value.year,
        value.month,
        value.day,
        23,
        59,
        59,
        999,
      ).toUtc();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final cards = repository.giftCardsForCustomer(customer.id);

        Future<void> editExpiration(GiftCard card) async {
          final today = DateTime.now();
          final firstDate = DateTime(today.year, today.month, today.day);
          final current = card.expiresAtUtc?.toLocal();
          DateTime? selectedDate = current == null
              ? null
              : DateTime(current.year, current.month, current.day);

          final result = await showDialog<_GiftCardExpirationDraft>(
            context: dialogContext,
            builder: (editContext) => StatefulBuilder(
              builder: (context, setEditState) {
                Future<void> pickDate() async {
                  final safeInitial = selectedDate == null ||
                          selectedDate!.isBefore(firstDate)
                      ? firstDate
                      : selectedDate!;
                  final picked = await showDatePicker(
                    context: editContext,
                    initialDate: safeInitial,
                    firstDate: firstDate,
                    lastDate: DateTime(today.year + 20, 12, 31),
                  );
                  if (picked != null) {
                    setEditState(() => selectedDate = picked);
                  }
                }

                return AlertDialog(
                  title: Text(
                    '${itEn('Scadenza buono', 'Gift card expiration')} ${card.code}',
                  ),
                  content: SizedBox(
                    width: 430,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          itEn(
                            'Imposta una data di scadenza oppure lascia il buono senza scadenza.',
                            'Set an expiration date or leave the gift card without expiration.',
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            selectedDate == null
                                ? itEn('Nessuna scadenza', 'No expiration')
                                : dateText(selectedDate!),
                          ),
                        ),
                        if (selectedDate != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                setEditState(() => selectedDate = null),
                            icon: const Icon(Icons.event_busy_outlined),
                            label: Text(
                              itEn('Rimuovi scadenza', 'Remove expiration'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(editContext).pop(),
                      child: Text(AppStrings.t('cancel')),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(editContext).pop(
                        _GiftCardExpirationDraft(
                          selectedDate == null
                              ? null
                              : endOfLocalDayUtc(selectedDate!),
                        ),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(itEn('Salva scadenza', 'Save expiration')),
                    ),
                  ],
                );
              },
            ),
          );

          if (result == null) return;
          repository.updateGiftCardExpiration(
            card.id,
            expiresAtUtc: result.expiresAtUtc,
          );
          setDialogState(() {});
        }

        return AlertDialog(
          title: Text(itEn('Scadenze buoni regalo', 'Gift card expirations')),
          content: SizedBox(
            width: 620,
            height: (cards.length * 82.0).clamp(180.0, 460.0).toDouble(),
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      itEn(
                        'Nessun buono regalo associato a questo cliente.',
                        'No gift cards are linked to this customer.',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return ListTile(
                        leading: Icon(
                          card.isExpired
                              ? Icons.event_busy_outlined
                              : Icons.card_giftcard_outlined,
                        ),
                        title: Text(
                          card.code,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          card.expiresAtUtc == null
                              ? itEn('Nessuna scadenza', 'No expiration')
                              : '${itEn('Scadenza', 'Expires')}: ${dateText(card.expiresAtUtc!)}',
                        ),
                        trailing: IconButton(
                          tooltip: itEn(
                            'Modifica scadenza',
                            'Edit expiration',
                          ),
                          onPressed: () => editExpiration(card),
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                        onTap: () => editExpiration(card),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(itEn('Chiudi', 'Close')),
            ),
          ],
        );
      },
    ),
  );
}
