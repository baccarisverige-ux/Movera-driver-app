// Real-screen run 2026-11-07 (Rules audits/screens-2026-11-07/
// full-lifecycle, 3-cancel 047/192, W2): after a trip restored by a
// restart, the app showed « Radar AV / Pausad » while the server profile
// said `online`; dispatch offered him a ride his app never showed (~90 s).
//
// Cause (app): a restart is offline (D11, DriverSessionController.restore),
// so the restored trip's beginTrip keeps "offline" as the status before the
// trip and endTrip goes back offline. The server put the driver `online` at
// the trip's end; LiveDriverPresence._onSession only tells the server
// offline when the app had asked online (`_wantOnline`), never after a
// restart.
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
  testWidgets('W2 a trip restored after a restart ends: the app is offline, '
      'the server is set offline too and the sender stops (§74)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    IslandMessages.reset();
    InMemoryWaybillRepository.instance.reset();
    ScheduledRideStore.reset();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    var status = 'driver_to_pickup';
    var version = 4;
    var driverStatus = 'on_trip';
    var driverVersion = 7;
    final offline = <Object?>[];
    // §74 (2026-11-09): every POST /driver/location, to prove the sender stops.
    final locationPosts = <DateTime>[];
    final events = StreamController<List<int>>();
    Map<String, Object?> trip() => {
      'tripId': 'trp_r',
      'status': status,
      'version': version,
      'kind': 'now',
      'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'Sergels torg'},
      'dropoff': {'lat': 59.31, 'lng': 18.07, 'address': 'Medborgarplatsen'},
      'fare': {'amountMinor': 6800, 'currency': 'SEK'},
      'driverEarnings': {'amountMinor': 5400, 'currency': 'SEK'},
      'paymentMethod': 'card',
      'categoryId': 'economy',
      'rider': {'firstName': 'Alva', 'rating': 4.9},
    };
    final client = MockClient.streaming((request, body) async {
      http.StreamedResponse json(Object value, [int code = 200]) =>
          http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(value))),
            code,
            headers: {'content-type': 'application/json'},
          );
      final path = request.url.path;
      switch (path) {
        case '/api/v1/driver/profile':
          return json({
            'driverId': 'd1',
            'onlineStatus': driverStatus,
            'version': driverVersion,
            if (driverStatus == 'on_trip') 'activeTripId': 'trp_r',
          });
        case '/api/v1/driver/availability':
          final sent = jsonDecode(utf8.decode(await body.toBytes())) as Map;
          if (sent['onlineStatus'] == 'offline') offline.add(sent);
          driverStatus = sent['onlineStatus'] as String;
          driverVersion++;
          return json({
            'driverId': 'd1',
            'onlineStatus': driverStatus,
            'version': driverVersion,
          });
        case '/api/v1/trips/trp_r/events':
          return http.StreamedResponse(
            events.stream,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        case '/api/v1/trips/trp_r':
          return json(trip());
        case '/api/v1/driver/offers':
          return json({'items': <Object>[], 'nextCursor': null});
        case '/api/v1/driver/location':
          locationPosts.add(DateTime.now());
          return json({'accepted': 1});
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
      // Short ticks, so a sender left running shows up within a few frames.
      locationEvery: const Duration(milliseconds: 300),
    );
    LiveDriverServices.instance = live;
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // The restart: the session starts offline (D11); the trip is saved.
    final session = DriverSessionController();
    live.attach(session);
    final rides = MemoryActiveRideRepository();
    await rides.save(
      PersistedActiveRide(
        tripId: 'trp_r',
        stage: ActiveRideStage.headingToPickup,
        savedAt: DateTime.now(),
        riderName: 'Alva',
        fare: '54 kr',
        pickupLat: 59.33,
        pickupLng: 18.06,
        dropoffLat: 59.31,
        dropoffLng: 18.07,
        pickupAddress: 'Sergels torg',
        dropoffAddress: 'Medborgarplatsen',
      ),
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
              activeRideRepository: rides,
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

    await frames(50);
    expect(find.byType(AcceptRide), findsOneWidget);
    // The rider cancels; the server puts the driver online again.
    status = 'cancelled_by_rider';
    version = 5;
    driverStatus = 'online';
    driverVersion++;
    events.add(
      utf8.encode(
        'id: 9\ndata: ${jsonEncode({'eventId': 'evt_9', 'tripId': 'trp_r', 'sequence': 9, 'version': 5, 'kind': 'trip_projection', 'occurredAt': DateTime.now().toUtc().toIso8601String(), 'projection': trip()})}\n\n',
      ),
    );
    await frames(60);
    expect(find.byType(AcceptRide), findsNothing);
    expect(session.isOnline, isFalse, reason: 'the app shows Radar AV');
    expect(
      offline,
      isNotEmpty,
      reason: 'the server still holds the driver online ($driverStatus)',
    );
    expect(driverStatus, 'offline');
    // §74 (owner Q14, 2026-11-09): once the restored trip is over and the app
    // is offline, the location sender stops: no POST /driver/location after.
    final postsAtEnd = locationPosts.length;
    await frames(30);
    expect(
      locationPosts.length,
      postsAtEnd,
      reason: 'the sender kept posting after the trip ended offline',
    );
    unawaited(events.close());
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    LiveDriverServices.instance = null;
    await frames(20);
  });
}
