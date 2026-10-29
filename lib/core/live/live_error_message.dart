import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.14.0: the missing documents of a `409 documents_not_approved`
/// by their contract names in the app's language ("Insurance, Registration").
String missingDocumentNames(ApiError error) => {
  for (final type in error.missingDocumentTypes)
    DriverOnboardingRules.documentName(type, tr.localeName),
}.join(', ');

/// The driver's words for `409 documents_not_approved`: a car
/// (`vehicle_documents_not_approved`) or the account's own documents.
String documentsNotApprovedMessage(ApiError error) {
  final names = missingDocumentNames(error);
  final car =
      error.detail == 'vehicle_documents_not_approved' ||
      error.details.any((item) => item.startsWith('vehicle:'));
  return car ? tr.docsNotApprovedCar(names) : tr.docsNotApprovedAccount(names);
}

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
  if (error.documentsNotApproved) return documentsNotApprovedMessage(error);
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
        'price_changed' => tr.cashPriceChanged,
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
