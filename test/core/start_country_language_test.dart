import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Driver group 1 re-check (owner 2026-10-30, contract v0.18.2 §24):
/// `auth.startCountry` ("France or sweden") and `auth.firstLanguage`
/// ("Phone language (Recommended)").
void main() {
  final contract =
      (jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>)['auth']
          as Map<String, dynamic>;

  tearDown(StartCountryHints.reset);

  group('auth.startCountry', () {
    test('only Sweden or France, in the contract\'s order, else Sweden', () {
      final rule = contract['startCountry'] as Map<String, dynamic>;
      expect(PhoneCountries.startCountries, rule['countries']);
      expect(rule['order'], ['lastFix', 'lastZone', 'deviceRegion']);
      expect(rule['fallback'], 'SE');

      expect(PhoneCountries.startFor(deviceRegion: 'FR').dial, '33');
      expect(PhoneCountries.startFor(deviceRegion: 'SE').dial, '46');
      expect(PhoneCountries.startFor(deviceRegion: 'US').dial, '46');
      expect(PhoneCountries.startFor(deviceRegion: 'TN').dial, '46');
      expect(PhoneCountries.startFor().dial, '46');
      // The last fix first, then the last zone, then the device.
      expect(
        PhoneCountries.startFor(
          lastFix: 'FR',
          lastZone: 'SE',
          deviceRegion: 'SE',
        ).iso,
        'FR',
      );
      expect(
        PhoneCountries.startFor(lastZone: 'FR', deviceRegion: 'SE').iso,
        'FR',
      );
      // A hint outside Sweden and France is skipped, not used.
      expect(
        PhoneCountries.startFor(lastFix: 'TN', deviceRegion: 'FR').iso,
        'FR',
      );
      expect(defaultPhoneCountry(localeRegion: 'FR').iso, 'FR');
      expect(defaultPhoneCountry(localeRegion: 'US').iso, 'SE');
    });

    test('what the phone kept: the zone around the last fix, else the last '
        'settings\' zone', () async {
      List<List<double>> box(double lat, double lng) => [
        [lat - 0.5, lng - 0.5],
        [lat - 0.5, lng + 0.5],
        [lat + 0.5, lng + 0.5],
        [lat + 0.5, lng - 0.5],
      ];
      final zones = jsonEncode({
        'zones': [
          {'zoneId': 'Z001', 'country': 'SE', 'polygon': box(59.33, 18.06)},
          {'zoneId': 'FR-PC', 'country': 'FR', 'polygon': box(48.86, 2.35)},
        ],
      });
      SharedPreferences.setMockInitialValues({
        PrefsDriverZonesCache.key: zones,
        DriverStartPosition.key: jsonEncode({'lat': 48.85, 'lng': 2.3}),
        PrefsDriverConfigCache.key: jsonEncode({
          'version': 3,
          'zoneId': 'Z001',
        }),
      });
      await StartCountryHints.load();
      expect(StartCountryHints.fixCountry, 'FR');
      expect(StartCountryHints.zoneCountry, 'SE');
      expect(defaultPhoneCountry(localeRegion: 'SE').iso, 'FR');

      // No fix kept: the last zone decides, before the device.
      SharedPreferences.setMockInitialValues({
        PrefsDriverZonesCache.key: zones,
        PrefsDriverConfigCache.key: jsonEncode({
          'version': 3,
          'zoneId': 'FR-PC',
        }),
      });
      await StartCountryHints.load();
      expect(StartCountryHints.fixCountry, isNull);
      expect(defaultPhoneCountry(localeRegion: 'SE').iso, 'FR');

      // Nothing kept: the device region.
      SharedPreferences.setMockInitialValues({});
      await StartCountryHints.load();
      expect(defaultPhoneCountry(localeRegion: 'FR').iso, 'FR');
      expect(defaultPhoneCountry(localeRegion: 'DE').iso, 'SE');
    });
  });

  group('auth.firstLanguage', () {
    test('the phone\'s language when sv, fr or en; else the start '
        'country\'s; else English', () {
      final rule = contract['firstLanguage'] as Map<String, dynamic>;
      expect(rule['supported'], unorderedEquals(DriverLanguage.supported));
      expect(rule['countryDefault'], DriverLanguage.countryDefault);
      expect(rule['fallback'], DriverLanguage.fallback);

      String first(String? phone, String? country) =>
          DriverLanguage.firstLanguage(
            phoneLanguage: phone,
            startCountry: country,
          );
      expect(first('fr', 'SE'), 'fr');
      expect(first('en', 'SE'), 'en');
      expect(first('sv', 'FR'), 'sv');
      expect(first('de', 'FR'), 'fr');
      expect(first('ar', 'SE'), 'sv');
      expect(first('de', null), 'en');
      expect(first(null, null), 'en');
    });

    test('a French or English phone no longer opens in the Stockholm '
        'zone\'s Swedish', () {
      // main(): the zone's default first (Stockholm: sv), then the phone.
      DriverLanguage.applyZone(const DriverHomeAdminContentService().languages);
      expect(DriverLanguage.current.value, 'sv');
      DriverLanguage.applyDevice(phoneLanguage: 'fr', startCountry: 'SE');
      expect(DriverLanguage.current.value, 'fr');
      DriverLanguage.applyDevice(phoneLanguage: 'en', startCountry: 'SE');
      expect(DriverLanguage.current.value, 'en');
      DriverLanguage.applyDevice(phoneLanguage: 'de', startCountry: 'FR');
      expect(DriverLanguage.current.value, 'fr');
    });

    test('a picked language is kept and wins over the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      DriverLanguage.applyDevice(phoneLanguage: 'fr', startCountry: 'FR');
      await DriverLanguage.choose('sv', settings);
      expect(DriverLanguage.current.value, 'sv');
      // The next start: the phone's language again, then the saved pick.
      DriverLanguage.resetForTest();
      DriverLanguage.applyDevice(phoneLanguage: 'fr', startCountry: 'FR');
      expect(DriverLanguage.current.value, 'fr');
      await DriverLanguage.restore(settings);
      expect(DriverLanguage.current.value, 'sv');
    });

    test('an account\'s language wins over the phone when nothing was '
        'picked here; a pick still wins over the account', () async {
      DriverLanguage.applyDevice(phoneLanguage: 'en', startCountry: 'SE');
      final tokens = MemoryTokenStore();
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 404)),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      final session = DriverAccountSession(
        repository: DriverAccountRepository(api),
      );
      session.replace(
        const DriverAccount(
          driverId: 'drv_1',
          accountStatus: 'active',
          firstName: 'Nils',
          version: 1,
          language: 'fr',
        ),
      );
      expect(DriverLanguage.current.value, 'fr');

      SharedPreferences.setMockInitialValues({});
      DriverLanguage.resetForTest();
      DriverLanguage.applyDevice(phoneLanguage: 'en', startCountry: 'SE');
      await DriverLanguage.choose('sv', SettingsRepository());
      session.replace(
        const DriverAccount(
          driverId: 'drv_1',
          accountStatus: 'active',
          firstName: 'Nils',
          version: 2,
          language: 'fr',
        ),
      );
      expect(DriverLanguage.current.value, 'sv');
    });
  });
}
