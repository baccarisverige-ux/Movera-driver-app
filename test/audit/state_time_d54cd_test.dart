// Wave 5 D5.4 (parts c + d): state and time. Time cases also run under
// TZ=Europe/Stockholm and TZ=America/New_York.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/navigation.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// GPS the test feeds by hand, standing near the default drop-off.
class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
  DriverLocation fix() => DriverLocation(
    point: const GeoPoint(59.3279, 18.0615),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
}

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps [total] in 250 ms steps, so timers fire on time.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMilliseconds ~/ 250; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// A trip screen with the rider on board.
Future<_Loc> _pumpTrip(
  WidgetTester tester, {
  ActiveRideStage stage = ActiveRideStage.onTrip,
  bool paidByCash = false,
  DriverRealtime? realtime,
  bool destination = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final location = _Loc();
  addTearDown(location.updates.close);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: AcceptRide(
          tripId: 'cd-trip',
          fare: '250,00 kr',
          paidByCash: paidByCash,
          initialStage: stage,
          locationRepository: location,
          realtime: realtime,
          waitNow: () => tester.binding.clock.now(),
          activeRideRepository: MemoryActiveRideRepository(),
          waybillRepository: InMemoryWaybillRepository.instance,
          sessionController: DriverSessionController()..setOnline(true),
          destinationModeActive: destination,
          destinationAddress: destination ? 'Arlanda, Sigtuna' : null,
          destinationPosition: destination
              ? const LatLng(59.6519, 17.9186)
              : null,
        ),
      ),
    ),
  );
  await _settle(tester, 10);
  return location;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 10);
}

/// Drags the trip's slide action (start, then complete).
Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester
        .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .last
        .controller!
        .animatePanelToSnapPoint();
    await _settle(tester, 18);
  }
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _settle(tester, 6);
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

/// The onboarding wizard, pushed over a plain home.
Future<void> _pumpOnboarding(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Existing home')),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const AdditionalInfoNavigation()),
  );
  await tester.pumpAndSettle();
}

Future<void> _onboardingStep(WidgetTester tester, {bool back = false}) async {
  if (back) {
    await tester.tap(find.byTooltip('Back'));
  } else {
    await tester.tap(find.byType(CustomButton));
  }
  await tester.pumpAndSettle();
}

int _onboardingPage(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

/// A map whose camera moves are recorded; each waits [ack] when set, or
/// takes [latency] of test time.
class _Camera extends HeadlessMapPlatform {
  final List<CameraUpdate> moves = [];
  Completer<void>? ack;
  Duration latency = Duration.zero;
  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {
    moves.add(update);
    final hold = ack;
    if (hold != null) await hold.future;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  double latOf(CameraUpdate update) =>
      (((update.toJson() as List)[1] as Map)['target'] as List)[0] as double;
}

const _cameraStart = CameraPosition(target: LatLng(59, 18), zoom: 16);

/// A Google map on [_Camera]; returns its controller.
Future<GoogleMapController> _pumpMap(
  WidgetTester tester,
  _Camera camera,
) async {
  final original = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = camera;
  addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
  GoogleMapController? controller;
  await tester.pumpWidget(
    MaterialApp(
      home: GoogleMap(
        initialCameraPosition: _cameraStart,
        onMapCreated: (value) => controller = value,
      ),
    ),
  );
  await tester.pump();
  return controller!;
}

/// Home's GPS: the first one-shot fix answers, later ones wait (weak
/// signal) while the stream keeps delivering.
class _HomeGps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  int oneShots = 0;
  @override
  Future<DriverLocation> getCurrentPosition() => oneShots++ == 0
      ? Future.value(at(59.34, 18.07))
      : Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
  DriverLocation at(double lat, double lng) => DriverLocation(
    point: GeoPoint(lat, lng),
    measuredAt: DateTime.now(),
    accuracyMeters: 4,
  );
}

/// DriverHome on a headless map, with the demo extras off.
Future<void> _pumpHome(
  WidgetTester tester, {
  DriverLocationRepository? location,
  DispatchRepository? dispatch,
  DriverSessionController? session,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  final config = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = const DriverRuntimeConfig(
    externalRouting: false,
    liveMapTicker: false,
    reservationPopup: false,
    islandHint: false,
    simulatedArrival: false,
    skipAccountActivation: false,
  );
  addTearDown(() => DriverRuntimeConfig.current = config);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        // As in the app: Home hears routes covering it and leaving.
        navigatorObservers: [driverRouteObserver],
        home: DriverHome(
          locationRepository: location,
          dispatchRepository: dispatch,
          sessionController: session,
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Where Home's car marker is.
LatLng? _carOnHome(WidgetTester tester) {
  for (final map in tester.widgetList<GoogleMap>(find.byType(GoogleMap))) {
    for (final marker in map.markers) {
      if (marker.markerId.value == 'driver_location') return marker.position;
    }
  }
  return null;
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
  }) => Stream.multi((sink) {
    sink.addSync(offers);
    final sub = updates.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
  }, isBroadcast: true);
  List<RideOffer> offers = [_radarTrip('first'), _radarTrip('second')];
  final updates = StreamController<List<RideOffer>>.broadcast();
  void publish(List<RideOffer> next) => updates.add(offers = next);
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

/// Home online with both [_RadarDispatch] trips on its deck.
Future<void> _pumpDeck(
  WidgetTester tester,
  DispatchRepository dispatch, {
  DriverSessionController? session,
}) async {
  await _pumpHome(
    tester,
    location: _NoGps(),
    dispatch: dispatch,
    session: session,
  );
  await tester.tap(find.text('OFF'));
  await _pumpFor(tester, const Duration(seconds: 24));
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-first')),
    findsOneWidget,
  );
}

/// The Exclusive offer card on Home, if one is up.
final _exclusiveCard = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('exclusive-offer-card-'),
);

const _offerCard = ValueKey<String>('on-trip-radar-offer-button');
const _matchNext = ValueKey<String>('on-trip-radar-match-next');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    InMemoryWaybillRepository.instance.reset();
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() {
    WaybillStore.reset();
    RideCheckGate.set(false);
    DriverOfferRules.current = const DriverOfferRules();
  });

  testWidgets('driver-u76: no next-trip offer after the trip ended, even '
      'after a resume and a GPS fix', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    final location = await _pumpTrip(tester, realtime: realtime);
    realtime.emit(
      tripId: 'cd-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.cancelledByAdmin,
    );
    await _until(
      tester,
      find.byKey(const ValueKey<String>('trip-outcome-acknowledge')),
    );
    // The driver leaves the app and comes back; the sheet is still up.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    location.updates.add(location.fix());
    await _pumpFor(tester, const Duration(seconds: 20));
    expect(find.byKey(_offerCard), findsNothing);
    expect(ExclusiveAnswers.instance.missedInRow, 0);
    await _unmount(tester);
  });

  testWidgets('driver-u77: a card trip is archived as paid by Card', (
    tester,
  ) async {
    await _pumpTrip(tester, stage: ActiveRideStage.waitingForRider);
    await _slide(tester); // Start the trip.
    await _slide(tester); // Complete.
    final confirm = find.byKey(const ValueKey('finish-soon-finish'));
    if (confirm.evaluate().isNotEmpty) await tester.tap(confirm);
    await _until(tester, find.byType(DriverRideCompleted));
    await _settle(tester, 24);
    final row = (await PrefsTripHistoryRepository().list()).single;
    expect(row.paymentMethod, 'Card');
    await _unmount(tester);
  });

  testWidgets('driver-45: a next-trip offer hidden for a Ride check comes '
      'back with only the time it had left', (tester) async {
    await _pumpTrip(tester);
    await _until(tester, find.byKey(_offerCard));
    // 15 s offer: 6 s on screen, then a 4 s Ride check.
    await _pumpFor(tester, const Duration(seconds: 6));
    RideCheckGate.set(true);
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(find.byKey(_offerCard), findsNothing);
    RideCheckGate.set(false);
    await tester.pump();
    expect(find.byKey(_offerCard), findsOneWidget);
    // About 9 s were left; it runs out then, not 15 s later.
    await _pumpFor(tester, const Duration(seconds: 10));
    expect(find.byKey(_offerCard), findsNothing);
    // Owner 2026-10-27 (§6.7): missed while on a trip, so it never counts.
    expect(ExclusiveAnswers.instance.missedInRow, 0);
    await _unmount(tester);
  });

  testWidgets('driver-46: ending the trip early starts the secured next trip '
      'with destination mode on', (tester) async {
    await _pumpTrip(tester, destination: true);
    await _until(tester, find.byKey(_matchNext));
    await tester.ensureVisible(find.byKey(_matchNext));
    await tester.tap(find.byKey(_matchNext));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(WaybillStore.next, isNotNull);
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await _settle(tester, 6);
    await tester.tap(
      find.byKey(const ValueKey<String>('active-ride-cancel-option')),
    );
    await _settle(tester, 6);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
      ),
    );
    await _settle(tester, 6);
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-trip-cancellation')),
    );
    await _settle(tester, 24);
    final next = tester.widget<AcceptRide>(find.byType(AcceptRide));
    expect(next.tripId, isNot('cd-trip'));
    expect(next.destinationModeActive, isTrue);
    expect(next.destinationAddress, 'Arlanda, Sigtuna');
    await _unmount(tester);
  });

  testWidgets('driver-u171: a saved ticket keeps its category; older '
      'tickets still load', (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalSupportRepository.key: jsonEncode({
        'schemaVersion': 1,
        'tickets': [
          {'subject': 'Old ticket', 'preview': 'Saved before'},
        ],
        'draft': {
          'subject': 'Payout',
          'message': 'Missing',
          'category': 'Wallet & payments',
        },
      }),
    });
    Future<void> open() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: SupportInboxScreen(repository: LocalSupportRepository()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.text('Draft local ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft in demo'));
    await tester.pumpAndSettle();
    await open(); // read back from storage
    expect(find.text('Payout'), findsOneWidget);
    expect(find.text('Wallet & payments'), findsOneWidget);
    expect(find.text('Old ticket'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('driver-u159: a trip hidden with × stays hidden when the Live '
      'list is opened again', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final hidden = RadarHiddenTrips(); // Home's
    const card = ValueKey<String>('radar-offer-card-nearby-1');
    Future<void> open() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: RideRequests(hiddenTrips: hidden)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }

    await open();
    expect(find.byKey(card), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('radar-offer-dismiss-nearby-1')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await open(); // closed and opened again
    expect(find.byKey(card), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('radar-offer-card-nearby-2')),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('driver-u98: system back goes to the previous onboarding step', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await _onboardingStep(tester);
    await _onboardingStep(tester);
    expect(_onboardingPage(tester), 2);
    await tester.binding.handlePopRoute(); // Android back
    await tester.pumpAndSettle();
    expect(find.byType(AdditionalInfoNavigation), findsOneWidget);
    expect(_onboardingPage(tester), 1);
  });

  testWidgets(
    'driver-r3-8: Back to an onboarding step keeps what was entered',
    (tester) async {
      await _pumpOnboarding(tester);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Enter model year',
        ),
        '2019',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _onboardingStep(tester);
      await _onboardingStep(tester, back: true);
      expect(_onboardingPage(tester), 0);
      expect(find.text('2019'), findsOneWidget);
    },
  );

  testWidgets('driver-100: with reduced motion a fix that lands during the '
      'camera move is still sent', (tester) async {
    final camera = _Camera()..ack = Completer<void>();
    final port = GoogleDriverCameraPort(
      await _pumpMap(tester, camera),
      reducedMotion: true,
      initialPosition: _cameraStart,
    );
    final done = port.animate(
      const DriverCameraPose(GeoPoint(59.001, 18), 16, 0, 0),
    );
    await tester.pump();
    port.retarget(const DriverCameraPose(GeoPoint(59.002, 18), 16, 0, 0));
    camera.ack!.complete();
    camera.ack = null;
    await tester.pump();
    await done;
    expect(camera.moves.map(camera.latOf), [59.001, 59.002]);
    port.dispose();
  });

  testWidgets('driver-u177: a recenter flight lands in about 1 s even when '
      'each camera move takes 16 ms', (tester) async {
    final camera = _Camera()..latency = const Duration(milliseconds: 16);
    final port = GoogleDriverCameraPort(
      await _pumpMap(tester, camera),
      initialPosition: _cameraStart,
      clock: tester.binding.clock.now,
    );
    var landed = false;
    final started = tester.binding.clock.now();
    unawaited(
      port
          .animate(
            const DriverCameraPose(
              GeoPoint(59.004, 18.004),
              17,
              0,
              0,
              duration: Duration(milliseconds: 1000),
            ),
          )
          .then((_) => landed = true),
    );
    while (!landed &&
        tester.binding.clock.now().difference(started) <
            const Duration(seconds: 4)) {
      await tester.pump(const Duration(milliseconds: 4));
    }
    final flight = tester.binding.clock.now().difference(started);
    // 1 s of flight; before it ran about 2 s (only the 16 ms sleeps counted).
    expect(flight, lessThan(const Duration(milliseconds: 1400)));
    port.dispose();
  });

  testWidgets('driver-u119: Locate does not mute the running GPS stream '
      'while its one-shot fix waits', (tester) async {
    final gps = _HomeGps();
    addTearDown(gps.updates.close);
    await _pumpHome(tester, location: gps);
    expect(_carOnHome(tester), const LatLng(59.34, 18.07));
    await tester.tap(
      find.byKey(const ValueKey<String>('driver-location-zoom')),
    );
    await _settle(tester);
    gps.updates.add(gps.at(59.341, 18.071)); // the car moved on
    await _settle(tester);
    expect(_carOnHome(tester), const LatLng(59.341, 18.071));
    await _unmount(tester);
  });

  testWidgets('driver-u128: a pick window that ends during a failed Match '
      'claim still fades Match', (tester) async {
    final dispatch = _RadarDispatch();
    await _pumpDeck(tester, dispatch);
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    await _pumpFor(tester, const Duration(seconds: 20)); // window ends
    dispatch.claims.single.complete(const ClaimResult.networkError());
    await _settle(tester);
    final match = find.byKey(const ValueKey<String>('radar-match-first'));
    expect(tester.widget<FilledButton>(match).onPressed, isNull);
    await _unmount(tester);
  });

  testWidgets('driver-r3-15: a resume during a Match claim keeps the '
      'reservation\'s Exclusive step', (tester) async {
    final dispatch = _RadarDispatch();
    await _pumpDeck(tester, dispatch);
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    // The shade comes down and up while dispatch has not answered.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
    dispatch.publish(const []); // both trips leave Radar
    await _pumpFor(tester, const Duration(seconds: 5));
    expect(
      find.byKey(const ValueKey<String>('radar-offer-card-second')),
      findsNothing,
    );
    // The demo reservation's Exclusive step is about 50 s into the day.
    await _until(
      tester,
      find.byKey(
        const ValueKey<String>('exclusive-offer-card-$demoReservationId'),
      ),
      const Duration(seconds: 40),
    );
    expect(
      find.byKey(
        const ValueKey<String>('exclusive-offer-card-$demoReservationId'),
      ),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('driver-72: back on Home, the Exclusive offer keeps its time '
      'left instead of starting over', (tester) async {
    await _pumpHome(tester, location: _NoGps());
    await tester.tap(find.text('OFF'));
    await _until(tester, _exclusiveCard);
    await _pumpFor(tester, const Duration(seconds: 5));
    // Ride history (any route) covers Home and closes again.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering')),
      ),
    );
    await _settle(tester);
    navigator.pop();
    await _settle(tester);
    expect(_exclusiveCard, findsOneWidget);
    // About 9 s were left of its 15 s; it does not restart at 15.
    await _pumpFor(tester, const Duration(seconds: 12));
    expect(_exclusiveCard, findsNothing);
    await _unmount(tester);
  });

  testWidgets('driver-u115: an Exclusive offer under the open side menu '
      'does not count as missed', (tester) async {
    await _pumpHome(tester, location: _NoGps());
    await tester.tap(find.text('OFF'));
    await _until(tester, _exclusiveCard);
    final home = tester.state<ScaffoldState>(
      find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null),
    );
    home.openDrawer();
    await _pumpFor(tester, const Duration(seconds: 20)); // reads the menu
    home.closeDrawer();
    await _pumpFor(tester, const Duration(seconds: 3)); // its card slides down
    expect(ExclusiveAnswers.instance.missedInRow, 0);
    expect(_exclusiveCard, findsNothing, reason: 'its time ran out unseen');
    await _unmount(tester);
  });

  testWidgets('driver-u116: a trip matched from the full Radar list clears '
      'Home\'s deck', (tester) async {
    final dispatch = _RadarDispatch();
    final session = DriverSessionController();
    await _pumpDeck(tester, dispatch, session: session);
    await tester.tap(find.byKey(const ValueKey<String>('island-radar-offers')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    dispatch.publish([_radarTrip('second')]); // dispatch hands it to us
    dispatch.claims.single.complete(ClaimResult.success(_radarTrip('first')));
    await _until(tester, find.byType(AcceptRide));
    await _settle(tester);
    expect(
      IslandMessages.posted.map((m) => m.title),
      isNot(contains('Trip unavailable')),
    );
    // The trip ends; Home is on top again, without the pre-trip cards.
    session.endTrip();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('radar-home-deck')), findsNothing);
    await _unmount(tester);
  });

  test('driver-u148: "Yesterday" only for the day before, by the calendar', () {
    final now = DateTime(2026, 10, 21, 1);
    expect(noticeTimeLabel(DateTime(2026, 10, 19, 23), now), '2 days ago');
    expect(
      noticeTimeLabel(
        DateTime(2026, 10, 19, 23, 30),
        DateTime(2026, 10, 20, 23, 45),
      ),
      'Yesterday',
    );
  });

  test('driver-97: a time tomorrow says "tomorrow" on the spring DST day', () {
    // 28 Mar 2027 in Europe, 14 Mar 2027 in the US: a 23 h local day.
    for (final now in [DateTime(2027, 3, 28, 12), DateTime(2027, 3, 14, 12)]) {
      final until = DateTime(now.year, now.month, now.day + 1, 7);
      expect(scheduledTimeFrom(until, now), 'tomorrow 07:00');
    }
  });
}
