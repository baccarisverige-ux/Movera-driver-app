// Split from test/widget_test.dart (step 54, Rule 25: no file over 1500 lines).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import '_helpers.dart';

void main() {
  registerCommonSetUp();

  testWidgets('Destination Mode: confirm shows it on the island, no popup card', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final openDestination = find.byKey(
      const ValueKey<String>('destination-mode-open'),
    );
    expect(openDestination, findsOneWidget);
    final destinationControl = tester.widget<InkWell>(openDestination);
    expect(destinationControl.onTap, isNotNull);
    destinationControl.onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));

    expect(find.byType(DriverDestinationPicker), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('destination-search')),
      findsOneWidget,
    );
    expect(find.byType(CustomGoogleMap), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-result-solna')),
      findsOneWidget,
    );
    expectNoException(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('destination-result-solna')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    // Choose-destination step: one option, then Confirm.
    expect(find.text('Fastest route to your destination'), findsOneWidget);
    expect(
      find.textContaining('those heading your way are marked'),
      findsOneWidget,
    );
    expect(find.textContaining('Arrive by '), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('destination-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.byType(DriverHome), findsOneWidget);
    // No popup card on the map.
    expect(find.text('On your way'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-mode-home-tab')),
      findsNothing,
    );
    // R13-9: no white popup on the map; the island shows the destination.
    expect(
      find.byKey(const ValueKey<String>('destination-mode-bar')),
      findsNothing,
    );
    expect(find.textContaining('Destination mode until '), findsNothing);
    expect(find.text('STARTING'), findsOneWidget);

    final map = tester.widget<CustomGoogleMap>(
      find.byType(CustomGoogleMap).first,
    );
    // Routing is real-road only. In widget tests there is no live GPS/provider,
    // so Destination Mode must not invent a straight two-point route.
    expect(
      map.polylines!.any(
        (polyline) => polyline.polylineId.value == 'destination_mode_route',
      ),
      isFalse,
    );
    // Exactly one destination pin and no offer stops in Destination mode.
    expect(
      map.markers!.where(
        (marker) => marker.markerId.value == 'destination_mode_target',
      ),
      hasLength(1),
    );
    expect(
      map.markers!.where((m) => m.markerId.value.startsWith('radar_')),
      isEmpty,
    );

    await tester.pump(const Duration(milliseconds: 1550));
    expect(find.text('LIVE'), findsOneWidget);
    expectNoException(tester);

    // Once the online notices pass, the island shows the destination.
    final face = find.byKey(const ValueKey<String>('island-destination-face'));
    for (var i = 0; i < 24 && face.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(face, findsOneWidget);
    expect(
      find.descendant(of: face, matching: find.textContaining('Solna Torg')),
      findsOneWidget,
    );
    expect(find.text('On your way'), findsNothing);

    // Tap the island: details with "Turn off destination".
    tester
        .widget<InkWell>(
          find.byKey(const ValueKey<String>('last-trip-launcher')),
        )
        .onTap!
        .call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('Turn off destination'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('destination-mode-end')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(
      find.byKey(const ValueKey<String>('island-destination-face')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('destination-mode-bar')),
      findsNothing,
    );
    expect(find.text('LIVE'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('Home destination control does not block the map area', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    final destinationControl = find.byKey(
      const ValueKey<String>('destination-mode-open'),
    );
    expect(destinationControl, findsOneWidget);

    final interceptor = find.ancestor(
      of: destinationControl,
      matching: find.byType(PointerInterceptor),
    );
    expect(interceptor, findsOneWidget);

    // One black island, centred, leaving both map corners free.
    final islandRect = tester.getRect(interceptor);
    expect(islandRect.width, lessThanOrEqualTo(250));
    expect(islandRect.height, lessThan(70));
    expect(islandRect.center.dx, closeTo(375 / 2, 2));
    expectNoException(tester);
  });

  testWidgets('Destination picker remains layout-safe on narrow phone', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(const MaterialApp(home: DriverDestinationPicker()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Choose one address'), findsOneWidget);
    expect(find.text('Suggested addresses'), findsOneWidget);
    expect(find.byType(CustomGoogleMap), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('destination-search')),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  // Q2 (owner 2026-11-07): destination mode hides no trip; the ones on the
  // way carry the "On your way" badge.
  testWidgets('Destination radar shows every trip, same-way ones with the '
      '"On your way" badge', (WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Tall enough for all three cards at once.
    await tester.binding.setSurfaceSize(const Size(375, 1600));
    await tester.pumpWidget(
      const MaterialApp(
        home: RideRequests(
          destinationModeActive: true,
          destinationAddress: 'Solna Torg, Solna',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey<String>('radar-destination-filter')),
      findsOneWidget,
    );
    expect(find.textContaining('Destination: Solna Torg'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('nearby-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('nearby-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('nearby-3')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('radar-offer-on-your-way-nearby-1')),
      findsNothing,
    );
    for (final id in ['nearby-2', 'nearby-3']) {
      expect(
        find.byKey(ValueKey<String>('radar-offer-on-your-way-$id')),
        findsOneWidget,
      );
    }
    expectNoException(tester);
  });

  testWidgets('Trip radar online and Go offline sheet flow is safe', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester, const Size(375, 812));

    expect(find.text('OFF'), findsOneWidget);
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 1550));

    expect(find.text('LIVE'), findsOneWidget);
    // R13-6: going online never tints the Home sheet.
    expectSheetNotTinted(tester);
    expectNoException(tester);

    await openPanel(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // Same radar, now "Hold · OFF · Go offline".
    expect(find.text('Hold'), findsOneWidget);
    expect(find.text('Go offline'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    // A short tap does nothing.
    await tester.tap(find.byKey(const ValueKey<String>('home-radar-hold-off')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hold'), findsOneWidget);

    await holdRadarOff(tester);
    expect(find.text('Tap to scan'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    // Holding the radar still goes offline; the sheet stays white.
    expectSheetNotTinted(tester);
    final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
    expect(
      panel.controller!.panelPosition,
      closeTo(0, 0.02),
      reason: 'Going offline brings the sheet down by itself',
    );
    expectNoException(tester);
  });
}
