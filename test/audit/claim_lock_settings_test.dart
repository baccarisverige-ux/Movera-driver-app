import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Decision 4 ("lock settings while matching"): while a Match or Accept is
// with dispatch, the ride categories and Destination mode cannot be
// changed; the controls come back once the claim resolves.

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
        navigatorObservers: [driverRouteObserver],
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
  expect(
    find.byKey(const ValueKey<String>('radar-offer-card-first')),
    findsOneWidget,
  );
}

/// The island's destination search.
InkWell _search(WidgetTester tester) => tester.widget<InkWell>(
  find.byKey(const ValueKey<String>('destination-mode-open')),
);

/// Ride preferences from the dock: the category tiles.
Future<void> _openPreferences(WidgetTester tester) async {
  final action = find.descendant(
    of: find.byTooltip('Ride preferences').first,
    matching: find.byType(InkWell),
  );
  tester.widget<InkWell>(action).onTap!();
  await _frames(tester, 12);
  expect(find.byType(Preferences), findsOneWidget);
}

InkWell _tile(WidgetTester tester, String title) => tester.widget<InkWell>(
  find
      .ancestor(
        of: find.descendant(
          of: find.byType(Preferences),
          matching: find.text(title),
        ),
        matching: find.byType(InkWell),
      )
      .first,
);

Future<void> _closePreferences(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Preferences))).pop();
  await _frames(tester, 12);
  expect(find.byType(Preferences), findsNothing);
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

  testWidgets('a Match with dispatch locks the categories and Destination '
      'mode; they come back once it is answered', (tester) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    expect(_search(tester).onTap, isNotNull);
    await _openPreferences(tester);
    expect(_tile(tester, 'Comfort').onTap, isNotNull);
    await _closePreferences(tester);

    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    expect(dispatch.claims, hasLength(1));
    expect(
      _search(tester).onTap,
      isNull,
      reason: 'Destination mode waits for the Match',
    );
    await _openPreferences(tester);
    expect(
      _tile(tester, 'Comfort').onTap,
      isNull,
      reason: 'the categories wait for the Match',
    );
    await _closePreferences(tester);

    dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
    await _frames(tester, 20);
    expect(_search(tester).onTap, isNotNull);
    await _openPreferences(tester);
    expect(_tile(tester, 'Comfort').onTap, isNotNull);
    await _closePreferences(tester);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await dispatch.updates.close();
  });
}
