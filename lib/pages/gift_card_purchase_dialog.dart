import 'package:flutter/material.dart';

import '../core/app_runtime.dart';
import '../l10n/app_strings.dart';

class GiftCardPurchaseDraft {
  const GiftCardPurchaseDraft({
    required this.valueCents,
    this.expiresAtUtc,
  });

  final int valueCents;
  final DateTime? expiresAtUtc;
}

Future<GiftCardPurchaseDraft?> showGiftCardPurchaseDialog(
  BuildContext context, {
  required String customerName,
}) async {
  final valueController = TextEditingController();
  DateTime? expirationDate;
  String? error;

  String dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  int valueCents() {
    final parsed = double.tryParse(
      valueController.text.trim().replaceAll(',', '.'),
    );
    return parsed == null ? 0 : (parsed * 100).round();
  }

  final result = await showDialog<GiftCardPurchaseDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
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

        void submit() {
          final cents = valueCents();
          if (cents <= 0) {
            setDialogState(() {
              error = AppStrings.t('value_greater_than_zero');
            });
            return;
          }

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
            GiftCardPurchaseDraft(
              valueCents: cents,
              expiresAtUtc: expiresAtUtc,
            ),
          );
        }

        return AlertDialog(
          title: Text(AppStrings.t('gift_card_add')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.t(
                    'gift_card_purchase_help',
                    {'customerName': customerName},
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: valueController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) {
                    setDialogState(() {
                      if (error != null) error = null;
                    });
                  },
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppStrings.t('gift_card_value_price'),
                    prefixText: '${AppRuntime.currencySymbol} ',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.t('expiration_date_optional'),
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
                              ? AppStrings.t('no_expiration')
                              : dateText(expirationDate!),
                        ),
                      ),
                    ),
                    if (expirationDate != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: AppStrings.t('remove_expiration'),
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
              onPressed: submit,
              icon: const Icon(Icons.card_giftcard_outlined),
              label: Text(AppStrings.t('add_to_cart')),
            ),
          ],
        );
      },
    ),
  );

  valueController.dispose();
  return result;
}
