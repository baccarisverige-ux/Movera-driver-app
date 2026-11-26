import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'phase5/live_fixture.dart';

/// Rules audits/impact/driver-offer-cursor.md "Open" 1 (privacy): a
/// session the server refuses runs none of Sign out's clean-up. Another
/// driver who then signs in on that phone saw the last driver's LAST TRIP
/// amount, his notifications (rider pickup addresses), his trip history,
/// his recent destinations, and got his offers filtered by the last
/// driver's switched-off categories. The data now belongs to one driver:
/// a sign-in by another driver clears it first; the same driver signing
/// in again keeps everything.
String _jwt(String driverId) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': driverId})}.sig';
}

const _categories = 'movera_driver_settings_section_categories';

/// The phone's storage; [failing] (a platform key) cannot be removed.
class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  String? failing;
  @override
  Future<bool> remove(String key) async =>
      key == failing ? false : super.remove(key);
}

void main() {
  /// The driver the next verified code signs in; null = every signed-in
  /// call is refused (401, and the refresh too).
  String? driver;

  /// The phone's token store (each test's own).
  var tokens = MemoryTokenStore();

  /// Each `POST /auth/sign-out`: its bearer, and the access token the
  /// phone still held while the server was asked.
  final signOuts = <({String? bearer, String? stored})>[];

  http.Client server() => MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/sign-out')) {
      signOuts.add((
        bearer: request.headers['Authorization'],
        stored: await tokens.readAccess(),
      ));
      return http.Response('{}', 200);
    }
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
    if (path.endsWith('/auth/otp/verify')) {
      return json({
        'accessToken': _jwt(driver!),
        'refreshToken': 'refresh-$driver',
      });
    }
    if (path.endsWith('/auth/test-accounts')) return json({'accounts': []});
    if (path.contains('/legal/')) return json({});
    return json({'code': 'unauthorized', 'message': 'no session'}, 401);
  });

  /// Starts the app on [store] (the phone's storage) with [kept] (a
  /// session kept from an earlier start) in the token store.
  Future<void> boot(WidgetTester tester, {_Store? store, String? kept}) async {
    signOuts.clear();
    tokens = MemoryTokenStore();
    if (kept != null) {
      await tokens.save(access: _jwt(kept), refresh: 'refresh-$kept');
    }
    SharedPreferences.setMockInitialValues({});
    if (store != null) {
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    }
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      authRequired: true,
      apiBaseUrl: 'https://api.test.movera.se',
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    addTearDown(DriverCategoryChoice.reset);
    addTearDown(InMemoryWaybillRepository.instance.reset);
    addTearDown(DriverNotificationFeed.instance.reset);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MoveraApp(
        tokenStore: tokens,
        httpClient: server(),
        locationRepository: FixedGps(),
      ),
    );
    await settle(tester);
  }

  Future<AuthController> start(WidgetTester tester, {_Store? store}) async {
    await boot(tester, store: store);
    return DriverRuntimeScope.maybeOf(
      tester.element(find.byType(DriverSignIn)),
    )!.auth!;
  }

  Future<void> signIn(
    WidgetTester tester,
    AuthController auth,
    String id,
  ) async {
    driver = id;
    await tester.runAsync(
      () => auth.verify(
        challenge: OtpChallenge(
          phone: '+46700000000',
          sessionId: 'otp-1',
          expiresAt: DateTime(2030),
          retryAfter: Duration.zero,
        ),
        code: '1234',
      ),
    );
    await settle(tester);
  }

  /// What driver A leaves on the phone while signed in.
  Future<void> driverAUsesTheApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsTripHistoryRepository.key,
      '{"schemaVersion":1,"rows":[]}',
    );
    await prefs.setString(
      RecentDestinations.key,
      jsonEncode([
        {'name': 'Home', 'address': 'Storgatan 1', 'lat': 59.2, 'lng': 17.6},
      ]),
    );
    await prefs.setString(
      _categories,
      '{"schemaVersion":1,"values":{"selected":[false]}}',
    );
    DriverCategoryChoice.off.value = DriverCategoryChoice.fromSaved([false]);
    InMemoryWaybillRepository.instance
      ..beginCurrent(
        WaybillRecord(
          tripId: 'trip-A',
          statusLabel: 'x',
          issuedAt: DateTime(2026, 11, 15),
          fare: '418,00 kr',
          service: 'Economy',
          riderName: 'Rider',
          pickup: 'Södertälje centrum',
          dropoff: 'Arlanda',
          source: 'Movera',
          driverName: 'A',
          vehicle: 'Car',
          licensePlate: 'ABC123',
          passengerCapacity: 4,
        ),
      )
      ..completeCurrent();
    DriverNotificationFeed.instance.add(
      DriverNotice(
        id: 'n-A',
        kind: DriverNoticeKind.values.first,
        title: 'Pickup',
        body: 'Storgatan 1',
        at: DateTime(2026, 11, 15),
      ),
      popup: false,
    );
  }

  /// The server refuses the session (ApiClient → main `_sessionExpired`).
  Future<void> sessionRefused(WidgetTester tester) async {
    driver = null;
    await tester.runAsync(() async {
      await LiveDriverServices.instance!.events.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    LiveDriverServices.instance = null;
  }

  testWidgets('refused session, then ANOTHER driver signs in: nothing of '
      'the last driver is left', (tester) async {
    final auth = await start(tester);
    await signIn(tester, auth, 'drv_A');
    await tester.runAsync(driverAUsesTheApp);
    await sessionRefused(tester);
    expect(await tester.runAsync(auth.hasSession), isFalse);
    // Kept so far: the same driver may sign in again.
    expect(InMemoryWaybillRepository.instance.last, isNotNull);

    await signIn(tester, auth, 'drv_B');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsTripHistoryRepository.key), isNull);
    expect(prefs.getString(RecentDestinations.key), isNull);
    expect(prefs.getString(_categories), isNull);
    expect(DriverCategoryChoice.off.value, isEmpty);
    expect(InMemoryWaybillRepository.instance.last, isNull);
    expect(DriverNotificationFeed.instance.items, isEmpty);
    await close(tester);
  });

  // Rules audits/impact/post-merge-2026-11-15d.md S1: the owner key went
  // before the section keys and the in-memory resets. A clean-up that
  // stopped there left nobody recorded: B's next sign-in cleared nothing
  // and he saw A's category choice, LAST TRIP and notifications.
  testWidgets('a clean-up that fails part-way is finished at the next '
      'driver\'s next sign-in', (tester) async {
    final store = _Store();
    final auth = await start(tester, store: store);
    await signIn(tester, auth, 'drv_A');
    await tester.runAsync(driverAUsesTheApp);
    await sessionRefused(tester);

    store.failing = 'flutter.$_categories';
    driver = 'drv_B';
    Object? error;
    await tester.runAsync(() async {
      try {
        await auth.verify(
          challenge: OtpChallenge(
            phone: '+46700000000',
            sessionId: 'otp-1',
            expiresAt: DateTime(2030),
            retryAfter: Duration.zero,
          ),
          code: '1234',
        );
      } catch (e) {
        error = e;
      }
    });
    await settle(tester);
    expect(error, isNotNull);
    expect(await tester.runAsync(auth.hasSession), isFalse);
    // Round 2 (SF1): the phone's tokens go FIRST, then the server ends the
    // refused session (a kill in between leaves no session here).
    expect(signOuts, hasLength(1));
    expect(signOuts.single.bearer, 'Bearer ${_jwt('drv_B')}');
    expect(signOuts.single.stored, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString(localDataOwnerKey),
      'drv_A',
    );

    store.failing = null;
    await signIn(tester, auth, 'drv_B');
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(prefs.reload);
    expect(prefs.getString(_categories), isNull);
    expect(prefs.getString(PrefsTripHistoryRepository.key), isNull);
    expect(prefs.getString(RecentDestinations.key), isNull);
    expect(DriverCategoryChoice.off.value, isEmpty);
    expect(InMemoryWaybillRepository.instance.last, isNull);
    expect(DriverNotificationFeed.instance.items, isEmpty);
    await close(tester);
  });

  /// What A left on the phone, A recorded as its owner.
  Future<_Store> phoneOfDriverA() async {
    final store = _Store();
    await store.setValue('String', 'flutter.$localDataOwnerKey', 'drv_A');
    await store.setValue(
      'String',
      'flutter.${PrefsTripHistoryRepository.key}',
      '{"schemaVersion":1,"rows":[]}',
    );
    await store.setValue(
      'String',
      'flutter.${RecentDestinations.key}',
      '[{"name":"Home","address":"Storgatan 1","lat":59.2,"lng":17.6}]',
    );
    await store.setValue(
      'String',
      'flutter.$_categories',
      '{"schemaVersion":1,"values":{"selected":[false]}}',
    );
    return store;
  }

  // Round 2, supervisor SF1 (Rules audits/impact/driver-s1-supervisor.md):
  // B's tokens are saved before the clean-up of A's data. An app killed in
  // that clean-up started again signed in as B, next to what was left,
  // with A still recorded.
  testWidgets('start with ANOTHER driver\'s kept session: the clean-up is '
      'finished before Home reads local data, then he is recorded', (
    tester,
  ) async {
    final store = await phoneOfDriverA();
    await boot(tester, store: store, kept: 'drv_B');
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(prefs.reload);
    expect(prefs.getString(PrefsTripHistoryRepository.key), isNull);
    expect(prefs.getString(RecentDestinations.key), isNull);
    expect(prefs.getString(_categories), isNull);
    expect(DriverCategoryChoice.off.value, isEmpty);
    expect(prefs.getString(localDataOwnerKey), 'drv_B');
    expect(signOuts, isEmpty);
    await close(tester);
  });

  testWidgets('start with ANOTHER driver\'s kept session and a clean-up '
      'that cannot finish: the tokens go first, the session is ended, Sign '
      'in shows, A stays recorded', (tester) async {
    final store = await phoneOfDriverA();
    store.failing = 'flutter.$_categories';
    await boot(tester, store: store, kept: 'drv_B');
    expect(await tester.runAsync(tokens.readAccess), isNull);
    expect(await tester.runAsync(tokens.readRefresh), isNull);
    expect(signOuts, hasLength(1));
    expect(signOuts.single.bearer, 'Bearer ${_jwt('drv_B')}');
    expect(signOuts.single.stored, isNull);
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(prefs.reload);
    expect(prefs.getString(localDataOwnerKey), 'drv_A');
    expect(DriverCategoryChoice.off.value, isEmpty);
    expect(find.byType(DriverSignIn), findsOneWidget);
    await close(tester);
  });

  testWidgets('start with the recorded driver\'s own kept session: '
      'nothing is cleared', (tester) async {
    final store = await phoneOfDriverA();
    await boot(tester, store: store, kept: 'drv_A');
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(prefs.reload);
    expect(prefs.getString(RecentDestinations.key), isNotNull);
    expect(prefs.getString(_categories), isNotNull);
    expect(prefs.getString(localDataOwnerKey), 'drv_A');
    expect(signOuts, isEmpty);
    await close(tester);
  });

  // Round 2, supervisor SF2: the main.dart half. The owner key must outlive
  // the in-memory resets of `_clearLocal` (keepOwner: true) and go at its
  // very end (forgetLocalDataOwner()).
  String? ownerDuringResets;
  Future<void> watchResets(WidgetTester tester) async {
    ownerDuringResets = 'not reset';
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    // Read at once (the cache), in the middle of `_clearLocal`.
    void seen() => ownerDuringResets = prefs.getString(localDataOwnerKey);
    DriverNotificationFeed.instance.changes.addListener(seen);
    addTearDown(
      () => DriverNotificationFeed.instance.changes.removeListener(seen),
    );
  }

  testWidgets('another driver\'s sign-in: A stays recorded while the '
      'in-memory state is reset', (tester) async {
    final auth = await start(tester);
    await signIn(tester, auth, 'drv_A');
    await tester.runAsync(driverAUsesTheApp);
    await sessionRefused(tester);
    await watchResets(tester);
    await signIn(tester, auth, 'drv_B');
    expect(ownerDuringResets, 'drv_A');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(localDataOwnerKey), 'drv_B');
    await close(tester);
  });

  testWidgets('Log out: the owner goes last, after the in-memory resets', (
    tester,
  ) async {
    final auth = await start(tester);
    await signIn(tester, auth, 'drv_A');
    await tester.runAsync(driverAUsesTheApp);
    final logout = DriverRuntimeScope.maybeOf(
      tester.element(find.byType(Navigator).first),
    )!.logout!;
    await watchResets(tester);
    await tester.runAsync(logout);
    await settle(tester);
    expect(ownerDuringResets, 'drv_A');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(localDataOwnerKey), isNull);
    expect(prefs.getString(_categories), isNull);
    await close(tester);
  });

  testWidgets('refused session, then the SAME driver signs in again: he '
      'keeps everything', (tester) async {
    final auth = await start(tester);
    await signIn(tester, auth, 'drv_A');
    await tester.runAsync(driverAUsesTheApp);
    await sessionRefused(tester);
    expect(await tester.runAsync(auth.hasSession), isFalse);

    await signIn(tester, auth, 'drv_A');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsTripHistoryRepository.key), isNotNull);
    expect(prefs.getString(RecentDestinations.key), isNotNull);
    expect(prefs.getString(_categories), isNotNull);
    expect(
      DriverCategoryChoice.off.value,
      DriverCategoryChoice.fromSaved([false]),
    );
    expect(InMemoryWaybillRepository.instance.last?.fare, '418,00 kr');
    expect(DriverNotificationFeed.instance.items, hasLength(1));
    await close(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
}
