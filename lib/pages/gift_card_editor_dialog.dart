import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';
import 'customer_picker_dialog.dart';

class GiftCardEditDraft {
  const GiftCardEditDraft({
    required this.customerId,
    required this.expiresAtUtc,
  });

  final int? customerId;
  final DateTime? expiresAtUtc;
}

Future<GiftCardEditDraft?> showGiftCardEditorDialog(
  BuildContext context, {
  required CustomerRepository repository,
  required GiftCard card,
}) async {
  Customer? customer =
      card.customerId == null ? null : repository.getById(card.customerId!);
  DateTime? expirationDate = card.expiresAtUtc?.toLocal();

  String t(String it, String en) => AppStrings.pair(it, en);
  String dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  return showDialog<GiftCardEditDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> pickCustomer() async {
          final selected = await showCustomerPickerDialog(
            dialogContext,
            repository: repository,
          );
          if (selected == null) return;
          setDialogState(() => customer = selected);
        }

        Future<void> pickExpiration() async {
          final now = DateTime.now();
          final selected = await showDatePicker(
            context: dialogContext,
            initialDate: expirationDate ?? now.add(const Duration(days: 365)),
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: DateTime(now.year + 20, 12, 31),
          );
          if (selected == null) return;
          setDialogState(() => expirationDate = selected);
        }

        void save() {
          DateTime? expiresAtUtc;
          if (expirationDate != null) {
            final value = expirationDate!;
            expiresAtUtc = DateTime(
              value.year,
              value.month,
              value.day,
              23,
              59,
              59,
              999,
            ).toUtc();
          }
          Navigator.of(dialogContext).pop(
            GiftCardEditDraft(
              customerId: customer?.id,
              expiresAtUtc: expiresAtUtc,
            ),
          );
        }

        return AlertDialog(
          title: Text(t('Modifica buono regalo', 'Edit gift card')),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.card_giftcard_outlined),
                  title: Text(
                    card.code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${t('Valore', 'Value')}: ${card.totalDisplay} · ${t('Residuo', 'Remaining')}: ${card.remainingDisplay}',
                  ),
                ),
                const Divider(),
                Text(
                  t('Cliente associato', 'Associated customer'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer == null
                            ? t('Nessun cliente associato', 'No associated customer')
                            : '${customer!.displayName} (${customer!.customerCodeDisplay})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: pickCustomer,
                      icon: const Icon(Icons.person_search_outlined),
                      label: Text(
                        customer == null ? t('Associa', 'Assign') : t('Cambia', 'Change'),
                      ),
                    ),
                    if (customer != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: t('Rimuovi associazione', 'Remove association'),
                        onPressed: () => setDialogState(() => customer = null),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  t('Scadenza', 'Expiration'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickExpiration,
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          expirationDate == null
                              ? t('Nessuna scadenza', 'No expiration')
                              : dateText(expirationDate!),
                        ),
                      ),
                    ),
                    if (expirationDate != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: t('Rimuovi scadenza', 'Remove expiration'),
                        onPressed: () =>
                            setDialogState(() => expirationDate = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppStrings.t('cancel')),
            ),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: Text(t('Salva modifiche', 'Save changes')),
            ),
          ],
        );
      },
    ),
  );
}
