import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// G7 live fix, checker round: an aged fix never makes "Framme" look
/// disabled (the tap asks a fresh one), and a stop arrival from the server
/// shows the stop-wait line on the screen from minute 1.
class _Gps implements DriverLocationRepository {
  final requests = <Completer<DriverLocation>>[];
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() {
    final request = Completer<DriverLocation>();
    requests.add(request);
    return request.future;
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

const _pickup = GeoPoint(59.3279, 18.0615);

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _middle(WidgetTester tester) async {
  tester
      .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
      .last
      .controller!
      .animatePanelToSnapPoint();
  await _frames(tester, 16);
}

void _view(WidgetTester tester) {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Color? _background(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.byKey(const ValueKey<String>('active-ride-arrived-button')),
    )
    .style
    ?.backgroundColor
    ?.resolve(<WidgetState>{});

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
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

  for (final language in ['sv', 'fr', 'en']) {
    testWidgets('an aged fix: Framme looks enabled, the tap asks a fresh '
        'one, then far says why ($language)', (tester) async {
      DriverAppTexts.language = language;
      _view(tester);
      final gps = _Gps();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) =>
              MaterialApp(home: AcceptRide(locationRepository: gps)),
        ),
      );
      await _frames(tester);
      gps.requests.single.complete(
        DriverLocation(
          point: _pickup,
          // Taken while fresh, then the parked phone sends nothing more
          // and it ages past its 30 s.
          measuredAt: DateTime.now().subtract(const Duration(seconds: 29)),
          accuracyMeters: 5,
        ),
      );
      await _frames(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await _middle(tester);
      expect(
        _background(tester),
        const Color(0xFF111614),
        reason: 'an aged fix alone must not look disabled',
      );
      final arrive = find.byKey(
        const ValueKey<String>('active-ride-arrived-button'),
      );
      await tester.ensureVisible(arrive);
      await tester.tap(arrive);
      await _frames(tester, 2);
      expect(gps.requests, hasLength(2), reason: 'a fresh fix is asked');
      gps.requests.last.complete(
        DriverLocation(
          point: const GeoPoint(59.3305, 18.0615),
          measuredAt: DateTime.now(),
          accuracyMeters: 5,
        ),
      );
      await _frames(tester);
      expect(
        find.byKey(const ValueKey('active-ride-panel-waitingForRider')),
        findsNothing,
      );
      expect(find.textContaining(tr.moveWithin100MOfPickup), findsWidgets);
      // A fresh fix far away: now it looks disabled.
      expect(_background(tester), const Color(0xFFEEEFF1));
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 2);
      await gps.updates.close();
    });
  }

  for (final language in ['sv', 'fr', 'en']) {
    testWidgets('a server stop arrival shows the stop-wait line on the '
        'screen from minute 1 ($language)', (tester) async {
      DriverAppTexts.language = language;
      _view(tester);
      final realtime = MemoryDriverRealtime();
      addTearDown(realtime.dispose);
      final arrivedAt = DateTime.now().toUtc().subtract(
        const Duration(seconds: 70),
      );
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(
              tripId: 'g7-ui',
              stopAddresses: const ['Odenplan'],
              initialStage: ActiveRideStage.onTrip,
              activeRideRepository: MemoryActiveRideRepository(),
              realtime: realtime,
            ),
          ),
        ),
      );
      await _frames(tester);
      realtime.emit(
        tripId: 'g7-ui',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.inTrip,
        projection: {
          'tripId': 'g7-ui',
          'version': 5,
          'status': 'in_trip',
          'terms': {
            'currency': 'SEK',
            'freeWaitMin': 5,
            'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
            'noShowAfterMin': 5,
            'noShowFee': {'amountMinor': 5000, 'currency': 'SEK'},
            'stopFreeWaitMin': 0,
            'stopWaitPerMin': {'amountMinor': 450, 'currency': 'SEK'},
          },
          'stops': [
            {
              'lat': 59.3429,
              'lng': 18.0498,
              'address': 'Odenplan',
              'arrivedAt': arrivedAt.toIso8601String(),
            },
          ],
        },
      );
      await _frames(tester);
      await _middle(tester);
      final chip = find.byKey(const ValueKey('active-ride-stop-wait-line'));
      expect(chip, findsOneWidget, reason: 'the stop-wait line is on screen');
      final line = find.descendant(
        of: chip,
        matching: find.textContaining(tr.paidWaitAtStopNumber(1)),
      );
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.textContaining('/min')),
        findsOneWidget,
        reason: 'with the stop price',
      );
      expect(
        tester.getTopLeft(line.first).dy,
        lessThan(844),
        reason: 'and inside the view',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 2);
    });
  }
}
