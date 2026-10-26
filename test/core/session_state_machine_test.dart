import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';

typedef _Setup = void Function(DriverSessionController session);

void main() {
  // (description, before trip, during trip, expected after trip)
  final cases = <(String, _Setup, _Setup, DriverOnlineStatus)>[
    (
      'online driver returns online',
      (s) => s.setOnline(true),
      (_) {},
      DriverOnlineStatus.online,
    ),
    (
      'offline restored trip returns offline',
      (_) {},
      (_) {},
      DriverOnlineStatus.offline,
    ),
    (
      'suspension during trip survives the trip end',
      (s) => s.setOnline(true),
      (s) => s.suspend(),
      DriverOnlineStatus.suspended,
    ),
    (
      'suspended before restored trip stays suspended',
      (s) => s.suspend(),
      (_) {},
      DriverOnlineStatus.suspended,
    ),
    (
      'go offline during trip applies after the trip',
      (s) => s.setOnline(true),
      (s) => s.setOnline(false),
      DriverOnlineStatus.offline,
    ),
    (
      'offline intent can be withdrawn during trip',
      (s) => s.setOnline(true),
      (s) {
        s.setOnline(false);
        s.setOnline(true);
      },
      DriverOnlineStatus.online,
    ),
    (
      'suspension wins over online intent',
      (s) => s.setOnline(true),
      (s) {
        s.suspend();
        s.setOnline(true);
      },
      DriverOnlineStatus.suspended,
    ),
  ];

  for (final (name, before, during, expected) in cases) {
    test(name, () async {
      final store = MemoryDriverSessionRepository();
      final session = DriverSessionController(repository: store);
      before(session);
      session.beginTrip('trip-a');
      expect(session.status, DriverOnlineStatus.onTrip);
      expect(session.availableForOffers, isFalse);
      during(session);
      expect(session.activeTripId, 'trip-a');
      session.endTrip();
      expect(session.status, expected);
      expect(session.activeTripId, isNull);
      expect(session.availableForOffers, expected == DriverOnlineStatus.online);
      await Future<void>.delayed(Duration.zero);
      expect(await store.readOnline(), expected == DriverOnlineStatus.online);
    });
  }

  test('queued next trip keeps the pre-trip availability across the chain', () {
    final session = DriverSessionController();
    session.suspend();
    session.beginTrip('a');
    session.endTrip();
    session.beginTrip('b');
    session.endTrip();
    expect(session.status, DriverOnlineStatus.suspended);
  });

  test('legacy stayOnlineAfterTrip no longer bypasses suspension', () {
    final session = DriverSessionController()..setOnline(true);
    session.beginTrip('a');
    session.suspend();
    session.stayOnlineAfterTrip();
    expect(session.isSuspended, isTrue);
    expect(session.consumeResumeHomeAfterTrip(), isTrue);
  });

  test('reset clears pending after-trip intents', () {
    final session = DriverSessionController()..setOnline(true);
    session.beginTrip('a');
    session.suspend();
    session.reset();
    session.setOnline(true);
    expect(session.status, DriverOnlineStatus.online);
  });

  test('rapid A-to-B trip handoff cannot consume an old Home return hint', () {
    final session = DriverSessionController()..setOnline(true);
    addTearDown(session.dispose);
    session.beginTrip('trip-A');
    session.endTrip();
    // Home can be offstage or restoring when B begins immediately.
    session.beginTrip('trip-B');
    expect(session.status, DriverOnlineStatus.onTrip);
    expect(session.activeTripId, 'trip-B');
    expect(session.consumeResumeHomeAfterTrip(), isFalse);
    session.endTrip();
    expect(session.consumeResumeHomeAfterTrip(), isTrue);
    expect(session.consumeResumeHomeAfterTrip(), isFalse);
  });

  test(
    'duplicate current-trip start preserves a pending Home return state',
    () {
      final session = DriverSessionController()..setOnline(true);
      addTearDown(session.dispose);
      session.beginTrip('trip-A');
      session.endTrip();
      // The new trip owns the session; duplicate mount stays a no-op.
      session.beginTrip('trip-B');
      session.beginTrip('trip-B');
      expect(session.consumeResumeHomeAfterTrip(), isFalse);
      session.endTrip();
      expect(session.consumeResumeHomeAfterTrip(), isTrue);
    },
  );

  test(
    'duplicate trip end cannot reactivate a deliberately offline driver',
    () async {
      final store = MemoryDriverSessionRepository();
      final session = DriverSessionController(repository: store);
      session.setOnline(true);
      session.beginTrip('trip-a');
      session.setOnline(false);
      session.endTrip();
      expect(session.status, DriverOnlineStatus.offline);
      session.endTrip(); // A duplicate terminal event must remain a no-op.
      expect(session.status, DriverOnlineStatus.offline);
      expect(session.activeTripId, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(await store.readOnline(), isFalse);
      session.dispose();
    },
  );

  test('stale trip end cannot bypass suspension or going-online gate', () {
    final session = DriverSessionController();
    session.suspend();
    session.endTrip();
    expect(session.status, DriverOnlineStatus.suspended);
    session.reset();
    session.beginGoingOnline();
    session.endTrip();
    expect(session.status, DriverOnlineStatus.goingOnline);
    expect(session.availableForOffers, isFalse);
    session.dispose();
  });

  test('late terminal event after explicit offline request stays offline', () {
    final session = DriverSessionController()..setOnline(true);
    session.beginTrip('trip-a');
    session.endTrip();
    session.setOnline(false);
    session.stayOnlineAfterTrip();
    expect(session.status, DriverOnlineStatus.offline);
    expect(session.availableForOffers, isFalse);
    session.dispose();
  });

  test('duplicate and foreign trip starts preserve active trip ownership', () {
    final session = DriverSessionController()..setOnline(true);
    session.beginTrip('trip-a');
    session.setOnline(false); // Remember the offline intent while occupied.
    session.beginTrip('trip-a'); // Same trip remounted after a route rebuild.
    session.beginTrip('trip-b'); // Stale competing route may not steal it.
    session.beginTrip(' ');
    expect(session.activeTripId, 'trip-a');
    expect(session.status, DriverOnlineStatus.onTrip);
    session.endTrip();
    expect(session.status, DriverOnlineStatus.offline);
    expect(session.activeTripId, isNull);
    session.beginTrip('trip-b'); // Legitimate next trip after the first ends.
    expect(session.activeTripId, 'trip-b');
    session.endTrip();
    expect(session.status, DriverOnlineStatus.offline);
    session.dispose();
  });

  test('demo dispatch reset restores the first-launch offers', () async {
    final dispatch = DemoDispatchRepository(
      claimDelay: Duration.zero,
      newOfferDelay: const Duration(hours: 1),
      externalClaimDelay: const Duration(hours: 1),
    );
    final seen = <List<String>>[];
    final sub = dispatch.watchNearbyOffers().listen(
      (offers) => seen.add(offers.map((o) => o.id).toList()),
    );
    await Future<void>.delayed(Duration.zero);
    await dispatch.claimOffer('nearby-1');
    dispatch.reset();
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, contains('nearby-1'));
    await sub.cancel();
    dispatch.dispose();
  });
}
