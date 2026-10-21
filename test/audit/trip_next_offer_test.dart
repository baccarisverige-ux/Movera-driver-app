// D3.4 regressions: next-trip offers on the trip screen (driver-u60,
// driver-u62, driver-u80).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class _Loc implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => _fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

DriverLocation _fix() => DriverLocation(
  point: const GeoPoint(59.3279, 18.0615),
  measuredAt: DateTime.now(),
  accuracyMeters: 5,
);

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var i = 0; i < total.inMilliseconds ~/ 250; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpTrip(
  WidgetTester tester,
  _Loc location, {
  GlobalKey<NavigatorState>? navigator,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [driverRouteObserver],
      home: AcceptRide(
        locationRepository: location,
        initialStage: ActiveRideStage.onTrip,
        waitNow: () => tester.binding.clock.now(),
      ),
    ),
  ));
  await _settle(tester, 10);
}

Future<void> _unmount(WidgetTester tester, _Loc location) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 10);
  await location.updates.close();
}

/// The id of the next-trip offer on screen, from its countdown key.
String? _offerId(WidgetTester tester) {
  for (final element in find.byType(TweenAnimationBuilder<double>).evaluate()) {
    final key = element.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('on-trip-offer-')) {
      return key.value.substring('on-trip-offer-'.length);
    }
  }
  return null;
}

const _offerCard = ValueKey<String>('on-trip-radar-offer-button');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() {
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  group('driver-u60: each next-trip offer has its own trip id', () {
    testWidgets('a re-offered next trip after a cancel is a new trip',
        (tester) async {
      final location = _Loc();
      await _pumpTrip(tester, location);
      await tester.pump(const Duration(milliseconds: 2600));
      final first = _offerId(tester);
      expect(first, isNotNull);
      final match = find.byKey(const ValueKey('on-trip-radar-match-next'));
      await tester.ensureVisible(match);
      await tester.tap(match);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(WaybillStore.next?.tripId, first);

      // Cancel the secured next trip: it is archived under its id.
      tester
          .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .controller!
          .open();
      await _settle(tester, 20);
      await tester.tap(find.byKey(const ValueKey('next-trip-more')));
      await _settle(tester, 4);
      await tester.tap(find.byKey(const ValueKey('next-trip-cancel-option')));
      await _settle(tester, 4);
      await tester.tap(
        find.byKey(
          const ValueKey('trip-cancel-reason-next_trip_current_running_late'),
        ),
      );
      await _settle(tester, 4);
      await tester.tap(find.byKey(const ValueKey('confirm-trip-cancellation')));
      await _settle(tester, 4);
      expect(WaybillStore.next, isNull);

      // Radar scans again; the next fix brings another offer.
      location.updates.add(_fix());
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byKey(_offerCard), findsOneWidget);
      final second = _offerId(tester);
      expect(second, isNotNull);
      expect(second, isNot(first),
          reason: 'a cancelled and a later next trip never share an id');
      await _unmount(tester, location);
    });
  });

  group('driver-u62: the on-trip offer card is a map overlay', () {
    testWidgets('it sits in a PointerInterceptor and blocks map gestures',
        (tester) async {
      final location = _Loc();
      await _pumpTrip(tester, location);
      await tester.pump(const Duration(milliseconds: 2600));
      final card = find.byKey(_offerCard);
      expect(card, findsOneWidget);
      expect(
        find.ancestor(of: card, matching: find.byType(PointerInterceptor)),
        findsOneWidget,
        reason: 'web: the map element must not take the card\'s touches',
      );
      final mapBlock = find.byWidgetPredicate(
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
      );
      bool blocked() => tester.widgetList<AbsorbPointer>(mapBlock).last.absorbing;
      expect(blocked(), isFalse);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      expect(blocked(), isTrue, reason: 'a touch on the card holds the map');
      await gesture.up();
      await tester.pump();
      expect(blocked(), isFalse);
      await _unmount(tester, location);
    });
  });

  group('driver-u80: no next-trip offer behind a covering route (D-05)', () {
    Future<void> covered(
      WidgetTester tester, {
      required bool offerFirst,
    }) async {
      final location = _Loc();
      final navigator = GlobalKey<NavigatorState>();
      await _pumpTrip(tester, location, navigator: navigator);
      if (offerFirst) {
        await tester.pump(const Duration(milliseconds: 2600));
        expect(find.byKey(_offerCard), findsOneWidget);
      }
      // History, Chat and the other screens open over the trip.
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering')),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      location.updates.add(_fix());
      await _pumpFor(tester,
          DriverOfferRules.current.exclusiveAcceptTime + const Duration(seconds: 4));
      expect(ExclusiveAnswers.instance.missedInRow, 0,
          reason: 'an offer the driver cannot see is not a miss');
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byKey(_offerCard), findsOneWidget,
          reason: 'back on the trip, Radar offers again');
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _unmount(tester, location);
    }

    testWidgets('none arrives or runs out while covered', (tester) async {
      await covered(tester, offerFirst: false);
    });

    testWidgets('one already up waits behind the route, then counts down',
        (tester) async {
      await covered(tester, offerFirst: true);
    });
  });
}
