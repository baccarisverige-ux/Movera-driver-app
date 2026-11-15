import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// BQ-V42 follow-up (Rules audits/impact/queue-triage-2026-11-14.md:22,
/// job C9, contract v0.18.93 `TripTerms.autoArriveMeters`; owner
/// decisions/driver-g7.md:84 "the driver can also tap Framme himself (only
/// within that distance)"): the Arrive hint names the trip's own arrive
/// distance from the server, and the button's "near" uses the same number.
/// 100 m only when the server sends none (a trip booked before v0.18.93).

const _trip = 'v42-hint';

/// AcceptRide's default pickup is at 59.3279, 18.0615.
const _paris = GeoPoint(48.8566, 2.3522);

/// ~120 m north of the default pickup (0.00108° of latitude).
const _at120m = GeoPoint(59.32898, 18.0615);

/// ~130 m and ~160 m north of the default pickup.
const _at130m = GeoPoint(59.329069, 18.0615);
const _at160m = GeoPoint(59.329339, 18.0615);

class _Gps implements DriverLocationRepository {
  _Gps(this.point);
  final GeoPoint point;
  DriverLocation get _fix => DriverLocation(
    point: point,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(_fix);
}

Map<String, dynamic> _projection({int? arriveMeters}) => {
  'tripId': _trip,
  'version': 3,
  'status': 'driver_to_pickup',
  'kind': 'live',
  'acceptedAt': '2026-11-14T09:50:00Z',
  'pickup': {'lat': 59.3279, 'lng': 18.0615, 'address': 'Sergels torg'},
  'dropoff': {'lat': 59.3143, 'lng': 18.0735, 'address': 'Medborgarplatsen'},
  'rider': {'firstName': 'Camille'},
  'terms': {
    'currency': 'SEK',
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 1226, 'currency': 'SEK'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
    'noShowDriverSharePct': 80,
    'cancelDriverSharePct': 100,
    'maxPickupMoveMeters': 200,
    if (arriveMeters != null) ...{
      'autoArriveMeters': arriveMeters,
      'leaveMeters': 400,
    },
  },
};

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(
  WidgetTester tester,
  GeoPoint at, {
  int? arriveMeters,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final realtime = MemoryDriverRealtime();
  addTearDown(realtime.dispose);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: AcceptRide(
          tripId: _trip,
          riderName: 'Camille',
          initialStage: ActiveRideStage.headingToPickup,
          activeRideRepository: MemoryActiveRideRepository(),
          realtime: realtime,
          locationRepository: _Gps(at),
        ),
      ),
    ),
  );
  await _frames(tester);
  realtime.emit(
    tripId: _trip,
    kind: DriverRealtimeKind.tripProjection,
    status: TripStatus.driverToPickup,
    projection: _projection(arriveMeters: arriveMeters),
  );
  await _frames(tester, 16);
  tester
      .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .last
      .controller!
      .animatePanelToSnapPoint();
  await _frames(tester, 16);
}

Finder get _arrive =>
    find.byKey(const ValueKey<String>('active-ride-arrived-button'));

Color? _background(WidgetTester tester) => tester
    .widget<FilledButton>(_arrive)
    .style
    ?.backgroundColor
    ?.resolve(<WidgetState>{});

Future<void> _tapArrive(WidgetTester tester) async {
  await tester.ensureVisible(_arrive);
  await tester.tap(_arrive);
  await _frames(tester, 6);
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverAppTexts.language = 'en';
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    DriverAppTexts.reset();
  });

  testWidgets('a zone at 150 m: far away, the tap says "Move within 150 m"', (
    tester,
  ) async {
    await _pump(tester, _paris, arriveMeters: 150);
    await _tapArrive(tester);
    expect(
      find.text('Move within 150 m of the pickup to arrive.'),
      findsOneWidget,
    );
    expect(find.textContaining('within 100 m'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no arrive distance from the server: 100 m is the fallback', (
    tester,
  ) async {
    await _pump(tester, _paris);
    await _tapArrive(tester);
    expect(
      find.text('Move within 100 m of the pickup to arrive.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a zone at 150 m: 120 m from the pickup counts as near, so the '
      'hint and the button agree', (tester) async {
    await _pump(tester, _at120m, arriveMeters: 150);
    expect(_background(tester), const Color(0xFF111614));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no arrive distance: 120 m is still too far (100 m)', (
    tester,
  ) async {
    await _pump(tester, _at120m);
    expect(_background(tester), const Color(0xFFEEEFF1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  final waiting = find.byKey(
    const ValueKey<String>('active-ride-panel-waitingForRider'),
  );

  testWidgets('coordinator: a zone at 150 m, a tap from 130 m is allowed', (
    tester,
  ) async {
    await _pump(tester, _at130m, arriveMeters: 150);
    await _tapArrive(tester);
    await _frames(tester, 16);
    expect(waiting, findsOneWidget, reason: 'the driver is arrived');
    expect(find.textContaining('Move within'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('coordinator: a zone at 150 m, a tap from 160 m is refused', (
    tester,
  ) async {
    await _pump(tester, _at160m, arriveMeters: 150);
    await _tapArrive(tester);
    await _frames(tester, 16);
    expect(waiting, findsNothing);
    expect(
      find.text('Move within 150 m of the pickup to arrive.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('coordinator: no arrive distance, a tap from 130 m is refused '
      '(100 m)', (tester) async {
    await _pump(tester, _at130m);
    await _tapArrive(tester);
    await _frames(tester, 16);
    expect(waiting, findsNothing);
    expect(
      find.text('Move within 100 m of the pickup to arrive.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
