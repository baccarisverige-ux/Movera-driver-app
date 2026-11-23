import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';

/// PAY's check of the driver's share ("you get").
///
/// Owner 2026-11-21 14:55 hid the earnings card on the collect screen
/// (cash_collect_sheet.dart `showEarnings: false`), so the share is no
/// longer looked for there. It is checked where the driver sees it now:
/// the Ride completed page's "Din andel" (`ride-completed-fare`,
/// ride_completed.dart), the same number the waybill keeps.
class PayVerdict {
  const PayVerdict._();

  /// The texts of the share widget itself. `ride-completed-fare` is the
  /// key ON the `Text.rich` (ride_completed.dart), so a plain
  /// `find.descendant` (matchRoot false) finds no Text under it and the
  /// share read as missing (Firebase run 45126933400: 112,83 kr
  /// shown=false while the screen showed it). The root is matched too.
  static List<String> shareTexts(Finder share) => <String>[
    for (final e
        in find
            .descendant(of: share, matching: find.byType(Text), matchRoot: true)
            .evaluate())
      if ((e.widget as Text).data case final t?)
        t
      else if ((e.widget as Text).textSpan case final s?)
        s.toPlainText(),
  ];

  /// null when the server sent no share (nothing to compare); else whether
  /// one of [shown] (texts of the Ride completed share) IS [share] in its
  /// full or short form: an exact match, so 12,83 kr never passes for
  /// 112,83 kr.
  static bool? shareShown(Money? share, List<String> shown) {
    if (share == null) return null;
    final want = {share.formatted, share.formattedShort};
    return shown.any((t) => want.contains(t.trim()));
  }

  /// PAY passes when the cash to collect matches, the trip completed with
  /// the preview's fare, Ride completed shows, and the share (when sent)
  /// is on Ride completed. The collect screen's balance is not needed.
  static bool good({
    required String? shownCash,
    required String wantCash,
    required bool? shareShown,
    required bool completed,
    required bool fareMatches,
    required bool finishedShown,
  }) =>
      shownCash == wantCash &&
      shareShown != false &&
      completed &&
      fareMatches &&
      finishedShown;
}
