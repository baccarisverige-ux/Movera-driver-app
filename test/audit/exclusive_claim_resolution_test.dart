import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.1): an Exclusive Accept (admin direct assign, reservation
// close to pickup, assigned ride) whose answer from dispatch arrives
// after something else happened on Home.
// - driver-u131: Go offline from the island while the admin assign's
//   Accept is with dispatch; a won claim must still open its trip.
// - driver-r3-14: a network error on Accept while Home is hidden: the
//   re-armed time out must not run in the background and count a miss.
// - driver-u140: a category switched off while the reservation's Accept
//   is with dispatch; a won claim must still open its trip.
// - driver-73: a route covers Home as the claim is won: the trip opens
//   once Home is back on top, like a won Radar Match.
// - Decision 3 ("the accept wins"): the driving limit reached while a
//   claim is with dispatch waits for the answer; won, the trip is driven
//   and the driver is offline after it; lost, offline at once.

/// Dispatch whose claims the test answers.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  final assignments = StreamController<ReservationRequestPreview>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <Completer<ClaimResult>>[];
  final claimed = <String>[];

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
  Future<ClaimResult> claimOffer(String offerId) {
    claimed.add(offerId);
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

/// Which Exclusive offer the test accepts.
enum _Kind {
  /// Contract §3.1: an admin direct assign from dispatch.
  assign,

  /// The demo reservation close to its 07:40 pickup (its Exclusive step
  /// is reached 20 min before, about 40 s into the fast test day).
  reservation,

  /// Q29: a ride Movera assigned to this driver; Accept keeps it for later.
  assigned,
}

extension on _Kind {
  String get id => switch (this) {
    _Kind.assign => DemoAdminOffers.directAssign.id,
    _Kind.reservation => demoReservationId,
    _Kind.assigned => DemoReservations.assigned.id,
  };

  Key get card => ValueKey<String>('exclusive-offer-card-$id');

  /// Dispatch's answer when the claim wins.
  ClaimResult get won => switch (this) {
    _Kind.assign => ClaimResult.success(DemoAdminOffers.directAssign),
    _Kind.reservation => ClaimResult.success(
      RideOffer.reservation(DemoReservations.main),
    ),
    _Kind.assigned => ClaimResult.success(
      RideOffer.reservation(DemoReservations.assigned),
    ),
  };

  String get matchedVia => switch (this) {
    _Kind.assign => 'Assigned by Movera',
    _Kind.reservation => 'Exclusive reservation',
    _Kind.assigned => throw StateError('kept for later, never a trip now'),
  };

  /// How long until the offer is up, counted from going online.
  Duration get arrives => switch (this) {
    _Kind.reservation => const Duration(seconds: 50),
    _ => const Duration(seconds: 5),
  };
}

typedef _Home = ({_Dispatch dispatch, DriverSessionController session});

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  Duration limit = const Duration(seconds: 5),
}) async {
  for (
    var t = Duration.zero;
    t < limit && finder.evaluate().isEmpty;
    t += const Duration(milliseconds: 100)
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

/// Home online, with the app's route observer so a screen pushed over
/// Home pauses it, as in the app.
Future<_Home> _pumpHome(WidgetTester tester, _Kind kind) async {
  final dispatch = _Dispatch()
    ..offers = kind == _Kind.assign ? [DemoAdminOffers.directAssign] : const [];
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
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  // Radar on, as the driver does.
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  await _frames(tester, const Duration(milliseconds: 1500));
  if (kind == _Kind.assigned) {
    dispatch.assignments.add(DemoReservations.assigned);
  }
  await _until(tester, find.byKey(kind.card), limit: kind.arrives);
  return (dispatch: dispatch, session: session);
}

/// The sheet settles, then Accept: the claim is with dispatch.
Future<void> _accept(WidgetTester tester, _Home home) async {
  await _frames(tester, const Duration(milliseconds: 1500));
  await tester.tap(find.byKey(const ValueKey<String>('home-radar-exclusive')));
  await tester.pump();
  expect(home.dispatch.claims, hasLength(1));
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void _pause(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

AcceptRide _trip(WidgetTester tester) =>
    tester.widget<AcceptRide>(find.byType(AcceptRide, skipOffstage: false));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    DriverCategoryChoice.reset();
  });

  group('driver-u131: Go offline while the admin assign\'s Accept is sent', () {
    testWidgets('the won claim still opens its trip', (tester) async {
      final home = await _pumpHome(tester, _Kind.assign);
      await _accept(tester, home);
      // "Matching…" is on the island, where a long press asks "Go
      // offline?"; the driver confirms.
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('last-trip-launcher')),
          )
          .onLongPress
          ?.call();
      await _frames(tester, const Duration(milliseconds: 600));
      final yes = find.byKey(const ValueKey<String>('go-offline-yes'));
      if (yes.evaluate().isNotEmpty) {
        await tester.tap(yes);
        await _frames(tester, const Duration(milliseconds: 600));
      }
      home.dispatch.claims.single.complete(_Kind.assign.won);
      await _frames(tester, const Duration(seconds: 2));
      expect(
        find.byType(AcceptRide, skipOffstage: false),
        findsOneWidget,
        reason: 'dispatch gave the trip to this driver',
      );
      expect(_trip(tester).offerId, _Kind.assign.id);
      expect(_trip(tester).matchedVia, _Kind.assign.matchedVia);
      await _end(tester);
    });
  });

  group('driver-r3-14: a network error on Accept while Home is hidden', () {
    // (The reservation's Exclusive offer takes the same path; untaken it
    // simply comes back while the reservation is open, so nothing of it
    // can be seen from outside.)
    for (final kind in [_Kind.assign, _Kind.assigned]) {
      testWidgets('${kind.name}: the offer waits; back on screen it leaves, '
          'not a miss', (tester) async {
        final home = await _pumpHome(tester, kind);
        await _accept(tester, home);
        // The phone locks; dispatch's answer comes meanwhile.
        _pause(tester);
        await _frames(tester, const Duration(milliseconds: 300));
        home.dispatch.claims.single.complete(const ClaimResult.networkError());
        // Longer than any accept time (the assigned ride's is 30 s).
        await _frames(tester, const Duration(seconds: 33));
        // Hidden, the offer does not run out in the background.
        expect(ExclusiveAnswers.instance.missedInRow, 0);
        expect(_said, isNot(contains('Assignment not accepted')));
        expect(home.session.availableForOffers, isTrue);
        _resume(tester);
        await _frames(tester, const Duration(seconds: 1));
        expect(
          find.byKey(kind.card),
          findsNothing,
          reason: 'ran out unseen: it leaves on resume',
        );
        expect(
          ExclusiveAnswers.instance.missedInRow,
          0,
          reason: 'not a miss (D-05)',
        );
        expect(home.session.availableForOffers, isTrue);
        await _end(tester);
      });
    }
  });

  group('driver-u140: the reservation\'s category switched off mid-claim', () {
    testWidgets('the won reservation still opens its trip', (tester) async {
      final home = await _pumpHome(tester, _Kind.reservation);
      await _accept(tester, home);
      // Comfort goes off while dispatch decides.
      DriverCategoryChoice.off.value = {DemoReservations.main.category};
      await _frames(tester, const Duration(milliseconds: 900));
      home.dispatch.claims.single.complete(_Kind.reservation.won);
      await _frames(tester, const Duration(seconds: 2));
      expect(
        find.byType(AcceptRide, skipOffstage: false),
        findsOneWidget,
        reason: 'dispatch gave the reservation to this driver',
      );
      expect(_trip(tester).offerId, demoReservationId);
      expect(_trip(tester).matchedVia, _Kind.reservation.matchedVia);
      await _end(tester);
    });
  });

  group('driver-73: a screen covers Home as the claim is won', () {
    for (final kind in [_Kind.assign, _Kind.reservation]) {
      testWidgets('${kind.name}: the trip opens once Home is back on top', (
        tester,
      ) async {
        final home = await _pumpHome(tester, kind);
        await _accept(tester, home);
        // A drawer item (Ride history, Wallet…) pushes its screen.
        final navigator = Navigator.of(tester.element(find.byType(DriverHome)));
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('cover')),
            ),
          ),
        );
        await _frames(tester, const Duration(milliseconds: 600));
        expect(find.text('cover'), findsOneWidget);
        home.dispatch.claims.single.complete(kind.won);
        await _frames(tester, const Duration(seconds: 2));
        expect(
          find.byType(AcceptRide, skipOffstage: false),
          findsNothing,
          reason: 'the trip waits for Home',
        );
        navigator.pop();
        await _frames(tester, const Duration(seconds: 2));
        expect(
          find.byType(AcceptRide, skipOffstage: false),
          findsOneWidget,
          reason: 'dispatch gave the trip to this driver',
        );
        expect(_trip(tester).offerId, kind.id);
        expect(_trip(tester).matchedVia, kind.matchedVia);
        await _end(tester);
      });
    }
  });

  group('Decision 3: the driving limit reached while a claim is sent', () {
    /// The limit lands [after] going online: with the claim in flight.
    void limitIn(Duration after) {
      final rule = DrivingTimeClock.instance.rule;
      DrivingTimeClock.instance.load(
        worked: rule.work - after,
        offlineSince: ScheduledClock.realNow(),
      );
    }

    Future<void> untilRest(WidgetTester tester, _Home home) async {
      for (
        var i = 0;
        i < 200 && !_said.any((t) => t.startsWith('Rest until'));
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_said.any((t) => t.startsWith('Rest until')), isTrue);
      await _frames(tester, const Duration(milliseconds: 500));
    }

    for (final kind in [_Kind.assign, _Kind.reservation]) {
      testWidgets('${kind.name} won: the trip is driven, then offline', (
        tester,
      ) async {
        limitIn(kind.arrives + const Duration(seconds: 4));
        final home = await _pumpHome(tester, kind);
        await _accept(tester, home);
        await untilRest(tester, home);
        expect(
          home.session.availableForOffers,
          isTrue,
          reason: 'the app waits for dispatch\'s answer',
        );
        expect(_said, isNot(contains('Radar offline')));
        home.dispatch.claims.single.complete(kind.won);
        await _frames(tester, const Duration(seconds: 2));
        expect(
          find.byType(AcceptRide, skipOffstage: false),
          findsOneWidget,
          reason: 'the accept wins',
        );
        expect(_trip(tester).offerId, kind.id);
        expect(home.session.activeTripId, isNotNull);
        expect(
          home.session.availableAfterTrip,
          isFalse,
          reason: 'offline once the trip ends',
        );
        await _end(tester);
      });
    }

    testWidgets('lost: offline at once', (tester) async {
      limitIn(_Kind.assign.arrives + const Duration(seconds: 4));
      final home = await _pumpHome(tester, _Kind.assign);
      await _accept(tester, home);
      await untilRest(tester, home);
      expect(home.session.availableForOffers, isTrue);
      home.dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
      await _frames(tester, const Duration(seconds: 2));
      expect(find.byType(AcceptRide, skipOffstage: false), findsNothing);
      expect(home.session.availableForOffers, isFalse);
      expect(_said, contains('Radar offline'));
      await _end(tester);
    });
  });
}
