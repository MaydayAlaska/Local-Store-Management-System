import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../services/app_services.dart';
import 'gift_card_management_dialog.dart';

class GiftCardsPage extends StatefulWidget {
  const GiftCardsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<GiftCardsPage> createState() => _GiftCardsPageState();
}

class _GiftCardsPageState extends State<GiftCardsPage> {
  final _search = TextEditingController();
  String? _status;

  String _t(String it, String en) => AppStrings.pair(it, en);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _cleanupGiftCards() async {
    final deleted = await showGiftCardManagementDialog(
      context,
      repository: widget.services.customers,
    );
    if (!mounted || deleted == null) return;
    setState(() {
      _status = deleted > 0
          ? _t(
              '$deleted buoni regalo eliminati definitivamente.',
              '$deleted gift cards permanently deleted.',
            )
          : null;
    });
  }

  Future<void> _deleteGiftCard(GiftCard card, Customer? customer) async {
    final owner = customer == null
        ? ''
        : '\n${_t('Cliente', 'Customer')}: ${customer.displayName} (${customer.customerCodeDisplay})';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_t('Elimina buono regalo', 'Delete gift card')),
            content: Text(
              _t(
                'Eliminare definitivamente il buono ${card.code}?$owner\n\n'
                    'Il credito residuo di ${card.remainingDisplay} verrà perso. '
                    'Gli ordini storici conserveranno il codice e l’importo eventualmente utilizzato.',
                'Permanently delete gift card ${card.code}?$owner\n\n'
                    'Its remaining credit of ${card.remainingDisplay} will be lost. '
                    'Historical orders will keep the code and any amount that was used.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppStrings.t('cancel')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.delete_outline),
                label: Text(_t('Elimina buono', 'Delete gift card')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final deleted = widget.services.customers.deleteGiftCard(card.id);
    if (!mounted) return;
    setState(() {
      _status = deleted
          ? _t(
              'Buono ${card.code} eliminato definitivamente.',
              'Gift card ${card.code} permanently deleted.',
            )
          : _t(
              'Il buono ${card.code} non esiste più.',
              'Gift card ${card.code} no longer exists.',
            );
    });
  }

  String _cardStatus(GiftCard card) {
    if (card.isExpired) return _t('SCADUTO', 'EXPIRED');
    if (card.isExhausted) return _t('ESAURITO', 'USED UP');
    return _t('ATTIVO', 'ACTIVE');
  }

  IconData _cardIcon(GiftCard card) {
    if (card.isExpired) return Icons.event_busy_outlined;
    if (card.isExhausted) return Icons.redeem_outlined;
    return Icons.card_giftcard_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.services.customers;
    final customers = repository.search('', 5000);
    final customerById = <int, Customer>{
      for (final customer in customers) customer.id: customer,
    };
    final entries = <_GiftCardEntry>[];
    for (final customer in customers) {
      for (final card in repository.giftCardsForCustomer(customer.id, 5000)) {
        entries.add(_GiftCardEntry(card: card, customer: customer));
      }
    }
    entries.sort(
      (a, b) => b.card.createdAtUtc.compareTo(a.card.createdAtUtc),
    );

    final query = _search.text.trim().toLowerCase();
    final visibleEntries = query.isEmpty
        ? entries
        : entries.where((entry) {
            final customer = customerById[entry.card.customerId];
            final haystack = <String>[
              entry.card.code,
              customer?.displayName ?? '',
              customer?.customerCodeDisplay ?? '',
              customer?.fiscalCode ?? '',
              _cardStatus(entry.card),
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList(growable: false);

    final activeCount = entries.where((entry) => entry.card.isUsable).length;
    final exhaustedCount = entries.where((entry) => entry.card.isExhausted).length;
    final expiredCount = entries.where((entry) => entry.card.isExpired).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('Buoni regalo', 'Gift cards'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cleanupGiftCards,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(_t('Pulizia buoni', 'Gift card cleanup')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                icon: Icons.card_giftcard_outlined,
                label: _t('Totali', 'Total'),
                value: entries.length.toString(),
              ),
              _SummaryCard(
                icon: Icons.check_circle_outline,
                label: _t('Attivi', 'Active'),
                value: activeCount.toString(),
              ),
              _SummaryCard(
                icon: Icons.redeem_outlined,
                label: _t('Esauriti', 'Used up'),
                value: exhaustedCount.toString(),
              ),
              _SummaryCard(
                icon: Icons.event_busy_outlined,
                label: _t('Scaduti', 'Expired'),
                value: expiredCount.toString(),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              labelText: _t('Cerca buono', 'Search gift cards'),
              hintText: _t(
                'Codice buono, cliente, codice cliente o stato',
                'Gift card code, customer, customer code or status',
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: _t('Azzera ricerca', 'Clear search'),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: visibleEntries.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? _t(
                                'Nessun buono regalo presente.',
                                'No gift cards available.',
                              )
                            : _t(
                                'Nessun buono corrisponde alla ricerca.',
                                'No gift cards match the search.',
                              ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = visibleEntries[index];
                        final card = entry.card;
                        final customer = entry.customer;
                        final expiration = card.expirationDateDisplay;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(_cardIcon(card)),
                          ),
                          title: Text(
                            '${card.code} · ${_cardStatus(card)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${customer.displayName} · ${customer.customerCodeDisplay}\n'
                            '${_t('Totale', 'Total')}: ${card.totalDisplay} · '
                            '${_t('Speso', 'Spent')}: ${card.spentDisplay} · '
                            '${_t('Residuo', 'Remaining')}: ${card.remainingDisplay}\n'
                            '${_t('Acquistato', 'Purchased')}: ${card.purchasedDateDisplay} · '
                            '${expiration == null ? _t('Nessuna scadenza', 'No expiration') : '${_t('Scadenza', 'Expires')}: $expiration'}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: _t('Elimina buono', 'Delete gift card'),
                            onPressed: () => _deleteGiftCard(card, customer),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCardEntry {
  const _GiftCardEntry({required this.card, required this.customer});

  final GiftCard card;
  final Customer customer;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
