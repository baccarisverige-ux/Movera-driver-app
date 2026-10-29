import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_path.dart';

/// The route of a past ride (contract v0.17.0 §25): `GET /trips/{tripId}/path`
/// answers the driven line, or the planned road route for an older trip.
void main() {
  Map<String, dynamic> path({
    String source = 'driven',
    List<Map<String, num>>? points,
  }) => {
    'tripId': 'trp_1',
    'source': source,
    'points':
        points ??
        [
          {'lat': 59.33, 'lng': 18.06},
          {'lat': 59.32, 'lng': 18.07},
          {'lat': 59.31, 'lng': 18.08},
        ],
    'pickup': {'lat': 59.33, 'lng': 18.06},
    'dropoff': {'lat': 59.31, 'lng': 18.08},
    'stops': [
      {'lat': 59.32, 'lng': 18.07},
      'not a point',
    ],
    'keptUntil': '2026-11-28T12:00:00Z',
  };

  test('reads a driven and a planned path', () {
    final driven = TripPath.fromJson(path())!;
    expect(driven.source, TripPathSource.driven);
    expect(driven.points, hasLength(3));
    expect(driven.pickup.latitude, 59.33);
    expect(driven.dropoff.longitude, 18.08);
    expect(driven.stops, hasLength(1));
    expect(driven.extent, hasLength(6));
    expect(
      TripPath.fromJson(path(source: 'planned'))!.source,
      TripPathSource.planned,
    );
  });

  test('refuses what is not a path', () {
    expect(TripPath.fromJson(path(source: 'guessed')), isNull);
    expect(
      TripPath.fromJson(
        path(
          points: [
            {'lat': 59.3, 'lng': 18.0},
          ],
        ),
      ),
      isNull,
    );
    expect(
      TripPath.fromJson(
        path(
          points: [
            {'lat': 59.3, 'lng': 18.0},
            {'lat': 99, 'lng': 18.0},
          ],
        ),
      ),
      isNull,
    );
    expect(TripPath.fromJson({...path(), 'pickup': null}), isNull);
    expect(TripPath.fromJson({...path(), 'points': 'x'}), isNull);
    final noStops = TripPath.fromJson({...path(), 'stops': null})!;
    expect(noStops.stops, isEmpty);
  });

  test('pins only: no line, the two saved points', () {
    final pins = TripPath.pinsOnly(
      const GeoPoint(59.3, 18.0),
      const GeoPoint(59.2, 17.9),
    );
    expect(pins.source, TripPathSource.pins);
    expect(pins.points, isEmpty);
    expect(pins.extent, hasLength(2));
  });

  group('LiveTripPath', () {
    late List<http.Request> requests;
    LiveTripPath live(http.Response Function() answer) {
      requests = [];
      return LiveTripPath(
        api: ApiClient(
          client: MockClient((request) async {
            requests.add(request);
            return answer();
          }),
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
        ),
      );
    }

    test('asks GET /trips/{tripId}/path and reads the answer', () async {
      final loaded = await live(
        () => http.Response(
          jsonEncode(path()),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).load('trp 1');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/trips/trp%201/path');
      expect(loaded!.source, TripPathSource.driven);
    });

    test('a refusal or a failure is no path', () async {
      final refused = await live(
        () => http.Response(
          jsonEncode({
            'code': 'invalid_transition',
            'message': 'The trip has not ended yet.',
            'reason': 'trip_not_ended',
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ).load('trp_1');
      expect(refused, isNull);
    });
  });
}
