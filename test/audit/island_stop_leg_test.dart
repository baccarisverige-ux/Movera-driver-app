import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/island/trip_island_controller.dart';

/// driver-u22: every stop-to-stop leg has `TripLeg.stop`. The next stop must
/// still start a new leg, or it inherits the floored ETA of the stop just
/// reached and the strip says "Traffic ahead" when the longer route loads.
void main() {
  testWidgets('the next stop starts a new leg: no false traffic, own announcement', (tester) async {
    final strip = TripStripController(clock: () => DateTime(2026, 1, 1, 6));
    addTearDown(strip.dispose);
    final seen = <String>[];
    strip.addListener(() {
      if (strip.current.kind == TripStripKind.message) seen.add(strip.current.text);
    });

    strip.update(const TripStripInput(leg: TripLeg.stop, stopLabel: 'Stop 1', etaMinutes: 9));
    await tester.pump(TripStripController.messageTime);
    for (final eta in [6, 3, 1]) {
      strip.update(TripStripInput(leg: TripLeg.stop, stopLabel: 'Stop 1', etaMinutes: eta));
    }
    // Paid stop wait over, slide on: the route to stop 2 loads, then 9 min.
    strip.update(const TripStripInput(leg: TripLeg.stop, stopLabel: 'Stop 2'));
    await tester.pump(TripStripController.messageTime);
    strip.update(const TripStripInput(leg: TripLeg.stop, stopLabel: 'Stop 2', etaMinutes: 9));
    await tester.pump(TripStripController.messageTime);

    expect(seen.where((t) => t.startsWith('Traffic ahead')), isEmpty);
    expect(seen, contains('Stop 2 next'));
  });
}
