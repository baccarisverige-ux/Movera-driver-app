import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/server_settings_sync.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinator 2026-11-26 (audit of the tester's settings bug):
/// (A) a refused server save of Ride preferences puts the phone copy back,
///     so a restart offline follows what the screen shows (last confirmed);
/// (2) the saved choice is read again after every sign-in.
class _Remote implements RemoteSettings {
  Map<String, dynamic> server = {};
  bool fail = false;
  bool offline = false;
  @override
  bool handles(String section) => section == DriverCategoryChoice.section;
  @override
  Future<Map<String, dynamic>> read(
    String section,
    Map<String, dynamic> local,
  ) async {
    if (offline) throw const SocketException('offline');
    return server.isEmpty ? local : server;
  }

  @override
  Future<void> save(String section, Map<String, dynamic> values) async {
    if (fail) throw const SocketException('offline');
    server = Map.of(values);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Remote remote;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    remote = _Remote();
    SettingsRepository.remote = remote;
    DriverCategoryChoice.reset();
  });
  tearDown(() {
    SettingsRepository.remote = null;
    DriverCategoryChoice.reset();
  });

  test(
    'a refused server save puts the phone copy back (restart offline)',
    () async {
      final repo = SettingsRepository();
      await repo.save(DriverCategoryChoice.section, {
        'selected': [true, true],
      });
      remote.fail = true;
      await expectLater(
        repo.save(DriverCategoryChoice.section, {
          'selected': [false, true],
        }),
        throwsA(isA<SocketException>()),
      );
      // Restart, offline: the phone copy is the last confirmed choice.
      remote.offline = true;
      final data = await SettingsRepository().read(
        DriverCategoryChoice.section,
      );
      expect(data['selected'], [true, true]);
    },
  );

  test(
    'the saved choice comes back after a sign-in (logout reset it)',
    () async {
      remote.server = {
        'selected': [false],
      };
      DriverCategoryChoice.reset(); // logout
      await DriverCategoryChoice.restore();
      expect(DriverCategoryChoice.off.value, isNotEmpty);
      // main.dart wires it into every sign-in.
      final main = File('lib/main.dart').readAsStringSync();
      final signedIn = main.substring(
        main.indexOf('Future<void> _signedIn() async {'),
        main.indexOf('Future<void> _logout() async {'),
      );
      expect(signedIn, contains('DriverCategoryChoice.restore()'));
    },
  );
}
