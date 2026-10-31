import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';
import '../audit/phase5/live_fixture.dart';

/// Driver group 5 on the trip screen (contract v0.18.7 `pickupWaiting`,
/// Rules decisions/driver-g5.md): the rider's first name and rating chip
/// (Q1), the terms from the trip (EUR in Paris), the server's ETA (Q4),
/// the no-show amount in the confirm (Q6), the rider-cancel island with
/// the driver's share (decision 7), a moved pickup (status item 4), the
/// Google Maps / Waze choice (status item 3), the trip settings button and
/// the cancel reasons before arrival (re-check 2026-10-30), and the 10 s
/// poll only while the stream is down (`pickupWaiting.follow`).

const _trip = 'g5-trip';

Map<String, dynamic> _projection({
  String status = 'driver_to_pickup',
  int version = 2,
  Map<String, dynamic>? rider = const {'firstName': 'Camille', 'rating': 4.87},
  Map<String, dynamic>? eta = const {
    'etaSeconds': 215,
    'distanceMeters': 1249,
    'target': 'pickup',
    'at': '2026-10-31T09:01:00Z',
    'source': 'osrm',
  },
  Map<String, dynamic>? pickup = const {
    'lat': 59.3279,
    'lng': 18.0615,
    'address': 'Odlarvägen 22',
  },
  Map<String, dynamic>? waiting,
  Map<String, dynamic>? cancellation,
}) => {
  'tripId': _trip,
  'version': version,
  'status': status,
  'acceptedAt': '2026-10-31T09:00:00Z',
  'pickup': ?pickup,
  'dropoff': {'lat': 59.3326, 'lng': 18.0649, 'address': 'T-Centralen'},
  'rider': ?rider,
  'terms': {
    'currency': 'EUR',
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 110, 'currency': 'EUR'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
    'noShowDriverSharePct': 80,
    'cancelRule': {
      'freeMin': 2,
      'type': 'fixed',
      'value': 350,
      'min': null,
      'max': null,
    },
    'cancelDriverSharePct': 80,
    'cancelAfterArrivedIsNoShow': true,
    'maxPickupMoveMeters': 200,
  },
  'eta': ?eta,
  'waiting': ?waiting,
  'cancellation': ?cancellation,
};

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpTrip(
  WidgetTester tester, {
  required MemoryDriverRealtime realtime,
  ActiveRideStage stage = ActiveRideStage.headingToPickup,
  int waitSeconds = 0,
  Future<bool> Function(Uri)? launch,
  bool home = false,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final trip = AcceptRide(
    tripId: _trip,
    riderName: 'Angelica',
    initialStage: stage,
    initialWaitSeconds: waitSeconds,
    activeRideRepository: MemoryActiveRideRepository(),
    realtime: realtime,
    launchExternalMap: launch,
  );
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: home
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => trip),
                      ),
                      child: const Text('Home'),
                    ),
                  ),
                ),
              )
            : trip,
      ),
    ),
  );
  if (home) {
    await tester.tap(find.text('Home'));
  }
  await _frames(tester);
}

AdaptiveTripIsland _island(WidgetTester tester) =>
    tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland));

Future<void> _middle(WidgetTester tester) async {
  tester
      .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .last
      .controller!
      .animatePanelToSnapPoint();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 520));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    IslandMessages.reset();
    NavigationAppSetting.reset();
    DriverOfferRules.current = const DriverOfferRules();
    WaitingTerms.active = WaitingRules.current.base;
  });
  tearDown(() {
    NavigationAppSetting.reset();
    DriverOfferRules.current = const DriverOfferRules();
    WaitingTerms.active = WaitingRules.current.base;
    LiveDriverServices.instance = null;
  });

  testWidgets(
    'Q1 + Q4 + terms: first name, rating chip, server ETA, EUR terms',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(tester, realtime: realtime);
      expect(find.text('Pick up Angelica'), findsWidgets);

      realtime.emit(
        tripId: _trip,
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.driverToPickup,
        projection: _projection(),
      );
      await _frames(tester);

      // The rider's first name everywhere the name is read.
      expect(find.text('Pick up Camille'), findsWidgets);
      expect(find.text('Pick up Angelica'), findsNothing);
      // The server's ETA on the island, not the app's own guess.
      final island = _island(tester);
      expect(island.eta, '4 min');
      expect(island.detail, 'Arrives in 4 min · 1.2 km');
      // The trip's own terms: a French trip is in euro.
      expect(WaitingTerms.active.perMinute.formatted, '1,10 €');
      expect(WaitingTerms.active.noShowFee.formatted, '6,15 €');
      expect(WaitingTerms.active.driverNoShowFee.formatted, '4,92 €');

      // The rating chip on the rider row, one decimal and a star.
      await _middle(tester);
      expect(
        find.byKey(const ValueKey<String>('active-ride-rider-rating')),
        findsOneWidget,
      );
      expect(find.text('4.9'), findsWidgets);
      expect(find.text('Camille'), findsWidgets);

      // The ETA tick every 30 s on a location event.
      realtime.emit(
        tripId: _trip,
        kind: DriverRealtimeKind.location,
        latitude: 59.33,
        longitude: 18.06,
        eta: const TripEta(
          etaSeconds: 95,
          distanceMeters: 480,
          target: 'pickup',
        ),
      );
      await _frames(tester);
      expect(_island(tester).eta, '2 min');
      expect(_island(tester).detail, 'Arrives in 2 min · 400 m');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Q1: no rating → no chip; the zone switch hides it too', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.driverToPickup,
      projection: _projection(rider: {'firstName': 'Rider'}),
    );
    await _frames(tester);
    await _middle(tester);
    expect(find.text('Rider'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('active-ride-rider-rating')),
      findsNothing,
    );

    DriverOfferRules.current = DriverOfferRules.current.withOffers({
      'offerCard': {'riderRating': false},
    });
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.driverToPickup,
      projection: _projection(version: 3),
    );
    await _frames(tester);
    expect(find.text('Camille'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('active-ride-rider-rating')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('status item 4: pickup_moved re-points the trip and the island', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.driverToPickup,
      projection: _projection(),
    );
    await _frames(tester);
    expect(_island(tester).address, 'Odlarvägen 22');
    expect(_island(tester).noticeKey, 0);

    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.pickupMoved,
      status: TripStatus.driverToPickup,
      projection: _projection(
        version: 3,
        pickup: {'lat': 59.3291, 'lng': 18.0633, 'address': 'Odlarvägen 40'},
      ),
    );
    await _frames(tester);
    final island = _island(tester);
    expect(island.address, 'Odlarvägen 40');
    expect(island.notice, 'Pickup moved');
    expect(island.noticeKey, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Q6: the no-show confirm says what the driver gets', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(
      tester,
      realtime: realtime,
      stage: ActiveRideStage.waitingForRider,
      waitSeconds: 6 * 60,
    );
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.arrived,
      projection: _projection(
        status: 'arrived',
        eta: null,
        waiting: {
          'arrivedAt': '2026-10-31T09:05:00Z',
          'freeUntil': '2026-10-31T09:10:00Z',
          'noShowAt': '2026-10-31T09:10:00Z',
          'chargedSeconds': 0,
          'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
          'noShowDriverShare': {'amountMinor': 492, 'currency': 'EUR'},
          'chargedSecondsNow': 60,
          'chargedSoFar': {'amountMinor': 110, 'currency': 'EUR'},
        },
      ),
    );
    await _frames(tester);
    // No ETA while arrived: the car is there.
    expect(_island(tester).eta, isNot('4 min'));

    // The island's waiting clock opens the pickup-wait sheet.
    _island(tester).onWait();
    await _frames(tester, 8);
    expect(
      find.byKey(const ValueKey<String>('waiting-time-sheet')),
      findsOneWidget,
    );
    // Q5 + Q2 on the waiting sheet: the server's running cost and the rule.
    expect(find.text('Waiting charged so far: 1,10 €'), findsOneWidget);
    final sheetList = find.descendant(
      of: find.byKey(const ValueKey<String>('waiting-time-sheet')),
      matching: find.byType(Scrollable),
    );
    final rule = find.byKey(
      const ValueKey<String>('waiting-cancel-after-arrived'),
    );
    await tester.scrollUntilVisible(rule, 120, scrollable: sheetList.first);
    expect(rule, findsOneWidget);
    expect(
      find.text(
        'Cancelling after the driver has arrived and the free waiting is '
        'over counts as a no-show',
      ),
      findsOneWidget,
    );
    final noShow = find.byKey(const ValueKey('waiting-no-show-cancel'));
    await tester.scrollUntilVisible(noShow, 120, scrollable: sheetList.first);
    await tester.tap(noShow);
    await _frames(tester, 8);
    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-confirmation')),
      findsOneWidget,
    );
    expect(find.text('Mark as no-show? You get 4,92 €'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'decision 7 + Q6: rider cancelled after arrival → island with the share',
    (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(
        tester,
        realtime: realtime,
        stage: ActiveRideStage.waitingForRider,
        waitSeconds: 6 * 60,
        home: true,
      );
      expect(find.byType(AcceptRide), findsOneWidget);
      realtime.emit(
        tripId: _trip,
        kind: DriverRealtimeKind.riderCancelled,
        status: TripStatus.cancelledByRider,
        // The rider's fee (never the driver's money) on the old field.
        cancelFee: Money(minorUnits: 615, currency: 'EUR'),
        projection: _projection(
          status: 'cancelled_by_rider',
          eta: null,
          cancellation: {
            'actor': 'rider',
            'reasonCode': 'plans_changed',
            'at': '2026-10-31T09:12:00Z',
            'fee': {'amountMinor': 615, 'currency': 'EUR'},
            'feeStatus': 'paid',
            'feeKind': 'no_show',
            'driverShare': {'amountMinor': 492, 'currency': 'EUR'},
          },
        ),
      );
      await _frames(tester, 30);
      expect(find.byType(AcceptRide), findsNothing);
      final message = IslandMessages.take();
      expect(message?.title, 'Rider cancelled · +4,92 €');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('re-check: "Rider not at pickup" only once at the pickup', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    tester.takeException();
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await tester.pump(const Duration(milliseconds: 260));
    final cancel = find.byKey(
      const ValueKey<String>('active-ride-cancel-option'),
    );
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-reasons-sheet')),
      findsOneWidget,
    );
    expect(find.text('Rider asked to cancel'), findsOneWidget);
    expect(find.text('Rider not at pickup'), findsNothing);
    tester.takeException();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('re-check: the sheet button opens the trip settings', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    await _middle(tester);
    await tester.tap(find.byTooltip('Trip settings'));
    await _frames(tester, 8);
    expect(find.byType(TripSettings), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('trip-settings-waze')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('status item 3: Waze chosen → the map button opens Waze', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await NavigationAppSetting.save(NavigationApp.waze, SettingsRepository());
    Uri? opened;
    await _pumpTrip(
      tester,
      realtime: realtime,
      launch: (uri) async {
        opened = uri;
        return true;
      },
    );
    final button = find.byKey(
      const ValueKey<String>('active-ride-navigation-button'),
    );
    expect(
      tester.widget<MapControlButton>(button).tooltip,
      'Navigate with Waze',
    );
    tester.widget<MapControlButton>(button).onTap();
    await _frames(tester, 4);
    expect(opened?.host, 'waze.com');
    expect(opened?.queryParameters['navigate'], 'yes');

    // Back to Google Maps: the same button, the Google Maps link.
    await NavigationAppSetting.save(
      NavigationApp.googleMaps,
      SettingsRepository(),
    );
    await _frames(tester, 4);
    expect(
      tester.widget<MapControlButton>(button).tooltip,
      'Navigate with Google Maps',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('status item 3: Trip settings saves the choice', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: TripSettings(repository: SettingsRepository())),
    );
    await _frames(tester, 4);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('trip-settings-waze')));
    await _frames(tester, 4);
    expect(NavigationAppSetting.current.value, NavigationApp.waze);
    await SettingsRepository.settle();
    final saved = (await SharedPreferences.getInstance()).getString(
      '${SettingsRepository.sectionPrefix}trip',
    );
    expect(saved, contains('"navigationApp":"waze"'));
    NavigationAppSetting.reset();
    expect(
      await NavigationAppSetting.load(SettingsRepository()),
      NavigationApp.waze,
    );
  });

  testWidgets('checker M1: a reservation reached 8 min early → no-show only '
      'from waiting.noShowAt', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    // 10 min on the phone's own count: the local rule (5 + 5) would allow
    // the no-show, the server's moments do not (booked time + 5 min).
    await _pumpTrip(
      tester,
      realtime: realtime,
      stage: ActiveRideStage.waitingForRider,
      waitSeconds: 10 * 60,
    );
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.arrived,
      projection: _projection(
        status: 'arrived',
        eta: null,
        waiting: {
          'arrivedAt': '2026-10-31T09:52:00Z',
          // Booked 10:00, 5 free minutes after it.
          'freeUntil': '2026-10-31T10:05:00Z',
          'noShowAt': '2026-10-31T10:05:00Z',
          'chargedSeconds': 0,
          'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
          'noShowDriverShare': {'amountMinor': 492, 'currency': 'EUR'},
        },
      ),
    );
    await _frames(tester);
    expect(WaitingTerms.active.freeSeconds, 13 * 60);
    expect(WaitingTerms.active.noShowSeconds, 13 * 60);
    _island(tester).onWait();
    await _frames(tester, 8);
    expect(find.byKey(const ValueKey('waiting-no-show-cancel')), findsNothing);
    // Still in the free minutes on the island too.
    expect(_island(tester).paidWait, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('checker M2: a stale ETA without a local route says '
      '"last known"', (tester) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    realtime.emit(
      tripId: _trip,
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.driverToPickup,
      projection: _projection(
        eta: {
          'etaSeconds': 215,
          'distanceMeters': 1249,
          'target': 'pickup',
          'at': '2026-10-31T09:01:00Z',
          'source': 'stale',
        },
      ),
    );
    await _frames(tester);
    expect(_island(tester).eta, 'Last known: 4 min');
    expect(_island(tester).detail, 'Last known: Arrives in 4 min · 1.2 km');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (name, cancellation, title)
      in <(String, Map<String, dynamic>?, String)>[
        // Contract 0.18.6: no cancellation on the projection at all.
        ('0.18.6 server', null, 'Rider cancelled'),
        (
          'no driverShare',
          {
            'actor': 'rider',
            'reasonCode': 'plans_changed',
            'at': '2026-10-31T09:12:00Z',
            'fee': {'amountMinor': 615, 'currency': 'EUR'},
            'feeKind': 'no_show',
          },
          'Rider cancelled · No-show fee',
        ),
      ]) {
    testWidgets('checker M3: the rider\'s fee is never the driver\'s money '
        '($name)', (tester) async {
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      await _pumpTrip(
        tester,
        realtime: realtime,
        stage: ActiveRideStage.waitingForRider,
        waitSeconds: 6 * 60,
        home: true,
      );
      final projection = _projection(status: 'cancelled_by_rider', eta: null);
      if (cancellation != null) projection['cancellation'] = cancellation;
      realtime.emit(
        tripId: _trip,
        kind: DriverRealtimeKind.riderCancelled,
        status: TripStatus.cancelledByRider,
        cancelFee: Money(minorUnits: 615, currency: 'EUR'),
        projection: projection,
      );
      await _frames(tester, 30);
      final message = IslandMessages.take();
      expect(message?.title, title);
      expect(message?.title, isNot(contains('6,15')));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('checker M4: the map button has a neutral icon and the name', (
    tester,
  ) async {
    final realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await _pumpTrip(tester, realtime: realtime);
    final label = find.byKey(
      const ValueKey<String>('active-ride-navigation-label'),
    );
    expect(tester.widget<Text>(label).data, 'Google Maps');
    await NavigationAppSetting.save(NavigationApp.waze, SettingsRepository());
    await _frames(tester, 4);
    expect(tester.widget<Text>(label).data, 'Waze');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('active-ride-navigation-button')),
        matching: find.byIcon(Icons.navigation_outlined),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('follow: poll every 10 s only while the stream is down', (
    tester,
  ) async {
    var reads = 0;
    final live = installLive(
      answer: (http.Request request) {
        if (request.url.path == '/api/v1/trips/$_trip') {
          reads++;
          return _projection(
            eta: {
              'etaSeconds': 400,
              'distanceMeters': 3449,
              'target': 'pickup',
              'at': '2026-10-31T09:01:00Z',
              'source': 'estimate',
            },
          );
        }
        // The event stream never opens (503): the stream is down.
        return null;
      },
    );
    final realtime = live.realtime();
    addTearDown(() async {
      LiveDriverServices.instance = null;
      realtime.dispose();
      await live.dispose();
    });
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: AcceptRide(
            tripId: _trip,
            activeRideRepository: MemoryActiveRideRepository(),
            realtime: realtime,
            locationRepository: FixedGps(),
          ),
        ),
      ),
    );
    await _frames(tester);
    // The first read is the stream's "what is known" check, not a poll.
    final before = reads;
    await tester.pump(const Duration(seconds: 9));
    await _frames(tester, 2);
    expect(reads, before, reason: 'never faster than 10 s');
    await tester.pump(const Duration(seconds: 1));
    await _frames(tester, 4);
    expect(reads, before + 1);
    expect(_island(tester).eta, '7 min');
    expect(_island(tester).detail, 'Arrives in 7 min · 3.4 km');
    await tester.pump(const Duration(seconds: 10));
    await _frames(tester, 4);
    expect(reads, before + 2);
    expect(
      jsonEncode(live.trips.projectionOf(_trip)?['eta']),
      contains('3449'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
