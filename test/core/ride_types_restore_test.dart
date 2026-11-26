import 'dart:async';
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
  Completer<void>? gate;
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
    final wait = gate;
    if (wait != null) {
      gate = null;
      await wait.future;
    }
    if (fail) throw const SocketException('offline');
    server = Map.of(values);
  }
}

/// Holds every server save until the test lets it answer.
class _TwoGates implements RemoteSettings {
  bool fail = false;
  final waiting = <Completer<void>>[];
  @override
  bool handles(String section) => section == DriverCategoryChoice.section;
  @override
  Future<Map<String, dynamic>> read(
    String section,
    Map<String, dynamic> local,
  ) async => local;
  @override
  Future<void> save(String section, Map<String, dynamic> values) async {
    if (!fail) return;
    final gate = Completer<void>();
    waiting.add(gate);
    await gate.future;
    throw const SocketException('offline');
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

  test('a newer save is not undone by an older refused one', () async {
    final repo = SettingsRepository();
    await repo.save(DriverCategoryChoice.section, {
      'selected': [true, true],
    });
    final held = Completer<void>();
    remote.gate = held;
    remote.fail = true;
    final older = repo.save(DriverCategoryChoice.section, {
      'selected': [false, true],
    });
    await SettingsRepository.settle();
    await Future<void>.delayed(Duration.zero);
    // A newer save reaches the phone while the older one is with the server.
    remote.fail = false;
    final newerRepo = SettingsRepository();
    SettingsRepository.remote = null;
    await newerRepo.save(DriverCategoryChoice.section, {
      'selected': [true, false],
    });
    SettingsRepository.remote = remote;
    remote.fail = true;
    held.complete();
    await expectLater(older, throwsA(isA<SocketException>()));
    remote.offline = true;
    final data = await SettingsRepository().read(DriverCategoryChoice.section);
    expect(data['selected'], [true, false]);
  });

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

  test('two screens both refused offline: the last confirmed choice comes '
      'back, whichever refusal lands first', () async {
    for (final olderFirst in [true, false]) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final two = _TwoGates();
      SettingsRepository.remote = two;
      final repo = SettingsRepository();
      two.fail = false;
      await repo.save(DriverCategoryChoice.section, {
        'selected': [true, true],
      });
      two.fail = true;
      final a = repo.save(DriverCategoryChoice.section, {
        'selected': [false, true],
      });
      await pumpEventQueue();
      final b = SettingsRepository().save(DriverCategoryChoice.section, {
        'selected': [true, false],
      });
      await pumpEventQueue();
      expect(two.waiting, hasLength(2));
      final refusedA = expectLater(a, throwsA(isA<SocketException>()));
      final refusedB = expectLater(b, throwsA(isA<SocketException>()));
      final order = olderFirst ? [0, 1] : [1, 0];
      for (final index in order) {
        two.waiting[index].complete();
        await pumpEventQueue();
      }
      await refusedA;
      await refusedB;
      remote.offline = true;
      SettingsRepository.remote = remote;
      final data = await SettingsRepository().read(
        DriverCategoryChoice.section,
      );
      expect(data['selected'], [true, true], reason: 'olderFirst=$olderFirst');
      remote.offline = false;
    }
  });
}
