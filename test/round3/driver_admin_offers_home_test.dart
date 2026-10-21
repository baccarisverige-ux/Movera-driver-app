import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Dispatch whose accept answer, declines and withdrawals the test sets.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  final _withdrawals = StreamController<OfferWithdrawal>.broadcast();
  List<RideOffer> offers = const [];
  final List<String> claims = <String>[];
  final List<String> declines = <String>[];
  ClaimResult Function(String id) answer =
      (_) => const ClaimResult.unavailable();

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  /// Contract `offer_withdrawn`: first the reason, then the list without it.
  void withdraw(String id, OfferGoneReason reason) {
    _withdrawals.add(OfferWithdrawal(offerId: id, reason: reason));
    publish([for (final offer in offers) if (offer.id != id) offer]);
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
  Future<ClaimResult> claimOffer(String offerId) async {
    claims.add(offerId);
    final result = answer(offerId);
    if (result.isSuccess) {
      publish([for (final offer in offers) if (offer.id != offerId) offer]);
    }
    return result;
  }

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async {
    declines.add(offerId);
    publish([for (final offer in offers) if (offer.id != offerId) offer]);
    return true;
  }

  @override
  Stream<OfferWithdrawal> watchWithdrawals() => _withdrawals.stream;
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

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

const _assignCard = ValueKey<String>('exclusive-offer-card-admin-assign-1');
const _groupCard = ValueKey<String>('radar-offer-priority-admin-group-1');

Future<void> _accept(WidgetTester tester) async {
  // The sheet settles first.
  await _frames(tester, const Duration(milliseconds: 1500));
  await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
  await _frames(tester, const Duration(milliseconds: 900));
}

/// Round 3: the driver's side of admin direct assigns and radar groups.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
  });

  group('Direct assign (Exclusive, "Assigned by Movera")', () {
    testWidgets('Accept claims it through dispatch; won, the trip opens with '
        'the bonus', (tester) async {
      final dispatch = await _online(tester, [DemoAdminOffers.directAssign]);
      dispatch.answer = (id) => ClaimResult.success(DemoAdminOffers.directAssign);
      await _until(tester, find.byKey(_assignCard));
      expect(find.byType(AcceptRide), findsNothing);
      await _accept(tester);
      expect(dispatch.claims, ['admin-assign-1']);
      await _until(tester, find.byType(AcceptRide));
      final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
      expect(trip.offerId, 'admin-assign-1');
      // driver-12: the total its Exclusive sheet showed, 128,60 kr plus
      // 0,80 kr pickup pay (3 min to pickup); the pickup pay is Movera's,
      // on top of its 30 kr bonus.
      expect(trip.fare, '129,40 kr');
      expect(trip.driverBonus, const Money(minorUnits: 3080));
      expect(trip.matchedVia, 'Assigned by Movera');
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      tester.takeException();
      await _leave(tester);
    });

    testWidgets('lost: no trip, "Taken by another driver", not a miss', (
      tester,
    ) async {
      final dispatch = await _online(tester, [DemoAdminOffers.directAssign]);
      dispatch.answer = (_) => const ClaimResult.alreadyClaimed();
      await _until(tester, find.byKey(_assignCard));
      await _accept(tester);
      expect(dispatch.claims, ['admin-assign-1']);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(find.byType(AcceptRide), findsNothing);
      expect(find.byKey(_assignCard), findsNothing);
      expect(_said, contains('Taken by another driver'));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _leave(tester);
    });

    testWidgets('the down arrow declines it in dispatch and counts (Q46)', (
      tester,
    ) async {
      final dispatch = await _online(tester, [DemoAdminOffers.directAssign]);
      await _until(tester, find.byKey(_assignCard));
      await _frames(tester, const Duration(milliseconds: 1500));
      await tester.tap(find.byKey(const ValueKey('direct-offer-dismiss')));
      await _frames(tester, const Duration(milliseconds: 900));
      expect(dispatch.declines, ['admin-assign-1']);
      expect(dispatch.claims, isEmpty);
      expect(find.byKey(_assignCard), findsNothing);
      expect(ExclusiveAnswers.instance.missedInRow, 1);
      await _leave(tester);
    });

    testWidgets('running out counts as a miss (Q45)', (tester) async {
      await _online(tester, [DemoAdminOffers.directAssign]);
      await _until(tester, find.byKey(_assignCard));
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime + const Duration(seconds: 1),
      );
      expect(find.byKey(_assignCard), findsNothing);
      expect(ExclusiveAnswers.instance.missedInRow, 1);
      await _leave(tester);
    });

    testWidgets('withdrawn for another driver: it leaves, not a miss', (
      tester,
    ) async {
      final dispatch = await _online(tester, [DemoAdminOffers.directAssign]);
      await _until(tester, find.byKey(_assignCard));
      dispatch.withdraw('admin-assign-1', OfferGoneReason.claimedElsewhere);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(find.byKey(_assignCard), findsNothing);
      expect(_said, contains('Taken by another driver'));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _leave(tester);
    });
  });

  group('Radar group (Radar card, first to accept wins)', () {
    testWidgets('Match claims it through dispatch', (tester) async {
      final dispatch = await _online(tester, [DemoAdminOffers.radarGroup]);
      await _until(tester, find.byKey(_groupCard));
      await tester.tap(find.byKey(const ValueKey('radar-match-admin-group-1')));
      await _frames(tester, const Duration(milliseconds: 400));
      expect(dispatch.claims, ['admin-group-1']);
      await _leave(tester);
    });

    testWidgets('another driver of the group took it: "Taken by another '
        'driver", the card goes, nothing counts', (tester) async {
      final dispatch = await _online(tester, [DemoAdminOffers.radarGroup]);
      await _until(tester, find.byKey(_groupCard));
      // The usual demo Exclusive came (and ran out) first.
      final before = ExclusiveAnswers.instance.missedInRow;
      dispatch.withdraw('admin-group-1', OfferGoneReason.claimedElsewhere);
      await _frames(tester, const Duration(milliseconds: 400));
      expect(_said, contains('Taken by another driver'));
      await _frames(tester, const Duration(seconds: 4));
      expect(find.byKey(_groupCard), findsNothing);
      expect(ExclusiveAnswers.instance.missedInRow, before);
      await _leave(tester);
    });

    testWidgets('× declines it in dispatch and never counts (Q45/Q46)', (
      tester,
    ) async {
      final dispatch = await _online(tester, [DemoAdminOffers.radarGroup]);
      await _until(tester, find.byKey(_groupCard));
      await _frames(tester, const Duration(milliseconds: 600));
      final before = ExclusiveAnswers.instance.missedInRow;
      await tester.tap(find.byKey(const ValueKey('radar-offer-close')).first);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(dispatch.declines, ['admin-group-1']);
      expect(find.byKey(_groupCard), findsNothing);
      expect(ExclusiveAnswers.instance.missedInRow, before);
      await _leave(tester);
    });
  });
}
