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
  static const fleetLeavePath = '/api/v1/driver/fleet/leave';
  static const vehiclesPath = '/api/v1/driver/vehicles';
  static const documentsPath = '/api/v1/driver/documents';

  static String removeDriverPath(String driverId) =>
      '/api/v1/driver/fleet/drivers/${Uri.encodeComponent(driverId)}/remove';

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

  /// `POST /driver/fleet/join`.
  Future<DriverAccount> joinFleet(
    String code,
    String ownerName,
    String ownerEmail,
  ) async => DriverAccount.fromJson(
    await _api.post(
      fleetJoinPath,
      body: FleetJoinRequest(
        code: code,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
      ).toJson(),
    ),
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
