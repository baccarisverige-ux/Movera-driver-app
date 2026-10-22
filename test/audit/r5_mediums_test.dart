import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Round-5 medium audit bugs (FIX_PLAN Wave 6b), one group per bug.

Map<String, dynamic> _wireOffer() => {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 20000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 17000, 'currency': 'SEK'},
  'pickupPay': {'amountMinor': 900, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

/// Dispatch with no trips unless the test publishes some.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <Completer<ClaimResult>>[];

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
  Future<ClaimResult> claimOffer(String offerId) {
    final claim = Completer<ClaimResult>();
    claims.add(claim);
    return claim.future;
  }

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

typedef _Home = ({_Dispatch dispatch, DriverSessionController session});

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Home with the app's route observer; with [online], the Radar is on.
Future<_Home> _pumpHome(
  WidgetTester tester, {
  bool online = true,
  ActiveRideRepository? activeRides,
  _Dispatch? dispatch,
}) async {
  final repo = dispatch ?? _Dispatch();
  final session = DriverSessionController();
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
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController: session,
            dispatchRepository: repo,
            activeRideRepository: activeRides,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  if (online) {
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await _frames(tester, const Duration(milliseconds: 1500));
  }
  return (dispatch: repo, session: session);
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
  });

  group('driver-r5-1', () {
    test("an API offer's card shows the server's driverEarnings and "
        'pickupPay', () {
      final offer = OfferWire.parse(_wireOffer());
      expect(offer.driverEarnings, Money.ore(17000));
      expect(offer.pickupPay, Money.ore(900));
      // The server's pickup pay, even where the local rules have none.
      final quote = PickupPayCalculator.quote(
        category: offer.category,
        kind: PickupPayOfferKind.radar,
        leg: const PickupLeg(km: 0.2, minutes: 1),
        serverPay: offer.pickupPay,
      );
      expect(quote.pay, Money.ore(900));
      final view = RadarOfferView(
        id: offer.id,
        category: offer.category,
        payment: offer.payment,
        rating: offer.rating,
        fare: offer.fareLabel,
        pickupMinutes: offer.pickupMinutes,
        pickupKm: offer.pickupKm,
        tripMinutes: offer.tripMinutes,
        tripKm: offer.tripKm,
        pickup: offer.pickup,
        dropoff: offer.dropoff,
        driverEarnings: offer.driverEarnings?.formatted,
      );
      // Net-fare card: 'Your share' is the server's 170 kr, not 75 % of 200.
      expect(view.shownFare(const OfferCardDetails(netFare: true)),
          '170,00 kr');
      expect(view.shownFare(const OfferCardDetails()), '200,00 kr');
    });
  });

  group('driver-r5-14', () {
    test('a cash rider with pickup pay still pays the fare without the '
        'Movera bonus', () {
      final quote = PickupPayQuote(
        pay: Money.ore(1300),
        leg: const PickupLeg(km: 4, minutes: 6),
      );
      final terms = quote.termsOf(
        fare: '152,40 kr',
        driverBonus: Money.ore(4000),
        paidByCash: true,
      );
      expect(terms.fare, '165,40 kr');
      expect(terms.driverBonus, Money.ore(5300));
      // 152,40 kr includes Movera's 40 kr bonus: the rider pays 112,40 kr.
      expect(terms.cashToCollect, '112,40 kr');
      // A server cash amount still wins.
      expect(
        quote
            .termsOf(
              fare: '152,40 kr',
              driverBonus: Money.ore(4000),
              cashToCollect: '120,00 kr',
              paidByCash: true,
            )
            .cashToCollect,
        '120,00 kr',
      );
    });
  });

  group('driver-r5-41', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    testWidgets("while admin has Scheduled rides on, a late cancel at the "
        'limit neither warns nor notifies a pause', (tester) async {
      final now = ScheduledClock.instance.now();
      ScheduledRideStore.driverAccess = ScheduledRidesDriverAccess.fromJson({
        'on': true,
        'until': now.add(const Duration(days: 3)).toUtc().toIso8601String(),
      });
      ScheduledRideStore.addLateCancel(now.subtract(const Duration(days: 2)));
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      final paused = DriverNotificationFeed.instance.items
          .where((n) => n.kind == DriverNoticeKind.scheduledPaused)
          .length;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepted'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gamla vägen, Stockholm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamla vägen, Stockholm').first);
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Personal emergency'));
      await tester.tap(find.text('Personal emergency'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final warning = tester.widget<Text>(
          find.byKey(const ValueKey<String>('scheduled-late-cancel')));
      expect(warning.data, isNot(contains('pause')));
      final confirm = find.widgetWithText(FilledButton, 'Cancel reservation');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(ScheduledRideStore.block(), isNull);
      expect(
        DriverNotificationFeed.instance.items
            .where((n) => n.kind == DriverNoticeKind.scheduledPaused)
            .length,
        paused,
      );
    });
  });

  group('driver-r5-42', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    test('at Leave now, requests that clash with the trip being driven stay '
        'hidden', () {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      expect(ScheduledRideStore.openRequests.value, 0);
      final ride = ScheduledRideStore.upcoming.firstWhere(
          (r) => r.pickupAddress == 'Gamla vägen, Stockholm');
      expect(ScheduledRideStore.start(ride), isTrue);
      // The Lidingö request clashes with the 07:40 trip now on the road.
      expect(ScheduledRideStore.openRequests.value, 0);
      // After a logout nothing is held back any more.
      ScheduledRideStore.reset();
      expect(ScheduledRideStore.openRequests.value, 2);
    });
  });

  group('driver-r5-36', () {
    testWidgets("'Close trip' on a stale saved trip hands its secured next "
        'trip off and asks about it', (tester) async {
      final rides = MemoryActiveRideRepository();
      final savedAt = DateTime.now().subtract(const Duration(hours: 7));
      await rides.save(PersistedActiveRide(
        tripId: 'stale-a',
        stage: ActiveRideStage.onTrip,
        savedAt: savedAt,
        fare: '120,00 kr',
        pickupLat: 59.3335,
        pickupLng: 18.0610,
        dropoffLat: 59.3380,
        dropoffLng: 18.0700,
        next: const PersistedQueuedTrip(
          tripId: 'next-b',
          riderName: 'Omar',
          fare: '90,00 kr',
          category: 'Comfort',
          pickup: 'Odengatan, Stockholm',
          dropoff: 'Sveavägen, Stockholm',
          pickupLat: 59.3428,
          pickupLng: 18.0475,
          dropoffLat: 59.3400,
          dropoffLng: 18.0590,
        ),
      ));
      await _pumpHome(tester, online: false, activeRides: rides);
      await _frames(tester, const Duration(milliseconds: 500));
      expect(find.text('Unresolved trip'), findsOneWidget);
      await tester.tap(find.text('Close trip'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _frames(tester, const Duration(milliseconds: 800));
      // B is now the saved trip, as old as A was: Home asks about it.
      final saved = await rides.read();
      expect(saved?.tripId, 'next-b');
      expect(find.text('Unresolved trip'), findsOneWidget);
      final history = await tester.runAsync(
        () => PrefsTripHistoryRepository().list(),
      );
      expect(history!.map((r) => r.tripId), contains('stale-a'));
      await tester.tap(find.text('Close trip'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.text('Unresolved trip'), findsNothing);
      expect(await rides.read(), isNull);
      await _end(tester);
    });
  });
}
