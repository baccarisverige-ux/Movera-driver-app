import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Gps implements DriverLocationRepository {
  /// How old each fix is when read (a browser with an emulated fixed
  /// position may answer from its cache).
  static Duration age = Duration.zero;
  static int reads = 0;

  /// Chromium with an emulated fixed position (probed 2026-11-02): the
  /// watch gives one fix, and a one-shot read once that fix is older than
  /// `maximumAge` (30 s) never answers.
  static bool hangOneShot = false;

  @override
  Future<DriverLocation> getCurrentPosition() async {
    reads++;
    if (hangOneShot) return Completer<DriverLocation>().future;
    return DriverLocation(
      point: const GeoPoint(59.3429, 18.0498),
      accuracyMeters: 5,
      measuredAt: DateTime.now().subtract(age),
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

void main() {
  final requests = <String>[];
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  final arrivedAt = DateTime.now().toUtc().subtract(
    const Duration(seconds: 90),
  );

  Map<String, Object?> projection(List<Map<String, Object?>> stops) => {
    'tripId': 'srv-stop-1',
    'status': 'in_trip',
    'version': 9,
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'acceptedAt': '2026-11-01T22:00:00Z',
    'startedAt': '2026-11-01T22:05:00Z',
    'pickup': {'lat': 59.3326, 'lng': 18.0649, 'address': 'Drottninggatan 1'},
    'dropoff': {'lat': 59.35, 'lng': 18.07, 'address': 'Hornsgatan 2'},
    'stops': stops,
    'fare': {'amountMinor': 15000, 'currency': 'SEK'},
    'driverEarnings': {'amountMinor': 12000, 'currency': 'SEK'},
    'terms': {
      'currency': 'SEK',
      'freeWaitMin': 3,
      'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
      'noShowAfterMin': 5,
      'noShowFee': {'amountMinor': 5000, 'currency': 'SEK'},
      'stopFreeWaitMin': 0,
      'stopWaitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    },
  };

  final previousConfig = DriverRuntimeConfig.current;
  setUp(() {
    // The live build's 100 m check (tests otherwise arrive from anywhere).
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
    );
    requests.clear();
    _Gps.age = Duration.zero;
    _Gps.reads = 0;
    _Gps.hangOneShot = false;
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() {
    DriverRuntimeConfig.current = previousConfig;
    LiveDriverServices.instance = null;
    DriverAppTexts.reset();
  });

  Future<LiveDriverServices> reopen(
    WidgetTester tester,
    Map<String, Object?> trip, {
    PersistedActiveRide? saved,
  }) async {
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/v1/driver/trips/srv-stop-1/stops/0/arrive') {
        final at = DateTime.now().toUtc().toIso8601String();
        return json(200, {
          ...trip,
          'version': 10,
          'stops': [
            {...(trip['stops']! as List).first as Map, 'arrivedAt': at},
          ],
          'stopVisits': [
            {'stopIndex': 0, 'arrivedAt': at},
          ],
        });
      }
      return switch (request.url.path) {
        '/api/v1/driver/profile' => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'on_trip',
          'version': 3,
          'activeTripId': 'srv-stop-1',
        }),
        '/api/v1/trips/srv-stop-1' => json(200, trip),
        _ => http.Response('', 503),
      };
    });
    final origin = Uri.parse('https://api.test.movera.se');
    final live = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
    final repository = MemoryActiveRideRepository();
    if (saved != null) await repository.save(saved);
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
              activeRideRepository: repository,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return live;
  }

  Future<void> leave(WidgetTester tester, LiveDriverServices live) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final stopNoArrival = [
    {'lat': 59.3429, 'lng': 18.0498, 'address': 'Odenplan'},
  ];

  // Live re-check round 2, item 2: at the stop, "Framme vid stoppet" sent
  // no request. Through the real widget path (Home → server's active trip
  // → AcceptRide), the tap must POST …/stops/0/arrive and show the wait.
  // Root cause of round 2 item 2 (live web build, emulated fixed
  // position): the browser's watch gives one fix and goes quiet while the
  // car stands still; 30 s later the trip screen's fix counts as aged, the
  // tap asked for a fresh one-shot fix, which Chromium never answers, and
  // the tap waited 8 s in silence with no request. A held fix from the
  // last 2 min at the stop now counts at once.
  testWidgets('aged fix at the stop, one-shot never answers: the tap posts '
      'at once', (tester) async {
    DriverAppTexts.language = 'sv';
    _Gps.age = const Duration(seconds: 28);
    final live = await reopen(tester, projection(stopNoArrival));
    _Gps.hangOneShot = true;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 4)),
    );
    final readsBefore = _Gps.reads;
    await tester.tap(find.text(tr.driveToStopNumber(1)).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('active-ride-arrived-button')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      requests,
      contains('POST /api/v1/driver/trips/srv-stop-1/stops/0/arrive'),
    );
    expect(find.text(tr.waitingAtStopNumber(1)), findsWidgets);
    // ignore: avoid_print
    print('one-shot reads at the tap: ${_Gps.reads - readsBefore}');
    await leave(tester, live);
  });

  testWidgets('at the stop, "Framme vid stoppet" posts the arrival and '
      'shows the stop wait', (tester) async {
    DriverAppTexts.language = 'sv';
    final live = await reopen(tester, projection(stopNoArrival));
    expect(find.text(tr.driveToStopNumber(1)), findsWidgets);
    // The bar opens the middle sheet with the button (as on the phone).
    await tester.tap(find.text(tr.driveToStopNumber(1)).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final button = find.byKey(const ValueKey('active-ride-arrived-button'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      requests,
      contains('POST /api/v1/driver/trips/srv-stop-1/stops/0/arrive'),
    );
    expect(find.text(tr.waitingAtStopNumber(1)), findsWidgets);
    expect(find.text(tr.tripArriveAtStop), findsNothing);
    await leave(tester, live);
  });

  // Round 2, item 2b: the live server sent the arrival only as
  // `stopVisits` and `stops[]` without `arrivedAt`. The contract field is
  // `stops[i].arrivedAt` (contract.json#stopWaits.projection); the server
  // now fills it, and the app still reads `stopVisits` from an older one.
  for (final shape in ['stops', 'stopVisits']) {
    testWidgets('reopened after a server arrival ($shape): the stop wait', (
      tester,
    ) async {
      DriverAppTexts.language = 'sv';
      final at = arrivedAt.toIso8601String();
      final trip = shape == 'stops'
          ? {
              ...projection([
                {...stopNoArrival.first, 'arrivedAt': at},
              ]),
              'stopVisits': [
                {'stopIndex': 0, 'arrivedAt': at},
              ],
            }
          : {
              ...projection(stopNoArrival),
              'stopVisits': [
                {'stopIndex': 0, 'arrivedAt': at},
              ],
            };
      final live = await reopen(tester, trip);
      expect(find.text(tr.waitingAtStopNumber(1)), findsWidgets);
      expect(find.text(tr.driveToStopNumber(1)), findsNothing);
      expect(find.text(tr.tripArriveAtStop), findsNothing);
      await leave(tester, live);
    });
  }
}
