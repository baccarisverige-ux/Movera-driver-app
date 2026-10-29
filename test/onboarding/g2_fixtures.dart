// Driver group 2 (contract v0.17.0 §25) test data, built from the contract
// copy: `GET /driver/onboarding/settings` as the server answers it with
// nothing published (version 0 = the admin's defaults), for SE and FR.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';

Map<String, dynamic> get _onboarding =>
    (jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>)['driverOnboarding']
        as Map<String, dynamic>;

/// A custom type the admin made (owner item 14).
const customType = 'custom_ab12cd34ef';

/// The settings answer of [country]; [custom] adds an admin-made driver
/// document with its own name and help text in sv / fr / en.
Map<String, dynamic> settingsJson(String country, {bool custom = false}) {
  final onboarding = _onboarding;
  final defaults = Map<String, dynamic>.from(
    (onboarding['settings'] as Map)['defaults'][country] as Map,
  );
  final types = (onboarding['documents'] as Map)['types'] as Map;
  final documents = Map<String, dynamic>.from(defaults['documents'] as Map);
  final driver = [...(documents['driver'] as List).cast<String>()];
  if (custom) driver.add(customType);
  documents['driver'] = driver;
  final expiring = (defaults['expiringTypes'] as List).cast<String>();
  final listed = {
    ...driver,
    ...(documents['fleet'] as List).cast<String>(),
    ...(documents['vehicle'] as List).cast<String>(),
    if ((defaults['vehicles'] as Map)['photosNeeded'] == true)
      ...((onboarding['settings'] as Map)['photoTypes'] as List).cast<String>(),
  };
  return {
    ...defaults,
    'version': 0,
    'country': country,
    'documents': documents,
    'documentTypes': {
      for (final type in listed)
        if (type == customType)
          type: {
            'owner': 'driver',
            'kind': 'file',
            'expires': true,
            'custom': true,
            'name': {
              'sv': 'Hälsointyg',
              'fr': 'Certificat médical',
              'en': 'Health certificate',
            },
            'help': {
              'sv': 'Läkarens namn och stämpel\nDatum högst 3 månader gammalt',
              'fr': 'Nom et cachet du médecin\nDaté de moins de 3 mois',
              'en': 'The doctor’s name and stamp\nDated less than 3 months ago',
            },
          }
        else
          type: {
            'owner': (types[type] as Map)['owner'],
            'kind': (types[type] as Map)['kind'],
            'expires': expiring.contains(type),
            'name': (types[type] as Map)['name'],
          },
    },
  };
}

http.Response jsonResponse(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> profileJson({
  String country = 'SE',
  String accountType = 'driver',
  String role = 'member',
  String status = 'active',
  String? fleetStatus = 'approved',
}) => {
  'driverId': 'drv_1',
  'accountStatus': status,
  'onlineStatus': 'offline',
  'firstName': 'Eva',
  'lastName': 'Berg',
  'accountType': accountType,
  'country': country,
  'zoneIds': [country == 'FR' ? 'FR-PC' : 'Z001'],
  'categoryIds': [],
  if (fleetStatus != null)
    'fleet': {
      'fleetId': 'flt_1',
      'name': 'Nord Taxi',
      'role': role,
      'status': fleetStatus,
    },
  'documents': const [],
  'requiredDocuments': const ['driving_license'],
  'requiredFleetDocuments': const [],
  'version': 3,
};

/// A fake server: routes by "METHOD /path"; every request is kept.
class FakeServer {
  FakeServer(this.routes);

  final Map<String, Future<http.Response> Function(http.Request)> routes;
  final List<http.Request> requests = [];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final route = routes['${request.method} ${request.url.path}'];
    if (route != null) return route(request);
    return jsonResponse(404, {
      'code': 'not_found',
      'message': 'x',
      'requestId': 'r',
      'retryable': false,
    });
  });

  DriverAccountSession session() => DriverAccountSession(
    repository: DriverAccountRepository(
      ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      ),
    ),
  );
}

/// A phone-sized test view.
void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
