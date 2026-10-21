import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.2, part b): the smart gap and a ride whose pickup passed.
// - driver-u143: a reservation accepted after its pickup time does not
//   stay the "next" ride for good, holding every trip offer back.

/// Dispatch with the trips the test publishes.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    final sub = _nearby.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
    sink.addSync(offers);
  }, isBroadcast: true);

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
  Future<ClaimResult> claimOffer(String offerId) =>
      Completer<ClaimResult>().future;

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

/// A short Radar trip near the driver.
final _trip = RideOffer(
  id: 'near',
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 2,
  pickupKm: 0.8,
  tripMinutes: 6,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3380, 18.0700),
  isNearby: true,
  followsDestination: false,
);

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(WidgetTester tester, _Dispatch dispatch) async {
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
            dispatchRepository: dispatch,
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
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() {
    DemoReservations.reset();
    ScheduledRideStore.reset();
  });

  group('driver-u143: a reservation accepted after its pickup time', () {
    testWidgets('it leaves Accepted and Radar trips reach Home', (
      tester,
    ) async {
      // 07:00 on the fast test day: the rides are at 07:40 and 08:05.
      ScheduledClock.instance.now();
      DemoReservations.reset();
      ScheduledRideStore.reset();
      // 08:10: the 08:05 Lidingö request is still listed; the driver
      // accepts it.
      await tester.pump(const Duration(seconds: 140));
      expect(clockLabel(ScheduledClock.instance.now()), '08:10');
      ScheduledRideStore.answer('Högsätravägen, Lidingö', accepted: true);
      expect(ScheduledRideStore.upcoming.first.pickupTime, '08:05');
      final dispatch = _Dispatch()..publish([_trip]);
      await _pumpHome(tester, dispatch);
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(milliseconds: 3500),
      );
      expect(find.byKey(const ValueKey<String>('radar-offer-card-near')),
          findsOneWidget,
          reason: 'trips are no longer held back for a past pickup');
      expect(ScheduledRideStore.upcoming.map((r) => r.pickupTime),
          isNot(contains('08:05')),
          reason: 'its pickup passed before anything could be planned');
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
