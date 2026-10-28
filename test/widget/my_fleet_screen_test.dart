import 'dart:async';
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

Map<String, Object?> _invitation({
  String id = 'inv_1',
  String direction = 'owner_invite',
  String? driverId = 'drv_5',
  String? driverName = 'Nils Berg',
  String? phone,
  String status = 'pending',
}) => {
  'invitationId': id,
  'fleetId': 'flt_1',
  'fleetName': 'Nord AB',
  'direction': direction,
  if (driverId != null) 'driverId': driverId,
  if (driverName != null) 'driverName': driverName,
  if (phone != null) 'phone': phone,
  'status': status,
  'createdAt': '2026-10-25T10:00:00Z',
  'expiresAt': '2026-11-01T10:00:00Z',
  'version': 1,
};

/// Round 4: My fleet for a driver without a fleet (a request to join, with
/// the one mismatch message and the hourly limit; the owners' invites)
/// and for an owner (the code, the requests and invites, drivers and
/// cars).
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

Map<String, Object?> _fleetView({
  String status = 'approved',
  String? code,
  List<Map<String, Object?>> invitations = const [],
}) => {
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
      // Contract v0.14.0: only a car with its documents approved is picked.
      'documents': [
        {
          'documentId': 'vd1',
          'type': 'vehicle_registration',
          'status': 'approved',
        },
        {'documentId': 'vd2', 'type': 'insurance', 'status': 'approved'},
      ],
      'requiredDocuments': ['vehicle_registration', 'insurance'],
    },
  ],
  'invitations': invitations,
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
  tester.view.physicalSize = const Size(390, 1800);
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

    /// Answers the reads My fleet does on open (the profile, the
    /// invitations); [onJoin] answers the request.
    http.Client server({
      List<Map<String, Object?>> invitations = const [],
      required http.Response Function(Map<String, dynamic> body) onJoin,
      void Function(String path)? onAction,
    }) => MockClient((request) async {
      if (request.url.path == DriverAccountRepository.profilePath) {
        return _json(200, driver);
      }
      if (request.url.path == DriverAccountRepository.fleetInvitationsPath) {
        return _json(200, {'items': invitations});
      }
      if (request.url.path == DriverAccountRepository.fleetJoinPath) {
        return onJoin(jsonDecode(request.body) as Map<String, dynamic>);
      }
      if (request.url.path.startsWith(
        '${DriverAccountRepository.fleetInvitationsPath}/',
      )) {
        onAction?.call(request.url.path);
        return _json(200, _invitation(status: 'accepted'));
      }
      return _json(404, {'code': 'not_found', 'message': 'x'});
    });

    Future<void> fillJoin(WidgetTester tester) async {
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
    }

    testWidgets('the join form; one mismatch message covers the three fields', (
      tester,
    ) async {
      final bodies = <Map<String, dynamic>>[];
      final session = _session(
        server(
          onJoin: (body) {
            bodies.add(body);
            return _json(400, {
              'code': 'invalid_request',
              'message': 'x',
              'reason': 'fleet_join_mismatch',
            });
          },
        ),
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
      await fillJoin(tester);
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
        server(
          onJoin: (_) => _json(
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
      await fillJoin(tester);
      expect(find.text(tr.acctTooManyTriesHour), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a matching code sends a request; it shows as pending with '
        'Cancel, and a second request is refused (request_pending)', (
      tester,
    ) async {
      var requested = false;
      final actions = <String>[];
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.profilePath) {
            return _json(200, driver);
          }
          if (request.url.path ==
              DriverAccountRepository.fleetInvitationsPath) {
            return _json(200, {
              'items': [
                if (requested)
                  _invitation(id: 'inv_7', direction: 'driver_request'),
              ],
            });
          }
          if (request.url.path == DriverAccountRepository.fleetJoinPath) {
            if (requested) {
              return _json(409, {
                'code': 'conflict',
                'message': 'x',
                'reason': 'request_pending',
              });
            }
            requested = true;
            return _json(
              201,
              _invitation(id: 'inv_7', direction: 'driver_request'),
            );
          }
          if (request.url.path.endsWith('/cancel')) {
            actions.add(request.url.path);
            requested = false;
            return _json(200, _invitation(id: 'inv_7', status: 'cancelled'));
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: driver,
      );
      await _pump(tester, session);
      await fillJoin(tester);
      // Not linked: the owner answers first.
      expect(session.account?.fleet, isNull);
      expect(find.text(tr.fleetRequestSent('Nord AB')), findsOneWidget);
      expect(find.byKey(const ValueKey('invitation-inv_7')), findsOneWidget);
      expect(find.text(tr.fleetRequestWaitsOwner), findsOneWidget);
      expect(find.byKey(const ValueKey('join-submit')), findsNothing);
      expect(
        find.byKey(const ValueKey('invitation-cancel-inv_7')),
        findsOneWidget,
      );
      // Cancel takes it back: the form is back.
      await tester.tap(find.byKey(const ValueKey('invitation-cancel-inv_7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-yes')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(actions.single, endsWith('/inv_7/cancel'));
      expect(find.byKey(const ValueKey('join-submit')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an owner\'s invite: Accept links the driver, the fleet '
        'shows; Decline asks first', (tester) async {
      var accepted = false;
      final actions = <String>[];
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.profilePath) {
            return _json(200, {
              ...driver,
              if (accepted)
                'fleet': {
                  'fleetId': 'flt_1',
                  'name': 'Nord AB',
                  'role': 'member',
                  'status': 'approved',
                }
              else
                'pendingFleetInvitations': 1,
            });
          }
          if (request.url.path ==
              DriverAccountRepository.fleetInvitationsPath) {
            return _json(200, {
              'items': [if (!accepted) _invitation()],
            });
          }
          if (request.url.path.endsWith('/inv_1/accept')) {
            actions.add('accept');
            accepted = true;
            return _json(200, _invitation(status: 'accepted'));
          }
          if (request.url.path == DriverAccountRepository.fleetPath &&
              accepted) {
            return _json(200, {..._fleetView(), 'drivers': []});
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: driver,
      );
      await _pump(tester, session);
      // The badge in the app bar and the invite with its two answers.
      expect(find.byKey(const ValueKey('invitation-badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('invitation-inv_1')), findsOneWidget);
      expect(find.text(tr.fleetInviteBodyDriver), findsOneWidget);
      expect(
        find.byKey(const ValueKey('invitation-accept-inv_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('invitation-decline-inv_1')),
        findsOneWidget,
      );
      // Decline asks first; Stay keeps it.
      await tester.tap(find.byKey(const ValueKey('invitation-decline-inv_1')));
      await tester.pump();
      expect(find.text(tr.fleetDeclineInviteQ('Nord AB')), findsOneWidget);
      await tester.tap(find.text(tr.cancel).last);
      await tester.pump();
      expect(actions, isEmpty);
      await tester.tap(find.byKey(const ValueKey('invitation-accept-inv_1')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(actions, ['accept']);
      expect(session.account?.fleet?.name, 'Nord AB');
      expect(find.byKey(const ValueKey('fleet-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('fleet-leave')), findsOneWidget);
      expect(find.byKey(const ValueKey('invitation-badge')), findsNothing);
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

    testWidgets('choosing one car, then another at once: one request '
        '(audit Phase 5)', (tester) async {
      Map<String, Object?> free(String id) => {
        ...(_fleetView()['vehicles'] as List).first as Map<String, Object?>,
        'vehicleId': id,
        'plate': 'P$id',
        'driverId': null,
        'inUse': false,
      };
      final gate = Completer<http.Response>();
      var patches = 0;
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.fleetPath) {
            return _json(200, {
              ..._fleetView(code: 'MV-7K3Q9'),
              'vehicles': [free('veh_a'), free('veh_b')],
            });
          }
          if (request.method == 'PATCH') {
            patches++;
            return gate.future;
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: _owner,
      );
      await _pump(tester, session);
      await tester.tap(find.byKey(const ValueKey('car-pick-veh_a')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('car-pick-veh_b')),
        warnIfMissed: false,
      );
      await tester.pump();
      gate.complete(_json(200, {..._owner, 'vehicleId': 'veh_a'}));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(patches, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sees the drivers\' requests with Accept / Decline, his own '
        'invites with Cancel, and invites a number', (tester) async {
      final calls = <String>[];
      var invited = false;
      final session = _session(
        MockClient((request) async {
          if (request.url.path == DriverAccountRepository.profilePath) {
            return _json(200, {..._owner, 'pendingFleetInvitations': 1});
          }
          if (request.url.path == DriverAccountRepository.fleetPath) {
            return _json(
              200,
              _fleetView(
                code: 'MV-7K3Q9',
                invitations: [
                  _invitation(
                    id: 'inv_r',
                    direction: 'driver_request',
                    driverId: 'drv_8',
                    driverName: 'Omar Said',
                  ),
                  if (invited)
                    _invitation(
                      id: 'inv_p',
                      driverId: null,
                      driverName: null,
                      phone: '+46701740608',
                    ),
                ],
              ),
            );
          }
          if (request.url.path == DriverAccountRepository.fleetInvitePath) {
            calls.add('invite ${jsonDecode(request.body)['phone']}');
            invited = true;
            return _json(
              201,
              _invitation(
                id: 'inv_p',
                driverId: null,
                driverName: null,
                phone: '+46701740608',
              ),
            );
          }
          if (request.url.path.endsWith('/inv_r/accept')) {
            calls.add('accept');
            return _json(200, _invitation(id: 'inv_r', status: 'accepted'));
          }
          return _json(404, {'code': 'not_found', 'message': 'x'});
        }),
        profile: _owner,
      );
      await _pump(tester, session);
      expect(find.byKey(const ValueKey('invitation-badge')), findsOneWidget);
      expect(find.text('Omar Said'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('invitation-accept-inv_r')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('invitation-decline-inv_r')),
        findsOneWidget,
      );
      expect(find.text(tr.fleetNoInvites), findsOneWidget);
      // Invite a number: +46 is there already, the national zero goes.
      await tester.ensureVisible(
        find.byKey(const ValueKey('fleet-invite-driver')),
      );
      await tester.tap(find.byKey(const ValueKey('fleet-invite-driver')));
      await tester.pump();
      expect(find.text(tr.fleetInviteDriver), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey('invite-phone')),
        '+46 070 174 06 08',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('invite-send')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(calls, ['invite +46701740608']);
      expect(find.byKey(const ValueKey('invitation-inv_p')), findsOneWidget);
      expect(find.text(tr.fleetInviteWaitsSignUp), findsOneWidget);
      expect(
        find.byKey(const ValueKey('invitation-cancel-inv_p')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('invitation-accept-inv_r')),
      );
      await tester.tap(find.byKey(const ValueKey('invitation-accept-inv_r')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(calls, ['invite +46701740608', 'accept']);
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
      // v0.10.4: the contract word for a fleet under review.
      expect(find.text(tr.swVehicleReviewStatusInReview), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
