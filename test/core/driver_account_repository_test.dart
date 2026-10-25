import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';

/// Round 4 (contract v0.5.3 §14): the account repository's parsing and
/// request bodies, including the multipart document upload.
void main() {
  final base = Uri.parse('https://api.test.movera.se');

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  (DriverAccountRepository, List<http.Request>) repo(
    http.Response Function(http.Request) answer,
  ) {
    final seen = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        return answer(request);
      }),
      baseUri: base,
      tokens: MemoryTokenStore()..save(access: 'acc', refresh: 'ref'),
      idempotencyKey: () => 'idem-1',
    );
    return (DriverAccountRepository(api), seen);
  }

  const driverJson = {
    'driverId': 'drv_1',
    'accountStatus': 'on_hold',
    'onlineStatus': 'offline',
    'firstName': 'Nils',
    'lastName': 'Berg',
    'dateOfBirth': '1990-05-04',
    'email': 'nils@example.se',
    'country': 'SE',
    'cityId': 'stockholm_lan',
    'language': 'sv',
    'accountType': 'driver',
    'zoneIds': ['Z001'],
    'categoryIds': [],
    'fleet': {
      'fleetId': 'flt_1',
      'name': 'Taxi Nord AB',
      'role': 'member',
      'status': 'approved',
    },
    'payoutTo': 'fleet',
    'documents': [
      {'documentId': 'doc_1', 'type': 'terms', 'status': 'approved'},
      {
        'documentId': 'doc_2',
        'type': 'driving_license',
        'status': 'rejected',
        'expiresAt': '2030-01-01T00:00:00Z',
      },
    ],
    'requiredDocuments': [
      'terms',
      'info_session',
      'driving_license',
      'profile_photo',
      'taxi_driver_license',
    ],
    'version': 3,
  };

  test('profile() reads the Driver', () async {
    final (repository, seen) = repo((_) => json(200, driverJson));
    final account = await repository.profile();
    expect(seen.single.url.path, DriverAccountRepository.profilePath);
    expect(seen.single.method, 'GET');
    expect(account.driverId, 'drv_1');
    expect(account.accountStatus, 'on_hold');
    expect(account.isActive, isFalse);
    expect(account.needsDetails, isFalse);
    expect(account.canSendDetails, isTrue);
    expect(account.fullName, 'Nils Berg');
    expect(account.fleet?.name, 'Taxi Nord AB');
    expect(account.fleet?.isOwner, isFalse);
    expect(account.awaitsFleet, isFalse);
    expect(account.payoutTo, 'fleet');
    expect(account.documents.map((d) => d.type), ['terms', 'driving_license']);
    expect(account.documents[1].expiresAt, DateTime.utc(2030));
    expect(account.requiredDocuments, hasLength(5));
    expect(account.requiredFleetDocuments, isEmpty);
    expect(account.version, 3);
  });

  test('a pending account without details awaits the details screen', () {
    final account = DriverAccount.fromJson({
      'driverId': 'drv_2',
      'accountStatus': 'pending',
      'firstName': '',
      'version': 1,
      'accountType': 'driver',
    });
    expect(account.needsDetails, isTrue);
    expect(account.awaitsFleet, isTrue);
    expect(account.isFleetAccount, isFalse);
  });

  test('submitDetails posts the DriverOnboardingRequest with the company '
      'and an Idempotency-Key', () async {
    final (repository, seen) = repo((_) => json(200, driverJson));
    await repository.submitDetails(
      const DriverDetailsRequest(
        firstName: ' Anna ',
        lastName: 'Lind',
        dateOfBirth: '1988-02-01',
        email: 'anna@example.se ',
        country: 'SE',
        cityId: 'stockholm_lan',
        language: 'sv',
        accountType: 'fleet',
        company: FleetCompany(
          name: 'Lind Taxi AB',
          orgNumber: '556677-8899',
          address: 'Storgatan 1, Stockholm',
        ),
      ),
    );
    final request = seen.single;
    expect(request.url.path, DriverAccountRepository.onboardingPath);
    expect(request.headers['Idempotency-Key'], 'idem-1');
    expect(request.headers['Authorization'], 'Bearer acc');
    expect(jsonDecode(request.body), {
      'firstName': 'Anna',
      'lastName': 'Lind',
      'dateOfBirth': '1988-02-01',
      'email': 'anna@example.se',
      'country': 'SE',
      'cityId': 'stockholm_lan',
      'language': 'sv',
      'accountType': 'fleet',
      'termsAccepted': true,
      'company': {
        'name': 'Lind Taxi AB',
        'orgNumber': '556677-8899',
        'address': 'Storgatan 1, Stockholm',
      },
    });
  });

  test('fleet() reads the FleetView and gives null for no fleet', () async {
    final (repository, _) = repo(
      (_) => json(200, {
        'fleet': {
          'fleetId': 'flt_1',
          'name': 'Taxi Nord AB',
          'orgNumber': '556677-8899',
          'country': 'SE',
          'cityId': 'stockholm_lan',
          'ownerDriverId': 'drv_9',
          'ownerName': 'Eva Nord',
          'ownerEmail': 'eva@nord.se',
          'status': 'approved',
          'code': 'MV-7K3Q9',
          'driverCount': 2,
          'vehicleCount': 1,
          'createdAt': '2026-10-01T00:00:00Z',
          'version': 4,
        },
        'drivers': [
          {
            'driverId': 'drv_1',
            'firstName': 'Nils',
            'lastName': 'Berg',
            'accountStatus': 'active',
            'onlineStatus': 'online',
            'vehicleId': 'veh_1',
            'linkedAt': '2026-10-02T00:00:00Z',
          },
        ],
        'vehicles': [
          {
            'vehicleId': 'veh_1',
            'make': 'Volvo',
            'model': 'XC60',
            'year': 2022,
            'color': 'Black',
            'plate': 'ABC123',
            'seats': 4,
            'categoryIds': ['comfort'],
            'status': 'approved',
            'version': 2,
            'fleetId': 'flt_1',
            'driverId': 'drv_1',
            'inUse': true,
            'documents': [],
            'requiredDocuments': ['vehicle_registration', 'insurance'],
          },
        ],
      }),
    );
    final view = (await repository.fleet())!;
    expect(view.fleet.code, 'MV-7K3Q9');
    expect(view.fleet.isApproved, isTrue);
    expect(view.fleet.ownerEmail, 'eva@nord.se');
    expect(view.drivers.single.fullName, 'Nils Berg');
    expect(view.vehicles.single.title, 'Volvo XC60 2022');
    expect(view.vehicles.single.inUse, isTrue);
    expect(view.vehicles.single.requiredDocuments, hasLength(2));

    final (none, _) = repo(
      (_) => json(404, {
        'code': 'not_found',
        'message': 'x',
        'reason': 'no_fleet',
      }),
    );
    expect(await none.fleet(), isNull);
  });

  test('joinFleet posts the three fields; a mismatch is one message', () async {
    final (repository, seen) = repo(
      (_) => json(400, {
        'code': 'invalid_request',
        'message': 'no match',
        'reason': 'fleet_join_mismatch',
      }),
    );
    final error = await repository
        .joinFleet(' mv-7k3q9 ', 'Eva Nord', 'EVA@nord.se')
        .then<Object>((_) => 'no error', onError: (Object e) => e);
    expect(jsonDecode(seen.single.body), {
      'code': 'mv-7k3q9',
      'ownerName': 'Eva Nord',
      'ownerEmail': 'EVA@nord.se',
    });
    expect((error as ApiError).detail, 'fleet_join_mismatch');
  });

  test(
    'pickVehicle patches the profile; vehicle_in_use is a 409 conflict',
    () async {
      final (repository, seen) = repo(
        (_) => json(409, {
          'code': 'conflict',
          'message': 'x',
          'reason': 'vehicle_in_use',
        }),
      );
      final error = await repository
          .pickVehicle('veh_1', 3)
          .then<Object>((_) => 'no error', onError: (Object e) => e);
      expect(seen.single.method, 'PATCH');
      expect(seen.single.url.path, DriverAccountRepository.profilePath);
      expect(jsonDecode(seen.single.body), {
        'expectedVersion': 3,
        'vehicleId': 'veh_1',
      });
      expect((error as ApiError).detail, 'vehicle_in_use');
    },
  );

  test(
    'addVehicle posts the VehicleRequest with the plate upper-cased',
    () async {
      final (repository, seen) = repo(
        (request) => json(201, {
          ...jsonDecode(request.body) as Map,
          'vehicleId': 'veh_2',
          'status': 'pending',
          'version': 1,
          'fleetId': 'flt_1',
        }),
      );
      final vehicle = await repository.addVehicle(
        const NewVehicle(
          make: 'Toyota',
          model: 'Prius',
          year: 2021,
          color: 'White',
          plate: 'xyz 789',
          seats: 4,
          categoryIds: ['economy', 'electric'],
        ),
      );
      expect(jsonDecode(seen.single.body)['plate'], 'XYZ 789');
      expect(vehicle.vehicleId, 'veh_2');
      expect(vehicle.status, 'pending');
    },
  );

  test(
    'uploadDocument sends a multipart body with the fields and the file',
    () async {
      final (repository, seen) = repo(
        (_) => json(201, {
          'documentId': 'doc_3',
          'ownerId': 'veh_1',
          'type': 'insurance',
          'status': 'in_review',
          'fileName': 'insurance.pdf',
          'mediaType': 'application/pdf',
          'uploadedAt': '2026-10-25T10:00:00Z',
          'version': 1,
        }),
      );
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4 fake'));
      final doc = await repository.uploadDocument(
        type: 'insurance',
        bytes: bytes,
        fileName: 'insurance.pdf',
        mediaType: 'application/pdf',
        ownerId: 'veh_1',
      );
      final request = seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, DriverAccountRepository.documentsPath);
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.headers['Authorization'], 'Bearer acc');
      expect(request.headers['Idempotency-Key'], 'idem-1');
      expect(request.headers['X-Api-Version'], '0.5');
      final body = request.body;
      expect(body, contains('name="type"\r\n\r\ninsurance'));
      expect(body, contains('name="ownerId"\r\n\r\nveh_1'));
      expect(body, contains('name="file"; filename="insurance.pdf"'));
      expect(body, contains('content-type: application/pdf'));
      expect(body, contains('%PDF-1.4 fake'));
      expect(body, isNot(contains('expiresAt')));
      expect(doc.documentId, 'doc_3');
      expect(doc.status, 'in_review');
      expect(doc.fileName, 'insurance.pdf');
    },
  );

  test(
    'a 401 on the upload renews the session and sends the file again',
    () async {
      final tokens = MemoryTokenStore()..save(access: 'old', refresh: 'ref');
      final seen = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          seen.add(request);
          if (request.url.path == ApiClient.refreshPath) {
            return json(200, {'accessToken': 'new', 'refreshToken': 'ref2'});
          }
          if (request.headers['Authorization'] == 'Bearer old') {
            return json(401, {'code': 'unauthenticated', 'message': 'x'});
          }
          return json(201, {
            'documentId': 'doc_4',
            'ownerId': 'drv_1',
            'type': 'profile_photo',
            'status': 'in_review',
            'version': 1,
          });
        }),
        baseUri: base,
        tokens: tokens,
      );
      final doc = await DriverAccountRepository(api).uploadDocument(
        type: 'profile_photo',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'me.jpg',
        mediaType: 'image/jpeg',
      );
      expect(doc.documentId, 'doc_4');
      expect(seen.map((r) => r.url.path), [
        DriverAccountRepository.documentsPath,
        ApiClient.refreshPath,
        DriverAccountRepository.documentsPath,
      ]);
      expect(seen.last.headers['Authorization'], 'Bearer new');
      expect(seen.last.body, contains('filename="me.jpg"'));
    },
  );

  test('the server reasons map to texts and to the details fields', () {
    ApiError err(int status, String code, String reason) =>
        ApiError(code: code, message: 'x', reason: reason, statusCode: status);
    expect(
      accountErrorMessage(
        err(400, 'invalid_request', 'under_age'),
        fallback: 'f',
      ),
      contains('21'),
    );
    expect(
      detailsFieldOf(err(400, 'invalid_request', 'under_age')),
      DetailsField.dateOfBirth,
    );
    expect(
      detailsFieldOf(err(400, 'invalid_request', 'invalid_email')),
      DetailsField.email,
    );
    expect(
      detailsFieldOf(err(400, 'invalid_request', 'fleet_join_mismatch')),
      DetailsField.fleetJoin,
    );
    expect(
      detailsFieldOf(err(400, 'invalid_request', 'company_required')),
      DetailsField.company,
    );
    expect(detailsFieldOf(err(409, 'invalid_transition', 'on_trip')), isNull);
    for (final reason in [
      'country_not_open',
      'invalid_city',
      'terms_required',
      'company_required',
      'fleet_join_mismatch',
      'unknown_document_type',
      'unsupported_file_type',
      'file_too_large',
      'already_in_fleet',
      'fleet_account',
      'on_trip',
      'fleet_owner',
      'no_fleet',
      'vehicle_in_use',
    ]) {
      expect(
        accountErrorMessage(err(400, 'invalid_request', reason), fallback: 'f'),
        isNot('f'),
        reason: reason,
      );
    }
    expect(
      accountErrorMessage(
        const ApiError(
          code: 'rate_limited',
          message: 'x',
          statusCode: 429,
          retryAfter: Duration(hours: 1),
        ),
        fallback: 'f',
      ),
      contains('hour'),
    );
    expect(
      accountErrorMessage(
        const ApiError(code: 'bad_response', message: 'x', statusCode: 400),
        fallback: 'f',
      ),
      'f',
    );
  });
}
