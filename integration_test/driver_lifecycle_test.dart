import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

import 'headless_map_platform.dart';

/// Fresh fixes in central Stockholm. Never touches the host location stack,
/// so the test does not depend on D-Bus/GeoClue on Linux runners.
class _ScriptedLocation implements DriverLocationRepository {
  const _ScriptedLocation();

  DriverLocation get _fix => DriverLocation(
    point: const GeoPoint(59.3293, 18.0686),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(_fix);
}

/// Frontend lifecycle on the real [MoveraApp] composition root.
///
/// Demo services are the ones [MoveraApp] already injects. No backend.
/// The map platform is a Flutter stand-in so this can run on the headless
/// tester. It does not certify the native Google Map.

/// Pumps frames across [duration]. The integration binding waits in real
/// time, so one `pump` does not advance tickers the way a widget test does.
Future<void> _elapse(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  var left = duration;
  while (left > Duration.zero) {
    final slice = left < step ? left : step;
    await tester.pump(slice);
    left -= slice;
  }
}

/// The "OFF" glyph sits inside the collapsed sheet's hit region. The radar
/// ring above that sheet is the control that calls go-online.
Future<void> _goOnlineFromHome(WidgetTester tester) async {
  final orb = find.byKey(const ValueKey<String>('trip-radar-touch-target'));
  expect(orb, findsOneWidget);
  final rect = tester.getRect(orb);
  await tester.tapAt(Offset(rect.center.dx, rect.top + 12));
  await tester.pump();
}

Future<void> _tapArrived(WidgetTester tester) async {
  tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last).controller!.animatePanelToSnapPoint();
  await _elapse(tester, const Duration(milliseconds: 700));
  final button = find.byKey(const ValueKey<String>('active-ride-arrived-button'));
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _elapse(tester, const Duration(milliseconds: 300));
}

Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey<String>('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last).controller!.animatePanelToSnapPoint();
    await _elapse(tester, const Duration(milliseconds: 700));
  }
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _elapse(tester, const Duration(milliseconds: 300));
}

Future<void> _confirmShortTripIfAsked(WidgetTester tester) async {
  await _elapse(tester, const Duration(milliseconds: 250));
  final confirm = find.text('Confirm finish');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
  }
  for (var i = 0; i < 40 && find.byType(DriverRideCompleted).evaluate().isEmpty; i++) {
    await _elapse(tester, const Duration(milliseconds: 50));
  }
  await _elapse(tester, const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  DriverRuntimeConfig.current = const DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: false,
    skipAccountActivation: true,
    liveMapTicker: false,
    reservationPopup: false,
    islandHint: false,
  );

  setUp(() {
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    CompletionJournal.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('launch, accept, complete, and return home once', (tester) async {
    WaybillStore.reset();
    addTearDown(() async {
      WaybillStore.reset();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(const MoveraApp(locationRepository: _ScriptedLocation()));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _elapse(tester, const Duration(milliseconds: 200));
    expect(find.byType(DriverHome), findsOneWidget);
    expect(find.text('Demo mode — no account'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('headless-map')), findsWidgets);
    expect(tester.takeException(), isNull);

    await _goOnlineFromHome(tester);
    expect(
      find.text('Resolve saved trip recovery before going online.'),
      findsNothing,
    );
    await _elapse(tester, const Duration(milliseconds: 4500));
    expect(
      find.text('Accept'),
      findsWidgets,
      reason: 'The demo offer did not appear after going online.',
    );
    // The Exclusive offer's Accept is the blue radar in the dock.
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
    await _elapse(tester, const Duration(milliseconds: 520));
    expect(find.byType(AcceptRide), findsOneWidget);

    await _tapArrived(tester);
    await _slide(tester);
    await _slide(tester);
    await _confirmShortTripIfAsked(tester);
    expect(find.byType(DriverRideCompleted), findsOneWidget);

    await tester.tap(find.text('Done'));
    await _elapse(tester, const Duration(milliseconds: 500));
    expect(find.byType(DriverHome), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.byType(AcceptRide), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver cancel reason can be dismissed without ending the trip', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: AcceptRide(locationRepository: _ScriptedLocation())));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _elapse(tester, const Duration(milliseconds: 200));

    await _tapArrived(tester);
    await _slide(tester);
    expect(find.byKey(const ValueKey<String>('active-ride-panel-onTrip')), findsOneWidget);

    // The island keeps trip options reachable even while Radar covers the sheet.
    await _elapse(tester, const Duration(milliseconds: 700));
    await tester.tap(find.byTooltip('Trip route and options').hitTestable());
    await _elapse(tester, const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey<String>('active-ride-cancel-option')));
    await _elapse(tester, const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('trip-cancellation-reasons-sheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
      ),
    );
    await _elapse(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep trip'));
    await _elapse(tester, const Duration(milliseconds: 250));
    // Still on the trip (an on-trip Radar offer may lift over the sheet).
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(find.byType(DriverHome), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
