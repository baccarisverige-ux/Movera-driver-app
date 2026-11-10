import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/l10n/app_localizations.dart';

Map<String, Object> _m(int amountMinor) => {
  'amountMinor': amountMinor,
  'currency': 'SEK',
};

/// Contract v0.18.58 §80: counts-as-arrived per zone (300 m, 1000 m at an
/// airport); the app follows the server's preview, never a fixed 300 m.
void main() {
  test('an early end carries the limit and the distance for the warning', () {
    final preview = CompletePreview.tryParse({
      'total': _m(24500),
      'cashDue': _m(24500),
      'earlyEnd': true,
      'repriced': false,
      'arrivedLimitMeters': 300,
      'distanceToDropoffMeters': 940,
    })!;
    expect(preview.arrivedLimitMeters, 300);
    expect(preview.farFromDropoffMeters, 940);
  });

  test('940 m at an airport (limit 1000 m) is a normal finish: no warning', () {
    final preview = CompletePreview.tryParse({
      'total': _m(24500),
      'cashDue': _m(24500),
      'earlyEnd': false,
      'arrivedLimitMeters': 1000,
      'distanceToDropoffMeters': 940,
    })!;
    expect(preview.earlyEnd, isFalse);
    expect(preview.farFromDropoffMeters, isNull);
  });

  test('an older server without the fields still parses', () {
    final preview = CompletePreview.tryParse({
      'total': _m(100),
      'cashDue': _m(100),
      'earlyEnd': true,
    })!;
    expect(preview.arrivedLimitMeters, isNull);
    expect(preview.farFromDropoffMeters, isNull);
  });

  test('the warning in en, sv and fr (contract arrivedDistance.texts)', () {
    expect(
      lookupAppLocalizations(const Locale('en')).arrivedFarWarning(940),
      'You are 940 m from the destination – the trip ends early',
    );
    expect(
      lookupAppLocalizations(const Locale('sv')).arrivedFarWarning(940),
      'Du är 940 m från destinationen – resan avslutas tidigt',
    );
    expect(
      lookupAppLocalizations(const Locale('fr')).arrivedFarWarning(940),
      'Vous êtes à 940 m de la destination – la course se termine plus tôt',
    );
  });
}
