import 'package:movera/core/money/money.dart';

/// Owner button 2026-11-20 "Change meter to app (Rec.)": the driver sets
/// the taximeter to the app's price. Before the start the meter follows
/// the server's `fare` as it is at the start; after the start every new
/// `fare` from the server is a price the driver must type in again.
///
/// Only the server's own amount is kept and handed back: nothing is added
/// or worked out on the phone.
class MeterPriceWatch {
  Money? _meter;

  /// The server's new price when [fare] differs from the price the meter
  /// has, while the trip is [started]; null otherwise. Before the start
  /// (or the first price seen) [fare] only becomes the meter's price.
  Money? observe(Money? fare, {required bool started}) {
    if (fare == null) return null;
    final meter = _meter;
    _meter = fare;
    if (!started || meter == null || meter == fare) return null;
    return fare;
  }
}
