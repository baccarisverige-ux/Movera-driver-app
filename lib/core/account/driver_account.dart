/// The driver's account as the server keeps it (contract v0.5.3 §14:
/// `Driver`, `Fleet`, `FleetView`, `Vehicle`, `Document`).
library;

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String) item,
];

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

int _whole(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// `DocumentSummary` on a driver or a car.
class DocumentSummary {
  const DocumentSummary({
    required this.documentId,
    required this.type,
    required this.status,
    this.expiresAt,
  });

  factory DocumentSummary.fromJson(Map<String, dynamic> json) =>
      DocumentSummary(
        documentId: _text(json['documentId']) ?? '',
        type: _text(json['type']) ?? '',
        status: _text(json['status']) ?? 'missing',
        expiresAt: _time(json['expiresAt']),
      );

  final String documentId;
  final String type;

  /// `missing`, `in_review`, `approved`, `rejected`, `expired`.
  final String status;
  final DateTime? expiresAt;
}

/// `Document`, as `GET /driver/documents` and an upload answer it.
class AccountDocument {
  const AccountDocument({
    required this.documentId,
    required this.ownerId,
    required this.type,
    required this.status,
    required this.version,
    this.expiresAt,
    this.fileUrl,
    this.fileName,
    this.mediaType,
    this.uploadedAt,
    this.reviewNote,
  });

  factory AccountDocument.fromJson(Map<String, dynamic> json) =>
      AccountDocument(
        documentId: _text(json['documentId']) ?? '',
        ownerId: _text(json['ownerId']) ?? '',
        type: _text(json['type']) ?? '',
        status: _text(json['status']) ?? 'missing',
        version: _whole(json['version'], 1),
        expiresAt: _time(json['expiresAt']),
        fileUrl: _text(json['fileUrl']),
        fileName: _text(json['fileName']),
        mediaType: _text(json['mediaType']),
        uploadedAt: _time(json['uploadedAt']),
        reviewNote: _text(json['reviewNote']),
      );

  final String documentId;

  /// The driverId, or the vehicleId of a car document.
  final String ownerId;
  final String type;
  final String status;
  final int version;
  final DateTime? expiresAt;
  final String? fileUrl;
  final String? fileName;
  final String? mediaType;
  final DateTime? uploadedAt;
  final String? reviewNote;

  DocumentSummary get summary => DocumentSummary(
    documentId: documentId,
    type: type,
    status: status,
    expiresAt: expiresAt,
  );
}

/// `Driver.fleet`.
class FleetSummary {
  const FleetSummary({
    required this.fleetId,
    required this.name,
    required this.role,
    required this.status,
  });

  factory FleetSummary.fromJson(Map<String, dynamic> json) => FleetSummary(
    fleetId: _text(json['fleetId']) ?? '',
    name: _text(json['name']) ?? '',
    role: _text(json['role']) ?? 'member',
    status: _text(json['status']) ?? 'pending',
  );

  final String fleetId;
  final String name;

  /// `owner` or `member`.
  final String role;

  /// `pending`, `approved`, `rejected`, `blocked`.
  final String status;

  bool get isOwner => role == 'owner';
}

/// `Driver` (`GET /driver/profile`).
class DriverAccount {
  const DriverAccount({
    required this.driverId,
    required this.accountStatus,
    required this.firstName,
    required this.version,
    this.accountType,
    this.lastName,
    this.dateOfBirth,
    this.email,
    this.country,
    this.cityId,
    this.language,
    this.zoneIds = const [],
    this.vehicleId,
    this.fleet,
    this.payoutTo,
    this.pendingFleetInvitations = 0,
    this.documents = const [],
    this.requiredDocuments = const [],
    this.requiredFleetDocuments = const [],
  });

  factory DriverAccount.fromJson(Map<String, dynamic> json) {
    final fleet = json['fleet'];
    return DriverAccount(
      driverId: _text(json['driverId']) ?? '',
      accountStatus: _text(json['accountStatus']) ?? 'pending',
      firstName: _text(json['firstName']) ?? '',
      version: _whole(json['version'], 1),
      accountType: _text(json['accountType']),
      lastName: _text(json['lastName']),
      dateOfBirth: _text(json['dateOfBirth']),
      email: _text(json['email']),
      country: _text(json['country']),
      cityId: _text(json['cityId']),
      language: _text(json['language']),
      zoneIds: _strings(json['zoneIds']),
      vehicleId: _text(json['vehicleId']),
      fleet: fleet is Map ? FleetSummary.fromJson(_map(fleet)) : null,
      payoutTo: _text(json['payoutTo']),
      pendingFleetInvitations: _whole(json['pendingFleetInvitations']),
      documents: [
        if (json['documents'] is List)
          for (final item in json['documents'] as List)
            if (item is Map) DocumentSummary.fromJson(_map(item)),
      ],
      requiredDocuments: _strings(json['requiredDocuments']),
      requiredFleetDocuments: _strings(json['requiredFleetDocuments']),
    );
  }

  final String driverId;

  /// `pending` (no details yet), `on_hold`, `active`, `suspended`.
  final String accountStatus;
  final String firstName;
  final int version;

  /// `driver` or `fleet`; null before the details were sent.
  final String? accountType;
  final String? lastName;

  /// `YYYY-MM-DD`.
  final String? dateOfBirth;
  final String? email;
  final String? country;
  final String? cityId;
  final String? language;
  final List<String> zoneIds;
  final String? vehicleId;
  final FleetSummary? fleet;

  /// `fleet` or `self`.
  final String? payoutTo;

  /// Round 4b: invitations waiting for this account's answer (a driver's
  /// owner invites, an owner's driver requests): the badge on Home and in
  /// My fleet.
  final int pendingFleetInvitations;
  final List<DocumentSummary> documents;
  final List<String> requiredDocuments;
  final List<String> requiredFleetDocuments;

  bool get isActive => accountStatus == 'active';

  /// Signed in, details not sent yet: the details screen comes next.
  bool get needsDetails => accountStatus == 'pending';

  /// The details may be (re)sent.
  bool get canSendDetails =>
      accountStatus == 'pending' || accountStatus == 'on_hold';

  bool get isFleetAccount => accountType == 'fleet';

  /// A driver account that has no fleet yet: no cars until it joins one.
  bool get awaitsFleet => accountType == 'driver' && fleet == null;

  String get fullName =>
      [firstName, if (lastName != null) lastName!].join(' ').trim();
}

/// `Vehicle` with its v0.5.3 fields.
class FleetVehicle {
  const FleetVehicle({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.seats,
    required this.categoryIds,
    required this.status,
    required this.version,
    this.fleetId,
    this.driverId,
    this.inUse = false,
    this.documents = const [],
    this.requiredDocuments = const [],
    this.fuel,
  });

  factory FleetVehicle.fromJson(Map<String, dynamic> json) => FleetVehicle(
    vehicleId: _text(json['vehicleId']) ?? '',
    make: _text(json['make']) ?? '',
    model: _text(json['model']) ?? '',
    year: _whole(json['year']),
    color: _text(json['color']) ?? '',
    plate: _text(json['plate']) ?? '',
    seats: _whole(json['seats'], 4),
    categoryIds: _strings(json['categoryIds']),
    status: _text(json['status']) ?? 'pending',
    version: _whole(json['version'], 1),
    fleetId: _text(json['fleetId']),
    driverId: _text(json['driverId']),
    inUse: json['inUse'] == true,
    documents: [
      if (json['documents'] is List)
        for (final item in json['documents'] as List)
          if (item is Map) DocumentSummary.fromJson(_map(item)),
    ],
    requiredDocuments: _strings(json['requiredDocuments']),
    fuel: _text(json['fuel']),
  );

  final String vehicleId;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int seats;
  final List<String> categoryIds;

  /// `pending`, `approved`, `rejected`, `blocked`.
  final String status;
  final int version;
  final String? fleetId;

  /// The driver who has the car picked; null = free.
  final String? driverId;

  /// That driver is online or on a trip.
  final bool inUse;
  final List<DocumentSummary> documents;
  final List<String> requiredDocuments;

  /// v0.17.0 `Vehicle.fuel`.
  final String? fuel;

  bool get isApproved => status == 'approved';

  /// Contract v0.14.0: the required car documents that are not approved.
  List<String> get missingDocuments {
    final approved = {
      for (final doc in documents)
        if (doc.status == 'approved') doc.type,
    };
    return [
      for (final type in requiredDocuments)
        if (!approved.contains(type)) type,
    ];
  }

  /// Nobody can pick or drive a car whose documents are not all approved.
  bool get canBeDriven => isApproved && missingDocuments.isEmpty;

  /// "Volvo XC60 2022".
  String get title => '$make $model${year > 0 ? ' $year' : ''}'.trim();
}

/// `Fleet`.
class Fleet {
  const Fleet({
    required this.fleetId,
    required this.name,
    required this.orgNumber,
    required this.country,
    required this.cityId,
    required this.ownerName,
    required this.status,
    required this.driverCount,
    required this.vehicleCount,
    required this.version,
    this.address,
    this.ownerEmail,
    this.code,
  });

  factory Fleet.fromJson(Map<String, dynamic> json) => Fleet(
    fleetId: _text(json['fleetId']) ?? '',
    name: _text(json['name']) ?? '',
    orgNumber: _text(json['orgNumber']) ?? '',
    country: _text(json['country']) ?? '',
    cityId: _text(json['cityId']) ?? '',
    ownerName: _text(json['ownerName']) ?? '',
    status: _text(json['status']) ?? 'pending',
    driverCount: _whole(json['driverCount']),
    vehicleCount: _whole(json['vehicleCount']),
    version: _whole(json['version'], 1),
    address: _text(json['address']),
    ownerEmail: _text(json['ownerEmail']),
    code: _text(json['code']),
  );

  final String fleetId;
  final String name;
  final String orgNumber;
  final String country;
  final String cityId;
  final String ownerName;
  final String status;
  final int driverCount;
  final int vehicleCount;
  final int version;
  final String? address;
  final String? ownerEmail;

  /// Only after approval, only to the owner.
  final String? code;

  bool get isApproved => status == 'approved';
}

/// `FleetDriver`.
class FleetDriver {
  const FleetDriver({
    required this.driverId,
    required this.firstName,
    required this.accountStatus,
    required this.onlineStatus,
    this.lastName,
    this.vehicleId,
    this.linkedAt,
  });

  factory FleetDriver.fromJson(Map<String, dynamic> json) => FleetDriver(
    driverId: _text(json['driverId']) ?? '',
    firstName: _text(json['firstName']) ?? '',
    accountStatus: _text(json['accountStatus']) ?? 'pending',
    onlineStatus: _text(json['onlineStatus']) ?? 'offline',
    lastName: _text(json['lastName']),
    vehicleId: _text(json['vehicleId']),
    linkedAt: _time(json['linkedAt']),
  );

  final String driverId;
  final String firstName;
  final String accountStatus;
  final String onlineStatus;
  final String? lastName;
  final String? vehicleId;
  final DateTime? linkedAt;

  String get fullName =>
      [firstName, if (lastName != null) lastName!].join(' ').trim();
}

/// Round 4b: `FleetInvitation` (contract v0.5.3 §14, "Joining is an
/// invitation"): a `driver_request` the owner answers, or an
/// `owner_invite` the driver answers.
class FleetInvitation {
  const FleetInvitation({
    required this.invitationId,
    required this.fleetId,
    required this.fleetName,
    required this.direction,
    required this.status,
    required this.version,
    this.driverId,
    this.driverName,
    this.phone,
    this.createdAt,
    this.expiresAt,
    this.decidedAt,
  });

  factory FleetInvitation.fromJson(Map<String, dynamic> json) =>
      FleetInvitation(
        invitationId: _text(json['invitationId']) ?? '',
        fleetId: _text(json['fleetId']) ?? '',
        fleetName: _text(json['fleetName']) ?? '',
        direction: _text(json['direction']) ?? 'driver_request',
        status: _text(json['status']) ?? 'pending',
        version: _whole(json['version'], 1),
        driverId: _text(json['driverId']),
        driverName: _text(json['driverName']),
        phone: _text(json['phone']),
        createdAt: _time(json['createdAt']),
        expiresAt: _time(json['expiresAt']),
        decidedAt: _time(json['decidedAt']),
      );

  final String invitationId;
  final String fleetId;
  final String fleetName;

  /// `driver_request` or `owner_invite`.
  final String direction;

  /// The driver concerned; missing while an owner invite waits for a
  /// number without an account.
  final String? driverId;
  final String? driverName;

  /// The invited number (owner and admin views).
  final String? phone;

  /// `pending`, `accepted`, `declined`, `cancelled`, `expired`.
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? decidedAt;
  final int version;

  bool get isPending => status == 'pending';
  bool get isDriverRequest => direction == 'driver_request';
  bool get isOwnerInvite => direction == 'owner_invite';

  /// Whether this account answers it: a driver answers owner invites, an
  /// owner answers driver requests.
  bool awaitsAnswerFrom({required bool owner}) =>
      isPending && (owner ? isDriverRequest : isOwnerInvite);
}

/// `FleetView`.
class FleetView {
  const FleetView({
    required this.fleet,
    required this.drivers,
    required this.vehicles,
    this.invitations = const [],
  });

  factory FleetView.fromJson(Map<String, dynamic> json) => FleetView(
    fleet: Fleet.fromJson(_map(json['fleet'])),
    drivers: [
      if (json['drivers'] is List)
        for (final item in json['drivers'] as List)
          if (item is Map) FleetDriver.fromJson(_map(item)),
    ],
    vehicles: [
      if (json['vehicles'] is List)
        for (final item in json['vehicles'] as List)
          if (item is Map) FleetVehicle.fromJson(_map(item)),
    ],
    invitations: [
      if (json['invitations'] is List)
        for (final item in json['invitations'] as List)
          if (item is Map) FleetInvitation.fromJson(_map(item)),
    ],
  );

  final Fleet fleet;
  final List<FleetDriver> drivers;
  final List<FleetVehicle> vehicles;

  /// Round 4b: the fleet's pending invitations and requests (owner and
  /// admins; a member gets none).
  final List<FleetInvitation> invitations;
}

/// Round 4b: `Notification` (`GET /notifications`), as the server sends
/// it: a fleet invitation, an answer to one, later more kinds.
class ServerNotification {
  const ServerNotification({
    required this.notificationId,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.read,
    this.tripId,
    this.deepLink,
  });

  factory ServerNotification.fromJson(Map<String, dynamic> json) =>
      ServerNotification(
        notificationId: _text(json['notificationId']) ?? '',
        kind: _text(json['kind']) ?? '',
        title: _text(json['title']) ?? '',
        body: _text(json['body']) ?? '',
        at: _time(json['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        read: json['read'] == true,
        tripId: _text(json['tripId']),
        deepLink: _text(json['deepLink']),
      );

  final String notificationId;

  /// `fleet_invitation`, …
  final String kind;
  final String title;
  final String body;
  final DateTime at;
  final bool read;
  final String? tripId;
  final String? deepLink;

  /// A tap opens My fleet (the invitations).
  bool get opensFleet => kind == 'fleet_invitation';

  /// Contract v0.17.0 (owner group 2 items 1, 3 and the note check): an
  /// expiry warning (30 / 7 / 1 days), an expired document or "Finish
  /// your sign-up" opens Documents.
  bool get opensDocuments =>
      kind == 'document_expiring' ||
      kind == 'document_expired' ||
      kind == 'finish_sign_up';

  ServerNotification asRead() => ServerNotification(
    notificationId: notificationId,
    kind: kind,
    title: title,
    body: body,
    at: at,
    read: true,
    tripId: tripId,
    deepLink: deepLink,
  );
}

/// `DriverOnboardingRequest`.
class DriverDetailsRequest {
  const DriverDetailsRequest({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
    required this.country,
    required this.cityId,
    required this.language,
    required this.accountType,
    this.company,
    this.fleetJoin,
  });

  final String firstName;
  final String lastName;

  /// `YYYY-MM-DD`.
  final String dateOfBirth;
  final String email;
  final String country;
  final String cityId;
  final String language;

  /// `driver` or `fleet`.
  final String accountType;
  final FleetCompany? company;
  final FleetJoinRequest? fleetJoin;

  Map<String, dynamic> toJson() => {
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'dateOfBirth': dateOfBirth,
    'email': email.trim(),
    'country': country,
    'cityId': cityId,
    'language': language,
    'accountType': accountType,
    'termsAccepted': true,
    if (company != null) 'company': company!.toJson(),
    if (fleetJoin != null) 'fleetJoin': fleetJoin!.toJson(),
  };
}

class FleetCompany {
  const FleetCompany({
    required this.name,
    required this.orgNumber,
    required this.address,
  });

  final String name;
  final String orgNumber;
  final String address;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'orgNumber': orgNumber.trim(),
    'address': address.trim(),
  };
}

class FleetJoinRequest {
  const FleetJoinRequest({
    required this.code,
    required this.ownerName,
    required this.ownerEmail,
  });

  final String code;
  final String ownerName;
  final String ownerEmail;

  Map<String, dynamic> toJson() => {
    'code': code.trim(),
    'ownerName': ownerName.trim(),
    'ownerEmail': ownerEmail.trim(),
  };
}

/// `VehicleRequest`.
class NewVehicle {
  const NewVehicle({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
    required this.seats,
    required this.categoryIds,
    this.fuel,
  });

  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;
  final int seats;
  final List<String> categoryIds;

  /// v0.17.0: `petrol`, `diesel`, `hybrid` or `electric`.
  final String? fuel;

  Map<String, dynamic> toJson() => {
    'make': make.trim(),
    'model': model.trim(),
    'year': year,
    'color': color.trim(),
    'plate': plate.trim().toUpperCase(),
    'seats': seats,
    'categoryIds': categoryIds,
    if (fuel != null) 'fuel': fuel,
  };
}
