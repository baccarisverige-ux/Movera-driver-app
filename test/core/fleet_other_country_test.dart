// Contract v0.18.109 (server BQ-FLEETCUR, owner 2026-11-15 "a fleet = one
// country = one currency", Rules decisions/session-2026-11-06.md:1322): a
// driver joins only a fleet of his own country; join, invite and accept are
// `409 conflict` with reason `fleet_other_country` otherwise. The app says
// so in sv / fr / en instead of the general fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_language.dart';

void _speak(String language) {
  switch (language) {
    case 'sv':
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    case 'fr':
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    default:
      DriverLanguage.resetForTest();
  }
}

const _refused = ApiError(
  code: 'conflict',
  message: 'A driver can join only a fleet of his own country.',
  statusCode: 409,
  reason: 'fleet_other_country',
);

void main() {
  tearDown(DriverLanguage.resetForTest);

  const expected = {
    'en':
        'The driver and the fleet are in different countries. A fleet works in one country only.',
    'sv':
        'Föraren och åkeriet är i olika länder. Ett åkeri arbetar bara i ett land.',
    'fr':
        'Le chauffeur et la flotte sont dans des pays différents. Une flotte travaille dans un seul pays.',
  };
  for (final entry in expected.entries) {
    test('[${entry.key}] 409 fleet_other_country has its own text', () {
      _speak(entry.key);
      expect(accountErrorMessage(_refused, fallback: 'fallback'), entry.value);
    });
  }

  test('already_in_fleet keeps its own text', () {
    _speak('en');
    expect(
      accountErrorMessage(
        const ApiError(
          code: 'conflict',
          message: 'x',
          statusCode: 409,
          reason: 'already_in_fleet',
        ),
        fallback: 'fallback',
      ),
      'You’re already in a fleet. Leave it first.',
    );
  });
}
