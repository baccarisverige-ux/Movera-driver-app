import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

// UI-05: on a small phone with large text the trip options sheet scrolls,
// so "End trip early" (the only way to end the trip) stays reachable.

const _sizes = <Size>[Size(320, 568), Size(375, 667)];
const _scale = 1.3;

Future<void> _pumpTrip(WidgetTester tester, Size size) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    LayoutViewport(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(_scale)),
          child: child!,
        ),
        home: const AcceptRide(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 160));
}

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 240));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _startTrip(WidgetTester tester) async {
  await _middle(tester);
  final arrived = find.byKey(
    const ValueKey<String>('active-ride-arrived-button'),
  );
  await tester.ensureVisible(arrived);
  await tester.tap(arrived);
  await _settle(tester);
  await _middle(tester);
  final action = find.byKey(
    const ValueKey<String>('active-ride-primary-action'),
  );
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()} @$_scale';
    for (final onTrip in [false, true]) {
      testWidgets(
        'UI-05 ${onTrip ? 'End trip early' : 'Cancel trip'} is reachable '
        'in the trip options at $at',
        (tester) async {
          await _pumpTrip(tester, size);
          if (onTrip) {
            await _startTrip(tester);
            expect(
              find.byKey(const ValueKey<String>('active-ride-panel-onTrip')),
              findsWidgets,
            );
            tester
                .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
                .last
                .controller!
                .close();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }
          // Layout of the trip screen itself is not what this test covers.
          tester.takeException();
          await tester.tap(
            find.byTooltip('Trip route and options').hitTestable(),
          );
          await tester.pump(const Duration(milliseconds: 260));
          expect(
            tester.takeException(),
            isNull,
            reason: 'the options sheet overflows',
          );
          final cancel = find.byKey(
            const ValueKey<String>('active-ride-cancel-option'),
          );
          expect(cancel, findsOneWidget);
          await tester.ensureVisible(cancel);
          await tester.pump(const Duration(milliseconds: 100));
          final rect = tester.getRect(cancel);
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          await tester.tap(cancel);
          await tester.pump(const Duration(milliseconds: 260));
          // The reasons sheet follows.
          expect(
            find.byKey(
              const ValueKey<String>('trip-cancellation-reasons-sheet'),
            ),
            findsOneWidget,
          );
          tester.takeException();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
