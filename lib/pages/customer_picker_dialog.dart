import 'package:flutter/material.dart';

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
      title: const Text('Cerca cliente'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              labelText: 'Nome, cognome o codice fiscale',
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: customers.isEmpty
                ? const Center(child: Text('Nessun cliente trovato.'))
                : ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(customer.displayName),
                        subtitle: Text(customer.fiscalCode),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(customer),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
      ],
    );
  }
}
