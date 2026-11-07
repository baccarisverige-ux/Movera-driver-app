import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finder A7 (plan/finders-2026-11-07/A.md): a language picked with the
/// globe BEFORE sign-in was never saved to the account (no account yet, and
/// after sign-in nothing compared the phone's pick with `Driver.language`),
/// so the server's pushes and bell notices kept the old language. After
/// sign-in the pick is now saved once (`PATCH /driver/profile {language}`).
void main() {
  late List<http.Request> requests;
  late int profileVersion;
  late String profileLanguage;
  late DriverAccountSession session;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> driver() => {
    'driverId': 'drv_1',
    'version': profileVersion,
    'accountStatus': 'active',
    'onlineStatus': 'offline',
    'firstName': 'Test',
    'language': profileLanguage,
    'zoneIds': ['Z001'],
    'categoryIds': ['economy'],
    'documents': <Object>[],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverLanguage.resetForTest();
    requests = [];
    profileVersion = 3;
    profileLanguage = 'sv';
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/driver/profile') {
          if (request.method == 'PATCH') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['expectedVersion'] != profileVersion) {
              return json(409, {'code': 'version_mismatch', 'message': 'x'});
            }
            profileLanguage = body['language'] as String;
            profileVersion++;
          }
          return json(200, driver());
        }
        return json(404, {'code': 'not_found', 'message': 'No.'});
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );
    session = DriverAccountSession(repository: DriverAccountRepository(api));
    // The live app's hook (main.dart): a pick is saved to the account.
    DriverLanguage.saveToAccount = session.saveLanguage;
  });

  tearDown(() {
    DriverLanguage.saveToAccount = null;
    DriverLanguage.resetForTest();
  });

  List<Map<String, dynamic>> patches() => [
    for (final r in requests)
      if (r.method == 'PATCH') jsonDecode(r.body) as Map<String, dynamic>,
  ];

  test(
    'globe pick "fr" before sign-in → saved to the account after it',
    () async {
      // Sign-in screen: no account yet, the pick stays on the phone.
      await DriverLanguage.choose('fr', SettingsRepository());
      await pumpEventQueue();
      expect(patches(), isEmpty);
      // Signed in: the account says sv.
      await session.refresh();
      await pumpEventQueue();
      expect(patches(), [
        {'expectedVersion': 3, 'language': 'fr'},
      ]);
      expect(profileLanguage, 'fr');
      expect(session.account?.language, 'fr');
      expect(DriverLanguage.current.value, 'fr');
      // Later reads do not save again.
      await session.refresh();
      await pumpEventQueue();
      expect(patches(), hasLength(1));
    },
  );

  test(
    'no pick on this phone → the account language is used, not saved',
    () async {
      await session.refresh();
      await pumpEventQueue();
      expect(patches(), isEmpty);
      expect(DriverLanguage.current.value, 'sv');
    },
  );

  test('the pick is the account language already → nothing saved', () async {
    await DriverLanguage.choose('sv', SettingsRepository());
    await session.refresh();
    await pumpEventQueue();
    expect(patches(), isEmpty);
  });
}
