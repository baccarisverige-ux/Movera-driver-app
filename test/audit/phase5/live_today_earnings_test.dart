import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/today_earnings.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// Audit Phase 1 R3 (S2): today's earnings came only from this device's
/// trips, summed as SEK. A live build reads the server's figure; local
/// sums keep the trips' currency.
void main() {
  tearDown(() {
    LiveDriverServices.instance = null;
    TodayEarnings.reset();
  });

  final now = DateTime.utc(2026, 10, 26, 12);
  Map<String, Object?> report(int net, String currency) => {
    'driverId': 'd1',
    'period': 'day',
    'periods': [
      {
        'periodStart': '2026-10-25T23:00:00Z',
        'periodEnd': '2026-10-26T23:00:00Z',
        'tripCount': 2,
        'gross': {'amountMinor': net, 'currency': currency},
        'commission': {'amountMinor': 0, 'currency': currency},
        'tips': {'amountMinor': 0, 'currency': currency},
        'adjustments': {'amountMinor': 0, 'currency': currency},
        'net': {'amountMinor': net, 'currency': currency},
      },
    ],
  };

  test('todayOf reads the period holding now, in its currency', () {
    expect(
      LiveEarnings.todayOf(report(2450, 'EUR'), now)?.formatted,
      '24,50 €',
    );
    expect(LiveEarnings.todayOf({'periods': []}, now), isNull);
  });

  test('a live build shows the server\'s figure, not the device sum', () async {
    final seen = <String>[];
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      seen.add(request.url.toString());
      return http.Response(
        jsonEncode(report(31200, 'SEK')),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final origin = Uri.parse('https://api.test.movera.se');
    LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _NoGps(),
    );
    await TodayEarnings.refresh();
    expect(TodayEarnings.label.value, '312,00 kr');
    expect(seen.single, contains('/api/v1/driver/earnings?period=day'));
  });

  test('device sum keeps a euro trip in euros, and never mixes', () {
    TripHistoryRecord trip(String fare, int minor) => TripHistoryRecord(
      tripId: fare,
      riderName: 'R',
      whenLabel: '',
      pickup: '',
      dropoff: '',
      fare: fare,
      category: 'Comfort',
      completedAt: DateTime.now(),
      fareMinorUnits: minor,
    );
    expect(
      TodayEarnings.totalOf([trip('12,50 €', 1250)], DateTime.now()),
      '12,50 €',
    );
    expect(
      TodayEarnings.totalOf([
        trip('12,50 €', 1250),
        trip('100,00 kr', 10000),
      ], DateTime.now()),
      isNull,
    );
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.33, 18.06),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
