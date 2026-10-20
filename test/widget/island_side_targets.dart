import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a touch at [at] reaches the widget [target] finds.
bool hitsTarget(WidgetTester tester, Finder target, Offset at) {
  final box = tester.renderObject(target);
  final result = tester.hitTestOnBinding(at);
  return result.path.any((entry) => entry.target == box);
}

/// UI-12: the 48 x 48 touch boxes of the island's side buttons. Each box
/// starts at the top of the visible button and reaches past its outer edge.
(Rect, Rect) sideTargetBoxes(Rect menu, Rect search) => (
  Rect.fromLTWH(menu.right - 48, menu.top, 48, 48),
  Rect.fromLTWH(search.left, search.top, 48, 48),
);

/// Every corner of each 48 x 48 box hits its button; just outside it, and
/// below the middle of the island, does not.
void expectSideTargets(
  WidgetTester tester, {
  required Finder menu,
  required Finder search,
  required Finder middle,
  required double screenWidth,
}) {
  final (menuBox, searchBox) = sideTargetBoxes(
    tester.getRect(menu),
    tester.getRect(search),
  );
  for (final (finder, box) in [(menu, menuBox), (search, searchBox)]) {
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(screenWidth));
    for (final corner in [
      box.topLeft + const Offset(.5, .5),
      box.topRight + const Offset(-.5, .5),
      box.bottomLeft + const Offset(.5, -.5),
      box.bottomRight + const Offset(-.5, -.5),
    ]) {
      expect(hitsTarget(tester, finder, corner), isTrue, reason: '$corner of $box');
    }
    expect(
      hitsTarget(tester, finder, box.bottomCenter + const Offset(0, 1.5)),
      isFalse,
      reason: 'below $box',
    );
  }
  expect(
    hitsTarget(tester, menu, menuBox.centerLeft - const Offset(1.5, 0)),
    isFalse,
  );
  expect(
    hitsTarget(tester, search, searchBox.centerRight + const Offset(1.5, 0)),
    isFalse,
  );
  // Below the middle of the island the map still takes the touch.
  final centre = tester.getRect(middle);
  final under = Offset(centre.center.dx, menuBox.bottom - 2);
  expect(hitsTarget(tester, middle, under), isFalse);
  expect(hitsTarget(tester, menu, under), isFalse);
  expect(hitsTarget(tester, search, under), isFalse);
}
