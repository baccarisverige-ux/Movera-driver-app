import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Review extra (D3.5): an admin direct assign (contract §3.1) of a
// reservation opens with the scheduled waiting rules, not the normal ones.
// Its source key still shows as "Assigned by Movera" on the waybill, in
// the driver's language. An admin direct assign of a plain trip keeps the
// normal rules. Harness from matched_via_language_test.dart.

RideOffer _assign({String? reservationTime}) => RideOffer(
  id: 'assign',
  category: 'Comfort',
  fare: const Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Karim',
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
  priority: true,
  source: OfferSource.admin,
  reservationTime: reservationTime,
);

/// Dispatch with only what a test publishes; claims win.
class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);

  List<RideOffer> offers;
  final claims = <String>[];

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
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
  Future<ClaimResult> claimOffer(String offerId) async {
    claims.add(offerId);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final offer = offers.firstWhere((item) => item.id == offerId);
    return ClaimResult.success(offer);
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Home online with [offer] from dispatch; Accept on its Exclusive sheet.
Future<AcceptRide> _acceptAssign(WidgetTester tester, RideOffer offer) async {
  final dispatch = _Dispatch([offer]);
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
  expect(
    find.byKey(const ValueKey<String>('exclusive-offer-card-assign')),
    findsOneWidget,
  );
  await _frames(tester, const Duration(milliseconds: 1500));
  await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
  await _frames(tester, const Duration(milliseconds: 1500));
  expect(dispatch.claims, ['assign']);
  return tester.widget<AcceptRide>(find.byType(AcceptRide));
}

/// Contract v0.18.8: the server picks the waiting rule; the app only
/// keeps the matched-via key that names a reservation.
bool _scheduled(AcceptRide trip) {
  final via = trip.matchedVia.toLowerCase();
  return via.contains('scheduled') || via.contains('reservation');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() => DriverAppTexts.language = 'en');

  for (final language in ['en', 'sv']) {
    testWidgets('an assigned reservation gets the scheduled waiting rules '
        '($language)', (tester) async {
      DriverAppTexts.language = language;
      final trip = await _acceptAssign(
        tester,
        _assign(reservationTime: '07:40'),
      );
      expect(_scheduled(trip), isTrue);
      // The waybill still says Movera assigned it.
      final record = WaybillRecord(
        tripId: 't',
        statusLabel: WaybillRecord.completed,
        issuedAt: DateTime(2026),
        fare: '88,10 kr',
        service: 'Comfort',
        riderName: 'Karim',
        pickup: 'A',
        dropoff: 'B',
        source: trip.matchedVia,
        driverName: 'D',
        vehicle: 'V',
        licensePlate: 'P',
        passengerCapacity: 4,
      );
      expect(
        record.sourceText,
        WaybillRecord(
          tripId: 't',
          statusLabel: WaybillRecord.completed,
          issuedAt: DateTime(2026),
          fare: '88,10 kr',
          service: 'Comfort',
          riderName: 'Karim',
          pickup: 'A',
          dropoff: 'B',
          source: WaybillRecord.assignedByMoveraSource,
          driverName: 'D',
          vehicle: 'V',
          licensePlate: 'P',
          passengerCapacity: 4,
        ).sourceText,
      );
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('an assigned plain trip keeps the normal waiting rules', (
    tester,
  ) async {
    final trip = await _acceptAssign(tester, _assign());
    expect(trip.matchedVia, WaybillRecord.assignedByMoveraSource);
    expect(_scheduled(trip), isFalse);
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });
}
