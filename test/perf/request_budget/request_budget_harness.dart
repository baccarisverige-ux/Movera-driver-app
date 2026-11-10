// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/presentation/driver/airport_queue/airport_queue_card.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/surge/surge_map.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';

/// Global plan step 62 (T3): counts every request the driver app sends
/// while it sits in one state. Each state runs the app's real request
/// owners (the classes that hold the timers and streams: LiveDriverServices
/// with its location reporter, offer feed, settings stream and trip
/// commands, ApiDriverRealtime, AirportQueue, SurgeMapController,
/// NavigationController + RoadRouteService, DriverAccountSession) over one
/// real `ApiClient` / `http.Client`, which is [CountingClient]; time is a
/// fake clock. Where the timer itself lives in a screen's State (Home's
/// 60 s badges, the trip screen's 10 s follow poll, the GPS fixes that
/// drive the route) the harness runs the same period and the same calls;
/// docs/request-budgets.md names the lines. Nothing in `lib/` is changed.
const tripId = 'trp_budget';
final _origin = Uri.parse('https://budget.invalid');

/// The driver app's main states (what runs in each is in [_enter]).
enum DriverState {
  offline,
  onlineIdle,
  offerShown,
  toPickup,
  atPickup,
  onTrip,
  tripFinished,

  /// Online, app in the background (phone locked, decision 1).
  background,

  /// Offline Home with `/driver/config/stream` refused.
  offlineConfigStreamDown,

  /// Online idle with `/driver/offers/stream` refused.
  onlineOffersStreamDown,

  /// To pickup with the trip stream refused (follow poll fallback).
  toPickupTripStreamDown,
}

/// One request: `METHOD path`, ids and coordinates folded so the same
/// endpoint always gets the same key; only `scope` is kept of the query.
String endpointKey(http.BaseRequest request) {
  final uri = request.url;
  var path = uri.path
      .replaceAll(tripId, '{tripId}')
      .replaceFirst(RegExp(r'/routes/driving/.*$'), '/routes/driving/{coords}');
  final scope = uri.queryParameters['scope'];
  if (scope != null) path += '?scope=$scope';
  final sse = request.headers['Accept'] == 'text/event-stream';
  return '${request.method} $path${sse ? ' (SSE open)' : ''}';
}

final _route = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 1500.0,
      'duration': 180.0,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [19.82, 41.33],
          [19.84, 41.34],
        ],
      },
      'legs': <Object>[],
    },
  ],
};

/// The fake server: answers each request, keeps SSE streams open with a
/// heartbeat every 15 s, and counts.
class CountingClient extends http.BaseClient {
  CountingClient({this.refuseStream = const {}});

  /// Path prefixes whose SSE open is refused with a 503.
  final Set<String> refuseStream;
  final List<({Duration at, String key})> sent = [];
  final List<StreamController<List<int>>> _open = [];
  Duration Function() now = () => Duration.zero;
  String onlineStatus = 'offline';
  String tripStatus = 'driver_to_pickup';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key = endpointKey(request);
    sent.add((at: now(), key: key));
    final path = request.url.path;
    if (request.headers['Accept'] == 'text/event-stream') {
      if (refuseStream.any(path.startsWith)) {
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 503);
      }
      late final Timer beat;
      final controller = StreamController<List<int>>(
        onCancel: () => beat.cancel(),
      );
      beat = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!controller.isClosed) controller.add(utf8.encode(': hb\n'));
      });
      _open.add(controller);
      return http.StreamedResponse(controller.stream, 200);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(_answer(path)))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  Object _answer(String path) {
    if (path.startsWith('/api/v1/routes/driving/')) return _route;
    if (path == '/api/v1/driver/profile') {
      return {'onlineStatus': onlineStatus, 'version': 1};
    }
    if (path.startsWith('/api/v1/trips/')) {
      return {
        'tripId': tripId,
        'status': tripStatus,
        'version': 1,
        'updatedAt': '2026-11-10T09:00:00Z',
      };
    }
    if (path == '/api/v1/driver/offers' ||
        path == '/api/v1/notifications' ||
        path == '/api/v1/driver/reservations') {
      return {'items': <Object>[]};
    }
    return <String, Object?>{};
  }

  void closeAll() {
    for (final c in _open) {
      if (!c.isClosed) unawaited(c.close());
    }
  }
}

class _StillPhone implements DriverLocationRepository {
  static const here = GeoPoint(41.33, 19.82);
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      const DriverLocation(point: here, accuracyMeters: 5);
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// What one state sent: requests per minute per endpoint (steady part) and
/// the requests sent in the first second (the entry burst).
class StateMeasure {
  StateMeasure(this.state, this.perMinute, this.onEntry);
  final DriverState state;
  final Map<String, double> perMinute;
  final Map<String, int> onEntry;
  double get total => perMinute.values.fold(0, (a, b) => a + b);
}

/// Steady window: minutes 1..11 after entering the state (10 minutes).
const warmUp = Duration(minutes: 1);
const window = Duration(minutes: 10);

/// Runs [state] for [warmUp] + [window] on a fake clock and counts.
/// [extra] is a seam for the Rule 35 proof only (an added poll).
StateMeasure measure(
  DriverState state, {
  void Function(LiveDriverServices live, List<void Function()> stops)? extra,
}) {
  late StateMeasure result;
  fakeAsync((async) {
    final client = CountingClient(
      refuseStream: switch (state) {
        DriverState.offlineConfigStreamDown => {'/api/v1/driver/config/'},
        DriverState.onlineOffersStreamDown => {'/api/v1/driver/offers/'},
        DriverState.toPickupTripStreamDown => {'/api/v1/trips/'},
        _ => const {},
      },
    )..now = () => async.elapsed;
    final stops = <void Function()>[];
    _enter(state, client, stops, () => async.elapsed, extra);
    async.elapse(warmUp + window);
    for (final stop in stops.reversed) {
      stop();
    }
    client.closeAll();
    async.flushMicrotasks();
    async.elapse(const Duration(minutes: 2));

    final perMinute = <String, double>{};
    final onEntry = <String, int>{};
    for (final r in client.sent) {
      if (r.at < const Duration(seconds: 1)) {
        onEntry[r.key] = (onEntry[r.key] ?? 0) + 1;
      }
      if (r.at >= warmUp && r.at < warmUp + window) {
        perMinute[r.key] = (perMinute[r.key] ?? 0) + 1 / window.inMinutes;
      }
    }
    result = StateMeasure(state, perMinute, onEntry);
  });
  return result;
}

/// What the app runs in each state (file references in
/// docs/request-budgets.md).
void _enter(
  DriverState state,
  CountingClient client,
  List<void Function()> stops,
  Duration Function() elapsed,
  void Function(LiveDriverServices live, List<void Function()> stops)? extra,
) {
  final tokens = MemoryTokenStore()..save(access: 'access', refresh: 'r');
  final live = LiveDriverServices(
    client: client,
    origin: _origin,
    tokens: tokens,
    api: ApiClient(client: client, baseUri: _origin, tokens: tokens),
    location: _StillPhone(),
  );
  stops.add(() => unawaited(live.dispose()));
  // Signed in (main.dart → attach → signedIn): settings, their stream,
  // zones, events and content. The settings stream runs in every state.
  live.signedIn();

  final online = switch (state) {
    DriverState.offline || DriverState.offlineConfigStreamDown => false,
    _ => true,
  };
  if (online) {
    // Home's Go online: LivePresence.goOnline → location sender + offer
    // feed + the open offers.
    client.onlineStatus = 'online';
    unawaited(live.presence.goOnline());
  }

  // Home stays mounted under every route; its AirportQueueCard polls
  // while mounted, only when online and in a queue or near an airport
  // (owner 2026-11-10; the phone here is far from any airport zone).
  AirportQueue.instance.startPolling(
    live.api,
    relevant: () => AirportQueueCard.wantedFor(live),
  );
  stops.add(AirportQueue.instance.stopPolling);

  final homeVisible = switch (state) {
    DriverState.offline ||
    DriverState.onlineIdle ||
    DriverState.offerShown ||
    DriverState.offlineConfigStreamDown ||
    DriverState.onlineOffersStreamDown => true,
    _ => false,
  };
  // Home's badges: on open and every 60 s while Home is visible and in
  // front (home_account.dart:83, :512-534).
  final session = DriverAccountSession(
    repository: DriverAccountRepository(live.api),
  );
  void badges() {
    unawaited(session.refreshBadges());
    unawaited(refreshReminders(session));
    unawaited(refreshOnboardingSettings(session).then((_) {}, onError: (_) {}));
  }

  if (homeVisible) {
    badges();
    final t = Timer.periodic(onboardingRefreshEvery, (_) => badges());
    stops.add(t.cancel);
  }
  // Surge zones: online and Home on screen in front (home_updates.dart:26).
  final surge = SurgeMapController(source: live.surgeMap)
    ..sync(online: online && homeVisible, onHome: homeVisible);
  stops.add(surge.dispose);

  if (state == DriverState.offerShown) {
    // The offer's road on the map (home_offer_route.dart:103): one leg
    // pickup → drop-off, once per offer.
    final routes = RoadRouteService(api: live.api);
    unawaited(
      routes
          .drivingRoute(
            origin: _StillPhone.here,
            destination: const GeoPoint(41.34, 19.84),
          )
          .then((_) {}, onError: (_) {}),
    );
  }

  final stage = switch (state) {
    DriverState.toPickup ||
    DriverState.toPickupTripStreamDown => ActiveRideStage.headingToPickup,
    DriverState.atPickup => ActiveRideStage.waitingForRider,
    DriverState.onTrip => ActiveRideStage.onTrip,
    _ => null,
  };
  if (stage != null) {
    client.tripStatus = switch (stage) {
      ActiveRideStage.headingToPickup => 'driver_to_pickup',
      ActiveRideStage.waitingForRider => 'arrived',
      ActiveRideStage.onTrip => 'in_trip',
    };
    _trip(live, stage, stops, elapsed);
  }
  extra?.call(live, stops);
}

/// The trip screen (accept_ride.dart:697-716): its trip stream, the begin
/// read, the follow poll while the stream is down, and the road route the
/// GPS fixes ask for (accept_ride_trip_drive.dart:222).
void _trip(
  LiveDriverServices live,
  ActiveRideStage stage,
  List<void Function()> stops,
  Duration Function() elapsed,
) {
  final realtime = live.realtime();
  unawaited(live.trips.begin(tripId));
  final sub = realtime.subscribe(tripId).listen((DriverRealtimeEvent _) {});
  stops.add(() {
    unawaited(sub.cancel());
    realtime.dispose();
  });
  // accept_ride_pickup.dart:76 + accept_ride_live.dart:20: every 10 s,
  // only while the trip stream is not connected.
  final follow = Timer.periodic(const Duration(seconds: 10), (_) {
    if (realtime is ApiDriverRealtime && realtime.connected) return;
    unawaited(live.trips.follow(tripId));
  });
  stops.add(follow.cancel);

  final start = DateTime.utc(2026, 11, 10, 9);
  final navigation = NavigationController(
    routeRepository: RoadRouteService(api: live.api),
    now: () => start.add(elapsed()),
  )..setStage(stage);
  final target = stage == ActiveRideStage.onTrip
      ? const GeoPoint(41.35, 19.86)
      : const GeoPoint(41.34, 19.84);
  void fix() {
    // accept_ride_trip_drive.dart:186: no route asked while waiting.
    // The car stands at the route's start (setVehicle first, as :153).
    // No time stamp: setVehicle checks freshness against the wall clock.
    navigation.setVehicle(const DriverLocation(point: _StillPhone.here));
    if (stage == ActiveRideStage.waitingForRider) return;
    unawaited(
      navigation.ensureRoute(origin: _StillPhone.here, destination: target),
    );
  }

  fix();
  final gps = Timer.periodic(const Duration(seconds: 1), (_) => fix());
  stops.add(() {
    gps.cancel();
    navigation.dispose();
  });
}
