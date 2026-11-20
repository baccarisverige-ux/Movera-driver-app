import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner button 2026-11-20 "Change meter to app (Rec.)": when the server's
/// trip price changes after the start (a stop, a new route, an admin
/// change), the driver sees "Ändra taxametern till 240,00 kr" with the
/// server's new `fare` (never worked out on the phone), and it stays until
/// he taps OK. Example: Ali typed 215 kr, Sara adds a stop, app 240 kr.

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _view(WidgetTester tester, {Map<String, Object> prefs = const {}}) {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> _trip(
  int fareMinor, {
  String status = 'in_trip',
  int version = 5,
}) => {
  'tripId': 'meter-1',
  'version': version,
  'status': status,
  'fare': {'amountMinor': fareMinor, 'currency': 'SEK'},
};

Future<MemoryDriverRealtime> _open(
  WidgetTester tester, {
  ActiveRideStage stage = ActiveRideStage.onTrip,
  Map<String, Object> prefs = const {},
}) async {
  _view(tester, prefs: prefs);
  final realtime = MemoryDriverRealtime();
  addTearDown(realtime.dispose);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: AcceptRide(
          tripId: 'meter-1',
          initialStage: stage,
          activeRideRepository: MemoryActiveRideRepository(),
          realtime: realtime,
        ),
      ),
    ),
  );
  await _frames(tester);
  return realtime;
}

void _send(MemoryDriverRealtime realtime, Map<String, dynamic> trip) =>
    realtime.emit(
      tripId: 'meter-1',
      kind: DriverRealtimeKind.tripProjection,
      status: switch (trip['status']) {
        'in_trip' => TripStatus.inTrip,
        'cancelled_by_rider' => TripStatus.cancelledByRider,
        _ => TripStatus.driverToPickup,
      },
      projection: trip,
    );

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
    testWidgets('a new server price after the start asks the driver to '
        'change the taximeter, until OK ($language)', (tester) async {
      DriverAppTexts.language = language;
      final realtime = await _open(tester);
      final notice = find.byKey(const ValueKey('meter-change-notice'));
      _send(realtime, _trip(21500));
      await _frames(tester);
      expect(notice, findsNothing, reason: 'the price the meter got');
      _send(realtime, _trip(21500, version: 6));
      await _frames(tester);
      expect(notice, findsNothing, reason: 'same price, no notice');
      _send(realtime, _trip(24000, version: 7));
      await _frames(tester);
      expect(notice, findsOneWidget);
      final amount = const Money(minorUnits: 24000, currency: 'SEK').formatted;
      expect(find.text(tr.meterChangeToAppPrice(amount)), findsOneWidget);
      if (language == 'sv') {
        expect(
          tr.meterChangeToAppPrice(amount),
          'Ändra taxametern till $amount',
        );
      }
      // Stays: time passes, a tap beside it, a back press.
      await _frames(tester, 40);
      await tester.tapAt(const Offset(5, 5));
      await _frames(tester);
      await tester.binding.handlePopRoute();
      await _frames(tester);
      expect(notice, findsOneWidget, reason: 'stays until OK');
      await tester.tap(find.descendant(of: notice, matching: find.text(tr.ok)));
      await _frames(tester);
      expect(notice, findsNothing);
      // A later change: the notice comes back with the newest amount.
      _send(realtime, _trip(26000, version: 8));
      await _frames(tester);
      _send(realtime, _trip(26500, version: 9));
      await _frames(tester);
      expect(notice, findsOneWidget);
      final newest = const Money(minorUnits: 26500, currency: 'SEK').formatted;
      expect(find.text(tr.meterChangeToAppPrice(newest)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 2);
    });
  }

  testWidgets('before the start a new price shows no meter notice', (
    tester,
  ) async {
    final realtime = await _open(
      tester,
      stage: ActiveRideStage.headingToPickup,
    );
    _send(realtime, _trip(21500, status: 'driver_to_pickup'));
    await _frames(tester);
    _send(realtime, _trip(24000, status: 'driver_to_pickup', version: 6));
    await _frames(tester);
    expect(find.byKey(const ValueKey('meter-change-notice')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });

  final notice = find.byKey(const ValueKey('meter-change-notice'));
  const stored = '{"amountMinor":21500,"currency":"SEK"}';

  testWidgets('restore: a price changed while the app was closed shows '
      'the notice; OK stores it', (tester) async {
    final realtime = await _open(
      tester,
      prefs: {'movera.meter_fare.meter-1': stored},
    );
    _send(realtime, _trip(24000));
    await _frames(tester);
    expect(notice, findsOneWidget, reason: 'stored 215, server 240');
    await tester.tap(find.byKey(const ValueKey('meter-change-ok')));
    await _frames(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('movera.meter_fare.meter-1'), contains('24000'));
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });

  testWidgets('restore: the stored price equal to the server shows nothing', (
    tester,
  ) async {
    final realtime = await _open(
      tester,
      prefs: {'movera.meter_fare.meter-1': stored},
    );
    _send(realtime, _trip(21500));
    await _frames(tester);
    expect(notice, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });

  testWidgets('the trip ends while the notice is open: it closes', (
    tester,
  ) async {
    final realtime = await _open(tester);
    _send(realtime, _trip(21500));
    await _frames(tester);
    _send(realtime, _trip(24000, version: 6));
    await _frames(tester);
    expect(notice, findsOneWidget);
    _send(realtime, _trip(24000, status: 'cancelled_by_rider', version: 7));
    await _frames(tester, 30);
    expect(notice, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });

  testWidgets('the start projection with a new price: no notice (the meter '
      'is set at the start); a later change shows one', (tester) async {
    final realtime = await _open(
      tester,
      stage: ActiveRideStage.waitingForRider,
    );
    _send(realtime, _trip(21500, status: 'arrived'));
    await _frames(tester);
    _send(realtime, _trip(23000, version: 6));
    await _frames(tester, 30);
    expect(notice, findsNothing);
    _send(realtime, _trip(24000, version: 7));
    await _frames(tester);
    expect(notice, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });

  testWidgets('start, restart, new price: the notice shows', (tester) async {
    var realtime = await _open(tester, stage: ActiveRideStage.waitingForRider);
    _send(realtime, _trip(21500, status: 'arrived'));
    await _frames(tester);
    _send(realtime, _trip(21500, version: 6));
    await _frames(tester, 30);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('movera.meter_fare.meter-1'), contains('21500'));
    // The app is closed and opened again on the trip (prefs stay).
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
    realtime = MemoryDriverRealtime();
    addTearDown(realtime.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: AcceptRide(
            tripId: 'meter-1',
            initialStage: ActiveRideStage.onTrip,
            activeRideRepository: MemoryActiveRideRepository(),
            realtime: realtime,
          ),
        ),
      ),
    );
    await _frames(tester);
    _send(realtime, _trip(24000, version: 8));
    await _frames(tester);
    expect(notice, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 2);
  });
}
