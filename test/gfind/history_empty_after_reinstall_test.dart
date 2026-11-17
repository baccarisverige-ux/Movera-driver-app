// "Empty driver history" (decisions/driver-g11.md:28 + :41, owner "Load
// from server (Recommended)" / "Yes, on the server (Recommended)"; live
// 2026-11-02: driver history 0 trips while the server had 2). G28 step 1
// (#566) moved only the TOTALS to GET /driver/earnings; the ride LIST is
// still read from this phone's archive, wiped at sign-out and reinstall.
// The contract has no driver trip list yet (BQ-V17 `GET /driver/trips`,
// stage S8: contract C10 → server S21 → driver D18).
//
// This test pinned the behaviour on main as the proof (Rule 36) that the
// finding was present. D18 (contract v0.18.124 C10, server S21) flipped
// it: the rides now come from the server list GET /driver/trips.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => LiveDriverServices.instance = null);

  Map<String, Object?> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };

  test('the driver contract copy has the driver trip list (BQ-V17, '
      'v0.18.124)', () {
    final openapi = File('contracts/openapi.yaml').readAsStringSync();
    expect(openapi, contains('\n  /rider/trips:'), reason: 'riders have one');
    expect(openapi, contains('\n  /driver/trips:'), reason: 'D18 reads it');
  });

  testWidgets('fixed: after a reinstall the list shows the server\'s '
      'rides, not an empty list', (tester) async {
    // Signed out and in again (or a new phone): the archive is empty.
    SharedPreferences.setMockInitialValues({});
    Money.zoneCurrency = 'SEK';
    final asked = <String>[];
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      asked.add(request.url.path);
      if (request.url.path == '/api/v1/driver/earnings') {
        return http.Response(
          jsonEncode({
            'driverId': 'd1',
            'period': 'day',
            'timeZone': 'Europe/Stockholm',
            'currency': 'SEK',
            'currencies': ['SEK'],
            'periods': [
              {
                'periodStart': '2026-11-11T23:00:00Z',
                'periodEnd': '2026-11-12T23:00:00Z',
                'tripCount': 6,
                'gross': money(600),
                'commission': money(0),
                'pickupPay': money(0),
                'tips': money(0),
                'adjustments': money(0),
                'cashCollected': money(0),
                'fees': money(0),
                'net': money(600),
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/driver/trips') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'tripId': 'trp_1',
                'status': 'completed',
                'categoryId': 'economy',
                'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'Odenplan'},
                'dropoff': {'lat': 59.32, 'lng': 18.07, 'address': 'Slussen'},
                'paymentMethod': 'card',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'endedAt': DateTime.now().toUtc().toIso8601String(),
                'earned': money(600),
              },
            ],
            'nextCursor': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final origin = Uri.parse('https://api.test.movera.se');
    LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _NoGps(),
    );
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DriverRideHistory()));
    await tester.pumpAndSettle();

    // The server's totals are shown (G28 step 1) ...
    expect(find.text('6,00 kr'), findsWidgets);
    // ... and, since D18, the rides themselves from the server's list.
    expect(find.text('No completed rides in this period.'), findsNothing);
    expect(find.textContaining('Odenplan'), findsWidgets);
    expect(
      asked.where((p) => p.startsWith('/api/v1/driver/trips')),
      isNotEmpty,
      reason: 'the server trip list is read',
    );
    expect(tester.takeException(), isNull);
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
