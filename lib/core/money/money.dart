import 'package:flutter/foundation.dart';

/// Integer minor-units money (D6, contract v0.3 `Money`). SEK uses öre, TND
/// millimes. Never store display strings; format locally.
///
/// Wire JSON is `{amountMinor, currency}` (`contracts/contract.json#wire`).
class Money {
  /// Job 3 / L12: every amount names its currency when it is made; there
  /// is no SEK default. [Money.zone] takes the zone's currency at creation.
  const Money({required this.minorUnits, required this.currency});

  /// [minorUnits] in the zone's currency ([zoneCurrency]), fixed now: a
  /// later zone switch never changes it.
  factory Money.zone(int minorUnits) =>
      Money(minorUnits: minorUnits, currency: zoneCurrency);

  /// Whole [units] (kronor, euros) of [currency], a two-decimal currency.
  factory Money.units(num units, {required String currency}) =>
      Money(minorUnits: (units * 100).round(), currency: currency);

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
    return Money(minorUnits: sign * (major * 100 + fraction), currency: 'SEK');
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
  /// `12.500 DT` or `+40 kr`: the currency comes from its symbol (or
  /// [currency] when it has none) and the fraction may have up to that
  /// currency's exponent of digits. Null when it is not an amount, or its
  /// symbol is another currency than [currency]. SEK reads exactly like
  /// [parseSekLabel].
  /// Job 3 / L12: the driver's zone currency (`DriverAppConfig.currency`),
  /// put in use with the zone's settings. SEK (the home zone) until a
  /// config arrives. Every "no currency known" fallback uses this, so a
  /// France driver never sees "kr".
  static String get zoneCurrency => _zone.value ?? 'SEK';
  static set zoneCurrency(String currency) => _zone.value = currency;

  /// P26: the zone currency as it arrives, null until a zone config (or a
  /// test) sets it. Screens built before the config listen to it, so a
  /// Paris driver's island turns to € when the config lands.
  static final ValueNotifier<String?> _zone = ValueNotifier<String?>(null);
  static ValueListenable<String?> get zoneCurrencyChanges => _zone;

  /// Whether a zone config has set [zoneCurrency] yet.
  static bool get zoneKnown => _zone.value != null;

  /// Back to "no zone known yet", as on a fresh launch.
  @visibleForTesting
  static void forgetZone() => _zone.value = null;

  /// The zone currency's symbol: `kr`, `€` or `DT`.
  static String get zoneSymbol => symbols[zoneCurrency] ?? zoneCurrency;

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
    final code = found ?? currency ?? zoneCurrency;
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

  /// One sum per currency, in the order the currencies first appear (live
  /// sweep 2026-11-02 M-5: never € added into kr). None = `0,00 kr`.
  static List<Money> totals(Iterable<Money> amounts) {
    final sums = <String, int>{};
    for (final amount in amounts) {
      sums[amount.currency] = (sums[amount.currency] ?? 0) + amount.minorUnits;
    }
    if (sums.isEmpty) return [Money.zone(0)];
    return [
      for (final entry in sums.entries)
        Money(minorUnits: entry.value, currency: entry.key),
    ];
  }

  /// "104,80 kr · 4,80 €".
  static String formatTotals(Iterable<Money> amounts) =>
      totals(amounts).map((m) => m.formatted).join(' · ');

  Money operator +(Money other) {
    _sameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _sameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  /// Decimal sign: a dot for the dinar (contract v0.18.59 §81), else a comma.
  String get _decimalSign => currency == 'TND' ? '.' : ',';

  /// Local display: `104,80 kr` / `2 994,80 kr` / `12.500 DT` /
  /// `1 250.000 DT` (contract v0.18.59 §81: the dinar with a dot).
  String get formatted {
    final symbol = symbols[currency];
    if (symbol == null) {
      throw UnsupportedError('No formatter for $currency');
    }
    final parts = majorString.replaceFirst('-', '').split('.');
    final sign = minorUnits < 0 ? '−' : '';
    return '$sign${_group(int.parse(parts[0]))}$_decimalSign${parts[1]} $symbol';
  }

  /// Exactly [formatted]: `40,00 kr`, `12,50 kr`, `5.000 DT`. Owner
  /// 2026-11-14 (contract v0.18.89 `moneyDisplay.wholeAmounts`): whole
  /// amounts keep their decimals everywhere, so the zero fraction is no
  /// longer dropped (it showed "40 kr" / "5 DT"). Kept as a name for the
  /// boosts, cash to collect and fee texts that used it.
  String get formattedShort => formatted;

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
