import 'package:movera/core/contracts/cancel_reason_code.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';

/// Server-owned state boundary (contract v0.3, `contracts/openapi.yaml`
/// "Driver · Trip" and "Driver · Offers"). No production implementation is
/// installed and nothing calls it yet: the app still runs on local state.
class DriverTripProjection {
  const DriverTripProjection({
    required this.tripId,
    required this.status,
    required this.version,
    this.sequence = 0,
  });
  final String tripId;
  final TripStatus status;

  /// Trip version (≥ 1); the next command sends it as `expectedVersion`.
  final int version;

  /// Last realtime sequence folded into this projection (≥ 0).
  final int sequence;
}

/// Fields every mutation carries: the `Idempotency-Key` header and the body's
/// `expectedVersion` (a stale version is `409 version_mismatch`).
class DriverCommand {
  const DriverCommand({
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  /// Version the caller last saw (≥ 1). For an offer it is the offer version.
  final int expectedVersion;

  /// 16–128 characters (`contract.json#headers`). Reuse it on retry.
  final String idempotencyKey;

  static const int minKeyLength = 16;
  static const int maxKeyLength = 128;

  bool get isValid =>
      expectedVersion >= 1 &&
      idempotencyKey.length >= minKeyLength &&
      idempotencyKey.length <= maxKeyLength;
}

abstract interface class DriverTripGateway {
  Future<DriverTripProjection> getTrip(String tripId);

  /// `POST /offers/{offerId}/accept`. [expectedOfferVersion] is sent as the
  /// body's `expectedVersion`; another driver winning is `409 conflict`.
  Future<DriverTripProjection> acceptOffer(
    String offerId, {
    required int expectedOfferVersion,
    required String idempotencyKey,
  });

  Future<DriverTripProjection> headToPickup(String tripId, DriverCommand command);

  Future<DriverTripProjection> arrive(String tripId, DriverCommand command);

  /// `board`: the rider is in the car. [verifiedPinToken] when the trip has
  /// `pinRequired`.
  Future<DriverTripProjection> board(
    String tripId,
    DriverCommand command, {
    String? verifiedPinToken,
  });

  Future<DriverTripProjection> start(String tripId, DriverCommand command);

  /// [cashCollected] for a cash trip.
  Future<DriverTripProjection> complete(
    String tripId,
    DriverCommand command, {
    Money? cashCollected,
  });

  /// [reasonCode] must be in the driver's groups (before trip, during trip,
  /// next trip, scheduled); the server checks it per actor.
  Future<DriverTripProjection> cancel(
    String tripId,
    DriverCommand command, {
    required CancelReasonCode reasonCode,
    String? note,
  });

  Future<DriverTripProjection> noShow(
    String tripId,
    DriverCommand command, {
    CancelReasonCode reasonCode = CancelReasonCode.riderNoShow,
  });
}
