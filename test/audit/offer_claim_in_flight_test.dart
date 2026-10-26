import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';

RideOffer _offer(String id) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 10000),
  rating: '4.9',
  pickupMinutes: 2,
  pickupKm: 1,
  tripMinutes: 10,
  tripKm: 5,
  pickup: 'Pickup, Stockholm',
  dropoff: 'Dropoff, Stockholm',
  pickupPosition: const GeoPoint(59.3279, 18.0615),
  dropoffPosition: const GeoPoint(59.3326, 18.0649),
  isNearby: true,
  followsDestination: true,
);

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final updates = StreamController<List<RideOffer>>.broadcast();
  final claims = <Completer<ClaimResult>>[];
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) async* {
    yield [_offer('first'), _offer('second')];
    yield* updates.stream;
  }

  @override
  Stream<List<RideOffer>> watchNextTripOffers() => const Stream.empty();
  @override
  void refreshOffers() {}
  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) {
    final claim = Completer<ClaimResult>();
    claims.add(claim);
    return claim.future;
  }
}

class _Location implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _mount(WidgetTester tester, _Dispatch dispatch) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: DriverHome(
          dispatchRepository: dispatch,
          locationRepository: _Location(),
        ),
      ),
    ),
  );
  await _frames(tester);
  await tester.tap(find.text('OFF'));
  await tester.pump(const Duration(milliseconds: 1550));
  await tester.pump(const Duration(milliseconds: 2300));
  await tester.pump(const Duration(seconds: 15));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 3100));
  await _frames(tester);
  // Both trips are on the Home deck, "first" in front.
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-first')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-second')),
    findsOneWidget,
  );
}

Future<void> _match(WidgetTester tester, String id) async {
  final match = find.byKey(ValueKey<String>('radar-match-$id'));
  await tester.tap(match);
  await tester.pump();
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  Future<void> win(WidgetTester tester, _Dispatch dispatch) async {
    expect(dispatch.claims, hasLength(1));
    dispatch.claims.single.complete(ClaimResult.success(_offer('first')));
    await _frames(tester, 30);
  }

  Future<void> finish(WidgetTester tester, _Dispatch dispatch) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await dispatch.updates.close();
  }

  // driver-71: × on the card whose Match is being sent.
  testWidgets('× on the matching Radar card cannot drop the won claim', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    await _match(tester, 'first');
    // The × sits beside the card, in the card's own Stack.
    final close = find.descendant(
      of: find
          .ancestor(
            of: find.byKey(const ValueKey<String>('radar-offer-card-first')),
            matching: find.byType(Stack),
          )
          .first,
      matching: find.byKey(const ValueKey<String>('radar-offer-close')),
    );
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close);
      await _frames(tester);
    }
    await win(tester, dispatch);
    expect(find.byType(AcceptRide), findsOneWidget);
    await finish(tester, dispatch);
  });

  // driver-69: "Go offline" while a Match is being sent.
  testWidgets('going offline waits for the Radar claim in flight', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    await _match(tester, 'first');
    await _frames(tester);
    // The radar face is switching: hold the one coming in.
    await tester.longPress(
      find.byKey(const ValueKey<String>('home-radar-long-press')).last,
    );
    await _frames(tester);
    final yes = find.byKey(const ValueKey<String>('go-offline-yes'));
    if (yes.evaluate().isNotEmpty) {
      await tester.tap(yes);
      await _frames(tester);
    }
    await win(tester, dispatch);
    expect(find.byType(AcceptRide), findsOneWidget);
    await finish(tester, dispatch);
  });

  // driver-70: two Radar offers gone from dispatch in one update.
  testWidgets('every Radar offer lost at once leaves the deck', (tester) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    dispatch.updates.add(const <RideOffer>[]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester);
    expect(
      find.byKey(const ValueKey<String>('radar-home-deck')),
      findsNothing,
      reason: 'Both lost offers are dismissed, not only the last one.',
    );
    await finish(tester, dispatch);
  });

  // driver-87: system Back on the Radar list while a Match is being sent.
  testWidgets('system Back waits for the Radar list claim in flight', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    await tester.tap(find.byKey(const ValueKey<String>('island-radar-offers')));
    await _frames(tester);
    expect(find.byType(RideRequests), findsOneWidget);
    await _match(tester, 'first');
    await tester.binding.handlePopRoute();
    await _frames(tester);
    await win(tester, dispatch);
    expect(find.byType(AcceptRide), findsOneWidget);
    await finish(tester, dispatch);
  });
}
