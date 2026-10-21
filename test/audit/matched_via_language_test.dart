import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

// driver-u130: Home passes a stable, English source key as matchedVia, not
// the translated label. The waiting rules for a reservation or scheduled
// ride, and the stored waybill source, must not depend on the UI language.
// Harness copied from test/widget/home_scheduled_test.dart; the demo day
// starts at 07:00 and runs 30 times faster.

/// Dispatch with only what a test publishes, and assignments it sends.
class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final _nearby = StreamController<List<RideOffer>>.broadcast();
  final assignments = StreamController<ReservationRequestPreview>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <String>[];

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
  Stream<ReservationRequestPreview> watchAssignments() => assignments.stream;

  @override
  Future<ClaimResult> claimOffer(String offerId) async {
    claims.add(offerId);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    RideOffer? offer;
    for (final item in offers) {
      if (item.id == offerId) offer = item;
    }
    publish([for (final o in offers) if (o.id != offerId) o]);
    return ClaimResult.success(
      offer ?? RideOffer.reservation(demoReservationRequest),
    );
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  DispatchRepository dispatch, {
  bool online = false,
}) async {
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
            sessionController: DriverSessionController(initialOnline: online),
            initialOnline: online,
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Radar on, as the driver does: the demo offers start.
Future<void> _goOnline(WidgetTester tester) async {
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

AcceptRide _trip0(WidgetTester tester) =>
    tester.widget<AcceptRide>(find.byType(AcceptRide));

/// While an Exclusive offer is live the blue radar is its Accept.
final _exclusiveRadar = find.byKey(const ValueKey<String>('home-radar-exclusive'));

WaitingRideType _typeOf(AcceptRide trip) => WaitingRules.typeOf(
  matchedVia: trip.matchedVia,
  pickupAddress: trip.pickupAddress,
);

void main() {
  for (final language in ['sv', 'fr']) {
    group('in $language', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
        IslandMessages.reset();
        ScheduledRideStore.reset();
        DriverAppTexts.language = language;
      });
      tearDown(() => DriverAppTexts.language = 'en');

      testWidgets('a reservation taken as Exclusive keeps its source key '
          'and the scheduled waiting rules', (tester) async {
        final dispatch = _Dispatch();
        await _pumpHome(tester, dispatch);
        await _goOnline(tester);
        await _frames(tester, const Duration(seconds: 40));
        expect(
          find.byKey(const ValueKey<String>(
            'exclusive-offer-card-$demoReservationId',
          )),
          findsOneWidget,
        );
        await tester.tap(_exclusiveRadar);
        await _frames(tester, const Duration(milliseconds: 1200));
        expect(dispatch.claims, [demoReservationId]);
        final trip = _trip0(tester);
        expect(DriverAppTexts.language, language);
        expect(trip.matchedVia, 'Exclusive reservation');
        expect(_typeOf(trip), WaitingRideType.scheduled);
        await _end(tester);
      });

      testWidgets('"Leave now" opens the scheduled ride with its source key',
          (tester) async {
        ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
        await _pumpHome(tester, _Dispatch(), online: true);
        await _frames(tester, const Duration(seconds: 49));
        expect(find.byType(AcceptRide), findsOneWidget);
        final trip = _trip0(tester);
        expect(DriverAppTexts.language, language);
        expect(trip.matchedVia, 'Scheduled ride');
        expect(_typeOf(trip), WaitingRideType.scheduled);
        await _end(tester);
      });

      test('the stored source shows in the driver\'s language', () {
        WaybillRecord record(String source) => WaybillRecord(
          tripId: 't',
          statusLabel: WaybillRecord.completed,
          issuedAt: DateTime(2026),
          fare: '0 kr',
          service: 'Movera',
          riderName: 'Karin',
          pickup: 'a',
          dropoff: 'b',
          source: source,
          driverName: 'd',
          vehicle: 'v',
          licensePlate: 'p',
          passengerCapacity: 4,
        );
        expect(record('Exclusive reservation').sourceText, tr.exclusiveReservation);
        expect(record('Scheduled ride').sourceText, tr.scheduledRide);
        expect(record('Assigned by Movera').sourceText, tr.assignedByMovera);
        expect(record('Exclusive offer').sourceText, tr.exclusiveOffer);
        expect(record('Movera Radar').sourceText, tr.moveraRadar);
        expect(tr.scheduledRide, isNot('Scheduled ride'));
      });
    });
  }
}
