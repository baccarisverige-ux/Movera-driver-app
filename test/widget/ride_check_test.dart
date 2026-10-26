import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/location/demo_trip_drive.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// The default demo drop-off of [AcceptRide].
const _dropoff = GeoPoint(59.3326, 18.0649);

GeoPoint _north(GeoPoint from, double meters) =>
    GeoPoint(from.latitude + meters / 111195, from.longitude);

const _trip = SafetyAlertTrip(
  tripId: 'trip-1',
  riderName: 'Angelica',
  riderRating: 4.9,
  pickup: 'Odlarvägen 22',
  dropoff: 'T-Centralen, Stockholm',
  fare: '126 kr',
  category: 'Comfort',
  driverName: 'Movera Driver',
  vehicle: 'Volvo XC60',
  plate: 'ABC 123',
);

class _Gps implements DriverLocationRepository {
  _Gps(this.point);
  GeoPoint point;
  final _fixes = StreamController<DriverLocation>.broadcast();

  DriverLocation get _fix => DriverLocation(
    point: point,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  void emit() => _fixes.add(_fix);

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _fixes.stream;
}

class _Kit {
  _Kit({DateTime Function()? now, Stream<DateTime>? hardStops}) {
    services = RideCheckServices(
      alerts: alerts,
      log: log,
      now: now,
      hardStops: hardStops,
      launch: (uri) async {
        dialed.add(uri);
        return true;
      },
    );
  }

  final alerts = DemoSafetyAlertRepository();
  final log = MemoryRideCheckLog();
  final dialed = <Uri>[];
  late final RideCheckServices services;
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _reduced(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// The card alone, on a pushed route, as the trip screen shows it.
Future<RideCheckController> _card(
  WidgetTester tester,
  _Kit kit, {
  RideCheckTrigger trigger = RideCheckTrigger.longStop,
}) async {
  _phone(tester);
  final controller = RideCheckController(
    services: kit.services,
    tripId: 'trip-1',
    tripDetails: () => _trip,
  );
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => _reduced(child!),
      home: const Scaffold(body: Text('Home')),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: Text('Trip map')),
            Positioned.fill(
              child: ListenableBuilder(
                listenable: controller,
                builder: (_, _) => controller.active
                    ? RideCheckLayer(
                        controller: controller,
                        top: 10,
                        maxHeight: 820,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    controller.open(
      RideCheckDetector().demo(
        trigger,
        DateTime.now(),
        destination: 'T-Centralen, Stockholm',
      ),
      instant: true,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _end(WidgetTester tester, RideCheckController controller) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

final _cardFinder = find.byKey(const ValueKey('ride-check-card'));

Future<void> _mountRide(
  WidgetTester tester,
  AcceptRide ride, {
  bool reduced = true,
}) async {
  _phone(tester);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        builder: (context, child) => reduced ? _reduced(child!) : child!,
        home: ride,
      ),
    ),
  );
  await _frames(tester);
}

/// The simulated next-trip offer can cover the trip sheet; decline it.
Future<void> _denyOnTripOffer(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2400));
  final deny = find.byKey(const ValueKey<String>('on-trip-radar-deny'));
  if (deny.evaluate().isNotEmpty) {
    await tester.tap(deny);
    await _frames(tester);
  }
}

void main() {
  final previous = DriverRuntimeConfig.current;
  late GoogleMapsFlutterPlatform maps;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    WaybillStore.reset();
    maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    GoogleMapsFlutterPlatform.instance = maps;
    WaybillStore.reset();
  });

  group('triggers open the right card', () {
    const reasons = {
      RideCheckTrigger.longStop: 'Your car has stopped for 2 min',
      RideCheckTrigger.droppedFar: 'Your trip ended 4.2 km from T-Centralen',
      RideCheckTrigger.offRoute: 'You are 2.4 km off the route to T-Centralen',
      RideCheckTrigger.possibleCrash: 'A very hard stop was detected',
    };
    for (final trigger in RideCheckTrigger.values) {
      testWidgets('demo tools on the trip island: ${trigger.label}', (
        tester,
      ) async {
        SafetyAudioOption.debugEnabled =
            true; // owner decision 10: offered again
        addTearDown(() => SafetyAudioOption.debugEnabled = null);
        final kit = _Kit();
        await _mountRide(
          tester,
          AcceptRide(
            tripId: 'demo-trip',
            initialStage: ActiveRideStage.onTrip,
            locationRepository: _Gps(_north(_dropoff, 1000)),
            rideCheck: kit.services,
          ),
        );
        await tester.longPress(
          find.byKey(const ValueKey('island-morph-shell')),
        );
        await _frames(tester);
        final demo = find.byKey(ValueKey('ride-check-demo-${trigger.name}'));
        await tester.ensureVisible(demo);
        await tester.tap(demo);
        await _frames(tester, 30);

        expect(_cardFinder, findsOneWidget);
        expect(
          find.descendant(
            of: _cardFinder,
            matching: find.text('Is everything OK?'),
          ),
          findsOneWidget,
        );
        expect(
          find.text(reasons[trigger]!, findRichText: true),
          findsOneWidget,
        );
        for (final topic in RideCheckTopic.forDriver(trigger)) {
          expect(
            find.byKey(ValueKey('ride-check-row-${topic.name}')),
            findsOneWidget,
            reason: topic.label,
          );
        }
        // Exactly these rows, top to bottom, red ones first.
        final shown =
            RideCheckTopic.values
                .where(
                  (topic) => find
                      .byKey(ValueKey('ride-check-row-${topic.name}'))
                      .evaluate()
                      .isNotEmpty,
                )
                .toList()
              ..sort(
                (a, b) => tester
                    .getTopLeft(
                      find.byKey(ValueKey('ride-check-row-${a.name}')),
                    )
                    .dy
                    .compareTo(
                      tester
                          .getTopLeft(
                            find.byKey(ValueKey('ride-check-row-${b.name}')),
                          )
                          .dy,
                    ),
              );
        expect(shown, RideCheckTopic.forDriver(trigger));
        expect(
          find.byKey(const ValueKey('ride-check-call-112')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('ride-check-ok')), findsOneWidget);
        expect(
          find.text(
            'Record audio · saved only on this phone',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(find.text('Your answer is saved to this trip.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      });
    }

    testWidgets(
      'finished far: tapping Finish 4.2 km from the drop-off asks first',
      (tester) async {
        DriverRuntimeConfig.current = const DriverRuntimeConfig(
          simulatedArrival: false,
          externalRouting: false,
          skipAccountActivation: true,
          liveMapTicker: false,
          reservationPopup: false,
          islandHint: false,
        );
        final kit = _Kit();
        await _mountRide(
          tester,
          AcceptRide(
            tripId: 'far-trip',
            initialStage: ActiveRideStage.onTrip,
            locationRepository: _Gps(_north(_dropoff, 4200)),
            activeRideRepository: MemoryActiveRideRepository(),
            rideCheck: kit.services,
          ),
        );
        await _denyOnTripOffer(tester);
        tester
            .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
            .controller!
            .animatePanelToSnapPoint();
        await _frames(tester, 16);
        final action = find.byKey(
          const ValueKey<String>('active-ride-primary-action'),
        );
        await tester.ensureVisible(action);
        await tester.drag(action, const Offset(320, 0));
        await _frames(tester, 30);

        expect(find.byType(DriverRideCompleted), findsNothing);
        expect(
          find.text(
            'Your trip ended 4.2 km from T-Centralen',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ride-check-row-riderStopHere')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
        await _frames(tester, 40);
        expect(find.byType(DriverRideCompleted), findsOneWidget);
        final saved = await kit.log.forTrip('far-trip');
        expect(saved.single.trigger, RideCheckTrigger.droppedFar);
        expect(saved.single.answers.single.answer, "I'm OK");
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      },
    );

    testWidgets('demo arrival never asks about the drop-off distance', (
      tester,
    ) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: true,
        externalRouting: false,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
      );
      final kit = _Kit();
      await _mountRide(
        tester,
        AcceptRide(
          tripId: 'demo-far-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: _Gps(_north(_dropoff, 5000)),
          activeRideRepository: MemoryActiveRideRepository(),
          rideCheck: kit.services,
        ),
      );
      await _denyOnTripOffer(tester);
      tester
          .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .controller!
          .animatePanelToSnapPoint();
      await _frames(tester, 16);
      final action = find.byKey(
        const ValueKey<String>('active-ride-primary-action'),
      );
      await tester.ensureVisible(action);
      await tester.drag(action, const Offset(320, 0));
      await _frames(tester, 40);
      expect(_cardFinder, findsNothing);
      expect(find.byType(DriverRideCompleted), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });

    testWidgets('far drop-off demo trip: its drive ends far away and Finish '
        'opens RideCheck through the real check', (tester) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: true,
        externalRouting: false,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
      );
      final kit = _Kit();
      const offer = DemoRideCheckTrips.farDropoff;
      final tripId = tripOccurrenceId(offer.id);
      await _mountRide(
        tester,
        AcceptRide(
          tripId: tripId,
          riderName: offer.riderName,
          fare: offer.fareLabel,
          category: offer.category,
          pickupAddress: offer.pickup,
          dropoffAddress: offer.dropoff,
          pickupPosition: offer.pickupPosition.toLatLng(),
          dropoffPosition: offer.dropoffPosition.toLatLng(),
          activeRideRepository: MemoryActiveRideRepository(),
          rideCheck: kit.services,
        ),
      );
      Future<void> middle() async {
        tester
            .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
            .controller!
            .animatePanelToSnapPoint();
        await _frames(tester, 16);
      }

      Future<void> slide() async {
        final action = find.byKey(
          const ValueKey<String>('active-ride-primary-action'),
        );
        await tester.ensureVisible(action);
        await tester.drag(action, const Offset(320, 0));
        await _frames(tester, 30);
      }

      // A normal trip: arrive, start, drive.
      await middle();
      await tester.tap(
        find.byKey(const ValueKey<String>('active-ride-arrived-button')),
      );
      await _frames(tester);
      await middle();
      await slide();
      await _denyOnTripOffer(tester);
      for (var i = 0; i < DemoTripDrive.driveTicks + 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(_cardFinder, findsNothing);
      await middle();
      await slide();

      expect(find.byType(DriverRideCompleted), findsNothing);
      expect(_cardFinder, findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'Your trip ended \d+\.\d km from Kista Galleria'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
      await _frames(tester, 40);
      expect(find.byType(DriverRideCompleted), findsOneWidget);
      final saved = await kit.log.forTrip(tripId);
      expect(saved.single.trigger, RideCheckTrigger.droppedFar);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });

    testWidgets('long stop: no movement for more than 2 min mid-trip', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 15, 14, 30);
      final kit = _Kit(now: () => now);
      final gps = _Gps(_north(_dropoff, 1000));
      await _mountRide(
        tester,
        AcceptRide(
          tripId: 'stop-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: gps,
          rideCheck: kit.services,
        ),
      );
      now = now.add(const Duration(minutes: 1, seconds: 50));
      gps.emit();
      await _frames(tester);
      expect(_cardFinder, findsNothing);
      now = now.add(const Duration(minutes: 1, seconds: 10));
      gps.emit();
      await _frames(tester);
      expect(
        find.text('Your car has stopped for 3 min', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ride-check-row-carProblem')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });

    testWidgets(
      'no new offer while the card is open; it comes after the answer',
      (tester) async {
        final kit = _Kit();
        await _mountRide(
          tester,
          AcceptRide(
            tripId: 'gate-trip',
            initialStage: ActiveRideStage.onTrip,
            locationRepository: _Gps(_north(_dropoff, 1000)),
            rideCheck: kit.services,
          ),
        );
        final offer = find.byKey(const ValueKey<String>('on-trip-radar-deny'));
        await tester.longPress(
          find.byKey(const ValueKey('island-morph-shell')),
        );
        await _frames(tester);
        await tester.tap(
          find.byKey(const ValueKey('ride-check-demo-longStop')),
        );
        await _frames(tester, 10);
        expect(_cardFinder, findsOneWidget);
        expect(RideCheckGate.open, isTrue);
        // The next-trip offer is due 2.2 s into the trip: it waits.
        await tester.pump(const Duration(seconds: 3));
        await _frames(tester);
        expect(offer, findsNothing);
        await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
        await _frames(tester, 20);
        expect(_cardFinder, findsNothing);
        expect(RideCheckGate.open, isFalse);
        expect(offer, findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await _frames(tester);
      },
    );

    // driver-u86: a parked car still gets fixes (the native stream sends
    // one a second); a GPS that goes quiet is lost, not a long stop
    // (test/audit/trip_silent_gps_test.dart).
    testWidgets('long stop: a parked car is caught by the trip clock', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 15, 14, 30);
      final kit = _Kit(now: () => now);
      final gps = _Gps(_north(_dropoff, 1000));
      await _mountRide(
        tester,
        AcceptRide(
          tripId: 'quiet-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: gps,
          rideCheck: kit.services,
        ),
      );
      now = now.add(const Duration(minutes: 6));
      gps.emit();
      await tester.pump(const Duration(seconds: 21));
      await _frames(tester);
      expect(
        find.text('Your car has stopped for 6 min', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });

    testWidgets('possible crash: the hook opens the card at once', (
      tester,
    ) async {
      final hardStops = StreamController<DateTime>.broadcast();
      addTearDown(hardStops.close);
      final kit = _Kit(hardStops: hardStops.stream);
      await _mountRide(
        tester,
        AcceptRide(
          tripId: 'crash-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: _Gps(_north(_dropoff, 1000)),
          rideCheck: kit.services,
        ),
        reduced: false,
      );
      hardStops.add(DateTime.now());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // No pulsing pill first: straight to the card, Call 112 on top.
      expect(
        find.text('A very hard stop was detected', findRichText: true),
        findsOneWidget,
      );
      final call = tester.getRect(
        find.byKey(const ValueKey('ride-check-call-112')),
      );
      final row = tester.getRect(
        find.byKey(const ValueKey('ride-check-row-accident')),
      );
      expect(call.top, lessThan(row.top));
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  });

  testWidgets(
    'the island turns into the pulsing pill, then grows into the card',
    (tester) async {
      final kit = _Kit();
      await _mountRide(
        tester,
        AcceptRide(
          tripId: 'pill-trip',
          initialStage: ActiveRideStage.onTrip,
          locationRepository: _Gps(_north(_dropoff, 1000)),
          rideCheck: kit.services,
        ),
        reduced: false,
      );
      tester
          .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
          .onRideCheckDemo!(RideCheckTrigger.longStop);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('ride-check-pill')), findsOneWidget);
      expect(
        tester
            .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
            .rideCheck,
        isTrue,
      );
      expect(_cardFinder, findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_cardFinder, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      final card = tester.getRect(
        find.byKey(const ValueKey('ride-check-layer')),
      );
      expect(card.width, 390);
      await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_cardFinder, findsNothing);
      expect(
        tester
            .widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland))
            .rideCheck,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    },
  );

  testWidgets('the card cannot be dismissed without an answer', (tester) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    expect(_cardFinder, findsOneWidget);
    // Back does nothing.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_cardFinder, findsOneWidget);
    expect(find.text('Trip map'), findsOneWidget);
    // Tapping the map around it does nothing.
    await tester.tapAt(const Offset(200, 836));
    await tester.pumpAndSettle();
    // Swiping it away does nothing.
    await tester.fling(_cardFinder, const Offset(0, -500), 2500);
    await tester.pumpAndSettle();
    await tester.fling(_cardFinder, const Offset(400, 0), 2500);
    await tester.pumpAndSettle();
    expect(_cardFinder, findsOneWidget);
    expect(controller.active, isTrue);
    // No close button anywhere on it.
    final layer = find.byType(RideCheckLayer);
    expect(
      find.descendant(of: layer, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: layer, matching: find.byTooltip('Close')),
      findsNothing,
    );
    expect(
      find.descendant(of: layer, matching: find.text('Close')),
      findsNothing,
    );
    await _end(tester, controller);
  });

  testWidgets("I'm OK closes the card and saves the answer", (tester) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
    await tester.pumpAndSettle();
    expect(_cardFinder, findsNothing);
    final saved = kit.log.rows.single;
    expect(saved.answers.single.answer, "I'm OK");
    expect(saved.answeredAt, isNotNull);
    expect(kit.alerts.alerts, isEmpty);
    await _end(tester, controller);
  });

  testWidgets('a red row alerts Movera at once, with trip, driver and rider', (
    tester,
  ) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    await tester.tap(find.byKey(const ValueKey('ride-check-row-unsafe')));
    await tester.pumpAndSettle();
    expect(find.text('RIDE CHECK · UNSAFE'), findsOneWidget);
    expect(find.text('Are you in danger right now?'), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-check-alert-sent')), findsOneWidget);
    expect(
      find.text(
        // driver-49: the demo outbox reached no one at Movera.
        'Demo: alert kept on this phone only. No one at Movera was notified.'
        '\nCall 112 if you need help now.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ride-check-big-112')), findsOneWidget);
    final alert = kit.alerts.alerts.single;
    expect(alert.topic, 'I feel unsafe');
    expect(alert.recipients, containsAll(['admin', 'dispatch']));
    expect(alert.trip.riderName, 'Angelica');
    expect(alert.trip.driverName, 'Movera Driver');
    expect(alert.trip.dropoff, 'T-Centralen, Stockholm');
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    expect(_cardFinder, findsNothing);
    await _end(tester, controller);
  });

  testWidgets('Yes or Not sure on a follow-up updates the alert', (
    tester,
  ) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    await tester.tap(find.byKey(const ValueKey('ride-check-row-accident')));
    await tester.pumpAndSettle();
    expect(find.text('RIDE CHECK · ACCIDENT'), findsOneWidget);
    expect(kit.alerts.alerts.single.updates, 0);
    await tester.tap(
      find.byKey(const ValueKey('ride-check-option-Is anyone hurt?-Yes')),
    );
    await tester.pumpAndSettle();
    expect(kit.alerts.alerts.single.updates, 1);
    await tester.tap(
      find.byKey(
        const ValueKey('ride-check-option-Is the car in a safe place?-No'),
      ),
    );
    await tester.pumpAndSettle();
    expect(kit.alerts.alerts.single.updates, 1);
    final notSure = find.byKey(
      const ValueKey('ride-check-option-Is the other person OK?-Not sure'),
    );
    await tester.ensureVisible(notSure);
    await tester.tap(notSure);
    await tester.pumpAndSettle();
    expect(kit.alerts.alerts.single.updates, 2);
    expect(kit.alerts.alerts.single.answers.last.answer, 'Not sure');
    await tester.ensureVisible(find.byKey(const ValueKey('ride-check-done')));
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    expect(
      [for (final a in kit.log.rows.single.answers) a.answer],
      ['Accident or collision', 'Yes', 'No', 'Not sure'],
    );
    await _end(tester, controller);
  });

  testWidgets('Call 112 opens the dialer with tel:112; the driver calls', (
    tester,
  ) async {
    final kit = _Kit();
    final controller = await _card(
      tester,
      kit,
      trigger: RideCheckTrigger.possibleCrash,
    );
    await tester.tap(find.byKey(const ValueKey('ride-check-call-112')));
    await tester.pumpAndSettle();
    expect(kit.dialed, [Uri.parse('tel:112')]);
    expect(
      find.text('Your dialer opens with 112. Movera never calls for you.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ride-check-alert-sent')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ride-check-big-112')));
    await tester.pumpAndSettle();
    expect(kit.dialed, [Uri.parse('tel:112'), Uri.parse('tel:112')]);
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    expect(_cardFinder, findsNothing);
    expect(kit.log.rows.single.answers.first.answer, 'Call 112');
    await _end(tester, controller);
  });

  testWidgets('follow-ups: car problem, other rows and something else', (
    tester,
  ) async {
    final kit = _Kit();
    var controller = await _card(
      tester,
      kit,
      trigger: RideCheckTrigger.offRoute,
    );
    await tester.tap(find.byKey(const ValueKey('ride-check-row-carProblem')));
    await tester.pumpAndSettle();
    expect(find.text('Can you continue the trip?'), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-check-big-112')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    await _end(tester, controller);

    controller = await _card(tester, kit, trigger: RideCheckTrigger.droppedFar);
    await tester.tap(find.byKey(const ValueKey('ride-check-row-roadClosed')));
    await tester.pumpAndSettle();
    expect(find.text('Thanks, this is saved to the trip.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    await _end(tester, controller);

    controller = await _card(tester, kit, trigger: RideCheckTrigger.longStop);
    await tester.tap(find.byKey(const ValueKey('ride-check-row-hurt')));
    await tester.pumpAndSettle();
    expect(find.text('Who needs help?'), findsOneWidget);
    expect(find.text('The rider'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('ride-check-option-Who needs help?-The rider')),
    );
    await tester.pumpAndSettle();
    expect(kit.alerts.alerts.last.updates, 1);
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    await _end(tester, controller);

    controller = await _card(tester, kit, trigger: RideCheckTrigger.longStop);
    await tester.tap(
      find.byKey(const ValueKey('ride-check-row-somethingElse')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ride-check-note')),
      'Rider is sick',
    );
    await tester.tap(find.byKey(const ValueKey('ride-check-done')));
    await tester.pumpAndSettle();
    expect(kit.log.rows.last.answers.last.answer, 'Rider is sick');
    expect(kit.alerts.alerts, hasLength(1));
    await _end(tester, controller);
  });

  testWidgets('every icon on the card is a Solar icon', (tester) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    void solarOnly() {
      final layer = find.byType(RideCheckLayer);
      expect(
        find.descendant(of: layer, matching: find.byType(Icon)),
        findsNothing,
      );
      final svgs = tester.widgetList<SvgPicture>(
        find.descendant(of: layer, matching: find.byType(SvgPicture)),
      );
      expect(svgs, isNotEmpty);
      for (final svg in svgs) {
        final asset = (svg.bytesLoader as SvgAssetLoader).assetName;
        expect(asset, startsWith('assets/icons/solar_'));
      }
    }

    solarOnly();
    // Every row has its own Solar icon in a rounded square.
    for (final topic in RideCheckTopic.forDriver(RideCheckTrigger.longStop)) {
      final icon = tester.widget<SvgPicture>(
        find
            .descendant(
              of: find.byKey(ValueKey('ride-check-row-${topic.name}')),
              matching: find.byType(SvgPicture),
            )
            .first,
      );
      expect(
        (icon.bytesLoader as SvgAssetLoader).assetName,
        RideCheckStyle.topicIcon(topic),
      );
    }
    await tester.tap(find.byKey(const ValueKey('ride-check-row-accident')));
    await tester.pumpAndSettle();
    solarOnly();
    await _end(tester, controller);
  });

  testWidgets('ride details show the Ride check: time, trigger, answers', (
    tester,
  ) async {
    _phone(tester);
    final at = DateTime(2026, 10, 15, 14, 31);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'trip-1',
              riderName: 'Angelica Holm',
              whenLabel: '15/10/2026, 14:42',
              pickup: 'Odlarvägen 22',
              dropoff: 'T-Centralen',
              fare: '126 kr',
              category: 'Comfort',
            ),
            loadRideChecks: (tripId) async => [
              RideCheckRecord(
                id: 'rc-1',
                tripId: tripId,
                trigger: RideCheckTrigger.longStop,
                reason: 'Your car has stopped for 4 min · Odenplan',
                openedAt: at,
                answeredAt: at,
                alertSent: true,
                alertReachedMovera: true,
                answers: [
                  RideCheckAnswer(
                    question: RideCheckAnswer.first,
                    answer: 'Accident or collision',
                    at: at,
                  ),
                  RideCheckAnswer(
                    question: 'Is anyone hurt?',
                    answer: 'No',
                    at: at,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('ride-check-history'));
    await tester.ensureVisible(entry);
    expect(
      find.descendant(of: entry, matching: find.text('Ride check')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: entry, matching: find.text('14:31')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: entry,
        matching: find.text(
          'Long stop · Your car has stopped for 4 min · Odenplan',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: entry,
        matching: find.text('Answer: Accident or collision'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: entry, matching: find.text('Is anyone hurt? No')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: entry,
        matching: find.text('Movera safety team alerted'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ride details without a Ride check show no entry', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'trip-2',
              riderName: 'Maya',
              whenLabel: 'Today',
              pickup: 'A',
              dropoff: 'B',
              fare: '90 kr',
              category: 'Movera',
            ),
            loadRideChecks: (_) async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ride-check-history')), findsNothing);
  });

  testWidgets('Safety toolkit says Ride check is on and what it checks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SafetyToolKits())),
    );
    await tester.pumpAndSettle();
    final info = find.byKey(const ValueKey('ride-check-info'));
    expect(info, findsOneWidget);
    expect(
      find.descendant(of: info, matching: find.text('Ride check')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: info, matching: find.text('On')),
      findsOneWidget,
    );
    expect(find.textContaining('long stop'), findsOneWidget);
    expect(
      find.textContaining('unavailable', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('Safety preferences'));
    await tester.pumpAndSettle();
    final preference = find.byKey(const ValueKey('ride-check-preference'));
    expect(
      find.descendant(
        of: preference,
        matching: find.text('On · set by Movera for every trip'),
      ),
      findsOneWidget,
    );
    expect(find.text('RideCheck alerts'), findsNothing);
    expect(find.text('Unavailable without route monitoring'), findsNothing);
  });

  test('the app wires the demo alert outbox like the other demo services', () {
    final services = RideCheckServices.fallback;
    expect(services.alerts, isA<DemoSafetyAlertRepository>());
    expect(services.log, isA<PrefsRideCheckLog>());
    expect(services.rules.farDropMeters, 3000);
  });

  testWidgets('map position stays visible around the card', (tester) async {
    final kit = _Kit();
    final controller = await _card(tester, kit);
    final rect = tester.getRect(_cardFinder);
    expect(rect.left, greaterThanOrEqualTo(10));
    expect(rect.right, lessThanOrEqualTo(380));
    expect(rect.top, greaterThanOrEqualTo(10));
    expect(rect.bottom, lessThan(844));
    // Glass: dark, see-through, 0.5 px white contour, 34 px corners.
    expect(RideCheckStyle.glass.a, closeTo(.74, .01));
    expect(RideCheckStyle.radius, 34);
    await _end(tester, controller);
  });

  testWidgets('the demo tools sit on the trip island long-press sheet', (
    tester,
  ) async {
    final kit = _Kit();
    await _mountRide(
      tester,
      AcceptRide(
        tripId: 'tools-trip',
        locationRepository: _Gps(_north(_dropoff, 3000)),
        rideCheck: kit.services,
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('island-morph-shell')));
    await _frames(tester);
    expect(find.text('Ride check demo'), findsOneWidget);
    for (final trigger in RideCheckTrigger.values) {
      expect(
        find.byKey(ValueKey('ride-check-demo-${trigger.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('Demo: finished far from drop-off'), findsOneWidget);
    expect(find.text('Demo: long stop'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}
