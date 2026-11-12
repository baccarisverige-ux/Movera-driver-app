import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/zones/position_zone_hold.dart';

/// F2: a position's zone is used only after it held (2 updates, 15 s).
void main() {
  late DateTime clock;
  late PositionZoneHold hold;
  setUp(() {
    clock = DateTime.utc(2026, 11, 12, 10);
    hold = PositionZoneHold(now: () => clock);
  });
  void after(int seconds) => clock = clock.add(Duration(seconds: seconds));

  test('nothing known until a first zone; that one applies at once', () {
    expect(hold.observe(null), isNull);
    expect(hold.known, isFalse);
    expect(hold.observe('A'), 'A');
    expect(hold.known, isTrue);
  });

  test('two updates are not enough before 15 s, nor 15 s with one', () {
    hold.observe('A');
    after(1);
    expect(hold.observe('B'), 'A');
    after(5);
    expect(hold.observe('B'), 'A', reason: '2 updates, 6 s');
    after(10);
    expect(hold.observe('B'), 'B', reason: '3 updates, 16 s');
  });

  test('back to the zone in use, or a third zone, starts over', () {
    hold.observe('A');
    hold.observe('B');
    after(20);
    expect(hold.observe('A'), 'A');
    expect(hold.observe('B'), 'A', reason: 'a new first update');
    after(20);
    expect(hold.observe('C'), 'A', reason: 'C starts over');
    after(16);
    expect(hold.observe('C'), 'C');
  });

  test('leaving every zone (null) holds the same way', () {
    hold.observe('A');
    expect(hold.observe(null), 'A');
    after(15);
    expect(hold.observe(null), isNull);
    expect(hold.zone, isNull);
  });
}
