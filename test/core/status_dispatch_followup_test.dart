import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/routing/route_instruction.dart';

TripIslandInput _input({String? fault, NavigationBanner? banner}) =>
    TripIslandInput(
      status: 'To pickup',
      address: 'Storgatan 8',
      waitingMessage: 'Waiting for rider',
      navigationStatus: fault,
      banner: banner,
    );

void main() {
  test(
    'S01 delayed nearby listener receives current filtered snapshot',
    () async {
      final repo = DemoDispatchRepository(claimDelay: Duration.zero);
      addTearDown(repo.dispose);
      final stream = repo.watchNearbyOffers(destinationModeActive: true);
      await Future<void>.delayed(Duration.zero);
      await repo.claimOffer('nearby-2');
      final initial = await stream.first.timeout(const Duration(seconds: 1));
      expect(initial.map((offer) => offer.id), ['nearby-3']);
      expect(() => initial.clear(), throwsUnsupportedError);
    },
  );

  test('S01 each nearby listener gets one initial snapshot without replay to others', () async {
    final repo = DemoDispatchRepository();
    addTearDown(repo.dispose);
    final stream = repo.watchNearbyOffers();
    final first = <List<RideOffer>>[];
    final firstSub = stream.listen(first.add);
    addTearDown(firstSub.cancel);
    await Future<void>.delayed(Duration.zero);
    final second = await stream.first.timeout(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    expect(second, hasLength(3));
    expect(first, hasLength(1));
    repo.refreshOffers();
    await Future<void>.delayed(Duration.zero);
    expect(first, hasLength(2));
  });

  test(
    'S01 delayed and repeated next-trip listeners receive empty snapshot',
    () async {
      final repo = DemoDispatchRepository();
      addTearDown(repo.dispose);
      final stream = repo.watchNextTripOffers();
      await Future<void>.delayed(Duration.zero);
      expect(await stream.first.timeout(const Duration(seconds: 1)), isEmpty);
      expect(await stream.first.timeout(const Duration(seconds: 1)), isEmpty);
    },
  );

  testWidgets(
    'S02 watching disposed dispatch creates no timers and closes streams',
    (tester) async {
      final repo = DemoDispatchRepository();
      repo.dispose();
      var timers = 0;
      final nearby = <List<RideOffer>>[];
      final nextTrip = <List<RideOffer>>[];
      var closed = 0;
      runZoned(
        () {
          repo.watchNearbyOffers().listen(nearby.add, onDone: () => closed++);
          repo.watchNextTripOffers().listen(
            nextTrip.add,
            onDone: () => closed++,
          );
        },
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            timers++;
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
      await tester.pump();
      expect(timers, 0);
      expect(nearby, isEmpty);
      expect(nextTrip, isEmpty);
      expect(closed, 2);
    },
  );

  testWidgets(
    'S03 touching an active navigation fault keeps the status visible',
    (tester) async {
      final island = TripIslandController(_input(fault: 'Location updating…'));
      addTearDown(island.dispose);
      island.hold();
      island.release();
      await tester.pump();
      expect(island.defaultFace, isFalse);
      expect(island.face.title, 'Location updating…');
      await tester.pump(const Duration(seconds: 2));
      expect(island.defaultFace, isFalse);
    },
  );

  testWidgets(
    'S03 new banner fault overrides already revealed default controls',
    (tester) async {
      final island = TripIslandController(_input());
      addTearDown(island.dispose);
      island.hold();
      island.release();
      await tester.pump();
      expect(island.defaultFace, isTrue);
      island.update(
        _input(
          banner: const NavigationBanner(
            primary: 'Continue ahead',
            distanceLabel: '',
            symbol: NavigationBannerSymbol.straight,
            status: 'Recalculating route…',
          ),
        ),
      );
      expect(island.defaultFace, isFalse);
      expect(island.face.title, 'Recalculating route…');
      island.update(_input());
      expect(island.defaultFace, isFalse);
      island.hold();
      island.release();
      await tester.pump();
      expect(island.defaultFace, isTrue);
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
