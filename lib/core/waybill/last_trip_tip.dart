import 'package:flutter/foundation.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/waybill/waybill.dart';

/// Owner 2026-11-07: the island's LAST TRIP shows the trip's money and
/// the rider's tip as one total (60,00 kr + 30,00 kr tip = 90,00 kr).
///
/// The rider can only tip once the trip has ended (contract finish.tips),
/// after the waybill took the trip's money, so Home reads the trip again:
/// as the LAST TRIP face opens (like TODAY), and by itself when Home is
/// shown, comes back on top or back to the front, for [autoWindow] after
/// the trip. The driver's `driverTotal` holds the tip, a tip given later
/// included. One tip per trip: once one is known nothing more is read.
/// One read at a time; no stream, no timer.
///
/// [WaybillRecord.fare] stays the driver's one number (`driverTotal`, the
/// tip in it) as the finish writes it: Trip finished and the waybill
/// sheet read it that way. Ride history keeps the money archived at the
/// finish (its own "Tip" line comes from the receipt), so nothing there
/// counts the tip twice.
class LastTripTip {
  LastTripTip._();

  /// Reads the trip's driver projection; tests set their own. Null: the
  /// live `GET /trips/{tripId}`, nothing without a live build.
  static Future<Map<String, dynamic>?> Function(String tripId)? readTrip;

  /// How long after the trip Home still looks for a tip by itself.
  static const Duration autoWindow = Duration(hours: 2);

  static String? _reading;

  /// The clock (tests set their own).
  static DateTime Function() now = DateTime.now;

  /// Supervisor #495: Home asks by itself on every lifecycle change while
  /// it is on screen; an [auto] read for the same trip waits this long
  /// after the last one (a tap on LAST TRIP always reads).
  static const Duration autoGap = Duration(seconds: 45);

  static String? _autoTrip;
  static DateTime? _autoAt;

  static Future<Map<String, dynamic>?> _readLive(String tripId) async {
    final api = LiveDriverServices.instance?.api;
    if (api == null) return null;
    return api.get('/api/v1/trips/${Uri.encodeComponent(tripId)}');
  }

  /// Folds the server's tip into the last trip's money; no answer, no
  /// tip or another trip by then keeps what the island has. [auto]: Home
  /// asks by itself, only within [autoWindow] of the trip's end.
  static Future<void> refresh(
    WaybillRepository waybills, {
    bool auto = false,
  }) async {
    final last = waybills.last;
    if (last == null || last.tip != null || _reading == last.tripId) return;
    if (auto) {
      final at = now();
      if (at.difference(last.issuedAt) > autoWindow) return;
      final previous = _autoAt;
      if (_autoTrip == last.tripId &&
          previous != null &&
          at.difference(previous) < autoGap) {
        return;
      }
      _autoTrip = last.tripId;
      _autoAt = at;
    }
    _reading = last.tripId;
    final Map<String, dynamic>? projection;
    try {
      projection = await (readTrip ?? _readLive)(last.tripId);
    } catch (_) {
      return;
    } finally {
      _reading = null;
    }
    final money = projection == null
        ? null
        : LiveTripMoney.tryParse(projection);
    final tip = money?.tip;
    if (money == null || tip == null) return;
    // driverTotal holds the tip. Price audit 2026-11-14: without it the
    // fare stays as it was; the tip is never added on the phone.
    final total = money.driverTotal;
    waybills.updateLast(last.copyWith(fare: total?.formatted, tip: tip));
  }

  @visibleForTesting
  static void resetForTesting() {
    _autoTrip = null;
    _autoAt = null;
    _reading = null;
    now = DateTime.now;
  }
}
