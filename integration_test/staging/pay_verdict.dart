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

  /// null when the server sent no share (nothing to compare); else whether
  /// [shown] (texts of the Ride completed share) holds [share] in its full
  /// or short form.
  static bool? shareShown(Money? share, List<String> shown) {
    if (share == null) return null;
    final want = {share.formatted, share.formattedShort};
    return shown.any((t) => want.any(t.contains));
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
