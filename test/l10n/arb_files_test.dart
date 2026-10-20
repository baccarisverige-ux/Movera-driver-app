import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_text_l10n.dart';
import 'package:movera/core/ride/cancel_reason_l10n.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Round 4: the app's texts in English, French and Swedish (lib/l10n).
Map<String, dynamic> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

/// The value names a message fills, e.g. {km}; plural cases left out.
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)[,}]').allMatches(message))
    match.group(1)!,
};

void main() {
  const languages = ['en', 'fr', 'sv'];

  test('the app has exactly English, French and Swedish', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      languages.toSet(),
    );
    for (final language in languages) {
      expect(_arb(language)['@@locale'], language);
    }
  });

  test('all ARB files have the same keys', () {
    final english = _messages(_arb('en')).toSet();
    expect(english.length, greaterThan(600));
    for (final language in ['fr', 'sv']) {
      final keys = _messages(_arb(language)).toSet();
      expect(english.difference(keys), isEmpty, reason: '$language lacks');
      expect(keys.difference(english), isEmpty, reason: '$language extra');
    }
  });

  test('every message keeps its values and is not empty', () {
    final english = _arb('en');
    for (final language in ['fr', 'sv']) {
      final arb = _arb(language);
      for (final key in _messages(english)) {
        final text = arb[key] as String;
        expect(text.trim(), isNotEmpty, reason: '$language $key');
        expect(
          _placeholders(text),
          _placeholders(english[key] as String),
          reason: '$language $key',
        );
      }
    }
  });

  test('French and Swedish are translated, not copied', () {
    final english = _arb('en');
    for (final language in ['fr', 'sv']) {
      final arb = _arb(language);
      final keys = _messages(english).toList();
      final same = keys.where((k) => arb[k] == english[k]).toList();
      // Names and codes stay the same in every language ("Radar",
      // "Movera Radar", "+{amount}", "{km} km"…), nothing more.
      expect(same.length, lessThan(keys.length * 0.06), reason: '$same');
    }
  });

  test('every admin text key has the app text in each language', () {
    for (final language in languages) {
      final strings = lookupAppLocalizations(Locale(language));
      for (final key in DriverTexts.all) {
        final text = driverTextTemplate(strings, key.id);
        expect(text, isNotNull, reason: '$language ${key.id}');
        expect(
          _placeholders(text!),
          _placeholders(key.english),
          reason: '$language ${key.id}',
        );
      }
    }
    // English is the default admin sees in Content › Driver app texts.
    final english = lookupAppLocalizations(const Locale('en'));
    for (final key in DriverTexts.all) {
      expect(driverTextTemplate(english, key.id), key.english);
    }
  });

  test('every cancel reason has its title in each language', () {
    const reasons = CancelReasons();
    final all = [
      reasons.noShow,
      for (final group in CancelReasonGroup.values) ...reasons.groups[group]!,
    ];
    final english = lookupAppLocalizations(const Locale('en'));
    for (final reason in all) {
      expect(cancelReasonTitle(english, reason.code), reason.title);
      for (final language in ['fr', 'sv']) {
        final strings = lookupAppLocalizations(Locale(language));
        expect(cancelReasonTitle(strings, reason.code), isNotNull);
        if (reason.subtitle.isNotEmpty) {
          expect(cancelReasonDetail(strings, reason.code), isNotNull);
        }
      }
    }
  });
}
