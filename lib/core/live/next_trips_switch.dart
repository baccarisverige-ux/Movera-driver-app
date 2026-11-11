import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.18.65 §86 (`contract.json#nextTripsSwitch`, owner phone test
/// 2026-11-11 "if he turn radar off while on trip do offers stop or not"):
/// holding the trip sheet's radar to stop (or start) next trips tells the
/// server, so it sends no on-trip offers while it is off. Before, only the
/// app hid them; the server kept sending them and each one held the rider's
/// search until it ran out. The switch belongs to one trip: the server
/// clears it when the trip ends.
abstract final class NextTripsSwitch {
  static const path = '/api/v1/driver/next-trips';

  /// True while the server says next trips are off for this trip
  /// (`Driver.nextTripsOff`): a trip screen restored after a restart shows
  /// its radar off.
  static final ValueNotifier<bool> off = ValueNotifier<bool>(false);

  /// Reads `Driver.nextTripsOff` from any Driver answer.
  static void observe(Map<String, dynamic> driver) {
    off.value =
        driver['onlineStatus'] == 'on_trip' && driver['nextTripsOff'] == true;
  }

  /// One POST. Null when done; else what to tell the driver.
  static Future<String?> request(ApiClient api, {required bool on}) async {
    try {
      observe(await api.post(path, body: {'on': on}));
      return null;
    } on ApiError catch (error) {
      if (error.neverReachedServer) return tr.authErrOffline;
      return tr.nextTripsSwitchFailed;
    } catch (_) {
      return tr.nextTripsSwitchFailed;
    }
  }
}
