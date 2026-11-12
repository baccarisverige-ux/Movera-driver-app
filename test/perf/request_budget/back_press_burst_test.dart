import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../integration_test/headless_map_platform.dart';

/// G27 (screen-switch audit 2026-11-12, G-S10): what a back press to Home
/// sends. Before: 5 requests after every page (the profile twice: the
/// badges and `LiveActiveTrip.fetch`'s own read), 6 after Notifications
/// (the bell twice). Live Home over a counting fake server, the app's own
/// route observer, a fake clock for the badge gate.
void main() {
  final previous = DriverRuntimeConfig.current;
  final previousClock = badgesClock;
  var now = DateTime.utc(2026, 11, 12, 9);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    now = DateTime.utc(2026, 11, 12, 9);
    badgesClock = () => now;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      authRequired: true,
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    badgesClock = previousClock;
    LiveDriverServices.instance = null;
  });

  http.Response json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Live Home (nothing saved on the phone, no trip on the server); every
  /// request as `METHOD path`.
  /// [serverTrip] is the trip the profile names from now on.
  String? serverTrip;
  Future<({List<String> sent, LiveDriverServices live})> pumpHome(
    WidgetTester tester,
  ) async {
    serverTrip = null;
    final sent = <String>[];
    final client = MockClient((request) async {
      sent.add('${request.method} ${request.url.path}');
      return switch (request.url.path) {
        '/api/v1/driver/profile' => json({
          'driverId': 'd1',
          'accountStatus': 'active',
          'firstName': 'Amira',
          'version': 3,
          'country': 'SE',
          'onlineStatus': 'offline',
          'activeTripId': ?serverTrip,
        }),
        '/api/v1/notifications' => json({'items': <Object>[]}),
        _ => json(<String, Object>{}),
      };
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final origin = Uri.parse('https://api.test.movera.se');
    final api = ApiClient(client: client, baseUri: origin, tokens: tokens);
    final live = LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: api,
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    final account = DriverAccountSession(
      repository: DriverAccountRepository(api),
    );
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverRuntimeScope(
              session: session,
              homeBuilder: () => const SizedBox(),
              account: account,
              child: DriverHome(
                sessionController: session,
                dispatchRepository: live.dispatch,
                locationRepository: _Gps(),
                activeRideRepository: MemoryActiveRideRepository(),
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    return (sent: sent, live: live);
  }

  Future<void> leave(WidgetTester tester, LiveDriverServices live) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    await frames(tester);
  }

  /// Opens [route] over Home and closes it (Android back); what was sent
  /// after the close, counted per endpoint.
  Future<Map<String, int>> openAndClose(
    WidgetTester tester,
    List<String> sent,
    Route<void> route,
  ) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(route).ignore();
    await frames(tester, 10);
    final from = sent.length;
    navigator.pop();
    await frames(tester);
    final counts = <String, int>{};
    for (final key in sent.skip(from)) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Route<void> menuPage() =>
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('p')));

  const profile = 'GET /api/v1/driver/profile';
  const unread = 'GET /api/v1/notifications';
  const reminders = 'GET /api/v1/driver/reminders';
  const settings = 'GET /api/v1/driver/onboarding/settings';

  testWidgets('G27: closing a menu page over Home (badges due) reads the '
      'profile once, not again for the server trip', (tester) async {
    final home = await pumpHome(tester);
    now = now.add(const Duration(seconds: 61));
    // Even when the server names a trip: a menu page changed none.
    serverTrip = 'srv-trip-9';
    final sent = await openAndClose(tester, home.sent, menuPage());
    expect(sent[profile], 1, reason: '$sent');
    expect(sent[unread], 1, reason: '$sent');
    expect(sent[reminders], 1, reason: '$sent');
    expect(sent[settings], 1, reason: '$sent');
    expect(sent.keys.where((k) => k.contains('/trips/')), isEmpty);
    await leave(tester, home.live);
  });

  testWidgets('G27: back on Home within 60 s of the last badges sends no '
      'badge reads', (tester) async {
    final home = await pumpHome(tester);
    now = now.add(const Duration(seconds: 30));
    final sent = await openAndClose(tester, home.sent, menuPage());
    expect(sent[profile], isNull, reason: '$sent');
    expect(sent[unread], isNull, reason: '$sent');
    expect(sent[reminders], isNull, reason: '$sent');
    expect(sent[settings], isNull, reason: '$sent');
    await leave(tester, home.live);
  });

  testWidgets('G27: back from a trip page reads the badges at once (a '
      'just-finished trip), the profile once', (tester) async {
    final home = await pumpHome(tester);
    now = now.add(const Duration(seconds: 30));
    // The server started a next trip: still asked after a trip.
    serverTrip = 'srv-trip-9';
    final sent = await openAndClose(
      tester,
      home.sent,
      ActiveRideTransition(const Scaffold(body: Text('trip'))),
    );
    expect(sent['GET /api/v1/trips/srv-trip-9'], 1, reason: '$sent');
    expect(sent[profile], 1, reason: '$sent');
    expect(sent[unread], 1, reason: '$sent');
    expect(sent[reminders], 1, reason: '$sent');
    expect(sent[settings], 1, reason: '$sent');
    await leave(tester, home.live);
  });

  testWidgets('G27: back from Notifications reads the bell once, at once '
      '(also within 60 s)', (tester) async {
    final home = await pumpHome(tester);
    now = now.add(const Duration(seconds: 61));
    await tester.tap(find.byKey(const ValueKey('home-notifications-bell')));
    await frames(tester, 10);
    final from = home.sent.length;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await frames(tester);
    final after = home.sent.skip(from).toList();
    expect(after.where((k) => k == unread), hasLength(1), reason: '$after');
    expect(after.where((k) => k == profile), hasLength(1), reason: '$after');
    // Within 60 s of that read: the Notifications screen still refreshes.
    now = now.add(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('home-notifications-bell')));
    await frames(tester, 10);
    final again = home.sent.length;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await frames(tester);
    expect(
      home.sent.skip(again).where((k) => k == unread),
      hasLength(1),
      reason: '${home.sent.skip(again)}',
    );
    await leave(tester, home.live);
  });

  test('G27: two unread reads at once share one request', () async {
    var asked = 0;
    final client = MockClient((request) async {
      asked++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return json({'items': <Object>[]});
    });
    final session = DriverAccountSession(
      repository: DriverAccountRepository(
        ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
        ),
      ),
    );
    await Future.wait([session.refreshUnread(), session.refreshUnread()]);
    expect(asked, 1);
    // Done: the next read asks again (fresh after the screen closed).
    await session.refreshUnread();
    expect(asked, 2);
  });
}

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
