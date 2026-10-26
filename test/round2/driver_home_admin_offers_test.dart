import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';

import '../../integration_test/headless_map_platform.dart';

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

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
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<_Dispatch> _online(WidgetTester tester, List<RideOffer> offers) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dispatch = _Dispatch()..offers = offers;
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
  return dispatch;
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester, const Duration(seconds: 2));
}

const _assignCard = ValueKey<String>('exclusive-offer-card-admin-assign-1');
const _usualCard = ValueKey<String>('exclusive-offer-card-home-direct-close');

/// Q16/Q18 on Home: an admin direct assign is an Exclusive offer
/// ("Assigned by Movera"), a radar-group trip is a Radar card; both show
/// the fare with the bonus and the red Priority badge.
void main() {
  testWidgets('a direct assign in dispatch comes as the Exclusive offer', (
    tester,
  ) async {
    await _online(tester, [DemoAdminOffers.directAssign]);
    await _until(tester, find.byKey(_assignCard));
    expect(find.byKey(_usualCard), findsNothing);
    expect(
      find.byKey(const ValueKey('exclusive-offer-priority-admin-assign-1')),
      findsOneWidget,
    );
    expect(find.textContaining('Assigned by Movera'), findsOneWidget);
    // The total with the 30 kr bonus.
    expect(
      tester
          .widget<ExclusiveRequestSheet>(find.byType(ExclusiveRequestSheet))
          .offer
          .fare,
      '128,60 kr',
    );
    // Never a Radar trip.
    expect(
      find.byKey(const ValueKey('radar-offer-category-admin-assign-1')),
      findsNothing,
    );
    await _leave(tester);
  });

  testWidgets('a direct assign sent while online comes at once', (
    tester,
  ) async {
    final dispatch = await _online(tester, const <RideOffer>[]);
    // The usual demo Exclusive first; it runs out.
    await _until(tester, find.byKey(_usualCard));
    await _frames(tester, const Duration(seconds: 17));
    expect(find.byKey(_usualCard), findsNothing);
    dispatch.publish([DemoAdminOffers.directAssign]);
    await _until(tester, find.byKey(_assignCard));
    await _leave(tester);
  });

  testWidgets('a radar-group trip is a Radar card with the badge', (
    tester,
  ) async {
    await _online(tester, [DemoAdminOffers.radarGroup]);
    await _until(
      tester,
      find.byKey(const ValueKey('radar-offer-priority-admin-group-1')),
    );
    final card = tester.widget<RadarOfferCard>(
      find.byType(RadarOfferCard).first,
    );
    expect(card.offer.fare, '152,40 kr');
    expect(card.offer.priority, isTrue);
    await _leave(tester);
  });
}
