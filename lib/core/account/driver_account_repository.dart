import 'dart:typed_data';

import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';

/// The driver's account over the contract's v0.5.3 §14 endpoints: profile
/// and details, fleet, cars and documents.
class DriverAccountRepository {
  DriverAccountRepository(this._api);

  final ApiClient _api;

  static const profilePath = '/api/v1/driver/profile';
  static const onboardingPath = '/api/v1/driver/onboarding';
  static const fleetPath = '/api/v1/driver/fleet';
  static const fleetJoinPath = '/api/v1/driver/fleet/join';
  static const fleetInvitePath = '/api/v1/driver/fleet/invite';
  static const fleetInvitationsPath = '/api/v1/driver/fleet/invitations';
  static const fleetLeavePath = '/api/v1/driver/fleet/leave';
  static const notificationsPath = '/api/v1/notifications';
  static const vehiclesPath = '/api/v1/driver/vehicles';
  static const documentsPath = '/api/v1/driver/documents';

  static String removeDriverPath(String driverId) =>
      '/api/v1/driver/fleet/drivers/${Uri.encodeComponent(driverId)}/remove';

  /// `accept`, `decline` or `cancel` on one invitation.
  static String invitationActionPath(String invitationId, String action) =>
      '$fleetInvitationsPath/${Uri.encodeComponent(invitationId)}/$action';

  static String notificationReadPath(String notificationId) =>
      '$notificationsPath/${Uri.encodeComponent(notificationId)}/read';

  /// `GET /driver/profile`.
  Future<DriverAccount> profile() async =>
      DriverAccount.fromJson(await _api.get(profilePath));

  /// `POST /driver/onboarding`: the details, once (a resend while pending
  /// or on hold replaces them).
  Future<DriverAccount> submitDetails(DriverDetailsRequest request) async =>
      DriverAccount.fromJson(
        await _api.post(onboardingPath, body: request.toJson()),
      );

  /// `GET /driver/fleet`; null when the driver is in no fleet (404).
  Future<FleetView?> fleet() async {
    try {
      return FleetView.fromJson(await _api.get(fleetPath));
    } on ApiError catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /driver/fleet/join` (round 4b): a request the owner accepts
  /// or declines, `201 FleetInvitation` (`driver_request`, `pending`). The
  /// three fields must match one approved fleet (`fleet_join_mismatch`,
  /// one message); one open request at a time (`409 request_pending`).
  Future<FleetInvitation> joinFleet(
    String code,
    String ownerName,
    String ownerEmail,
  ) async => FleetInvitation.fromJson(
    await _api.post(
      fleetJoinPath,
      body: FleetJoinRequest(
        code: code,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
      ).toJson(),
    ),
  );

  /// `POST /driver/fleet/invite { phone }` (the owner; round 4b): an
  /// invite the driver accepts, `201 FleetInvitation` (`owner_invite`).
  Future<FleetInvitation> inviteDriver(String phone) async =>
      FleetInvitation.fromJson(
        await _api.post(
          fleetInvitePath,
          body: {'phone': phone.replaceAll(RegExp(r'[\s\-()]'), '')},
        ),
      );

  /// `GET /driver/fleet/invitations`: a driver's incoming invites and own
  /// request; an owner's fleet's open requests and invites.
  Future<List<FleetInvitation>> invitations() async {
    final page = await _api.get(fleetInvitationsPath);
    final items = page['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map)
            FleetInvitation.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// `POST /driver/fleet/invitations/{id}/accept`: links the driver.
  Future<FleetInvitation> acceptInvitation(String invitationId) =>
      _invitationAction(invitationId, 'accept');

  /// `POST /driver/fleet/invitations/{id}/decline`.
  Future<FleetInvitation> declineInvitation(String invitationId) =>
      _invitationAction(invitationId, 'decline');

  /// `POST /driver/fleet/invitations/{id}/cancel`: one's own request or
  /// invite, taken back.
  Future<FleetInvitation> cancelInvitation(String invitationId) =>
      _invitationAction(invitationId, 'cancel');

  Future<FleetInvitation> _invitationAction(
    String invitationId,
    String action,
  ) async => FleetInvitation.fromJson(
    await _api.post(invitationActionPath(invitationId, action)),
  );

  /// `GET /notifications?limit&unreadOnly`: newest first.
  Future<List<ServerNotification>> notifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final page = await _api.get(
      '$notificationsPath?limit=$limit${unreadOnly ? '&unreadOnly=true' : ''}',
    );
    final items = page['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map && item['kind'] != hiddenKind)
            ServerNotification.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// Contract v0.7.2 (contract.json, no notice on surges): drivers get no surge notice,
  /// so an old one the server still holds is never listed or counted.
  static const hiddenKind = 'surge_started';

  /// `POST /notifications/{id}/read`.
  Future<ServerNotification> markNotificationRead(
    String notificationId,
  ) async => ServerNotification.fromJson(
    await _api.post(notificationReadPath(notificationId)),
  );

  /// `POST /driver/fleet/leave`.
  Future<DriverAccount> leaveFleet() async =>
      DriverAccount.fromJson(await _api.post(fleetLeavePath));

  /// `POST /driver/fleet/drivers/{driverId}/remove` (the owner; 204).
  Future<void> removeFleetDriver(String driverId) =>
      _api.post(removeDriverPath(driverId));

  /// `GET /driver/vehicles`: the fleet's cars (a member sees the approved
  /// ones; a driver without a fleet gets none).
  Future<List<FleetVehicle>> vehicles() async {
    final page = await _api.get(vehiclesPath);
    final items = page['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map)
            FleetVehicle.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// `POST /driver/vehicles` (fleet accounts; 201).
  Future<FleetVehicle> addVehicle(NewVehicle vehicle) async =>
      FleetVehicle.fromJson(
        await _api.post(vehiclesPath, body: vehicle.toJson()),
      );

  /// `PATCH /driver/profile { expectedVersion, vehicleId }`: the car this
  /// driver drives. `409 conflict` / `vehicle_in_use` when another driver
  /// is out with it.
  Future<DriverAccount> pickVehicle(
    String vehicleId,
    int expectedVersion,
  ) async => DriverAccount.fromJson(
    await _api.patch(
      profilePath,
      body: {'expectedVersion': expectedVersion, 'vehicleId': vehicleId},
    ),
  );

  /// `GET /driver/documents`: the account's and its cars' documents.
  Future<List<AccountDocument>> documents() async {
    final page = await _api.get(documentsPath);
    final items = page['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map)
            AccountDocument.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// `POST /driver/documents` (multipart): `type`, `ownerId` (a vehicleId
  /// for a car document), `expiresAt?`, and the `file` part. The server
  /// refuses files over 10 MB and types other than JPEG, PNG, HEIC or PDF
  /// (`file_too_large`, `unsupported_file_type`).
  Future<AccountDocument> uploadDocument({
    required String type,
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
    String? ownerId,
    DateTime? expiresAt,
  }) async => AccountDocument.fromJson(
    await _api.postMultipart(
      documentsPath,
      fields: {
        'type': type,
        if (ownerId != null) 'ownerId': ownerId,
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
      fileField: 'file',
      bytes: bytes,
      fileName: fileName,
      mediaType: mediaType,
    ),
  );
}
