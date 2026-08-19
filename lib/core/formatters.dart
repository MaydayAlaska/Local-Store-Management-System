String formatMoney(int? cents) {
  if (cents == null) return '—';
  final negative = cents < 0;
  final absolute = cents.abs();
  final euros = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  final groups = euros.toString().split('').reversed.toList();
  final parts = <String>[];
  for (var i = 0; i < groups.length; i += 3) {
    parts.add(groups.skip(i).take(3).toList().reversed.join());
  }
  final formattedEuros = parts.reversed.join('.');
  return '${negative ? '−' : ''}€ $formattedEuros,$decimals';
}

String formatMoneyRange(int? min, int? max) {
  if (min == null && max == null) return '—';
  if (min == max) return formatMoney(min);
  return '${formatMoney(min)} – ${formatMoney(max)}';
}

String formatLocalDateTime(DateTime utc) {
  final value = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}

int? parseEuroCents(String value) {
  final normalized = value.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null) throw const FormatException('Importo non valido.');
  return (parsed * 100).round();
}
