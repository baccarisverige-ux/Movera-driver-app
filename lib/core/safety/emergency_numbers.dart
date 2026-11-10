import 'dart:ui' show Locale;

import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/l10n/app_localizations.dart' show lookupAppLocalizations;

/// One row of `DriverAppConfig.emergencyNumbers` (contract v0.18.57 §79,
/// `contract.json#emergencyNumbers.item`).
class EmergencyNumber {
  const EmergencyNumber({
    required this.kind,
    required this.number,
    required this.label,
  });

  static const kinds = {'police', 'ambulance', 'fire', 'general'};
  static final _pattern = RegExp(r'^\+?[0-9]{2,15}$');

  /// police | ambulance | fire | general.
  final String kind;

  /// Digits, optional leading +.
  final String number;

  /// `{ sv, fr, en }`.
  final Map<String, String> label;

  Uri get uri => Uri(scheme: 'tel', path: number);

  /// The label in the app language (English when missing).
  String get localLabel =>
      label[DriverAppTexts.language] ?? label['en'] ?? number;

  /// `emergencyNumbers.texts.callNumber`: "Call {label} {number}".
  /// The text lives in lib/l10n/parts/safety.*.arb (emergencyCallNumber).
  String get callText => tr.emergencyCallNumber(localLabel, number);

  static EmergencyNumber? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'];
    final number = json['number'];
    final label = json['label'];
    if (kind is! String || !kinds.contains(kind)) return null;
    if (number is! String || !_pattern.hasMatch(number)) return null;
    if (label is! Map) return null;
    final labels = <String, String>{};
    for (final code in const ['sv', 'fr', 'en']) {
      final text = label[code];
      if (text is String && text.trim().isNotEmpty) labels[code] = text;
    }
    if (labels.isEmpty) return null;
    return EmergencyNumber(kind: kind, number: number, label: labels);
  }
}

/// The country's emergency numbers (contract v0.18.57 §79), written by the
/// server into DriverAppConfig.emergencyNumbers. The config document is
/// kept on the device (PrefsDriverConfigCache) and read back on start, so
/// the last list works offline; [fallback] (112) only if none was ever
/// received.
abstract final class EmergencyNumbers {
  /// "A country with no default and nothing saved shows 112."
  /// The label comes from lib/l10n (emergencyGeneralLabel).
  static final List<EmergencyNumber> fallback = List.unmodifiable([
    EmergencyNumber(
      kind: 'general',
      number: '112',
      label: {
        for (final code in const ['sv', 'fr', 'en'])
          code: lookupAppLocalizations(Locale(code)).emergencyGeneralLabel,
      },
    ),
  ]);

  static List<EmergencyNumber> current = fallback;

  /// True once a served list was taken. Before that the screens keep their
  /// "112" texts.
  static bool get received => !identical(current, fallback);

  /// The main number: the SOS dials it.
  static EmergencyNumber get main => current.first;

  /// The rows after the main one (extra buttons on "SOS sent").
  static List<EmergencyNumber> get others => current.skip(1).toList();

  /// [row]'s "Call {label} {number}", or [legacy] (the old "Call 112"
  /// text) while no list was ever received.
  static String labelFor(EmergencyNumber row, String legacy) =>
      received ? row.callText : legacy;

  /// 1–6 valid rows, else null.
  static List<EmergencyNumber>? parse(Object? json) {
    if (json is! List || json.isEmpty) return null;
    final rows = <EmergencyNumber>[];
    for (final item in json.take(6)) {
      final row = EmergencyNumber.fromJson(item);
      if (row != null) rows.add(row);
    }
    return rows.isEmpty ? null : List.unmodifiable(rows);
  }

  /// Takes a served list when valid; otherwise the kept one stays.
  static void accept(Object? json) {
    final rows = parse(json);
    if (rows != null) current = rows;
  }

  /// Tests: back to "never received".
  static void reset() => current = fallback;
}
