import 'dart:convert';

import 'package:movera/core/money/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-21 14:40: when the server's trip price (`fare`) changes
/// after the driver accepted (the rider changes the destination or a stop
/// before pickup or during the trip, or waiting adds to it), the driver
/// sees a short "New price: 240 kr" notice. This keeps the last price the
/// driver was shown and says when the server's price is a new one.
///
/// Only the server's own amount is kept and handed back: nothing is added
/// or worked out on the phone. The price last shown is kept on the device
/// per trip ([MeterPriceStore]), so a change made while the app was closed
/// is shown after a restart.
class MeterPriceWatch {
  Money? _meter, _pending, _stored;
  bool _seeded = false;

  /// The last price this phone knows the driver saw.
  Money? get meter => _meter;

  /// The server's new price when [fare] differs from the price known
  /// before; null otherwise (the first price seen only becomes the known
  /// one). While the stored price is not read yet ([seed]), the price
  /// waits for it.
  Money? observe(Money? fare) {
    if (fare == null) return null;
    if (!_seeded) {
      _pending = fare;
      return null;
    }
    final meter = _meter;
    _meter = fare;
    if (meter == null || meter == fare) return null;
    return fare;
  }

  /// The price stored for this trip (null for none). Returns the server's
  /// price when one seen meanwhile differs from it.
  Money? seed(Money? stored) {
    _seeded = true;
    _stored = stored;
    final pending = _pending;
    _pending = null;
    _meter ??= stored;
    if (pending == null) return null;
    final before = _meter;
    _meter = pending;
    return before != null && before != pending ? pending : null;
  }
}

extension MeterPriceStoreMark on MeterPriceWatch {
  /// True when [fare] is not the price stored last (then it is marked as
  /// stored): the store is written only when the value changes.
  bool needsStore(Money fare) {
    if (_stored == fare) return false;
    _stored = fare;
    return true;
  }
}

/// The price last shown to the driver, per trip, on this device.
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
