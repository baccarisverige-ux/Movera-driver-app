// Audit round 5, the high bugs (Wave 6b): routes over Home and the trip,
// the trip's GPS start, and a won Radar Match under a sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// GPS the test feeds by hand; [listening] says whether a screen
/// follows the stream.
class _Gps implements DriverLocationRepository {
  _Gps({this.firstFixFails = false});
  final bool firstFixFails;
  final updates = StreamController<DriverLocation>.broadcast();
  bool get listening => updates.hasListener;
  @override
  Future<DriverLocation> getCurrentPosition() async {
    if (firstFixFails) throw TimeoutException('no first fix');
    return at(0);
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// [meters] north of Stockholm Central, driving north.
DriverLocation at(double meters) => DriverLocation(
  point: GeoPoint(59.3300 + meters / 111000, 18.0600),
  speedMetersPerSecond: 10,
  measuredAt: DateTime.now(),
  accuracyMeters: 5,
);

/// A headless map that counts the camera moves sent to it.
class _Camera extends HeadlessMapPlatform {
  int moves = 0;
  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {
    moves++;
  }

  @override
  Future<void> animateCamera(CameraUpdate update, {required int mapId}) async {
    moves++;
  }
}

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Waits (in test time) until [finder] shows, up to [limit].
Future<void> _until(
  WidgetTester tester,
  Finder finder, [
  Duration limit = const Duration(seconds: 10),
]) async {
  for (
    var t = Duration.zero;
    t < limit && finder.evaluate().isEmpty;
    t += const Duration(milliseconds: 100)
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _setUp(WidgetTester tester, {GoogleMapsFlutterPlatform? map}) {
  SharedPreferences.setMockInitialValues({});
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = map ?? HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  final config = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = const DriverRuntimeConfig(
    externalRouting: false,
    liveMapTicker: false,
    reservationPopup: false,
    islandHint: false,
    radarSound: false,
    simulatedArrival: true,
    skipAccountActivation: true,
  );
  addTearDown(() => DriverRuntimeConfig.current = config);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<GlobalKey<NavigatorState>> _pumpApp(
  WidgetTester tester,
  Widget home,
) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [driverRouteObserver],
        home: home,
      ),
    ),
  );
  await _frames(tester, 20);
  return navigator;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester, 10, 100);
}

RideOffer _radarTrip(String id) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 10000),
  rating: '4.9',
  pickupMinutes: 2,
  pickupKm: 1,
  tripMinutes: 10,
  tripKm: 5,
  pickup: 'Pickup, Stockholm',
  dropoff: 'Dropoff, Stockholm',
  pickupPosition: const GeoPoint(59.3279, 18.0615),
  dropoffPosition: const GeoPoint(59.3326, 18.0649),
  isNearby: true,
  followsDestination: true,
);

/// Dispatch with two Radar trips; each Match waits for the test's answer.
class _RadarDispatch implements DispatchRepository {
  final claims = <Completer<ClaimResult>>[];
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() => const Stream.empty();
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.multi((sink) => sink.addSync(offers), isBroadcast: true);
  List<RideOffer> offers = [_radarTrip('first'), _radarTrip('second')];
  @override
  Stream<List<RideOffer>> watchNextTripOffers() => const Stream.empty();
  @override
  void refreshOffers() {}
  @override
  void releaseReservation(String reservationId) {}
  @override
  Stream<ReservationRequestPreview> watchAssignments() => const Stream.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) {
    claims.add(Completer<ClaimResult>());
    return claims.last.future;
  }
}

/// No GPS fix ever (Home stays on its start position).
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

void main() {
  testWidgets('driver-r5-28: the trip and the side menu pause Home; a sheet '
      'does not', (tester) async {
    _setUp(tester);
    final homeGps = _Gps(), tripGps = _Gps();
    addTearDown(homeGps.updates.close);
    addTearDown(tripGps.updates.close);
    final navigator = await _pumpApp(
      tester,
      DriverHome(locationRepository: homeGps),
    );
    expect(homeGps.listening, isTrue);

    // A sheet leaves Home visible and following GPS (driver-r4-31).
    final home = tester.element(find.byType(DriverHome));
    unawaited(
      showModalBottomSheet<void>(
        context: home,
        builder: (_) => const Text('sheet'),
      ),
    );
    await _frames(tester, 10);
    expect(homeGps.listening, isTrue);
    navigator.currentState!.pop();
    await _frames(tester, 10);

    // The trip opens with the route the app uses: Home pauses under it.
    unawaited(
      navigator.currentState!.push(
        ActiveRideTransition(
          AcceptRide(
            initialStage: ActiveRideStage.onTrip,
            locationRepository: tripGps,
          ),
        ),
      ),
    );
    await _frames(tester, 20);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      homeGps.listening,
      isFalse,
      reason: 'one GPS stream during the trip, the trip\'s',
    );
    navigator.currentState!.pop();
    await _frames(tester, 20);
    expect(homeGps.listening, isTrue, reason: 'Home resumes after the trip');

    // A side-menu page covers Home the same way.
    tester
        .state<ScaffoldState>(
          find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null),
        )
        .openDrawer();
    await _frames(tester, 10);
    await tester.tap(find.text('Promotions'));
    await _frames(tester, 10);
    expect(find.byType(Promotions), findsOneWidget);
    expect(homeGps.listening, isFalse);
    navigator.currentState!.pop();
    await _frames(tester, 10);
    expect(homeGps.listening, isTrue);
    await _unmount(tester);
  });

  testWidgets('driver-r5-15: a failed first GPS fix still follows the GPS '
      'stream on the trip', (tester) async {
    _setUp(tester);
    final gps = _Gps(firstFixFails: true);
    addTearDown(gps.updates.close);
    await _pumpApp(
      tester,
      AcceptRide(initialStage: ActiveRideStage.onTrip, locationRepository: gps),
    );
    expect(
      gps.listening,
      isTrue,
      reason: 'before: no subscription until the app went to the background',
    );
    await _unmount(tester);
  });

  testWidgets('driver-r5-24: a Radar Match won under a sheet opens its trip '
      'when the sheet closes', (tester) async {
    _setUp(tester);
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
    final dispatch = _RadarDispatch();
    final navigator = await _pumpApp(
      tester,
      DriverHome(
        locationRepository: _NoGps(),
        dispatchRepository: dispatch,
        sessionController: DriverSessionController(),
      ),
    );
    await tester.tap(find.text('OFF'));
    await _until(
      tester,
      find.byKey(const ValueKey<String>('radar-match-first')),
      const Duration(seconds: 24),
    );
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    // The driver opens a sheet (Safety) while dispatch decides.
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byType(DriverHome)),
        builder: (_) => const Text('sheet'),
      ),
    );
    await _frames(tester, 10);
    dispatch.claims.single.complete(ClaimResult.success(_radarTrip('first')));
    await _frames(
      tester,
      120,
      250,
    ); // 30 s: past the open timer and the pick window
    expect(find.byType(AcceptRide), findsNothing, reason: 'the sheet is up');
    navigator.currentState!.pop();
    await _until(tester, find.byType(AcceptRide));
    expect(
      find.byType(AcceptRide),
      findsOneWidget,
      reason: 'before: the won trip was dropped',
    );
    await _unmount(tester);
  });

  testWidgets('driver-r5-31: the trip camera follows the car under a sheet; '
      'a full screen stops it', (tester) async {
    final camera = _Camera();
    _setUp(tester, map: camera);
    final gps = _Gps();
    addTearDown(gps.updates.close);
    final navigator = await _pumpApp(
      tester,
      AcceptRide(initialStage: ActiveRideStage.onTrip, locationRepository: gps),
    );
    Future<void> drive(double from) async {
      for (var i = 1; i <= 4; i++) {
        gps.updates.add(at(from + i * 15));
        await _frames(tester, 20);
      }
    }

    await drive(0);
    expect(camera.moves, greaterThan(0), reason: 'the camera follows');
    // The island's tools sheet opens over the visible map.
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byType(AcceptRide)),
        builder: (_) => const Text('tools'),
      ),
    );
    await _frames(tester, 10);
    camera.moves = 0;
    await drive(60);
    expect(
      camera.moves,
      greaterThan(0),
      reason: 'before: suspended under every sheet',
    );
    navigator.currentState!.pop();
    await _frames(tester, 10);
    // A full screen hides the map (driver-u59).
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covering')),
        ),
      ),
    );
    await _frames(tester, 20);
    camera.moves = 0;
    await drive(120);
    expect(camera.moves, 0);
    await _unmount(tester);
  });
}
