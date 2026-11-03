import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// Contract v0.18.17 Book later (`contract.json#bookLater.driver`): the
/// driver's Scheduled rides on the server. Before this the live app had
/// no reservations at all (`GET /driver/reservations` answered 404).
class LiveReservations {
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
    return ServerReservations(open: open, accepted: accepted);
  }

  /// `POST /driver/reservations/{tripId}/accept`: null when this driver
  /// got the ride (the first tap wins), else why not.
  Future<ReservationRefusal?> accept(String tripId, {int? version}) =>
      _run(() => _api.post(
        commandPath(tripId, 'accept'),
        body: {if (version != null) 'expectedVersion': version},
      ));

  /// `POST /driver/reservations/{tripId}/release`: the ride goes back to
  /// the list. True when the server took it back.
  Future<bool> release(String tripId, {String reasonCode = 'scheduled_other'}) async =>
      await _run(() => _api.post(
        commandPath(tripId, 'release'),
        body: {'reasonCode': reasonCode},
      )) ==
      null;

  /// `POST /driver/reservations/{tripId}/start`: head to the pickup. The
  /// trip opens as the current trip ([onStarted]).
  Future<ReservationRefusal?> start(String tripId) => _run(() async {
    final trip = await _api.post(commandPath(tripId, 'start'), body: const {});
    if (trip['tripId'] is String) onStarted?.call(trip);
    return trip;
  });

  Future<ReservationRefusal?> _run(Future<Map<String, dynamic>> Function() call) async {
    try {
      await call();
      return null;
    } on ApiError catch (error) {
      if (error.code == ApiError.network || error.code == ApiError.timeout) {
        return ReservationRefusal.network;
      }
      return reservationRefusalOf(error.statusCode ?? 0, {'reason': error.reason});
    }
  }
}
