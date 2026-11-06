import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_error_message.dart';

/// Contract v0.18.37 §61 (`contract.json#goOfflineAfterTrips`, owner
/// 2026-11-05 "go offline mean after all trips finish"): Go offline during a
/// trip schedules offline on the server. He keeps his trip (and its
/// location), gets no new offers, and goes offline when his last trip ends
/// (a queued next trip and a due booked ride first). The state lives on the
/// server (`Driver.offlineAfterTrip`), so a restart brings it back.
abstract final class OfflineAfterTrips {
  static const profilePath = '/api/v1/driver/profile';
  static const availabilityPath = '/api/v1/driver/availability';

  /// True while the server says he goes offline after his trips; the trip
  /// sheet shows the banner with Undo.
  static final ValueNotifier<bool> pending = ValueNotifier<bool>(false);

  /// What Undo runs (set by the live services; a test sets its own).
  static Future<String?> Function()? undoAction;

  /// Reads `Driver.offlineAfterTrip` from any Driver answer.
  static void observe(Map<String, dynamic> driver) {
    pending.value =
        driver['onlineStatus'] == 'on_trip' &&
        driver['offlineAfterTrip'] == true;
  }

  /// [offline] true: go offline after the trips; false: undo. One POST
  /// (a stale version is retried with the version the 409 carries).
  /// Null when done; else what to tell the driver.
  static Future<String?> request(ApiClient api, {required bool offline}) async {
    try {
      var profile = await api.get(profilePath);
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          profile = await api.post(
            availabilityPath,
            body: {
              'expectedVersion': profile['version'],
              'onlineStatus': offline ? 'offline' : 'online',
            },
          );
          break;
        } on ApiError catch (error) {
          final current = error.projection;
          if (error.code != 'version_mismatch' || current == null) rethrow;
          profile = current;
        }
      }
      observe(profile);
      return null;
    } catch (error) {
      return liveAvailabilityErrorMessage(error, online: !offline);
    }
  }
}
