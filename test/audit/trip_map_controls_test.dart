// D3.4: the trip map controls and the GPS-less trip start (driver-u66,
// driver-u75).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No fix ever comes.
class _NoGps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('no fix');
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

bool _mapBlocked(WidgetTester tester) => tester
    .widgetList<AbsorbPointer>(find.byWidgetPredicate(
      (widget) =>
          widget is AbsorbPointer &&
          find
              .descendant(
                of: find.byWidget(widget),
                matching: find.byKey(
                  const ValueKey<String>('active-ride-throttled-map'),
                ),
              )
              .evaluate()
              .isNotEmpty,
    ))
    .last
    .absorbing;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(
      autoOffline: false,
      exclusiveWhileDriving: false,
    );
  });
  tearDown(() {
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  group('driver-u66: the stale-location label over the map buttons', () {
    testWidgets('stays on screen and leaves the map beside the buttons free',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final location = _NoGps();
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            locationRepository: location,
            initialStage: ActiveRideStage.onTrip,
          ),
        ),
      ));
      await _frames(tester, 20);
      final label =
          find.text('Demo offers — live location unavailable/stale');
      expect(label, findsOneWidget);
      final rect = tester.getRect(label);
      expect(rect.left, greaterThanOrEqualTo(0), reason: 'not cut at the left');
      expect(rect.right, lessThanOrEqualTo(320));

      // Touches beside the buttons and on the label go to the map.
      final safety = tester.getRect(
        find.byKey(const ValueKey<String>('active-ride-safety-button')),
      );
      for (final point in [
        Offset(safety.left - 60, safety.center.dy),
        Offset(rect.left + 8, rect.center.dy),
      ]) {
        final gesture = await tester.startGesture(point);
        await tester.pump();
        expect(_mapBlocked(tester), isFalse, reason: 'map touch at $point');
        await gesture.up();
        await tester.pump();
      }
      // The buttons still hold the map while touched.
      final gesture = await tester.startGesture(safety.center);
      await tester.pump();
      expect(_mapBlocked(tester), isTrue);
      await gesture.cancel();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 10, 100);
      await location.updates.close();
    });
  });
}
