import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-10-26: "after accepting, the driver sees a wrong location in
/// Stockholm for a second, then the real one." The trip screen opened with a
/// fixed Stockholm point until its own GPS read landed. It now starts where
/// the app last told the server the phone was, else at the pickup.
void main() {
  late LiveDriverServices live;
  const sodertalje = LatLng(59.1954, 17.6252);

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && request.url.path == '/api/v1/trips/t1') {
        return json(200, {
          'tripId': 't1',
          'status': 'driver_to_pickup',
          'version': 2,
        });
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
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
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });
  tearDown(() async {
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<CustomGoogleMap> pumpTrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 't1',
            pickupPosition: sodertalje,
            locationRepository: _NoGps(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap).first);
  }

  test(
    'the last fix sent to the server is a point; a bad or missing one is not',
    () {
      expect(live.reporter.lastKnownPoint, isNull);
      live.reporter.lastFix = {'lat': 59.2, 'lng': 17.6, 'accuracy': 5};
      expect(live.reporter.lastKnownPoint?.latitude, 59.2);
      expect(live.reporter.lastKnownPoint?.longitude, 17.6);
      live.reporter.lastFix = {'lat': 'x', 'lng': 17.6};
      expect(live.reporter.lastKnownPoint, isNull);
    },
  );

  testWidgets('before the first GPS read the trip screen starts at the last '
      'position sent to the server', (tester) async {
    live.reporter.lastFix = {'lat': 59.2101, 'lng': 17.6401, 'accuracy': 5};
    final map = await pumpTrip(tester);
    expect(map.initialPosition?.target, const LatLng(59.2101, 17.6401));
  });

  testWidgets('without any position yet it starts at the pickup, not in '
      'Stockholm', (tester) async {
    final map = await pumpTrip(tester);
    expect(map.initialPosition?.target, sodertalje);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}
