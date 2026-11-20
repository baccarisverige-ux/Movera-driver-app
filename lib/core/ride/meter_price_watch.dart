import 'dart:convert';

import 'package:movera/core/money/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner button 2026-11-20 "Change meter to app (Rec.)": the driver sets
/// the taximeter to the app's price. Before the start the meter follows
/// the server's `fare` as it is at the start; after the start every new
/// `fare` from the server is a price the driver must type in again.
///
/// Only the server's own amount is kept and handed back: nothing is added
/// or worked out on the phone. The price the driver confirmed is kept on
/// the device per trip ([MeterPriceStore]), so a change made while the
/// app was closed is shown after a restart.
class MeterPriceWatch {
  Money? _meter, _pending;
  bool _seeded = false;

  /// The meter's price as this phone knows it.
  Money? get meter => _meter;

  /// The server's new price when [fare] differs from the price the meter
  /// has, while the trip is [started]; null otherwise. Before the start
  /// (or the first price seen) [fare] only becomes the meter's price.
  /// While the stored price is not read yet ([seed]), a started trip's
  /// price waits for it.
  Money? observe(Money? fare, {required bool started}) {
    if (fare == null) return null;
    if (started && !_seeded) {
      _pending = fare;
      return null;
    }
    final meter = _meter;
    _meter = fare;
    if (!started || meter == null || meter == fare) return null;
    return fare;
  }

  /// The price stored for this trip (null for none). Returns the server's
  /// price when one seen meanwhile differs from it.
  Money? seed(Money? stored) {
    _seeded = true;
    final pending = _pending;
    _pending = null;
    _meter ??= stored;
    if (pending == null) return null;
    final before = _meter;
    _meter = pending;
    return before != null && before != pending ? pending : null;
  }
}

/// The confirmed meter price per trip on this device.
class MeterPriceStore {
  static String _key(String tripId) => 'movera.meter_fare.$tripId';

  static Future<Money?> read(String tripId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(tripId),
      );
      if (raw == null) return null;
      return Money.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String tripId, Money fare) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(tripId),
        jsonEncode(fare.toJson()),
      );
    } catch (_) {}
  }

  static Future<void> clear(String tripId) async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key(tripId));
    } catch (_) {}
  }
}
