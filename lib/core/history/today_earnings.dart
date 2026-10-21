import 'package:flutter/foundation.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/money/money.dart';

/// Today's earnings for the island's TODAY face, on Home and on the trip
/// screen (driver-u125): the trips completed today on this phone, counted
/// as Ride history counts its Today. It was a sample figure before.
class TodayEarnings {
  TodayEarnings._();

  /// Shown while the total is not known, or when a fare is unreadable.
  static const String unknown = '—';

  static final ValueNotifier<String?> _label = ValueNotifier<String?>(null);

  /// Today's total, e.g. `261,00 kr`; null until read or when unknown.
  static ValueListenable<String?> get label => _label;

  /// Reads the recorded trips again; the TODAY face calls it as it opens.
  static Future<void> refresh({
    Future<List<TripHistoryRecord>> Function()? read,
  }) async {
    try {
      final records = await (read ?? PrefsTripHistoryRepository().list)();
      _label.value = totalOf(records, DateTime.now());
    } catch (_) {
      _label.value = null;
    }
  }

  /// The completed trips on [now]'s day; null when one has no readable
  /// fare (Ride history then says "unavailable").
  static String? totalOf(Iterable<TripHistoryRecord> records, DateTime now) {
    var total = 0;
    for (final record in records) {
      final at = record.completedAt;
      if (record.status != TripStatus.completed || at == null) { continue; }
      final local = at.toLocal();
      if (local.year != now.year || local.month != now.month ||
          local.day != now.day) {
        continue;
      }
      final fare = record.fareMoney;
      if (fare == null) { return null; }
      total += fare.minorUnits;
    }
    return Money.ore(total).formatted;
  }

  @visibleForTesting
  static void reset() => _label.value = null;
}
