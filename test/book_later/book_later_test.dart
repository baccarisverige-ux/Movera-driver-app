import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// Contract v0.18.17 Book later (owner 2026-11-03): the live driver app
/// reads its Scheduled rides from the server and takes, gives back and
/// starts them there. Before, a live build had an empty list and the
/// server answered 404 (`GET /driver/reservations` not built).
Map<String, Object?> row(String id, {String status = 'requested'}) => {
  'tripId': id,
  'version': 3,
  'scheduledAt': '2026-11-05T07:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
  'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
  'stops': 0,
  'distanceMeters': 8000,
  'durationSeconds': 1080,
  'earnings': {'amountMinor': 17360, 'currency': 'SEK'},
  'status': status,
  'mustBeOnlineAt': '2026-11-05T06:00:00Z',
  'canStartAt': '2026-11-05T06:00:00Z',
};

void main() {
  test('a DriverReservation becomes the Scheduled rides card with the server money', () {
    final ride = ServerReservation.fromJson(Map<String, dynamic>.from(row('trp_1')));
    expect(ride.tripId, 'trp_1');
    expect(ride.earnings.minorUnits, 17360);
    expect(ride.accepted, isFalse);
    final card = ride.toPreview(dayWord: (_) => 'Tomorrow', pickupLabel: (t) => 'Tomorrow $t');
    expect(card.id, 'trp_1');
    expect(card.tripKm, 8.0);
    expect(card.tripMinutes, 18);
    expect(card.earnings, ride.earnings.formatted);
    expect(card.driverPayLabel, ride.earnings.formatted, reason: 'the server earnings, never the demo share');
    expect(card.pickupAddress, 'Sergels torg');
  });

  test('a broken row is left out, never a crash', () {
    final rows = ServerReservations.parsePage({
      'items': [row('trp_1'), {'tripId': 'trp_bad'}, 'x'],
    });
    expect(rows.map((r) => r.tripId), ['trp_1']);
  });

  test('every server refusal has its reason', () {
    expect(reservationRefusalOf(409, {'reason': 'reservation_taken'}), ReservationRefusal.taken);
    expect(reservationRefusalOf(409, {'reason': 'reservation_clash'}), ReservationRefusal.clash);
    expect(reservationRefusalOf(409, {'reason': 'reservation_too_early'}), ReservationRefusal.tooEarly);
    expect(reservationRefusalOf(409, {'reason': 'reservation_in_dispatch'}), ReservationRefusal.inDispatch);
    expect(reservationRefusalOf(404, null), ReservationRefusal.notOpen);
  });

  group('LiveReservations on the server', () {
    late List<http.Request> requests;
    LiveReservations live(http.Response Function(http.Request) answer, {void Function(Map<String, dynamic>)? started}) {
      requests = [];
      return LiveReservations(
        api: ApiClient(
          client: MockClient((request) async {
            requests.add(request);
            return answer(request);
          }),
          baseUri: Uri.parse('https://api.example.test'),
          tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
        ),
        onStarted: started,
      );
    }

    http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

    test('load reads the open and the accepted list', () async {
      final api = live((r) => json({'items': [row(r.url.queryParameters['scope'] == 'open' ? 'trp_open' : 'trp_mine', status: r.url.queryParameters['scope'] == 'open' ? 'requested' : 'accepted')], 'nextCursor': null}));
      final page = await api.load();
      expect(page.open.single.tripId, 'trp_open');
      expect(page.accepted.single.tripId, 'trp_mine');
      expect(requests.map((r) => '${r.method} ${r.url.path}?${r.url.query}'), ['GET /api/v1/driver/reservations?scope=open', 'GET /api/v1/driver/reservations?scope=accepted']);
    });

    test('reservations off in the zone: an empty open list', () async {
      final api = live((r) => r.url.queryParameters['scope'] == 'open' ? json({'code': 'forbidden', 'message': 'off', 'reason': 'reservations_off'}, 403) : json({'items': [], 'nextCursor': null}));
      expect((await api.load()).open, isEmpty);
    });

    test('accept: the first tap wins; another driver first is "taken"', () async {
      var api = live((_) => json({'tripId': 'trp_1', 'status': 'accepted', 'version': 4}));
      expect(await api.accept('trp_1', version: 3), isNull);
      expect(requests.single.url.path, '/api/v1/driver/reservations/trp_1/accept');
      expect(jsonDecode(requests.single.body), {'expectedVersion': 3});
      api = live((_) => json({'code': 'conflict', 'message': 'taken', 'reason': 'reservation_taken'}, 409));
      expect(await api.accept('trp_1'), ReservationRefusal.taken);
    });

    test('give back sends the scheduled reason; start opens the trip', () async {
      var api = live((_) => http.Response('', 204));
      expect(await api.release('trp_1'), isTrue);
      expect(jsonDecode(requests.single.body), {'reasonCode': 'scheduled_other'});
      Map<String, dynamic>? opened;
      api = live((_) => json({'tripId': 'trp_1', 'status': 'driver_to_pickup', 'version': 6}), started: (t) => opened = t);
      expect(await api.start('trp_1'), isNull);
      expect(requests.single.url.path, '/api/v1/driver/reservations/trp_1/start');
      expect(opened?['status'], 'driver_to_pickup');
      api = live((_) => json({'code': 'conflict', 'message': 'early', 'reason': 'reservation_too_early'}, 409));
      expect(await api.start('trp_1'), ReservationRefusal.tooEarly);
    });
  });
}
