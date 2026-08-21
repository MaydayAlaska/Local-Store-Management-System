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
                    '${AppStrings.t('gift_card_expiration')} ${card.code}',
                  ),
                  content: SizedBox(
                    width: 430,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(AppStrings.t('gift_card_expiration_help')),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            selectedDate == null
                                ? AppStrings.t('no_expiration')
                                : dateText(selectedDate!),
                          ),
                        ),
                        if (selectedDate != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                setEditState(() => selectedDate = null),
                            icon: const Icon(Icons.event_busy_outlined),
                            label: Text(AppStrings.t('remove_expiration')),
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
                      label: Text(AppStrings.t('save_expiration')),
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
          title: Text(AppStrings.t('gift_card_expirations')),
          content: SizedBox(
            width: 620,
            height: (cards.length * 82.0).clamp(180.0, 460.0).toDouble(),
            child: cards.isEmpty
                ? Center(
                    child: Text(AppStrings.t('no_gift_cards_customer')),
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
                              ? AppStrings.t('no_expiration')
                              : '${AppStrings.t('expiration')}: ${dateText(card.expiresAtUtc!)}',
                        ),
                        trailing: IconButton(
                          tooltip: AppStrings.t('edit_expiration'),
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
              child: Text(AppStrings.t('close')),
            ),
          ],
        );
      },
    ),
  );
}
