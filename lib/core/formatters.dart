import 'app_runtime.dart';

String formatMoney(int? cents) {
  if (cents == null) return '—';
  final negative = cents < 0;
  final absolute = cents.abs();
  final units = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  final english = AppRuntime.languageCode == 'en';
  final thousandsSeparator = english ? ',' : '.';
  final decimalSeparator = english ? '.' : ',';
  final groups = units.toString().split('').reversed.toList();
  final parts = <String>[];
  for (var i = 0; i < groups.length; i += 3) {
    parts.add(groups.skip(i).take(3).toList().reversed.join());
  }
  final formattedUnits = parts.reversed.join(thousandsSeparator);
  final symbol = switch (AppRuntime.currencyCode) {
    'USD' => r'$',
    'GBP' => '£',
    'CHF' => 'CHF',
    _ => '€',
  };
  return '${negative ? '−' : ''}$symbol $formattedUnits$decimalSeparator$decimals';
}

String formatMoneyRange(int? min, int? max) {
  if (min == null && max == null) return '—';
  if (min == max) return formatMoney(min);
  return '${formatMoney(min)} – ${formatMoney(max)}';
}

String formatLocalDateTime(DateTime utc) {
  final value = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  if (AppRuntime.languageCode == 'en') {
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}

String exportTimestamp([DateTime? value]) {
  final date = (value ?? DateTime.now()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}_${two(date.hour)}-${two(date.minute)}-${two(date.second)}';
}

int? parseEuroCents(String value) {
  final normalized = value
      .trim()
      .replaceAll('€', '')
      .replaceAll(r'$', '')
      .replaceAll('£', '')
      .replaceAll('CHF', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null) throw const FormatException('Importo non valido.');
  return (parsed * 100).round();
}
