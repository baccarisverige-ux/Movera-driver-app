import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_error_message.dart';

/// The field of the details screen a server reason belongs under.
enum DetailsField {
  firstName,
  lastName,
  dateOfBirth,
  email,
  country,
  city,
  company,
  fleetJoin,
  terms,
}

/// Which field of the details screen a `400 invalid_request` reason points
/// at; null for a reason that is about the whole form.
DetailsField? detailsFieldOf(Object error) {
  if (error is! ApiError) return null;
  return switch (error.detail) {
    'under_age' || 'invalid_date_of_birth' => DetailsField.dateOfBirth,
    'invalid_email' => DetailsField.email,
    'country_not_open' => DetailsField.country,
    'invalid_city' => DetailsField.city,
    'company_required' => DetailsField.company,
    'fleet_join_mismatch' || 'fleet_join_limit' => DetailsField.fleetJoin,
    'terms_required' => DetailsField.terms,
    _ => null,
  };
}

/// A plain text for an account, fleet, car or document failure
/// (contract v0.5.3 §14 reasons); [fallback] for anything else that the
/// server refused. [baseYear] is the country's base year for a car that
/// is too old (contract v0.18.3 R2), when known.
String accountErrorMessage(
  Object error, {
  required String fallback,
  int? baseYear,
}) {
  if (error is TimeoutException || error is http.ClientException) {
    return tr.authErrOffline;
  }
  if (error is! ApiError) return fallback;
  if (error.neverReachedServer) return tr.authErrOffline;
  final status = error.statusCode ?? 0;
  if (status == 429 || error.detail == 'rate_limited') {
    final wait = error.retryAfter;
    if (wait != null && wait >= const Duration(minutes: 30)) {
      return tr.acctTooManyTriesHour;
    }
    if (wait == null || wait <= Duration.zero) return tr.authErrTooManyWait;
    final seconds = wait.inSeconds + (wait.inMilliseconds % 1000 == 0 ? 0 : 1);
    return tr.authErrTooManyIn(tr.authRetrySeconds(seconds));
  }
  if (status >= 500) return tr.authErrServer;
  if (error.documentsNotApproved) return documentsNotApprovedMessage(error);
  return switch (error.detail) {
    'under_age' => tr.acctUnderAge(DriverOnboardingRules.minAge),
    'invalid_date_of_birth' => tr.acctInvalidDate,
    'country_not_open' => tr.acctCountryNotOpen,
    'invalid_city' => tr.acctInvalidCity,
    'invalid_email' => tr.acctInvalidEmail,
    'terms_required' => tr.acctTermsRequired,
    'company_required' => tr.acctCompanyRequired,
    'details_locked' || 'account_type_locked' => tr.acctDetailsLocked,
    'fleet_join_mismatch' => tr.fleetJoinMismatch,
    'fleet_join_limit' => tr.acctTooManyTriesHour,
    'request_pending' => tr.fleetRequestPending,
    'invite_pending' => tr.fleetInvitePending,
    'own_phone' => tr.fleetOwnPhone,
    'invalid_phone' => tr.fleetInvalidPhone,
    'fleet_not_approved' => tr.fleetNotApprovedYet,
    'invitation_expired' => tr.fleetInvitationExpired,
    'invalid_transition' when status == 409 => tr.fleetInvitationGone,
    'already_in_fleet' => tr.fleetAlreadyIn,
    'fleet_account' => tr.fleetAccountHasOwn,
    'on_trip' => tr.fleetOnTrip,
    'fleet_owner' => tr.fleetOwnerCannotLeave,
    'no_fleet' => tr.fleetNotInOne,
    'not_fleet_owner' || 'fleet_vehicles_only' => tr.fleetOwnerOnly,
    'vehicle_in_use' => tr.fleetVehicleInUse,
    'vehicle_not_approved' => tr.fleetVehicleNotApproved,
    'vehicle_not_found' => tr.fleetVehicleNotYours,
    'plate_taken' => tr.fleetPlateTaken,
    // v0.17.0 (owner items 7 and 11).
    'category_not_allowed' => categoryNotAllowedMessage(
      error.details,
      baseYear: baseYear,
    ),
    'already_fleet' => tr.startCompanyAlreadyFleet,
    // v0.18.0 (owner decision 19): car documents are the fleet owner's.
    'fleet_owner_only' => tr.docFleetOwnerOnly,
    'unknown_document_type' ||
    'not_a_file_document' ||
    'wrong_document_owner' => tr.docTypeNotAccepted,
    'unsupported_file_type' => tr.docUnsupportedFile,
    'file_too_large' => tr.docFileTooLarge,
    'empty_file' => tr.docEmptyFile,
    'version_mismatch' => tr.acctChangedReload,
    _ => fallback,
  };
}

/// Contract v0.18.3 (R2, owner 2026-10-30): `400 category_not_allowed`
/// with its `details` ("child_seat:extra_needs_ride", "car:year_too_old",
/// "economy:too_few_seats") as one plain line each, in the app's language;
/// the general sentence when the server sent none.
String categoryNotAllowedMessage(List<String> details, {int? baseYear}) {
  final lines = <String>[
    for (final item in details)
      if (item.contains(':')) _categoryProblemLine(item, baseYear),
  ];
  if (lines.isEmpty) return tr.carCategoryNotAllowed;
  return [tr.carRulesNotMet, for (final line in lines) '• $line'].join('\n');
}

String _categoryProblemLine(String item, int? baseYear) {
  final split = item.indexOf(':');
  final category = item.substring(0, split);
  final problem = item.substring(split + 1);
  final name = category == 'car'
      ? tr.carWholeCar
      : categoryNameText(CategoryCatalog.labelOf(category));
  final words = switch (problem) {
    'year_too_old' when baseYear != null => tr.carProblemYearTooOldBase(
      baseYear,
    ),
    'year_too_old' => tr.carProblemYearTooOld,
    'category_off' => tr.carProblemCategoryOff,
    'too_few_seats' => tr.carProblemTooFewSeats,
    'fuel_not_allowed' => tr.carProblemFuelNotAllowed,
    'fuel_required' => tr.carProblemFuelRequired,
    'extra_needs_ride' => tr.carProblemExtraNeedsRide,
    _ => tr.carProblemOther,
  };
  return tr.carProblemLine(name, words);
}
