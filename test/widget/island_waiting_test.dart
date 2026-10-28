import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/presentation/driver/home/components/island_waiting.dart';

void main() {
  final demo = IslandWaitingSignals.demo(
    const DriverHomeAdminContentService().load(),
  ).tips();

  testWidgets('waiting messages rotate, never the same kind twice in a row', (
    tester,
  ) async {
    {
      final waiting = IslandWaitingController(tips: () => demo);
      final shown = <String>[];
      waiting.addListener(() {
        if (waiting.tip case final tip?) {
          shown.add(tip.id);
        }
      });
      expect(waiting.sync(true), isTrue);
      expect(waiting.tip, isNull, reason: 'Finding trips first');
      await tester.pump(const Duration(minutes: 3));
      expect(shown.length, greaterThan(demo.length));
      for (var i = 1; i < shown.length; i++) {
        expect(shown[i], isNot(shown[i - 1]));
      }
      expect(shown.toSet(), demo.map((t) => t.id).toSet());
      waiting.dispose();
    }
  });

  testWidgets(
    'a touch hides the waiting faces, which come back when left alone',
    (tester) async {
      {
        final waiting = IslandWaitingController(tips: () => demo);
        waiting.sync(true);
        expect(waiting.touch(), isTrue);
        expect(waiting.showing, isFalse);
        expect(waiting.takeSwallowedTap(), isTrue);
        await tester.pump(waiting.resumeAfter);
        expect(waiting.showing, isTrue);
        // An offer: nothing shows, and no message pops up meanwhile.
        waiting.sync(false);
        await tester.pump(const Duration(minutes: 1));
        expect(waiting.showing, isFalse);
        expect(waiting.tip, isNull);
        waiting.dispose();
      }
    },
  );

  test('only facts the app has make a message; none are negative', () {
    expect(const IslandWaitingSignals().tips(), isEmpty);
    expect(
      demo.map((t) => t.title),
      containsAll(<String>[
        'High boost nearby',
        'Expect a trip in 2–5 min',
        'Busy area · trips expected soon',
        'Demand rising near you',
        'Airport queue: 4 drivers',
        'Peak hours start at 18:00',
        'Good streak · 3 trips in a row',
        "You're in a top zone right now",
        'Promotion · 3 rides = 159 kr',
      ]),
    );
    for (final tip in demo) {
      expect(tip.title.toLowerCase(), isNot(contains('quiet')));
    }
  });
}
