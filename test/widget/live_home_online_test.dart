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
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// A live build: Home's switch is the server's availability. A refusal is
/// said plainly and Home stays offline; once online, the server's offers
/// are the only ones (no demo offers).
void main() {
  late List<http.Request> seen;
  late http.Response Function(http.Request) availability;
  var openOffers = <Map<String, Object?>>[];
  late LiveDriverServices live;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  tearDown(() => LiveDriverServices.instance = null);

  /// Made inside the test: its futures must run on the test's clock.
  void makeLive() {
    seen = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      seen.add(request);
      final path = request.url.path;
      return switch (path) {
        '/api/v1/driver/profile' =>
          json(200, {'driverId': 'd1', 'onlineStatus': 'offline', 'version': 1}),
        '/api/v1/driver/availability' => availability(request),
        '/api/v1/driver/location' => json(200, {'accepted': 1}),
        '/api/v1/driver/offers' => json(200, {'items': openOffers, 'nextCursor': null}),
        // The live feed stays closed here; the list above is what is open.
        _ => http.Response('', 503),
      };
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
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
  }

  Future<void> frames(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Future<DriverSessionController> goOnline(WidgetTester tester) async {
    makeLive();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    live.attach(session);
    await tester.pumpWidget(LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: session,
            dispatchRepository: live.dispatch,
            locationRepository: _Gps(),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await frames(tester, const Duration(milliseconds: 2000));
    return session;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    await frames(tester, const Duration(seconds: 2));
  }

  testWidgets('a refusal is shown and Home stays offline', (tester) async {
    openOffers = [];
    availability = (_) => json(409, {
      'code': 'invalid_transition',
      'reason': 'no_vehicle',
      'message': 'Choose an approved car first.',
    });
    final session = await goOnline(tester);
    expect(seen.where((r) => r.url.path == '/api/v1/driver/availability'), hasLength(1));
    expect(find.text(tr.liveOnlineNoVehicle), findsOneWidget);
    expect(session.status, DriverOnlineStatus.offline);
    expect(live.presence.serverOnline, isFalse);
    await leave(tester);
  });

  testWidgets('online: only the server\'s offer comes up, no demo offers', (tester) async {
    availability = (request) => json(200, {
      'driverId': 'd1',
      'onlineStatus': 'online',
      'version': 2,
    });
    openOffers = [_exclusiveOffer()];
    final session = await goOnline(tester);
    expect(session.status, DriverOnlineStatus.online);
    expect(live.presence.serverOnline, isTrue);
    final sent = jsonDecode(seen
        .firstWhere((r) => r.url.path == '/api/v1/driver/availability')
        .body) as Map;
    expect(sent['expectedVersion'], 1);
    expect(sent['onlineStatus'], 'online');
    expect(seen.any((r) => r.url.path == '/api/v1/driver/location'), isTrue);
    await frames(tester, const Duration(seconds: 3));
    expect(find.byKey(const ValueKey<String>('exclusive-offer-card-srv-offer-1')),
        findsOneWidget);
    // The demo's own Exclusive offers never come up in a live build.
    await frames(tester, const Duration(seconds: 25));
    expect(find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('exclusive-offer-card-') &&
          key.value != 'exclusive-offer-card-srv-offer-1';
    }), findsNothing);
    await leave(tester);
  });
}

Map<String, Object?> _exclusiveOffer() => {
  'offerId': 'srv-offer-1',
  'tripId': 'srv-trip-1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
  'fare': {'amountMinor': 6800, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 5400, 'currency': 'SEK'},
  'priority': false,
  'source': 'system',
  'pickup': {'lat': 59.332, 'lng': 18.066, 'address': 'Vasagatan 1, Stockholm'},
  'dropoff': {'lat': 59.34, 'lng': 18.08, 'address': 'Kungsgatan 40, Stockholm'},
  'stops': <Object>[],
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 420,
  'tripMeters': 2100,
};

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
