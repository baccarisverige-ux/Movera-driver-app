import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/routing/route_instruction.dart';

TripIslandInput input({
  NavigationBanner? banner,
  String? status,
  String? arrival,
  bool arrived = false,
  int? waiting,
  int? paid,
  bool atStop = false,
}) => TripIslandInput(
  status: 'To pickup',
  address: 'Storgatan 8',
  waitingMessage: atStop ? 'Waiting at stop 2' : 'Waiting for Angelica',
  banner: banner,
  navigationStatus: status,
  arrival: arrival,
  arrived: arrived,
  waitingSeconds: waiting,
  paidWait: paid != null,
  paidSeconds: paid,
  waitingAtStop: atStop,
);
void main() {
  test(
    'Real maneuver wins over arrival proximity; faults win over old guidance',
    () {
      final c = TripIslandController(
        input(
          arrival: 'Pickup',
          banner: const NavigationBanner(
            primary: 'Turn right in 80 m',
            distanceLabel: '80 m',
            symbol: NavigationBannerSymbol.right,
          ),
        ),
      );
      expect(c.face.kind, TripIslandKind.guidance);
      expect(c.face.title, 'Turn right in 80 m');
      c.update(
        input(
          status: 'Recalculating route…',
          arrival: 'Pickup',
          banner: const NavigationBanner(
            primary: 'Turn right',
            distanceLabel: '',
            symbol: NavigationBannerSymbol.right,
          ),
        ),
      );
      expect(c.face.kind, TripIslandKind.status);
      expect(c.face.title, 'Recalculating route…');
      c.dispose();
    },
  );
  test('Proximity does not claim a confirmed arrival', () {
    final c = TripIslandController(input(arrival: 'Pickup', arrived: true));
    expect(c.face.title, 'Near pickup');
    c.dispose();
  });
  test('Paid pickup and stop clocks use their own elapsed time', () {
    final c = TripIslandController(input(waiting: 155, paid: 35));
    expect(c.face.title, '0:35');
    expect(c.face.subtitle, 'Paid waiting');
    c.update(input(waiting: 80, paid: 80, atStop: true));
    expect(c.face.title, '1:20');
    expect(c.face.subtitle, 'Waiting at stop');
    c.dispose();
  });
  testWidgets('stale release callback does not open island after a new touch', (
    tester,
  ) async {
    final c = TripIslandController(input());
    addTearDown(c.dispose);
    c.release(); // Spurious pointer-up must never reveal the default face.
    await tester.pump();
    expect(c.defaultFace, isFalse);

    c.hold();
    c.release();
    c.hold(); // New pointer-down arrives before release microtask runs.
    await tester.pump();
    expect(c.defaultFace, isFalse);

    c.release();
    await tester.pump();
    expect(c.defaultFace, isTrue);
    await tester.pump(const Duration(seconds: 1));
    c.hold(); // Cancels the old idle timer.
    await tester.pump(const Duration(seconds: 2));
    expect(c.defaultFace, isTrue);
    c.release();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(c.defaultFace, isFalse);
  });

  testWidgets('dispose prevents pending touch callback and late updates', (
    tester,
  ) async {
    final c = TripIslandController(input(waiting: 0));
    c.hold();
    c.release();
    c.dispose();
    await tester.pump();
    expect(c.defaultFace, isFalse);
    c.update(input(waiting: 1));
    c.hold();
    c.release();
    await tester.pump(const Duration(seconds: 10));
    expect(c.defaultFace, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GPS/clock ticks preserve waiting cycle; touch expires after two idle seconds',
    (tester) async {
      final c = TripIslandController(input(waiting: 0));
      await tester.pump(const Duration(seconds: 7));
      c.update(input(waiting: 7));
      await tester.pump(const Duration(seconds: 1));
      expect(c.face.kind, TripIslandKind.waitingMessage);
      c.hold();
      c.release();
      await tester.pump();
      expect(c.defaultFace, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(c.defaultFace, isFalse);
      expect(c.face.kind, TripIslandKind.waitingTimer);
      c.dispose();
    },
  );
}
