import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/waybill/waybill.dart';

/// Owner 2026-11-07: the island's LAST TRIP shows the trip's money and
/// the rider's tip as one total (60,00 kr + 30,00 kr tip = 90,00 kr).
///
/// The rider can only tip once the trip has ended (contract finish.tips),
/// after the waybill took the trip's money, so the face reads the trip
/// again as it opens (like TODAY): the driver's `driverTotal` holds the
/// tip, a tip given later included. One tip per trip: once one is known
/// nothing more is read.
class LastTripTip {
  LastTripTip._();

  /// Reads the trip's driver projection; tests set their own. Null: the
  /// live `GET /trips/{tripId}`, nothing without a live build.
  static Future<Map<String, dynamic>?> Function(String tripId)? readTrip;

  static Future<Map<String, dynamic>?> _readLive(String tripId) async {
    final api = LiveDriverServices.instance?.api;
    if (api == null) return null;
    return api.get('/api/v1/trips/${Uri.encodeComponent(tripId)}');
  }

  /// Folds the server's tip into the last trip's money; no answer, no
  /// tip or another trip by then keeps what the island has.
  static Future<void> refresh(WaybillRepository waybills) async {
    final last = waybills.last;
    if (last == null || last.tip != null) return;
    final Map<String, dynamic>? projection;
    try {
      projection = await (readTrip ?? _readLive)(last.tripId);
    } catch (_) {
      return;
    }
    final money = projection == null
        ? null
        : LiveTripMoney.tryParse(projection);
    final tip = money?.tip;
    if (money == null || tip == null) return;
    // driverTotal holds the tip; an older server's earnings do not.
    final total = money.driverTotal != null
        ? money.driverPay
        : tip.amount.currency == money.driverPay.currency
        ? money.driverPay + tip.amount
        : money.driverPay;
    waybills.updateLast(last.copyWith(fare: total.formatted, tip: tip));
  }
}
