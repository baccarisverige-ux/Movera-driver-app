import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/privacy/start_clean_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// N1 follow-up: the start clean-up as `main.dart` wires it
/// ([claimKeptSession] with the real [claimLocalData] and
/// [clearLocalUserData]). One a sign-in overtook never records the old
/// driver and never deletes what the new driver wrote.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StartCleanUp cleanUp;
  late List<String> ended;
  late int signedOut;

  Future<void> start({
    required Future<String?> Function() readAccess,
    required Future<void> Function(void Function() guard) clear,
  }) {
    final run = claimKeptSession(
      cleanUp: () => cleanUp,
      readAccess: readAccess,
      // The test's "token" is the driver id itself.
      claim: (session, clear, guard) => claimLocalData(session, clear, guard),
      clear: clear,
      endSession: (session) async => ended.add('$session'),
      signedOut: () => signedOut++,
    );
    cleanUp = StartCleanUp(run);
    return run;
  }

  /// The sign-in of `main.dart` `_signedIn` for [driver]: clears first,
  /// then the new driver records himself and writes his own data.
  Future<void> signIn(String driver) async {
    await cleanUp.beforeSignIn(() async {
      await clearLocalUserData(keepOwner: true);
      await forgetLocalDataOwner();
    });
    await claimLocalData(driver);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RecentDestinations.key, 'new driver data');
  }

  setUp(() {
    ended = [];
    signedOut = 0;
  });

  test('stuck before the owner read: never records the old driver', () async {
    SharedPreferences.setMockInitialValues({localDataOwnerKey: 'drv_A'});
    final token = Completer<String?>();
    final run = start(
      readAccess: () => token.future,
      clear: (guard) => clearLocalUserData(keepOwner: true, guard: guard),
    );
    await signIn('drv_B');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(localDataOwnerKey); // as if nobody were recorded
    token.complete('drv_A');
    await run;
    expect(prefs.getString(localDataOwnerKey), isNull);
    expect(prefs.getString(RecentDestinations.key), 'new driver data');
    expect(ended, isEmpty);
    expect(signedOut, 0);
  });

  test('stuck mid-clear: deletes nothing the new driver wrote', () async {
    SharedPreferences.setMockInitialValues({localDataOwnerKey: 'drv_A'});
    final stuck = Completer<void>();
    final run = start(
      readAccess: () async => 'drv_C',
      clear: (guard) async {
        await stuck.future;
        await clearLocalUserData(keepOwner: true, guard: guard);
        await forgetLocalDataOwner();
      },
    );
    await pumpEventQueue();
    await signIn('drv_B');
    stuck.complete();
    await run;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RecentDestinations.key), 'new driver data');
    expect(prefs.getString(localDataOwnerKey), 'drv_B');
    expect(ended, isEmpty);
    expect(signedOut, 0);
  });

  test(
    'not overtaken: clears the last driver and records the kept one',
    () async {
      SharedPreferences.setMockInitialValues({localDataOwnerKey: 'drv_A'});
      final prefs0 = await SharedPreferences.getInstance();
      await prefs0.setString(RecentDestinations.key, 'old');
      await start(
        readAccess: () async => 'drv_B',
        clear: (guard) async {
          await clearLocalUserData(keepOwner: true, guard: guard);
          await forgetLocalDataOwner();
        },
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RecentDestinations.key), isNull);
      expect(prefs.getString(localDataOwnerKey), 'drv_B');
      expect(ended, isEmpty);
    },
  );

  test('a clean-up that fails ends the session, tokens first', () async {
    SharedPreferences.setMockInitialValues({localDataOwnerKey: 'drv_A'});
    await start(
      readAccess: () async => 'drv_B',
      clear: (_) async => throw StateError('disk'),
    );
    expect(ended, ['drv_B']);
    expect(signedOut, 1);
  });
}
