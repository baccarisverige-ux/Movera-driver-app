import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/history/today_earnings.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';
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

/// Android after "Don't allow": still `denied` (the rationale can show),
/// and each request shows the system prompt again.
class _DeclinedGps extends GeolocatorPlatform {
  var prompts = 0;
  final pending = <Completer<LocationPermission>>[];

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() {
    prompts++;
    final answer = Completer<LocationPermission>();
    pending.add(answer);
    return answer.future;
  }

  void decline() {
    for (final answer in pending) {
      if (!answer.isCompleted) answer.complete(LocationPermission.denied);
    }
  }
}

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

/// The phone sleeps for [asleep]: the wall clock moves on, the app's
/// timers (monotonic time) do not.
void _sleep(WidgetTester tester, Duration asleep, void Function(Duration) jump) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  jump(asleep);
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// Points the wall clock at the test's fake time plus a jump [_sleep]
/// can move; restored after the test.
void Function(Duration) _wallClock() {
  final before = ScheduledClock.realNow;
  var offset = Duration.zero;
  ScheduledClock.realNow = () => before().add(offset);
  addTearDown(() => ScheduledClock.realNow = before);
  return (by) => offset += by;
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
      // The card shows the server's 170 kr, not 75 % of 200 and never the
      // 200 kr fare (owner decision 2026-10-26), with or without the
      // "Your share" caption.
      expect(view.shownFare(const OfferCardDetails(netFare: true)),
          '170,00 kr');
      expect(view.shownFare(const OfferCardDetails()), '170,00 kr');
      expect(offer.driverPay, Money.ore(17000));
    });
  });

  group('driver-r5-14', () {
    test('a cash rider with pickup pay still pays the fare without the '
        'Movera bonus', () {
      // 152,40 kr includes Movera's 40 kr bonus: the rider pays 112,40 kr
      // (RideOffer.riderCash), whatever the driver's own pay is.
      final offer = OfferWire.parse({
        ..._wireOffer(),
        'fare': {'amountMinor': 15240, 'currency': 'SEK'},
        'driverBonus': {'amountMinor': 4000, 'currency': 'SEK'},
        'paymentMethod': 'cash',
      });
      expect(offer.riderCashLabel, '112,40 kr');
      // The accepted terms keep it beside the driver's pay plus the pickup
      // pay; the pickup pay is Movera's.
      final quote = PickupPayQuote(
        pay: Money.ore(1300),
        leg: const PickupLeg(km: 4, minutes: 6),
      );
      final terms = quote.termsOf(
        fare: offer.driverPayLabel,
        driverBonus: offer.driverBonus,
        cashToCollect: offer.riderCashLabel,
      );
      expect(terms.fare, '183,00 kr');
      expect(terms.driverBonus, Money.ore(5300));
      expect(terms.cashToCollect, '112,40 kr');
      // A server cash amount still wins, and none is invented.
      expect(
        quote
            .termsOf(
              fare: offer.driverPayLabel,
              driverBonus: offer.driverBonus,
              cashToCollect: '120,00 kr',
            )
            .cashToCollect,
        '120,00 kr',
      );
      expect(
        quote.termsOf(fare: offer.driverPayLabel).cashToCollect,
        isNull,
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

  group('driver-r5-6', () {
    tearDown(() => DrivingTimeClock.instance.load(worked: Duration.zero));

    testWidgets('after the phone slept past the driving limit, resume '
        'ends the session at once', (tester) async {
      final jump = _wallClock();
      final rule = DrivingTimeClock.instance.rule;
      DrivingTimeClock.instance.load(
        worked: rule.work - const Duration(hours: 1),
        offlineSince: ScheduledClock.realNow(),
      );
      final home = await _pumpHome(tester);
      expect(home.session.availableForOffers, isTrue);
      _sleep(tester, const Duration(hours: 2), jump);
      await _frames(tester, const Duration(seconds: 1));
      expect(DrivingTimeClock.instance.left, Duration.zero);
      expect(IslandMessages.posted.map((m) => m.title),
          contains(startsWith('Rest until')));
      expect(home.session.availableForOffers, isFalse);
      await _end(tester);
    });
  });

  group('driver-r5-7', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    testWidgets("after the phone slept past 'Be online', resume plans "
        "again and says it once", (tester) async {
      final jump = _wallClock();
      // 08:05 Premium: online 45 min before, at 07:20 (40 s of the demo
      // day).
      ScheduledRideStore.answer('Högsätravägen, Lidingö', accepted: true);
      await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(seconds: 2));
      Iterable<String> said() => IslandMessages.posted.map((m) => m.title);
      expect(said(), isNot(contains('Go online for 08:05 pickup')));
      _sleep(tester, const Duration(seconds: 45), jump);
      await _frames(tester, const Duration(seconds: 1));
      expect(said(), contains('Go online for 08:05 pickup'));
      expect(ScheduledRideStore.reminder.value,
          'Go online now for your 08:05 pickup.');
      // A second lock and unlock does not say it again.
      _sleep(tester, Duration.zero, jump);
      await _frames(tester, const Duration(seconds: 1));
      expect(said().where((t) => t == 'Go online for 08:05 pickup'),
          hasLength(1));
      await _end(tester);
    });
  });

  group('admin direct assign (Exclusive)', () {
    setUp(() {
      ScheduledRideStore.reset();
      ExclusiveAnswers.instance.reset();
    });
    tearDown(() => DriverOfferRules.current = const DriverOfferRules());

    final card = find.byKey(ValueKey<String>(
        'exclusive-offer-card-${DemoAdminOffers.directAssign.id}'));

    Future<_Home> assignUp(WidgetTester tester) async {
      final home = await _pumpHome(tester,
          dispatch: _Dispatch()..offers = [DemoAdminOffers.directAssign]);
      for (var i = 0; i < 50 && card.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(card, findsOneWidget);
      return home;
    }

    testWidgets('driver-r5-30: a lock and unlock under the open side menu '
        'does not run the offer out as a miss', (tester) async {
      await assignUp(tester);
      final scaffold = tester.state<ScaffoldState>(
          find.byWidgetPredicate((w) => w is Scaffold && w.drawer != null));
      scaffold.openDrawer();
      await _frames(tester, const Duration(seconds: 1));
      _sleep(tester, Duration.zero, (_) {});
      await _frames(tester, const Duration(seconds: 20));
      expect(scaffold.isDrawerOpen, isTrue);
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      scaffold.closeDrawer();
      await _frames(tester, const Duration(seconds: 3));
      expect(card, findsNothing, reason: 'its time ran out unseen');
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _end(tester);
    });

    testWidgets('driver-r5-19: a network error on Accept keeps the time '
        'the offer had left, not a fresh window', (tester) async {
      final home = await assignUp(tester);
      await _frames(tester, const Duration(seconds: 10));
      await tester
          .tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
      await tester.pump();
      expect(home.dispatch.claims, hasLength(1));
      await _frames(tester, const Duration(milliseconds: 500));
      home.dispatch.claims.single.complete(const ClaimResult.networkError());
      await _frames(tester, const Duration(seconds: 1));
      expect(card, findsOneWidget, reason: 'it still had time left');
      // About 3 s were left of its 15 s, plus the slide down.
      await _frames(tester, const Duration(seconds: 6));
      expect(card, findsNothing);
      await _end(tester);
    });
  });

  group('driver-r5-12', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    testWidgets('pickup pay accepted with a ride saved for later is paid '
        'when Leave now opens its trip', (tester) async {
      // The ride's price is the driver's share of its fare (owner decision
      // 2026-10-26); the pickup pay comes on top.
      final base = Money.parseSekLabel(
          ScheduledRideStore.routeOf(demoReservationId)!.driverPayLabel)!;
      // An Exclusive reservation won before its Exclusive step: saved for
      // later with the pickup pay its card showed.
      ScheduledRideStore.take(demoReservationId,
          upcoming: true, pickupPay: Money.ore(1395));
      final total = (base + Money.ore(1395)).formatted;
      expect(ScheduledRideStore.acceptedPickupPay(demoReservationId),
          Money.ore(1395));
      await _pumpHome(tester);
      await _frames(tester, const Duration(seconds: 50));
      final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
      expect(trip.fare, total);
      expect(trip.driverBonus, Money.ore(1395));
      await _end(tester);
    });
  });

  group('driver-r5-51', () {
    late GeolocatorPlatform original;
    late _DeclinedGps gps;
    setUp(() {
      original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = gps = _DeclinedGps();
      DriverLocationService.resetForTesting();
    });
    tearDown(() {
      GeolocatorPlatform.instance = original;
      DriverLocationService.resetForTesting();
    });

    test("one prompt at a time, and none again after \"Don't allow\"",
        () async {
      const service = DriverLocationService();
      // Home's one-shot and a resume while the prompt is up: one prompt.
      final first = service.getCurrentPosition();
      final second = service.getCurrentPosition();
      await Future<void>.delayed(Duration.zero);
      expect(gps.prompts, 1);
      gps.decline();
      await expectLater(first,
          throwsA(isA<LocationPermissionDeniedException>()));
      await expectLater(second,
          throwsA(isA<LocationPermissionDeniedException>()));
      // Home then starts the stream: no second system prompt.
      await expectLater(service.watchPosition().first,
          throwsA(isA<LocationPermissionDeniedException>()));
      expect(gps.prompts, 1);
      // Only the driver's own "Allow" asks again.
      DriverLocationService.allowPrompt();
      final again = service.getCurrentPosition();
      await Future<void>.delayed(Duration.zero);
      expect(gps.prompts, 2);
      gps.decline();
      await expectLater(again,
          throwsA(isA<LocationPermissionDeniedException>()));
    });
  });

  group('driver-r5-13', () {
    WaybillRecord trip(String id) => WaybillRecord(
      tripId: id,
      statusLabel: WaybillRecord.currentTrip,
      issuedAt: DateTime.now(),
      fare: '120,00 kr',
      service: 'Comfort',
      riderName: 'Sara',
      pickup: 'Tegnérgatan, Stockholm',
      dropoff: 'Odengatan, Stockholm',
      source: WaybillRecord.moveraRadarSource,
      driverName: WaybillRecord.demoDriverName,
      vehicle: WaybillRecord.vehicleUnavailable,
      licensePlate: WaybillRecord.plateUnavailable,
      passengerCapacity: 4,
    );

    test('a rider-cancel fee and a no-show fee are kept and counted in '
        "today's earnings", () async {
      final journal = CompletionJournal(active: MemoryActiveRideRepository());
      await journal.finish(trip('done'));
      await journal.finish(
        trip('cancelled'),
        status: TripStatus.cancelledByRider,
        authoritative: true,
        cancellationActor: 'rider',
        feeEarned: '45,00 kr',
      );
      await journal.finish(
        trip('no-show'),
        status: TripStatus.noShow,
        cancellationActor: 'driver',
        feeEarned: '52,00 kr',
      );
      final rows = await PrefsTripHistoryRepository().list();
      final byId = {for (final row in rows) row.tripId: row};
      expect(byId['cancelled']!.feeEarned, '45,00 kr');
      expect(byId['no-show']!.feeEarned, '52,00 kr');
      expect(byId['cancelled']!.earnedMoney, Money.ore(4500));
      // 120 + 45 + 52.
      expect(TodayEarnings.totalOf(rows, DateTime.now()), '217,00 kr');
    });

    test('rows saved before it was kept still read, with no fee', () async {
      SharedPreferences.setMockInitialValues({
        PrefsTripHistoryRepository.key: '[{"tripId":"old","riderName":"Sara",'
            '"whenLabel":"1/1/2026, 10:00","pickup":"A","dropoff":"B",'
            '"fare":"120,00 kr","category":"Comfort",'
            '"status":"cancelled_by_rider","cancellationActor":"rider",'
            '"completedAt":"2026-01-01T10:00:00.000Z"}]',
      });
      final rows = await PrefsTripHistoryRepository().list();
      expect(rows.single.feeEarned, isNull);
      expect(rows.single.earnedMoney, Money.ore(0));
    });
  });
}
