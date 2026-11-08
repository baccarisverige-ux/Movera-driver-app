// Real-screen run 2026-11-07 (Rules audits/screens-2026-11-07/
// full-lifecycle, 2-booked 069/075, W3 HIGH): the green « Starta nu mot
// upphämtningen » banner on a booked ride's details is not a button; a
// tap sends nothing and the server stays `accepted`. The server allows the
// start from `mustBeOnlineAt` (scheduledAt − onlineBeforeMin, contract
// bookLater start).
//
// Live 5+5 test 2026-11-08 (Rules audits/screens-2026-11-08/live-5x5,
// 4-booked-p4 068 → 071/072 → 074): the trip opened under a made-up id
// ("trp_booked-<micros>"); the server answered 404 for it, the trip
// screen read that as the trip taken away and Home showed for ~2 s until
// it reopened the server's trip. It must open under the server's own id.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

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

void main() {
  testWidgets('W3 the « Start now » banner starts the booked ride on the '
      'server and opens its trip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    IslandMessages.reset();
    InMemoryWaybillRepository.instance.reset();
    ScheduledRideStore.reset();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    final now = DateTime.now().toUtc();
    final pickupAt = now.add(const Duration(minutes: 50));
    var started = false;
    final posts = <String>[];
    Map<String, Object?> trip() => {
      'tripId': 'trp_booked',
      'status': started ? 'driver_to_pickup' : 'accepted',
      'version': started ? 6 : 5,
      'kind': 'scheduled',
      'scheduledAt': pickupAt.toIso8601String(),
      'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'Sergels torg'},
      'dropoff': {'lat': 59.31, 'lng': 18.07, 'address': 'Medborgarplatsen'},
      'fare': {'amountMinor': 14943, 'currency': 'SEK'},
      'driverEarnings': {'amountMinor': 14943, 'currency': 'SEK'},
      'paymentMethod': 'card',
      'categoryId': 'economy',
      'rider': {'firstName': 'Alva', 'rating': 4.9},
    };
    final row = {
      'tripId': 'trp_booked',
      'version': 5,
      'scheduledAt': pickupAt.toIso8601String(),
      'categoryId': 'economy',
      'rideType': 'normal',
      'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
      'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
      'stops': 0,
      'distanceMeters': 8000,
      'durationSeconds': 1080,
      'earnings': {'amountMinor': 14943, 'currency': 'SEK'},
      'status': 'accepted',
      'mustBeOnlineAt': now
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
      'canStartAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      'reservation': {
        'leaveAt': now.add(const Duration(minutes: 30)).toIso8601String(),
        'driveSeconds': 600,
      },
    };
    final client = MockClient.streaming((request, _) async {
      http.StreamedResponse json(Object body, [int status = 200]) =>
          http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(body))),
            status,
            headers: {'content-type': 'application/json'},
          );
      final path = request.url.path;
      if (request.method == 'POST') posts.add(path);
      switch (path) {
        case '/api/v1/driver/profile':
          return json({
            'driverId': 'd1',
            'onlineStatus': 'online',
            'version': 1,
            if (started) 'activeTripId': 'trp_booked',
          });
        case '/api/v1/driver/reservations':
          final scope = request.url.queryParameters['scope'];
          return json({
            'items': [if (scope == 'accepted' && !started) row],
            'nextCursor': null,
          });
        case '/api/v1/driver/reservations/trp_booked/start':
          started = true;
          return json(trip());
        case '/api/v1/trips/trp_booked':
          return json(trip());
        case '/api/v1/driver/offers':
          return json({'items': <Object>[], 'nextCursor': null});
        case '/api/v1/driver/location':
          return json({'accepted': 1});
        case '/api/v1/driver/availability':
          return json({
            'driverId': 'd1',
            'onlineStatus': 'online',
            'version': 2,
          });
      }
      // As the server: a trip id it does not know is not this driver's.
      if (path.contains('/trips/') &&
          !RegExp(r'/trips/trp_booked(/|$)').hasMatch(path)) {
        return json({'code': 'not_found'}, 404);
      }
      return json({'code': 'unavailable'}, 503);
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController()..setOnline(true);
    live.attach(session);
    await tester.runAsync(
      () => ScheduledRideStore.syncFromServer(live.reservations),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverHome(
              sessionController: session,
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
              activeRideRepository: MemoryActiveRideRepository(),
            ),
          ),
        ),
      ),
    );
    Future<void> frames(int tenths) async {
      for (var i = 0; i < tenths; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await frames(30);
    final home = tester.element(find.byType(DriverHome));
    Navigator.of(home).push(
      MaterialPageRoute<void>(builder: (_) => const ScheduledRidesScreen()),
    );
    await frames(10);
    await tester.tap(find.text('Accepted').first);
    await frames(6);
    await tester.tap(find.textContaining('Sergels torg').first);
    await frames(10);
    final banner = find.byKey(
      const ValueKey<String>('scheduled-leave-countdown'),
    );
    expect(banner, findsOneWidget);
    await tester.tap(banner);
    // Every frame from the tap: once the trip screen is open, the same
    // one stays (no close and reopen, so no Home in between).
    State? opened;
    var flashes = 0;
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final trips = find.byType(AcceptRide).evaluate().toList();
      if (trips.length != 1) {
        // None (Home on top), or one closing while another opens.
        if (opened != null || trips.length > 1) flashes++;
        continue;
      }
      final state = (trips.single as StatefulElement).state;
      if (opened != null && !identical(opened, state)) flashes++;
      opened = state;
    }
    expect(
      posts,
      contains('/api/v1/driver/reservations/trp_booked/start'),
      reason: 'the banner sent nothing',
    );
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      tester.widget<AcceptRide>(find.byType(AcceptRide)).tripId,
      'trp_booked',
      reason: 'the booked trip opened under a made-up id, not the server\'s',
    );
    expect(flashes, 0, reason: 'the trip screen closed and Home showed');
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    LiveDriverServices.instance = null;
    ScheduledRideStore.reset();
    await frames(20);
  });
}
