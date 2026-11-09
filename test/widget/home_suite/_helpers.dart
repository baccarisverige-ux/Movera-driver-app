// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
// Shared helpers for the files in this folder; the leading underscore keeps
// the test runner from treating this as a test file.
import 'package:movera/presentation/driver/deferred_screens.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/main.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// The refresh icon a Radar refresh pill draws (driver-u190: Home has none).
final refreshIcon = find.byWidgetPredicate(
  (w) =>
      w is SvgPicture &&
      w.bytesLoader is SvgAssetLoader &&
      (w.bytesLoader as SvgAssetLoader).assetName == AppAssets.offerRefresh,
);

Future<void> pumpHome(WidgetTester tester, Size size) async {
  IslandMessages.reset();
  ScheduledRideStore.reset();
  // A returning driver: the last position saved by an earlier session is
  // where Home's map opens (tests have no live GPS provider).
  DriverStartPosition.clearMemory();
  await (await SharedPreferences.getInstance()).setString(
    DriverStartPosition.key,
    '{"lat":59.3326,"lng":18.0649}',
  );
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(const MoveraApp());

  // Allow responsive layout and map placeholders to settle.
  await tester.pump(const Duration(milliseconds: 120));
  expect(find.byType(DriverHome), findsOneWidget);

  final startupException = tester.takeException();
  expect(startupException, isNull, reason: startupException?.toString());
}

/// Lets the top island finish its launch animation (small → full → on).
Future<void> wakeIsland(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 450));
  }
}

class FakeRadarSound implements RadarSoundPlayer {
  final calls = <String>[];
  @override
  Future<void> startLoop() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> prime() async {}
  @override
  Future<void> dispose() async {}
}

/// How far Home Radar's soft sweep turns in 200 ms, per second.
Future<double> wedgeTurnsPerSecond(
  WidgetTester tester, [
  Finder? within,
]) async {
  final wedge = find.byKey(const ValueKey<String>('radar-sweep-wedge'));
  double turn() =>
      (tester
                  .widget<CustomPaint>(
                    within == null
                        ? wedge
                        : find.descendant(of: within, matching: wedge),
                  )
                  .painter!
              as RadarWedgePainter)
          .turn;
  final start = turn();
  await tester.pump(const Duration(milliseconds: 200));
  return ((turn() - start) % 1) * 5;
}

void expectNoException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: exception?.toString());
}

Future<void> advanceAnimation(WidgetTester tester, Duration duration) async {
  await tester.pump();
  await tester.pump(duration);
}

Future<void> confirmShortTripIfAsked(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 220));
  final confirm = find.byKey(const ValueKey<String>('finish-soon-finish'));
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
  }
  // Each asynchronous journal write must be flushed before asserting navigation.
  for (
    var i = 0;
    i < 60 && find.byType(DriverRideCompleted).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pump(const Duration(milliseconds: 1100));
}

Future<void> tapArrived(WidgetTester tester) async {
  await middleActiveRideSheet(tester);
  final button = find.byKey(
    const ValueKey<String>('active-ride-arrived-button'),
  );
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 240));
  // Flush awaited durability and the frame that unlocks the next action.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> slideActiveRideAction(WidgetTester tester) async {
  await middleActiveRideSheet(tester);
  final action = find.byKey(
    const ValueKey<String>('active-ride-primary-action'),
  );
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await tester.pump(const Duration(milliseconds: 240));
  // Flush awaited durability and the frame that unlocks the next action.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> openPanel(WidgetTester tester) async {
  final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
  panel.controller!.open();
  await advanceAnimation(tester, const Duration(milliseconds: 520));
}

Future<void> closePanel(WidgetTester tester) async {
  final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
  panel.controller!.close();
  await advanceAnimation(tester, const Duration(milliseconds: 520));
}

/// With the Home sheet open and Radar on, the radar reads "Hold · OFF";
/// holding it one second asks "Go offline?" (Q19), and Go offline goes
/// offline and closes the sheet.
Future<void> holdRadarOff(WidgetTester tester) async {
  final radar = find.byKey(const ValueKey<String>('home-radar-hold-off'));
  expect(radar, findsOneWidget);
  final gesture = await tester.startGesture(tester.getCenter(radar));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await gesture.up();
  await advanceAnimation(tester, const Duration(milliseconds: 320));
  expect(find.text('Go offline?'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey<String>('go-offline-yes')));
  await advanceAnimation(tester, const Duration(milliseconds: 520));
}

/// No green or red wash on the Home sheet (R13-6).
void expectSheetNotTinted(WidgetTester tester) {
  const tints = <Color>[Color(0xFF1C6B45), MoveraRadarOrb.holdSheet];
  expect(
    find.byWidgetPredicate(
      (w) =>
          (w is ColoredBox && tints.contains(w.color)) ||
          (w is PhysicalShape && tints.contains(w.color)),
    ),
    findsNothing,
  );
}

/// Home's sheet body is the map (behind an AbsorbPointer) plus the dim.
AbsorbPointer homeMapAbsorber(SlidingUpPanel panel) =>
    (panel.body! as Stack).children.first as AbsorbPointer;

SlidingUpPanel activeRidePanel(WidgetTester tester) {
  return tester.widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel)).last;
}

Future<void> collapseActiveRideSheet(WidgetTester tester) async {
  activeRidePanel(tester).controller!.close();
  await advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> expandActiveRideSheet(WidgetTester tester) async {
  // Flush a still-running middle-sheet spring before asking for full details.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  activeRidePanel(tester).controller!.open();
  await advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

/// Middle sheet: rider and the slide action; the full sheet has neither.
Future<void> middleActiveRideSheet(WidgetTester tester) async {
  if (find
          .byKey(const ValueKey('active-ride-arrived-button'))
          .evaluate()
          .isNotEmpty ||
      find
          .byKey(const ValueKey('active-ride-primary-action'))
          .evaluate()
          .isNotEmpty) {
    return;
  }
  activeRidePanel(tester).controller!.animatePanelToSnapPoint();
  await advanceAnimation(tester, const Duration(milliseconds: 520));
  // The top cards then change with a short fade.
  await tester.pump(const Duration(milliseconds: 300));
}

void invokeTooltipAction(WidgetTester tester, String tooltip) {
  final tooltips = find.byTooltip(tooltip);
  expect(tooltips, findsWidgets);
  final taps = find.descendant(of: tooltips, matching: find.byType(InkWell));
  final action = tester
      .widgetList<InkWell>(taps)
      .firstWhere((widget) => widget.onTap != null);
  action.onTap!.call();
}

Future<void> seedCompletedRideForHistory() async {
  SharedPreferences.setMockInitialValues({});
  await PrefsTripHistoryRepository().archive(
    WaybillRecord(
      tripId: 'ride-001',
      statusLabel: 'Completed',
      issuedAt: DateTime.now(),
      fare: '126.75 kr',
      service: 'Comfort',
      riderName: 'Rider',
      pickup: 'Central Station',
      dropoff: 'Södermalm',
      source: 'Radar',
      driverName: 'Driver',
      vehicle: 'Vehicle',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    ),
  );
}

/// The common main() prelude of the former test/widget_test.dart.
void registerCommonSetUp() {
  // LT-4 (owner 2026-11-03): Wallet, Ride history and Chat load on open; a
  // deferred load does not finish inside a widget test's fake clock.
  setUpAll(loadDeferredScreens);
  setUp(() {
    CompletionJournal.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
}

const phoneSizes = <Size>[
  Size(320, 700),
  Size(375, 812),
  Size(390, 844),
  Size(430, 932),
];
