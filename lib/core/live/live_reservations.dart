import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/app_update/min_app_version.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// Contract v0.18.17 Book later (`contract.json#bookLater.driver`): the
/// driver's Scheduled rides on the server. Before this the live app had
/// no reservations at all (`GET /driver/reservations` answered 404).
class LiveReservations implements PreferredAreasApi {
  LiveReservations({required ApiClient api, this.onStarted}) : _api = api;

  final ApiClient _api;

  /// The trip (`TripProjection`) a Start answered with: it becomes the
  /// driver's current trip, as an accepted offer does.
  final void Function(Map<String, dynamic> trip)? onStarted;

  static const path = '/api/v1/driver/reservations';
  static String commandPath(String tripId, String verb) =>
      '$path/${Uri.encodeComponent(tripId)}/$verb';

  /// `GET /driver/reservations?scope=open` and `?scope=accepted`. Booked
  /// rides off in the zone (`403 reservations_off`): an empty open list.
  Future<ServerReservations> load() async {
    List<ServerReservation> open;
    try {
      open = ServerReservations.parsePage(await _api.get('$path?scope=open'));
    } on ApiError catch (error) {
      if (error.reason != 'reservations_off') rethrow;
      open = const [];
    }
    final accepted = ServerReservations.parsePage(
      await _api.get('$path?scope=accepted'),
    );
    // v0.18.154 P16c review O-2: a held booked ride keeps the block away.
    MinAppVersion.bookedHeld.value = accepted.isNotEmpty;
    return ServerReservations(open: open, accepted: accepted);
  }

  /// `POST /driver/reservations/{tripId}/accept`: null when this driver
  /// got the ride (the first tap wins), else why not.
  Future<ReservationRefusal?> accept(String tripId, {int? version}) => _run(
    () => _api.post(
      commandPath(tripId, 'accept'),
      body: {if (version != null) 'expectedVersion': version},
    ),
  );

  /// `POST /driver/reservations/{tripId}/release`: the ride goes back to
  /// the list. True when the server took it back.
  Future<bool> release(
    String tripId, {
    String reasonCode = 'scheduled_other',
  }) async =>
      await _run(
        () => _api.post(
          commandPath(tripId, 'release'),
          body: {'reasonCode': reasonCode},
        ),
      ) ==
      null;

  /// Owner BL-Q6: `POST /driver/reservations/{tripId}/keep { keep }`.
  Future<ReservationRefusal?> keep(String tripId, {required bool keep}) =>
      _run(() => _api.post(commandPath(tripId, 'keep'), body: {'keep': keep}));

  /// Owner BL-Q4: `PUT /driver/home-area` (where "home nearby" booked
  /// rides are measured from). True when the server saved it.
  Future<bool> setHomeArea(double lat, double lng, {String? label}) async =>
      await _run(
        () => _api.put(
          '/api/v1/driver/home-area',
          body: {
            'lat': lat,
            'lng': lng,
            if (label != null && label.isNotEmpty) 'label': label,
          },
        ),
      ) ==
      null;

  /// v0.18.172 (`contract.json#preferredAreas.search`): areas of his
  /// zones whose name matches [query]; areas only, never addresses.
  @override
  Future<List<PreferredArea>> searchAreas(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final page = await _api.get('/api/v1/driver/areas/search?q=$q');
    return PreferredArea.listOf(page['items']);
  }

  /// v0.18.172 (`contract.json#preferredAreas.at`): the smallest area of
  /// his zones holding the point, or null. The point is sent once and
  /// never kept (not here, not on the server).
  @override
  Future<PreferredArea?> areaAt(double lat, double lng) async {
    final answer = await _api.get(
      '/api/v1/driver/areas/at?lat=${lat.toStringAsFixed(6)}&lng=${lng.toStringAsFixed(6)}',
    );
    return PreferredArea.fromJson(answer['area']);
  }

  /// v0.18.172: `PUT /driver/preferred-areas { areaIds }`, area ids only
  /// (no address text, no point). The saved list, or null when refused.
  @override
  Future<List<PreferredArea>?> setPreferredAreas(List<String> areaIds) async {
    try {
      final driver = await _api.put(
        '/api/v1/driver/preferred-areas',
        body: {'areaIds': areaIds},
      );
      return PreferredArea.listOf(driver['preferredAreas']);
    } on ApiError {
      return null;
    }
  }

  /// v0.18.172: `Driver.preferredAreas` of `GET /driver/profile`.
  @override
  Future<List<PreferredArea>> loadPreferredAreas() async =>
      PreferredArea.listOf(
        (await _api.get('/api/v1/driver/profile'))['preferredAreas'],
      );

  /// `POST /driver/reservations/{tripId}/start`: head to the pickup. The
  /// trip opens as the current trip ([onStarted]).
  Future<ReservationRefusal?> start(String tripId) => _run(() async {
    final trip = await _api.post(commandPath(tripId, 'start'), body: const {});
    if (trip['tripId'] is String) {
      _started[tripId] = LiveActiveTrip.snapshotOf(trip);
      onStarted?.call(trip);
    }
    return trip;
  });

  final Map<String, PersistedActiveRide?> _started = {};

  /// The trip a Start of booked ride [tripId] answered with: its payment
  /// method, cash and driver earnings, which the Scheduled rides row
  /// (`DriverReservation`) does not carry. Null before a Start.
  PersistedActiveRide? startedTrip(String tripId) => _started[tripId];

  Future<ReservationRefusal?> _run(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      await call();
      return null;
    } on ApiError catch (error) {
      if (error.code == ApiError.network || error.code == ApiError.timeout) {
        return ReservationRefusal.network;
      }
      if (error.code == 'version_mismatch') return ReservationRefusal.changed;
      return reservationRefusalOf(error.statusCode ?? 0, {
        'reason': error.reason,
      });
    }
  }
}
