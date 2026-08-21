import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/customer.dart';
import '../repositories/customer_repository.dart';

Future<Customer?> showCustomerPickerDialog(
  BuildContext context, {
  required CustomerRepository repository,
}) =>
    showDialog<Customer>(
      context: context,
      builder: (_) => _CustomerPickerDialog(repository: repository),
    );

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.repository});

  final CustomerRepository repository;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.repository.search(_search.text, 200);
    return AlertDialog(
      title: Text(AppStrings.t('search_customer')),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              labelText: AppStrings.pair(
                'Nome, codice cliente o codice fiscale',
                'Name, customer code or tax code',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: customers.isEmpty
                ? Center(
                    child: Text(
                      AppStrings.pair(
                        'Nessun cliente trovato.',
                        'No customers found.',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final fiscalCode = customer.fiscalCode?.trim();
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        title: Text(customer.displayName),
                        subtitle: Text(
                          '${customer.customerCodeDisplay}'
                          '${fiscalCode?.isNotEmpty == true ? ' · CF $fiscalCode' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(customer),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.t('cancel')),
        ),
      ],
    );
  }
}
