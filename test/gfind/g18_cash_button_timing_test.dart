// G18 (BrowserStack 2026-11-12 run 1 + run 2, plan/JOBS-2026-11-11-G.md):
// on a cash trip "Encaisser les espèces" (Collect cash) showed right after
// the start, kilometres from the drop-off. Owner 2026-11-16
// (Rules decisions/session-2026-11-06.md, G18 line): "Always finish trip
// then after clic it become collect cash ! And change color to black not
// marron". So on a cash trip the big button ALWAYS reads "Finish trip"
// ("Terminer la course") during the trip, at any distance; only once
// tapped is it "Collect cash" ("Encaisser les espèces"), whose tap shows
// the cash screen with the server's price (an early end is priced for the
// distance driven, test/g8/g8_driver_early_end_test.dart). Black, not
// maroon. Non-cash trips keep the slide.
//
// With `--dart-define=G18_SHOTS=<dir> --update-goldens` the button in both
// states (EN, FR) and the cash screen are written there as PNG.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show GoogleMapsFlutterPlatform;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

const _pickup = GeoPoint(59.3326, 18.0649); // Sergels torg
const _dropoff = GeoPoint(59.3429, 18.0498); // Odenplan, ~1.4 km away

/// The car stands at the pickup: the trip has just started.
class _AtPickup implements DriverLocationRepository {
  DriverLocation get fix => DriverLocation(
    point: _pickup,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(fix);
}

const _shots = String.fromEnvironment('G18_SHOTS');
const _black = Color(0xFF111614);

/// WCAG 2 contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  late List<http.Request> requests;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    realtime = MemoryDriverRealtime();
    requests = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add(request);
      if (path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && path == '/api/v1/trips/g18-trip') {
        return json(200, {
          'tripId': 'g18-trip',
          'status': 'in_trip',
          'version': 8,
          'paymentMethod': 'cash',
          'fare': money(20800),
          'driverEarnings': money(15136),
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/driver/trips/g18-trip/complete-preview') {
        // The server prices the early end for the distance driven.
        return json(200, {
          'previewId': 'cpv_g18',
          'tripId': 'g18-trip',
          'total': money(5400),
          'cashDue': money(5400),
          'driverEarnings': money(3920),
          'earlyEnd': true,
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
        return json(200, {
          'driverId': 'drv_1',
          'accountStatus': 'active',
          'version': 4,
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
      location: _AtPickup(),
    );
    LiveDriverServices.instance = live;
  });
  tearDown(() async {
    DriverAppTexts.reset();
    realtime.dispose();
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<String?> font() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (_shots.isEmpty || root == null) return null;
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
    );
    if (!file.existsSync()) return null;
    await (FontLoader('G18Proof')
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
        .load();
    return 'G18Proof';
  }

  // Written by the golden writer (`--update-goldens`), which needs no
  // real wait, so the map's platform view stays quiet.
  Future<void> shot(WidgetTester tester, String name) async {
    if (_shots.isEmpty) return;
    await expectLater(
      find.byKey(const ValueKey('g18-proof')),
      matchesGoldenFile('$_shots/$name.png'),
    );
  }

  Future<void> open(WidgetTester tester, {required bool cash}) async {
    expect(_pickup.distanceMetersTo(_dropoff), greaterThan(1000));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final family = await font();
    if (_shots.isNotEmpty) {
      // The golden writer waits for real: the map stays inside Flutter.
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    }
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      DriverRuntimeScope(
        session: session,
        homeBuilder: () => const SizedBox(),
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            theme: ThemeData(fontFamily: family),
            // The shot holds the sheets above the trip too.
            builder: (_, child) =>
                RepaintBoundary(key: const ValueKey('g18-proof'), child: child),
            home: AcceptRide(
              tripId: 'g18-trip',
              initialStage: ActiveRideStage.onTrip,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              paidByCash: cash,
              cashToCollect: cash ? '208,00 kr' : null,
              category: 'Economy',
              matchedVia: WaybillRecord.demoRadarSource,
              pickupAddress: 'Sergels torg',
              pickupArea: '',
              pickupPosition: LatLng(_pickup.latitude, _pickup.longitude),
              dropoffAddress: 'Odenplan',
              dropoffPosition: LatLng(_dropoff.latitude, _dropoff.longitude),
              locationRepository: _AtPickup(),
              activeRideRepository: MemoryActiveRideRepository(),
              sessionController: session,
              waybillRepository: InMemoryWaybillRepository.instance,
              realtime: realtime,
            ),
          ),
        ),
      ),
    );
    await frames(tester, 20);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  const finishKey = ValueKey<String>('active-ride-finish-trip');
  const collectKey = ValueKey<String>('active-ride-collect-cash');
  const slideKey = ValueKey<String>('active-ride-slide-action');

  void expectBlack(WidgetTester tester, ValueKey<String> key) {
    final style = tester.widget<FilledButton>(find.byKey(key)).style!;
    final bg = style.backgroundColor!.resolve(<WidgetState>{})!;
    final fg = style.foregroundColor!.resolve(<WidgetState>{})!;
    expect(bg, _black, reason: 'black, not maroon 0xFF7A5200');
    expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
  }

  final texts = {
    'en': ('Finish trip', 'Collect cash'),
    'fr': ('Terminer la course', 'Encaisser les espèces'),
  };
  for (final MapEntry(key: language, value: (finish, collect))
      in texts.entries) {
    testWidgets('G18: a cash trip shows "$finish" from the start, ~1.4 km '
        'from the drop-off; tapped it becomes "$collect", whose tap shows '
        'the server price; black ($language)', (tester) async {
      DriverAppTexts.language = language;
      await open(tester, cash: true);

      // 1. During the trip, at any distance: Finish trip only.
      expect(find.byKey(finishKey), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(finishKey), matching: find.text(finish)),
        findsOneWidget,
      );
      expect(find.byKey(collectKey), findsNothing);
      expect(find.text(collect), findsNothing);
      expect(find.byKey(slideKey), findsNothing);
      expectBlack(tester, finishKey);
      await shot(tester, 'g18-1-finish-trip-$language');

      // 2. Tapped: the same button now reads Collect cash; no price asked
      //    yet, no cash screen yet.
      final previews = requests
          .where((r) => r.url.path.endsWith('/complete-preview'))
          .length;
      await tester.ensureVisible(find.byKey(finishKey));
      await tester.tap(find.byKey(finishKey));
      await frames(tester, 6);
      expect(find.byKey(finishKey), findsNothing);
      expect(find.byKey(collectKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(collectKey),
          matching: find.text(collect),
        ),
        findsOneWidget,
      );
      expectBlack(tester, collectKey);
      expect(
        find.byKey(const ValueKey<String>('cash-collect-sheet')),
        findsNothing,
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/complete-preview')).length,
        previews,
      );
      await shot(tester, 'g18-2-collect-cash-$language');

      // 3. Collect cash: today's cash screen with the server's price for
      //    the distance driven (54,00 kr), not the booked 208,00 kr.
      await tester.tap(find.byKey(collectKey));
      await frames(tester, 10);
      expect(
        requests.where((r) => r.url.path.endsWith('/complete-preview')),
        isNotEmpty,
      );
      final sheet = find.byKey(const ValueKey<String>('cash-collect-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.textContaining('54')),
        findsWidgets,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('208')),
        findsNothing,
      );
      await shot(tester, 'g18-3-cash-screen-$language');
      await close(tester);
    });
  }

  // SF-1 (G18 post-merge review): "Collect cash" belongs to the last leg
  // it was tapped on (`_cashFinishTappedAt == _stopAddresses.length`,
  // accept_ride_state_getters.dart). A stop added after the tap takes the
  // button away; once that stop is done, the new last leg starts again
  // at "Finish trip".
  testWidgets('G18 SF-1: Finish trip tapped -> Collect cash; a stop is '
      'added -> the button goes back to "Finish trip" on the new last '
      'leg', (tester) async {
    DriverAppTexts.language = 'en';
    // The stop steps run on this phone (no server step to answer).
    LiveDriverServices.instance = null;
    await open(tester, cash: true);

    // A trip update can fold the sheet; the step buttons are in it.
    Future<void> reveal(Finder target) async {
      if (target.evaluate().isNotEmpty) return;
      tester
          .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .last
          .controller!
          .animatePanelToSnapPoint();
      await frames(tester, 16);
    }

    await tester.ensureVisible(find.byKey(finishKey));
    await tester.tap(find.byKey(finishKey));
    await frames(tester, 6);
    expect(find.byKey(collectKey), findsOneWidget);
    expect(find.byKey(finishKey), findsNothing);

    // The rider adds a stop; the change is accepted.
    final stop = {'lat': 59.3326, 'lng': 18.0296, 'address': 'Fridhemsplan'};
    final change = {
      'changeId': 'rc_sf1',
      'routeQuoteId': 'rq_sf1',
      'status': 'accepted',
      'answeredBy': 'driver',
      'dropoff': {
        'lat': _dropoff.latitude,
        'lng': _dropoff.longitude,
        'address': 'Odenplan',
      },
      'stops': [stop],
      'total': money(25000),
      'driverTotal': money(18000),
    };
    realtime.emit(
      tripId: 'g18-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.inTrip,
      projection: {
        'tripId': 'g18-trip',
        'version': 9,
        'status': 'in_trip',
        'paymentMethod': 'cash',
        'routeChange': change,
      },
    );
    await frames(tester, 10);
    // A stop ahead: no cash step now, the stop comes first.
    final arrive = find.byKey(
      const ValueKey<String>('active-ride-arrived-button'),
    );
    await reveal(arrive);
    expect(find.byKey(collectKey), findsNothing);
    expect(find.text('Collect cash'), findsNothing);
    expect(
      arrive,
      findsOneWidget,
    );

    // At the stop (the server's arrival), then leaving it.
    realtime.emit(
      tripId: 'g18-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.inTrip,
      projection: {
        'tripId': 'g18-trip',
        'version': 10,
        'status': 'in_trip',
        'paymentMethod': 'cash',
        'routeChange': change,
        'stops': [
          {
            ...stop,
            'arrivedAt': DateTime.now()
                .toUtc()
                .subtract(const Duration(seconds: 30))
                .toIso8601String(),
          },
        ],
      },
    );
    await frames(tester, 10);
    final slide = find.byKey(const ValueKey('active-ride-primary-action'));
    await reveal(slide);
    expect(slide, findsOneWidget);
    await tester.ensureVisible(slide);
    await tester.drag(slide, const Offset(320, 0));
    await frames(tester, 10);

    // The new last leg: "Finish trip" again, not the old tap's
    // "Collect cash".
    await reveal(find.byKey(finishKey));
    expect(find.byKey(finishKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(finishKey),
        matching: find.text('Finish trip'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(collectKey), findsNothing);
    expectBlack(tester, finishKey);

    // Tapped on this leg, it is "Collect cash" again.
    await tester.ensureVisible(find.byKey(finishKey));
    await tester.tap(find.byKey(finishKey));
    await frames(tester, 6);
    expect(find.byKey(collectKey), findsOneWidget);
    expect(find.byKey(finishKey), findsNothing);
    await close(tester);
  });

  testWidgets('G18: a non-cash trip is unchanged (the slide, no cash '
      'button)', (tester) async {
    await open(tester, cash: false);
    expect(find.byKey(slideKey), findsOneWidget);
    expect(find.byKey(finishKey), findsNothing);
    expect(find.byKey(collectKey), findsNothing);
    await close(tester);
  });
}
