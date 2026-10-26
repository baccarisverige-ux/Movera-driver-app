import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/navigation/map_zoom_sheet_settle.dart';

void main() {
  test('pinch zoom keeps the trip sheet still until both fingers lift', () {
    final settle = MapZoomSheetSettle();
    settle.pointerDown(10);
    settle.pointerDown(20);
    expect(settle.activePointers, 2);
    expect(
      settle.requestCollapse(),
      isFalse,
      reason: 'Map pinch must not move the bottom sheet mid-zoom',
    );
    expect(
      settle.pointerEnded(10),
      isFalse,
      reason: 'One remaining finger is still controlling the map',
    );
    expect(settle.activePointers, 1);
    expect(
      settle.pointerEnded(20),
      isTrue,
      reason: 'The browse sheet can collapse once both fingers lift',
    );
    expect(
      settle.pointerEnded(20),
      isFalse,
      reason: 'Duplicate up/cancel must not collapse twice',
    );
  });

  test('manual native zoom with no active Flutter pointers settles now', () {
    final settle = MapZoomSheetSettle();
    expect(
      settle.requestCollapse(),
      isTrue,
      reason: 'Keyboard or native zoom control has no active map fingers',
    );
    expect(settle.pointerEnded(1), isFalse);
  });

  test('recentering cancels delayed collapse after a held pinch', () {
    final settle = MapZoomSheetSettle();
    settle.pointerDown(1);
    expect(settle.requestCollapse(), isFalse);
    settle.cancel();
    expect(
      settle.pointerEnded(1),
      isFalse,
      reason: 'Recenter must never trigger an obsolete sheet collapse',
    );
  });

  test('active pointer identities prevent duplicate down or mismatched up', () {
    final settle = MapZoomSheetSettle();
    settle.pointerDown(1);
    settle.pointerDown(1);
    settle.pointerDown(2);
    expect(settle.activePointers, 2);
    expect(settle.requestCollapse(), isFalse);
    expect(settle.pointerEnded(99), isFalse);
    expect(settle.activePointers, 2);
    expect(settle.pointerEnded(1), isFalse);
    expect(settle.pointerEnded(2), isTrue);
    expect(
      settle.requestCollapse(),
      isTrue,
      reason: 'A later independent zoom interaction is still functional',
    );
  });
}
