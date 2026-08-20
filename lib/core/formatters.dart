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

int? parsePriceFormulaCents(String value) {
  final normalized = value
      .trim()
      .replaceAll('€', '')
      .replaceAll(r'$', '')
      .replaceAll('£', '')
      .replaceAll('CHF', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  if (normalized.isEmpty) return null;

  final result = _evaluatePriceExpression(normalized);
  if (!result.isFinite || result < 0) {
    throw const FormatException('Importo o formula non validi.');
  }
  return (result * 100).round();
}

double _evaluatePriceExpression(String expression) {
  final percentSuffix =
      RegExp(r'^(.+)([+-])(\d+(?:\.\d+)?)%$').firstMatch(expression);
  if (percentSuffix != null) {
    final base = _evaluatePriceExpression(percentSuffix.group(1)!);
    final percent = double.parse(percentSuffix.group(3)!);
    final factor = percent / 100;
    return percentSuffix.group(2) == '-'
        ? base * (1 - factor)
        : base * (1 + factor);
  }

  if (expression.contains('%')) {
    throw const FormatException('Percentuale non valida nella formula.');
  }
  return _evaluateArithmeticExpression(expression);
}

double _evaluateArithmeticExpression(String expression) {
  final tokens = RegExp(r'\d+(?:\.\d+)?|[+\-*/]')
      .allMatches(expression)
      .map((match) => match.group(0)!)
      .toList();
  if (tokens.isEmpty || tokens.join() != expression || tokens.length.isEven) {
    throw const FormatException('Importo o formula non validi.');
  }

  final values = <double>[];
  final lowOps = <String>[];
  var current = double.tryParse(tokens.first);
  if (current == null) {
    throw const FormatException('Importo o formula non validi.');
  }

  for (var i = 1; i < tokens.length; i += 2) {
    final op = tokens[i];
    final operand = double.tryParse(tokens[i + 1]);
    if (operand == null) {
      throw const FormatException('Importo o formula non validi.');
    }
    if (op == '*') {
      current *= operand;
    } else if (op == '/') {
      if (operand == 0) {
        throw const FormatException('Divisione per zero non valida.');
      }
      current /= operand;
    } else if (op == '+' || op == '-') {
      values.add(current);
      lowOps.add(op);
      current = operand;
    } else {
      throw const FormatException('Operatore non valido.');
    }
  }
  values.add(current);

  var result = values.first;
  for (var i = 0; i < lowOps.length; i++) {
    result = lowOps[i] == '+'
        ? result + values[i + 1]
        : result - values[i + 1];
  }
  return result;
}
