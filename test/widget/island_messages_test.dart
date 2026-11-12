import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';

void main() {
  setUp(IslandMessages.reset);

  test('important messages go ahead of quick ones still waiting', () {
    IslandMessages.show(
      const IslandMessage(title: 'Radar online', priority: IslandPriority.low),
    );
    IslandMessages.show(const IslandMessage(title: 'New reservation'));
    IslandMessages.show(
      const IslandMessage(
        title: 'Rider cancelled',
        priority: IslandPriority.high,
      ),
    );

    expect(IslandMessages.take()?.title, 'Rider cancelled');
    expect(IslandMessages.take()?.title, 'Radar online');
    expect(IslandMessages.take()?.title, 'New reservation');
    expect(IslandMessages.take(), isNull);
  });

  test('message times follow importance: 2 s, 3 s, 4.5 s', () {
    expect(IslandPriority.low.duration, const Duration(seconds: 2));
    expect(IslandPriority.normal.duration, const Duration(seconds: 3));
    expect(IslandPriority.high.duration, const Duration(milliseconds: 4500));
  });

  test('posting notifies the island', () {
    var calls = 0;
    void listener() => calls++;
    IslandMessages.changes.addListener(listener);
    addTearDown(() => IslandMessages.changes.removeListener(listener));
    IslandMessages.show(const IslandMessage(title: 'Matching…'));
    expect(calls, 1);
    expect(IslandMessages.peek()?.title, 'Matching…');
  });

  // Owner 2026-11-12 "Keep both": two waiting reminders about different
  // booked rides (e.g. both came due while a trip covered Home) are both
  // shown, one after the other.
  test('two reminders about different rides both wait', () {
    IslandMessages.show(
      HomeIslandNotices.scheduledReminder('07:40', '15 min').forRide('r1'),
    );
    IslandMessages.show(
      HomeIslandNotices.scheduledReminder('08:10', '15 min').forRide('r2'),
    );

    expect(IslandMessages.take()?.title, contains('07:40'));
    expect(IslandMessages.take()?.title, contains('08:10'));
    expect(IslandMessages.take(), isNull);
  });

  test('two accepted reservations both wait', () {
    IslandMessages.show(
      HomeIslandNotices.reservationAcceptedAt('19:30').forRide('r1'),
    );
    IslandMessages.show(
      HomeIslandNotices.reservationAcceptedAt('21:00').forRide('r2'),
    );

    expect(IslandMessages.take()?.title, contains('19:30'));
    expect(IslandMessages.take()?.title, contains('21:00'));
    expect(IslandMessages.take(), isNull);
  });

  test('a newer word about the same ride replaces the waiting one', () {
    IslandMessages.show(
      HomeIslandNotices.scheduledReminder('07:40', '15 min').forRide('r1'),
    );
    IslandMessages.show(
      HomeIslandNotices.scheduledReminder('07:40', '5 min').forRide('r1'),
    );

    expect(IslandMessages.take()?.title, contains('5 min'));
    expect(IslandMessages.take(), isNull);
  });

  test('a won offer drops only its own waiting offer notices', () {
    // "Assigned by Movera" for booked ride B waits; offer A's accept
    // notices wait too; A's trip opens.
    IslandMessages.show(HomeIslandNotices.assignedRide.forRide('B'));
    IslandMessages.show(HomeIslandNotices.accepting.forRide('A'));
    IslandMessages.show(HomeIslandNotices.exclusiveRide.forRide('A'));
    IslandMessages.show(HomeIslandNotices.matched.forRide('A'));
    IslandMessages.dropOffer('A', HomeIslandNotices.offerGroups);

    expect(IslandMessages.take()?.ride, 'B');
    expect(IslandMessages.take(), isNull);
  });
}
