import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// driver-u135: a cash offer on Home must show its CASH badge in Swedish
// and French too, on the Exclusive sheet and on the Radar card.

RideOffer _cash(String id, {OfferSource source = OfferSource.system}) =>
    RideOffer(
      id: id,
      category: 'Comfort',
      fare: Money(minorUnits: 8810),
      rating: '4.92',
      riderName: 'Sara',
      pickupMinutes: 3,
      pickupKm: 0.9,
      tripMinutes: 12,
      tripKm: 5.2,
      pickup: 'Tegnérgatan, Stockholm',
      dropoff: 'Odengatan, Stockholm',
      pickupPosition: const GeoPoint(59.3335, 18.0610),
      dropoffPosition: const GeoPoint(59.3428, 18.0475),
      isNearby: true,
      followsDestination: true,
      payment: 'Cash',
      source: source,
    );

class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);
  final List<RideOffer> offers;

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(offers);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _until(WidgetTester tester, Finder finder, Duration limit) async {
  for (var t = Duration.zero;
      t < limit && finder.evaluate().isEmpty;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> _online(WidgetTester tester, List<RideOffer> offers) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: _Dispatch(offers),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    // Only the badge is under test: missed offers never go offline.
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    DriverAppTexts.language = 'en';
  });

  for (final (code, word) in [('sv', 'Kontant'), ('fr', 'Espèces')]) {
    testWidgets('$code: the Exclusive sheet and the Radar card say $word', (
      tester,
    ) async {
      DriverAppTexts.language = code;
      await _online(tester, [
        // An admin direct assign is the Exclusive offer (§3.1).
        _cash('cash-assign', source: OfferSource.admin),
        _cash('cash-trip'),
      ]);
      await _until(
        tester,
        find.byKey(const ValueKey<String>('exclusive-offer-card-cash-assign')),
        const Duration(seconds: 5),
      );
      expect(
        find.byKey(const ValueKey<String>('exclusive-offer-cash-cash-assign')),
        findsOneWidget,
        reason: 'the rider pays cash',
      );
      expect(find.text(word), findsWidgets);
      // The down arrow skips it; the Radar trip is dealt onto the deck.
      await _frames(tester, const Duration(milliseconds: 1500));
      await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
      await _until(
        tester,
        find.byKey(const ValueKey<String>('radar-offer-card-cash-trip')),
        const Duration(seconds: 25),
      );
      expect(
        find.byKey(const ValueKey<String>('radar-offer-cash-cash-trip')),
        findsOneWidget,
        reason: 'the rider pays cash',
      );
      expect(find.text(word), findsWidgets);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
