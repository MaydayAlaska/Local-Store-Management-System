import '../models/customer.dart';

class FiscalCodeService {
  const FiscalCodeService._();

  static final RegExp _candidatePattern = RegExp(r'[A-Z0-9]{16}');
  static final RegExp _structurePattern = RegExp(
    r'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[ABCDEHLMPRST][0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{3}[A-Z]$',
  );

  static const Map<String, int> _omocodiaDigits = {
    'L': 0,
    'M': 1,
    'N': 2,
    'P': 3,
    'Q': 4,
    'R': 5,
    'S': 6,
    'T': 7,
    'U': 8,
    'V': 9,
  };

  static const Map<String, int> _months = {
    'A': 1,
    'B': 2,
    'C': 3,
    'D': 4,
    'E': 5,
    'H': 6,
    'L': 7,
    'M': 8,
    'P': 9,
    'R': 10,
    'S': 11,
    'T': 12,
  };

  static const Map<String, int> _oddValues = {
    '0': 1,
    '1': 0,
    '2': 5,
    '3': 7,
    '4': 9,
    '5': 13,
    '6': 15,
    '7': 17,
    '8': 19,
    '9': 21,
    'A': 1,
    'B': 0,
    'C': 5,
    'D': 7,
    'E': 9,
    'F': 13,
    'G': 15,
    'H': 17,
    'I': 19,
    'J': 21,
    'K': 2,
    'L': 4,
    'M': 18,
    'N': 20,
    'O': 11,
    'P': 3,
    'Q': 6,
    'R': 8,
    'S': 12,
    'T': 14,
    'U': 16,
    'V': 10,
    'W': 22,
    'X': 25,
    'Y': 24,
    'Z': 23,
  };

  static FiscalCodeData? tryParse(String raw, {DateTime? now}) {
    try {
      return parse(raw, now: now);
    } on FormatException {
      return null;
    }
  }

  static FiscalCodeData parse(String raw, {DateTime? now}) {
    final fiscalCode = _extractCandidate(raw);
    if (!_structurePattern.hasMatch(fiscalCode)) {
      throw const FormatException('Struttura del codice fiscale non valida.');
    }
    if (!_hasValidCheckCharacter(fiscalCode)) {
      throw const FormatException('Carattere di controllo del codice fiscale non valido.');
    }

    final year = _decodeNumber(fiscalCode.substring(6, 8));
    final month = _months[fiscalCode[8]];
    if (month == null) throw const FormatException('Mese non valido nel codice fiscale.');

    final encodedDay = _decodeNumber(fiscalCode.substring(9, 11));
    final isFemale = encodedDay > 40;
    final day = isFemale ? encodedDay - 40 : encodedDay;
    if (day < 1 || day > 31) throw const FormatException('Giorno non valido nel codice fiscale.');

    final reference = now ?? DateTime.now();
    var fullYear = 2000 + year;
    if (fullYear > reference.year) fullYear -= 100;

    late final DateTime birthDate;
    try {
      birthDate = DateTime(fullYear, month, day);
      if (birthDate.year != fullYear || birthDate.month != month || birthDate.day != day) {
        throw const FormatException('Data di nascita non valida nel codice fiscale.');
      }
    } on ArgumentError {
      throw const FormatException('Data di nascita non valida nel codice fiscale.');
    }

    final placeDigits = _decodeNumber(fiscalCode.substring(12, 15)).toString().padLeft(3, '0');
    final birthPlaceCode = '${fiscalCode[11]}$placeDigits';

    return FiscalCodeData(
      fiscalCode: fiscalCode,
      birthDate: birthDate,
      sex: isFemale ? 'F' : 'M',
      birthPlaceCode: birthPlaceCode,
    );
  }

  static String _extractCandidate(String raw) {
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.length == 16 && RegExp(r'^[A-Z0-9]{16}$').hasMatch(normalized)) {
      return normalized;
    }
    final match = _candidatePattern.firstMatch(normalized);
    if (match == null) throw const FormatException('Codice fiscale non trovato nella scansione.');
    return match.group(0)!;
  }

  static int _decodeNumber(String value) {
    var result = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final digit = int.tryParse(character) ?? _omocodiaDigits[character];
      if (digit == null) throw const FormatException('Parte numerica del codice fiscale non valida.');
      result = result * 10 + digit;
    }
    return result;
  }

  static bool _hasValidCheckCharacter(String fiscalCode) {
    var total = 0;
    for (var index = 0; index < 15; index++) {
      final character = fiscalCode[index];
      if (index.isEven) {
        final value = _oddValues[character];
        if (value == null) return false;
        total += value;
      } else {
        final code = character.codeUnitAt(0);
        if (code >= 48 && code <= 57) {
          total += code - 48;
        } else if (code >= 65 && code <= 90) {
          total += code - 65;
        } else {
          return false;
        }
      }
    }
    return fiscalCode.codeUnitAt(15) == 65 + (total % 26);
  }
}
