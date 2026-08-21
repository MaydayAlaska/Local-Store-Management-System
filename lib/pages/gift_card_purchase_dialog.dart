import 'package:flutter/material.dart';

import '../core/app_runtime.dart';
import '../core/formatters.dart';
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

  String itEn(String it, String en) => AppStrings.pair(it, en);
  String dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String percentText(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceAll('.', ',');
  int valueCents() {
    final parsed = double.tryParse(
      valueController.text.trim().replaceAll(',', '.'),
    );
    return parsed == null ? 0 : (parsed * 100).round();
  }

  int vatIncludedCents(int totalCents, double percent) {
    final rate = percent.clamp(0, 100).toDouble();
    if (totalCents <= 0 || rate <= 0) return 0;
    return (totalCents * rate / (100 + rate)).round();
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
              error = itEn(
                'Inserisci un valore maggiore di zero.',
                'Enter a value greater than zero.',
              );
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

        final vatPercent = AppRuntime.vatPercent.clamp(0, 100).toDouble();
        final vatCents = vatIncludedCents(valueCents(), vatPercent);

        return AlertDialog(
          title: Text(itEn('Aggiungi buono regalo', 'Add gift card')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  itEn(
                    'Il buono verrà aggiunto al carrello e associato a $customerName quando registri la vendita. Il prezzo pagato corrisponde al valore del buono.',
                    'The gift card will be added to the cart and linked to $customerName when the sale is registered. The price paid is the gift card value.',
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
                    labelText: itEn('Valore / prezzo', 'Value / price'),
                    prefixText: '${AppRuntime.currencySymbol} ',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${itEn('VAT inclusa', 'VAT included')} (${percentText(vatPercent)}%)',
                        ),
                      ),
                      Text(
                        formatMoney(vatCents),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  itEn(
                    'Data di scadenza (facoltativa)',
                    'Expiration date (optional)',
                  ),
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
                              ? itEn('Nessuna scadenza', 'No expiration')
                              : dateText(expirationDate!),
                        ),
                      ),
                    ),
                    if (expirationDate != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: itEn('Rimuovi scadenza', 'Clear expiration'),
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
              label: Text(itEn('Aggiungi al carrello', 'Add to cart')),
            ),
          ],
        );
      },
    ),
  );

  valueController.dispose();
  return result;
}
