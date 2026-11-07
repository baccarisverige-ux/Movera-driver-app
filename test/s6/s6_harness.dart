// S6 supervisor (2026-11-07): a live Home + trip harness with a fake server
// (MockClient.streaming) whose trip event stream (SSE) the test drives.
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
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

const tripId = 'trp_s6';

Map<String, Object?> money(int minor) => {
  'amountMinor': minor,
  'currency': 'SEK',
};

Map<String, Object?> projection(
  String status, {
  required int version,
  String kind = 'now',
  Map<String, Object?> extra = const {},
}) => {
  'tripId': tripId,
  'status': status,
  'version': version,
  'kind': kind,
  'pickup': {'lat': 59.332, 'lng': 18.066, 'address': 'Vasagatan 1, Stockholm'},
  'dropoff': {
    'lat': 59.34,
    'lng': 18.08,
    'address': 'Kungsgatan 40, Stockholm',
  },
  'fare': money(6800),
  'driverEarnings': money(5400),
  'paymentMethod': 'card',
  'categoryId': 'economy',
  'rider': {'firstName': 'Alva', 'rating': 4.9},
  'acceptedAt': DateTime.now().toUtc().toIso8601String(),
  ...extra,
};

PersistedActiveRide savedTrip(ActiveRideStage stage) => PersistedActiveRide(
  tripId: tripId,
  stage: stage,
  savedAt: DateTime.now(),
  riderName: 'Alva',
  fare: '54 kr',
  pickupLat: 59.332,
  pickupLng: 18.066,
  dropoffLat: 59.34,
  dropoffLng: 18.08,
  pickupAddress: 'Vasagatan 1, Stockholm',
  dropoffAddress: 'Kungsgatan 40, Stockholm',
);

/// One open SSE connection the test writes to.
class Sse {
  Sse(this.after);
  final int after;
  final StreamController<List<int>> out = StreamController<List<int>>();
  bool get closed => out.isClosed;
  void line(String text) {
    if (!out.isClosed) out.add(utf8.encode(text));
  }

  void heartbeat() => line(': heartbeat\n\n');
  Future<void> close() => out.close();
}

class FakeServer {
  /// The trip as `GET /trips/{id}` answers; null = 404.
  Map<String, Object?>? trip;
  String? activeTripId;

  /// Every envelope the trip has had (the stream replays after `after`).
  final List<Map<String, Object?>> log = [];

  /// How `/events` answers: 'sse', 'down' (503) or 'gone' (404).
  String eventsMode = 'sse';
  final List<Sse> connections = [];
  final List<http.BaseRequest> seen = [];

  Sse? get live =>
      connections.isEmpty || connections.last.closed ? null : connections.last;

  /// The server changes the trip: the projection moves and one event is
  /// logged and sent on the open stream (if any, and [send]).
  void change(
    String status, {
    String kind = 'trip_projection',
    Map<String, Object?> extra = const {},
    bool send = true,
    String tripKind = 'now',
  }) {
    final version = ((trip?['version'] as int?) ?? 0) + 1;
    trip = projection(status, version: version, kind: tripKind, extra: extra);
    final envelope = <String, Object?>{
      'eventId': 'evt_${log.length + 1}',
      'tripId': tripId,
      'sequence': log.length + 1,
      'version': version,
      'kind': kind,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'projection': trip,
    };
    log.add(envelope);
    if (send) {
      live?.line(
        'id: ${envelope['sequence']}\ndata: ${jsonEncode(envelope)}\n\n',
      );
    }
  }

  http.StreamedResponse _json(int status, Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    headers: {'content-type': 'application/json'},
  );

  /// Other trips the server knows (`GET /trips/{id}`), e.g. a queued one.
  final Map<String, Map<String, Object?>> others = {};

  Future<http.StreamedResponse> handle(http.BaseRequest request) async {
    seen.add(request);
    final path = request.url.path;
    for (final id in others.keys) {
      if (path == '/api/v1/trips/$id') return _json(200, others[id]!);
      if (path == '/api/v1/trips/$id/events') {
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }
    }
    if (path == '/api/v1/driver/profile') {
      return _json(200, {
        'driverId': 'd1',
        'onlineStatus': 'online',
        'version': 1,
        'activeTripId': ?activeTripId,
      });
    }
    if (path == '/api/v1/trips/$tripId/events') {
      if (eventsMode == 'down') return _json(503, {'code': 'unavailable'});
      if (eventsMode == 'gone') return _json(404, {'code': 'not_found'});
      final after =
          int.tryParse(request.url.queryParameters['after'] ?? '') ?? 0;
      final sse = Sse(after);
      connections.add(sse);
      for (final e in log) {
        if ((e['sequence'] as int) > after) {
          sse.line('id: ${e['sequence']}\ndata: ${jsonEncode(e)}\n\n');
        }
      }
      return http.StreamedResponse(
        sse.out.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    if (path == '/api/v1/trips/$tripId') {
      final t = trip;
      return t == null
          ? _json(404, {'code': 'not_found', 'reason': 'trip_not_found'})
          : _json(200, t);
    }
    if (request.method == 'POST' && path.startsWith('/api/v1/trips/$tripId/')) {
      final command = path.split('/').last;
      final to = switch (command) {
        'head-to-pickup' => 'driver_to_pickup',
        'arrive' => 'arrived',
        'board' => 'rider_onboard',
        'start' => 'in_trip',
        'complete' => 'completed',
        'no-show' => 'no_show',
        _ => null,
      };
      if (to != null) {
        change(to, send: true);
        return _json(200, trip!);
      }
    }
    if (path == '/api/v1/driver/offers') {
      return _json(200, {'items': <Object>[], 'nextCursor': null});
    }
    if (path == '/api/v1/driver/location') return _json(200, {'accepted': 1});
    if (path == '/api/v1/driver/availability') {
      return _json(200, {
        'driverId': 'd1',
        'onlineStatus': 'online',
        'version': 2,
      });
    }
    return _json(503, {'code': 'unavailable'});
  }
}

class Gps implements DriverLocationRepository {
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

class Harness {
  Harness(this.tester);
  final WidgetTester tester;
  final server = FakeServer();
  late LiveDriverServices live;
  late DriverSessionController session;
  final rides = MemoryActiveRideRepository();

  Future<void> frames(Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  void _makeLive() {
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient.streaming((request, _) => server.handle(request));
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
  }

  /// Opens Home (a cold start: Home restores what [rides] holds or what
  /// the server's profile names).
  Future<void> openHome() async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    IslandMessages.reset();
    InMemoryWaybillRepository.instance.reset();
    _makeLive();
    ScheduledRideStore.reset();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    session = DriverSessionController()..setOnline(true);
    live.attach(session);
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverHome(
              sessionController: session,
              dispatchRepository: live.dispatch,
              locationRepository: Gps(),
              activeRideRepository: rides,
            ),
          ),
        ),
      ),
    );
    await frames(const Duration(seconds: 3));
  }

  Future<void> leave() async {
    for (final c in server.connections) {
      if (!c.closed) unawaited(c.close());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    LiveDriverServices.instance = null;
    await frames(const Duration(seconds: 2));
  }

  void lifecycle(AppLifecycleState state) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }

  List<String> get islandTitles => [
    for (final m in IslandMessages.posted) m.title,
  ];
}
