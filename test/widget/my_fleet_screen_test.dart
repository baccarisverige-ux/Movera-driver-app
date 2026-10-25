import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';

/// Round 4: My fleet for a driver without a fleet (join, with the one
/// mismatch message and the hourly limit) and for an owner (the code,
/// drivers and cars).
http.Response _json(int status, Object map, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode(map),
      status,
      headers: {'content-type': 'application/json', ...?headers},
    );

const _owner = {
  'driverId': 'drv_9',
  'accountStatus': 'on_hold',
  'onlineStatus': 'offline',
  'firstName': 'Eva',
  'lastName': 'Nord',
  'email': 'eva@nord.se',
  'accountType': 'fleet',
  'zoneIds': ['Z001'],
  'categoryIds': [],
  'fleet': {
    'fleetId': 'flt_1',
    'name': 'Nord AB',
    'role': 'owner',
    'status': 'approved',
  },
  'documents': [],
  'requiredDocuments': [],
  'version': 2,
};

Map<String, Object?> _fleetView({String status = 'approved', String? code}) => {
  'fleet': {
    'fleetId': 'flt_1',
    'name': 'Nord AB',
    'orgNumber': '556677-8899',
    'country': 'SE',
    'cityId': 'stockholm_lan',
    'ownerDriverId': 'drv_9',
    'ownerName': 'Eva Nord',
    'ownerEmail': 'eva@nord.se',
    'status': status,
    if (code != null) 'code': code,
    'driverCount': 1,
    'vehicleCount': 1,
    'createdAt': '2026-10-01T00:00:00Z',
    'version': 3,
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
};

DriverAccountSession _session(
  http.Client client, {
  required Map<String, Object?> profile,
}) {
  final api = ApiClient(
    client: client,
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );
  return DriverAccountSession(repository: DriverAccountRepository(api))
    ..replace(DriverAccount.fromJson(Map<String, dynamic>.from(profile)));
}

Future<void> _pump(
  WidgetTester tester,
  DriverAccountSession session, {
  List<String>? shared,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MyFleetScreen(
        account: session,
        share: shared == null ? null : (text) async => shared.add(text),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('a driver without a fleet', () {
    // Not drv_1: that driver has the fleet's car in the view below.
    const driver = {
      'driverId': 'drv_5',
      'accountStatus': 'on_hold',
      'onlineStatus': 'offline',
      'firstName': 'Nils',
      'accountType': 'driver',
      'zoneIds': ['Z001'],
      'categoryIds': [],
      'documents': [],
      'requiredDocuments': [],
      'version': 2,
    };

    testWidgets('the join form; one mismatch message covers the three fields', (
      tester,
    ) async {
      final bodies = <Map<String, dynamic>>[];
      final session = _session(
        MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json(400, {
            'code': 'invalid_request',
            'message': 'x',
            'reason': 'fleet_join_mismatch',
          });
        }),
        profile: driver,
      );
      await _pump(tester, session);
      expect(find.text(tr.fleetJoinTitle), findsOneWidget);
      expect(find.text(tr.fleetJoinBody), findsOneWidget);
      // Nothing to join with yet: the button waits.
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const ValueKey('join-submit')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-code')),
        'MV-7K3Q9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-owner')),
        'Eva Nord',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-email')),
        'eva@nord.se',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('join-submit')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(bodies.single, {
        'code': 'MV-7K3Q9',
        'ownerName': 'Eva Nord',
        'ownerEmail': 'eva@nord.se',
      });
      expect(find.text(tr.fleetJoinMismatch), findsOneWidget);
      expect(session.account?.fleet, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('too many tries: the server\'s wait is said', (tester) async {
      final session = _session(
        MockClient(
          (_) async => _json(
            429,
            {
              'code': 'rate_limited',
              'message': 'x',
              'reason': 'fleet_join_limit',
            },
            headers: {'retry-after': '3600'},
          ),
        ),
        profile: driver,
      );
      await _pump(tester, session);
      await tester.enterText(
        find.byKey(const ValueKey('join-code')),
        'MV-7K3Q9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-owner')),
        'Eva Nord',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-email')),
        'eva@nord.se',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('join-submit')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(tr.acctTooManyTriesHour), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a matching code joins: the fleet shows', (tester) async {
      var joined = false;
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.fleetJoinPath) {
            joined = true;
            return _json(200, {
              ...driver,
              'fleet': {
                'fleetId': 'flt_1',
                'name': 'Nord AB',
                'role': 'member',
                'status': 'approved',
              },
              'version': 3,
            });
          }
          if (request.url.path == DriverAccountRepository.fleetPath && joined) {
            final view = _fleetView();
            return _json(200, {...view, 'drivers': []});
          }
          return _json(404, {
            'code': 'not_found',
            'message': 'x',
            'reason': 'no_fleet',
          });
        }),
        profile: driver,
      );
      await _pump(tester, session);
      await tester.enterText(
        find.byKey(const ValueKey('join-code')),
        'MV-7K3Q9',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-owner')),
        'Eva Nord',
      );
      await tester.enterText(
        find.byKey(const ValueKey('join-email')),
        'eva@nord.se',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('join-submit')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(session.account?.fleet?.name, 'Nord AB');
      expect(find.byKey(const ValueKey('fleet-card')), findsOneWidget);
      expect(find.text('Nord AB'), findsWidgets);
      // A member: no code, Leave fleet, and the car in use by Nils.
      expect(find.byKey(const ValueKey('fleet-code')), findsNothing);
      expect(find.byKey(const ValueKey('fleet-leave')), findsOneWidget);
      expect(find.byKey(const ValueKey('car-in-use-veh_1')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('the owner', () {
    testWidgets('sees the code large with Share and Copy, the drivers with '
        'Remove and the cars with Add car', (tester) async {
      final shared = <String>[];
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.fleetPath) {
            return _json(200, _fleetView(code: 'MV-7K3Q9'));
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: _owner,
      );
      await _pump(tester, session, shared: shared);
      expect(find.byKey(const ValueKey('fleet-code')), findsOneWidget);
      expect(find.text('MV-7K3Q9'), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-code-waiting')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('fleet-share')));
      await tester.pump();
      expect(shared.single, contains('MV-7K3Q9'));
      expect(shared.single, contains('Eva Nord'));
      expect(find.byKey(const ValueKey('fleet-driver-drv_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-remove-drv_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('car-veh_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-add-car')), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-leave')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('before approval there is no code, only the waiting line', (
      tester,
    ) async {
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.fleetPath) {
            return _json(200, _fleetView(status: 'pending'));
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: {
          ..._owner,
          'fleet': {
            'fleetId': 'flt_1',
            'name': 'Nord AB',
            'role': 'owner',
            'status': 'pending',
          },
        },
      );
      await _pump(tester, session);
      expect(find.byKey(const ValueKey('fleet-code-waiting')), findsOneWidget);
      expect(find.text(tr.fleetCodeWaiting), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-share')), findsNothing);
      expect(find.text(tr.fleetStatusPending), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
