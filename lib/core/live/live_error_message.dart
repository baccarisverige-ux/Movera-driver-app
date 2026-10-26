import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Plain words for a failed call that never got a clear answer: offline,
/// too many tries, or the server's own fault. Null for a real refusal.
String? _transportMessage(ApiError error) {
  if (error.neverReachedServer) return tr.authErrOffline;
  final status = error.statusCode ?? 0;
  if (status == 429) return tr.authErrTooManyWait;
  if (status >= 500) return tr.authErrServer;
  return null;
}

/// Why going online or offline failed (`POST /driver/availability`
/// reasons, contract §3.3), in the driver's words.
String liveAvailabilityErrorMessage(Object? error, {required bool online}) {
  final fallback = online ? tr.liveOnlineFailed : tr.liveOfflineFailed;
  if (error is! ApiError) return fallback;
  return _transportMessage(error) ??
      switch (error.detail) {
        'account_not_active' => tr.liveOnlineNotActive,
        'no_fleet' => tr.liveOnlineNoFleet,
        'fleet_not_approved' => tr.liveOnlineFleetNotApproved,
        'no_vehicle' => tr.liveOnlineNoVehicle,
        'vehicle_not_approved' => tr.liveOnlineVehicleNotApproved,
        'vehicle_in_use' => tr.liveOnlineVehicleInUse,
        'no_category' => tr.liveOnlineNoCategory,
        'on_trip' => tr.liveOfflineOnTrip,
        _ => fallback,
      };
}

/// Why a trip step (arrive, start, finish, cancel, no-show) was not
/// recorded, in the driver's words.
String liveTripErrorMessage(Object? error) {
  if (error is! ApiError) return tr.liveTripFailed;
  return _transportMessage(error) ??
      switch (error.detail) {
        'not_at_pickup' => tr.liveTripNotAtPickup,
        'no_show_too_early' => tr.liveTripNoShowTooEarly,
        'version_mismatch' || 'invalid_transition' => tr.liveTripChanged,
        _ => tr.liveTripFailed,
      };
}

/// Why a chat message to the rider was not sent, in the driver's words.
String liveChatErrorMessage(Object? error) {
  if (error is! ApiError) return tr.chatSendFailed;
  return _transportMessage(error) ?? tr.chatSendFailed;
}
