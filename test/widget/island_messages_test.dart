import 'package:flutter_test/flutter_test.dart';
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
}
