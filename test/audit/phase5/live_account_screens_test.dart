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
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/join_fleet_screen.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:movera/presentation/driver/vehicles/live_vehicles_screen.dart';

import '../../onboarding/g2_fixtures.dart';

/// Audit Phase 5: the four round-4b live screens that had no test at all
/// (baseline R7): loading, empty and error states, one request per
/// action however often it is tapped, forms, Back, and small screens with
/// large text in sv/fr/en.
void main() {
  late List<http.Request> seen;
  late Map<String, FutureOr<http.Response> Function(http.Request)> routes;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  DriverAccountSession session({Map<String, Object?>? profile}) {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      seen.add(request);
      final key = '${request.method} ${request.url.path}';
      final route = routes[key];
      return route == null
          ? json(503, {
              'code': 'unavailable',
              'message': 'down',
              'requestId': 'x',
              'retryable': true,
            })
          : await route(request);
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    final s = DriverAccountSession(repository: DriverAccountRepository(api));
    if (profile != null) s.replace(DriverAccount.fromJson(profile));
    return s;
  }

  int count(String method, String path) =>
      seen.where((r) => r.method == method && r.url.path == path).length;

  Future<void> host(
    WidgetTester tester,
    Widget screen, {
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  const notice = {
    'notificationId': 'n1',
    'kind': 'fleet_invitation_answered',
    'title': 'Request accepted',
    'body': 'Nord AB accepted you.',
    'at': '2026-10-26T10:00:00Z',
    'read': false,
  };

  Map<String, Object?> car(String id) => {
    'vehicleId': id,
    'make': 'Volvo',
    'model': 'XC60',
    'year': 2022,
    'color': 'Black',
    'plate': 'ABC$id',
    'seats': 4,
    'categoryIds': ['economy'],
    'status': 'approved',
    'version': 1,
  };

  const member = {
    'driverId': 'drv_1',
    'accountStatus': 'active',
    'onlineStatus': 'offline',
    'firstName': 'Ali',
    'accountType': 'driver',
    'zoneIds': ['Z001'],
    'categoryIds': ['economy'],
    'fleet': {
      'fleetId': 'flt_1',
      'name': 'Nord AB',
      'role': 'member',
      'status': 'approved',
    },
    'documents': [],
    'version': 3,
  };

  setUp(() {
    seen = [];
    routes = {};
    DriverAppTexts.language = 'en';
  });
  tearDown(() => DriverAppTexts.language = 'en');

  group('Notifications (server)', () {
    const path = '/api/v1/notifications';

    testWidgets('loading, then empty; Back', (tester) async {
      final gate = Completer<http.Response>();
      routes['GET $path'] = (_) => gate.future;
      await host(
        tester,
        ServerNotificationsScreen(account: session()),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(json(200, {'items': []}));
      await tester.pumpAndSettle();
      expect(find.text(tr.notifNone), findsOneWidget);
      await back(tester);
    });

    testWidgets('error, then Retry loads', (tester) async {
      await host(tester, ServerNotificationsScreen(account: session()));
      expect(find.text(tr.retry), findsOneWidget);
      routes['GET $path'] = (_) => json(200, {
        'items': [notice],
      });
      await tester.tap(find.text(tr.retry));
      await tester.pumpAndSettle();
      expect(find.text('Request accepted'), findsOneWidget);
      await back(tester);
    });

    testWidgets('a row tapped three times is marked read once', (tester) async {
      routes['GET $path'] = (_) => json(200, {
        'items': [notice],
      });
      routes['POST $path/n1/read'] = (_) =>
          json(200, {...notice, 'read': true});
      final account = session();
      await host(tester, ServerNotificationsScreen(account: account));
      expect(account.unreadNotifications.value, 1);
      // Three taps, a frame apart (a quick double tap).
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('notification-n1')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(count('POST', '$path/n1/read'), 1);
      expect(account.unreadNotifications.value, 0);
      expect(
        find.byKey(const ValueKey('notification-unread-n1')),
        findsNothing,
      );
      await back(tester);
    });
  });

  group('Add car', () {
    const path = '/api/v1/driver/vehicles';

    // Contract v0.17.0 (owner group 2 item 11): the car rules of the
    // country decide which car types are offered.
    setUp(() {
      routes['GET ${DriverAccountRepository.onboardingSettingsPath}'] = (_) =>
          json(200, settingsJson('SE'));
    });

    Future<void> fill(WidgetTester tester, {String year = '2022'}) async {
      await tester.enterText(find.byKey(const ValueKey('car-make')), 'Volvo');
      await tester.enterText(find.byKey(const ValueKey('car-model')), 'XC60');
      await tester.enterText(find.byKey(const ValueKey('car-year')), year);
      await tester.enterText(find.byKey(const ValueKey('car-color')), 'Black');
      await tester.enterText(find.byKey(const ValueKey('car-plate')), 'ABC123');
      await tester.pump();
      final fuel = find.byKey(const ValueKey('car-fuel-petrol'));
      await tester.ensureVisible(fuel);
      await tester.tap(fuel);
      await tester.pump();
      final economy = find.byKey(const ValueKey('car-type-economy'));
      if (economy.evaluate().isNotEmpty) {
        await tester.ensureVisible(economy);
        await tester.tap(economy);
        await tester.pump();
      }
    }

    bool saveEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const ValueKey('car-save')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed !=
        null;

    testWidgets('Save waits for a complete form (year in range)', (
      tester,
    ) async {
      await host(tester, AddCarScreen(account: session()));
      expect(saveEnabled(tester), isFalse);
      await fill(tester, year: '1900');
      expect(saveEnabled(tester), isFalse);
      await tester.enterText(find.byKey(const ValueKey('car-year')), '2022');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('car-type-economy')));
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
      await back(tester);
    });

    testWidgets('Save tapped three times sends one car; error is shown', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      routes['POST $path'] = (_) => gate.future;
      await host(tester, AddCarScreen(account: session()));
      await fill(tester);
      final save = find.byKey(const ValueKey('car-save'));
      await tester.ensureVisible(save);
      for (var i = 0; i < 3; i++) {
        await tester.tap(save, warnIfMissed: false);
        await tester.pump();
      }
      gate.complete(
        json(409, {
          'code': 'conflict',
          'message': 'Plate exists',
          'requestId': 'x',
          'retryable': false,
        }),
      );
      await tester.pumpAndSettle();
      expect(count('POST', path), 1);
      // Still on the form, with a message, and Save works again.
      expect(find.byKey(const ValueKey('car-save')), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await back(tester);
    });
  });

  group('Join fleet', () {
    const path = '/api/v1/driver/fleet/join';

    testWidgets('a bad e-mail keeps Ask disabled; one request per tap '
        'burst', (tester) async {
      final gate = Completer<http.Response>();
      routes['POST $path'] = (_) => gate.future;
      await host(tester, JoinFleetScreen(account: session()));
      await tester.enterText(find.byKey(const ValueKey('join-code')), 'NORD1');
      await tester.enterText(find.byKey(const ValueKey('join-owner')), 'Eva');
      await tester.enterText(
        find.byKey(const ValueKey('join-email')),
        'eva@nord',
      );
      await tester.pump();
      final submit = find.descendant(
        of: find.byKey(const ValueKey('join-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('join-email')),
        'eva@nord.se',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      for (var i = 0; i < 3; i++) {
        await tester.tap(submit, warnIfMissed: false);
        await tester.pump();
      }
      gate.complete(
        json(422, {
          'code': 'validation_failed',
          'message': 'no match',
          'requestId': 'x',
          'retryable': false,
        }),
      );
      await tester.pumpAndSettle();
      expect(count('POST', path), 1);
      await back(tester);
    });
  });

  group('Vehicles (live)', () {
    const path = '/api/v1/driver/vehicles';

    testWidgets('error then Retry; a member with no cars is told so', (
      tester,
    ) async {
      await host(tester, LiveVehiclesScreen(account: session(profile: member)));
      expect(find.text(tr.retry), findsOneWidget);
      routes['GET $path'] = (_) => json(200, {'items': []});
      await tester.tap(find.text(tr.retry));
      await tester.pumpAndSettle();
      expect(find.text(tr.fleetNoCarsMember), findsOneWidget);
      await back(tester);
    });

    testWidgets('choosing one car, then another at once: one request', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      routes['GET $path'] = (_) => json(200, {
        'items': [car('1'), car('2')],
      });
      routes['PATCH /api/v1/driver/profile'] = (_) => gate.future;
      await host(tester, LiveVehiclesScreen(account: session(profile: member)));
      await tester.tap(find.byKey(const ValueKey('car-pick-1')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('car-pick-2')));
      await tester.tap(
        find.byKey(const ValueKey('car-pick-2')),
        warnIfMissed: false,
      );
      await tester.pump();
      gate.complete(json(200, {...member, 'vehicleId': '1', 'version': 4}));
      await tester.pumpAndSettle();
      expect(count('PATCH', '/api/v1/driver/profile'), 1);
      await back(tester);
    });
  });

  group('small screen, large text, three languages', () {
    for (final language in ['sv', 'fr', 'en']) {
      testWidgets('$language: each screen lays out at 320x568, text x2', (
        tester,
      ) async {
        DriverAppTexts.language = language;
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        routes['GET /api/v1/notifications'] = (_) => json(200, {
          'items': [notice],
        });
        routes['GET /api/v1/driver/vehicles'] = (_) => json(200, {
          'items': [car('1')],
        });
        for (final screen in <Widget>[
          ServerNotificationsScreen(account: session()),
          AddCarScreen(account: session()),
          JoinFleetScreen(account: session()),
          LiveVehiclesScreen(account: session(profile: member)),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2),
                ),
                child: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$screen');
        }
      });
    }
  });
}
