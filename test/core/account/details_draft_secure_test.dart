import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/auth/secure_token_store.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Follow-up 2026-11-26 (sign-up v2 review): the draft's personnummer and
/// street address live in the Keychain / Keystore, never in the plain
/// settings store, and go at sign-out.
class _FakeSecure implements SecureKeyValue {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Broken extends _FakeSecure {
  @override
  Future<void> delete(String key) async => throw StateError('locked');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeSecure secure;
  final before = DetailsDraft.secure;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    secure = _FakeSecure();
    DetailsDraft.secure = secure;
  });
  tearDown(() => DetailsDraft.secure = before);

  test('personnummer and address go to the secure store only', () async {
    final draft = DetailsDraft();
    draft.save({
      'v2.firstName': 'Sara',
      'v2.personalNumber': '198503121234',
      'v2.street': 'Storgatan 1',
      'v2.postalCode': '11122',
      'v2.city': 'Stockholm',
    });
    await draft.flush();
    final plain = await SettingsRepository().read(DetailsDraft.section);
    expect(plain['v2.firstName'], 'Sara');
    for (final key in DetailsDraft.sensitiveKeys) {
      expect(plain.containsKey(key), isFalse, reason: key);
    }
    final prefs = await SharedPreferences.getInstance();
    final everything = prefs.getKeys().map((k) => '${prefs.get(k)}').join();
    expect(everything, isNot(contains('198503121234')));
    expect(everything, isNot(contains('Storgatan')));
    final hidden =
        (jsonDecode(secure.values[DetailsDraft.secureKey]!) as Map)['values']
            as Map;
    expect(hidden['v2.personalNumber'], '198503121234');
    // A closed app gets everything back.
    final back = await DetailsDraft().restore();
    expect(back['v2.firstName'], 'Sara');
    expect(back['v2.street'], 'Storgatan 1');
  });

  test('sent details and sign-out forget the secure part', () async {
    final draft = DetailsDraft();
    draft.save({'v2.personalNumber': '198503121234'});
    await draft.flush();
    await draft.clear();
    expect(secure.values, isEmpty);
    draft.save({'v2.street': 'Storgatan 1'});
    await draft.flush();
    expect(secure.values, isNotEmpty);
    await clearLocalUserData();
    expect(secure.values, isEmpty);
  });

  test('without a secure store (web) the draft stays as before', () async {
    DetailsDraft.secure = null;
    final draft = DetailsDraft();
    draft.save({'v2.personalNumber': '198503121234'});
    await draft.flush();
    final back = await DetailsDraft().restore();
    expect(back['v2.personalNumber'], '198503121234');
  });

  test(
    'a Keychain entry that outlived a reinstall is never restored',
    () async {
      final draft = DetailsDraft();
      draft.save({'v2.personalNumber': '198503121234'});
      await draft.flush();
      // Reinstall: the plain store (and its tag) is gone, the Keychain stays.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final back = await DetailsDraft().restore();
      expect(back.containsKey('v2.personalNumber'), isFalse);
      expect(secure.values, isEmpty);
    },
  );

  test(
    'a save that lands after the sign-out began writes nothing secure',
    () async {
      final draft = DetailsDraft();
      LocalWriteSession.beginCleanup();
      draft.save({'v2.personalNumber': '198503121234'});
      await draft.flush();
      LocalWriteSession.endCleanup();
      expect(secure.values, isEmpty);
    },
  );

  test('a failed secure clear fails the sign-out clean-up', () async {
    DetailsDraft.secure = _Broken();
    await expectLater(clearLocalUserData(), throwsStateError);
  });

  test(
    'a draft from before this version moves out of the plain store',
    () async {
      await SettingsRepository().save(DetailsDraft.section, {
        'v2.firstName': 'Sara',
        'v2.personalNumber': '198503121234',
      });
      final back = await DetailsDraft().restore();
      expect(back['v2.personalNumber'], '198503121234');
      final plain = await SettingsRepository().read(DetailsDraft.section);
      expect(plain.containsKey('v2.personalNumber'), isFalse);
      expect(secure.values[DetailsDraft.secureKey], contains('198503121234'));
    },
  );
}
