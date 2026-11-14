import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

/// SV supervisor must-fix 1 (contract.json#drivingLimits.restMinutes "the
/// break length the app shows", default 30; owner decisions/
/// driving-time-limits.md:3 "Rest rules (break length) as admin setting with
/// default"): the driver app reads DriverAppConfig.drivingLimits.restMinutes
/// and shows it; no hard-coded break.
void main() {
  tearDown(() => DriverAccountRules.current = const DriverAccountRules());

  test('drivingLimits.restMinutes is read; missing or bad = 30', () {
    expect(
      DriverAppConfig.fromJson(<String, dynamic>{
        'drivingLimits': <String, dynamic>{'restMinutes': 45},
      }).restMinutes,
      45,
    );
    expect(DriverAppConfig.fromJson(<String, dynamic>{}).restMinutes, 30);
    expect(
      DriverAppConfig.fromJson(<String, dynamic>{
        'drivingLimits': <String, dynamic>{'restMinutes': -5},
      }).restMinutes,
      30,
    );
  });

  test('applying the zone document puts the break in use for the clock', () {
    DriverAppConfig.fromJson(<String, dynamic>{
      'drivingLimits': <String, dynamic>{'restMinutes': 45},
    }).apply();
    expect(DriverAccountRules.current.rest.breakMinutes, 45);
    expect(DrivingTimeClock(now: () => DateTime(2026)).rule.breakMinutes, 45);
  });

  test('the sheet label exists in en, fr and sv', () {
    for (final code in ['en', 'fr', 'sv']) {
      final text = lookupAppLocalizations(Locale(code)).suggestedBreak;
      expect(text, isNotEmpty, reason: code);
    }
    expect(lookupAppLocalizations(const Locale('en')).suggestedBreak, 'Break');
  });
}
