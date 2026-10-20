/// Integer minor-units money (D6, contract v0.3 `Money`). SEK uses öre, TND
/// millimes. Never store display strings; format locally.
///
/// Wire JSON is `{amountMinor, currency}` (`contracts/contract.json#wire`).
class Money {
  const Money({required this.minorUnits, this.currency = 'SEK'});

  factory Money.ore(int ore) => Money(minorUnits: ore);

  factory Money.sek(num kronor) => Money(minorUnits: (kronor * 100).round());

  /// Contract wire form. Throws [FormatException] for anything else: a
  /// non-integer amount, a missing or non-ISO currency, a currency without a
  /// known exponent, or the legacy `minorUnits` key (see [fromStoredJson]).
  factory Money.fromJson(Map<String, dynamic> json) {
    final amount = json['amountMinor'];
    final currency = json['currency'];
    if (amount is! int) {
      throw FormatException('amountMinor must be an integer', amount);
    }
    if (currency is! String || !_iso.hasMatch(currency)) {
      throw FormatException('currency must be ISO 4217', currency);
    }
    if (!exponents.containsKey(currency)) {
      throw FormatException('Unknown currency exponent', currency);
    }
    return Money(minorUnits: amount, currency: currency);
  }

  /// Local storage written before contract v0.3 used `minorUnits`. Reads
  /// both; never use it for wire input.
  factory Money.fromStoredJson(Map<String, dynamic> json) {
    if (json.containsKey('amountMinor') || !json.containsKey('minorUnits')) {
      return Money.fromJson(json);
    }
    return Money.fromJson({
      'amountMinor': json['minorUnits'],
      'currency': json['currency'],
    });
  }

  /// ISO 4217 minor-unit exponents (`contract.json#currencies`).
  static const Map<String, int> exponents = {'SEK': 2, 'EUR': 2, 'TND': 3};

  /// Display symbols (`contract.json#currencies`).
  static const Map<String, String> symbols = {
    'SEK': 'kr',
    'EUR': '€',
    'TND': 'DT',
  };

  static final RegExp _iso = RegExp(r'^[A-Z]{3}$');

  /// Strict migration of known legacy SEK labels; unknown amounts stay unknown.
  static Money? parseSekLabel(String label) {
    var value = label.trim().replaceAll('−', '-').replaceAll(' ', ' ');
    value = value
        .replaceFirst(RegExp(r'\s*(kr|SEK)$', caseSensitive: false), '')
        .trim();
    var sign = 1;
    if (value.startsWith('-')) {
      sign = -1;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }
    final decimal = RegExp(r'[,.](\d{1,2})$').firstMatch(value);
    var fraction = 0;
    if (decimal != null) {
      fraction = int.parse(decimal.group(1)!.padRight(2, '0'));
      value = value.substring(0, decimal.start);
    }
    if (!RegExp(r'^(\d+|\d{1,3}([ .,])\d{3}(?:\2\d{3})*)$').hasMatch(value)) {
      return null;
    }
    final major = int.tryParse(value.replaceAll(RegExp(r'[ .,]'), ''));
    if (major == null) {
      return null;
    }
    return Money.ore(sign * (major * 100 + fraction));
  }

  /// Label suffixes (`symbols` and ISO codes) → currency.
  static const Map<String, String> _suffixes = {
    'kr': 'SEK',
    'SEK': 'SEK',
    '€': 'EUR',
    'EUR': 'EUR',
    'DT': 'TND',
    'TND': 'TND',
  };

  /// A display label in any known currency, e.g. `104,80 kr`, `24,50 €`,
  /// `12,500 DT` or `+40 kr`: the currency comes from its symbol (or
  /// [currency] when it has none) and the fraction may have up to that
  /// currency's exponent of digits. Null when it is not an amount, or its
  /// symbol is another currency than [currency]. SEK reads exactly like
  /// [parseSekLabel].
  static Money? parseLabel(String label, {String? currency}) {
    var value = label.trim().replaceAll('−', '-').replaceAll('\u00a0', ' ');
    String? found;
    for (final entry in _suffixes.entries) {
      if (value.toUpperCase().endsWith(entry.key.toUpperCase())) {
        found = entry.value;
        value = value.substring(0, value.length - entry.key.length).trim();
        break;
      }
    }
    if (found != null && currency != null && found != currency) return null;
    final code = found ?? currency ?? 'SEK';
    final exponent = exponents[code];
    if (exponent == null) return null;
    if (code == 'SEK') return parseSekLabel(value);
    var sign = 1;
    if (value.startsWith('-')) {
      sign = -1;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }
    var fraction = 0;
    final decimal = RegExp('[,.](\\d{1,$exponent})\$').firstMatch(value);
    if (decimal != null) {
      fraction = int.parse(decimal.group(1)!.padRight(exponent, '0'));
      value = value.substring(0, decimal.start);
    }
    // Thousands are grouped with spaces ([formatted]).
    if (!RegExp(r'^(\d+|\d{1,3}( \d{3})+)$').hasMatch(value)) return null;
    var unit = 1;
    for (var i = 0; i < exponent; i++) {
      unit *= 10;
    }
    final major = int.parse(value.replaceAll(' ', ''));
    return Money(minorUnits: sign * (major * unit + fraction), currency: code);
  }

  final int minorUnits;
  final String currency;

  /// Contract name of [minorUnits].
  int get amountMinor => minorUnits;

  int get ore => minorUnits;

  /// Minor-unit exponent of [currency] (SEK/EUR 2, TND 3).
  int get exponent =>
      exponents[currency] ??
      (throw UnsupportedError('No exponent for $currency'));

  bool get isZero => minorUnits == 0;

  Map<String, dynamic> toJson() => {
    'amountMinor': minorUnits,
    'currency': currency,
  };

  /// Plain decimal amount, e.g. `126.75`, `12.500` (TND), `-20.00`.
  String get majorString {
    final n = exponent;
    final abs = minorUnits.abs();
    var unit = 1;
    for (var i = 0; i < n; i++) {
      unit *= 10;
    }
    final sign = minorUnits < 0 ? '-' : '';
    return '$sign${abs ~/ unit}.${(abs % unit).toString().padLeft(n, '0')}';
  }

  Money operator +(Money other) {
    _sameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _sameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  /// Local display: `104,80 kr` / `2 994,80 kr` / `12,500 DT`.
  String get formatted {
    final symbol = symbols[currency];
    if (symbol == null) {
      throw UnsupportedError('No formatter for $currency');
    }
    final parts = majorString.replaceFirst('-', '').split('.');
    final sign = minorUnits < 0 ? '−' : '';
    return '$sign${_group(int.parse(parts[0]))},${parts[1]} $symbol';
  }

  /// Like [formatted], without a zero fraction: `40 kr`, `12,50 kr`. Used
  /// where the app showed whole amounts (boosts, cash to collect).
  String get formattedShort {
    final full = formatted;
    final zero = ',${'0' * exponent} ';
    return full.contains(zero) ? full.replaceFirst(zero, ' ') : full;
  }

  void _sameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError.value(other.currency, 'currency', 'mismatch');
    }
  }

  static String _group(int major) {
    final digits = major.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      if (i > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is Money &&
        other.minorUnits == minorUnits &&
        other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => formatted;
}
