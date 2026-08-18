import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'it_IT', symbol: '€');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');

String formatMoney(int? cents) => cents == null ? '—' : _currency.format(cents / 100);

String formatMoneyRange(int? min, int? max) {
  if (min == null && max == null) return '—';
  if (min == max) return formatMoney(min);
  return '${formatMoney(min)} – ${formatMoney(max)}';
}

String formatLocalDateTime(DateTime utc) => _dateTime.format(utc.toLocal());

int? parseEuroCents(String value) {
  final normalized = value.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null) throw const FormatException('Importo non valido.');
  return (parsed * 100).round();
}
