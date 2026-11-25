import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';
import 'package:movera/presentation/driver/home/reminder_fix_page.dart';

/// Contract v0.18.159 (contract.json#fleetNeedsCar; owner 2026-11-24 "Why
/// fleet owner after sign in don't know that he need to add car ?", mockup
/// PROPOSAL-fleet-add-car-2026-11-24.html A + B approved): the red Home line
/// "Add your first car" with the Add car button, the reworded grey
/// "Movera has not approved your fleet yet" line, and My fleet › Cars with
/// no car: the "No car yet" card with Add car. Written before the code.
http.Response _json(int status, Object map) => http.Response(
  jsonEncode(map),
  status,
  headers: {'content-type': 'application/json'},
);

const _owner = {
  'driverId': 'drv_9',
  'accountStatus': 'on_hold',
  'onlineStatus': 'offline',
  'firstName': 'Eva',
  'lastName': 'Nord',
  'accountType': 'fleet',
  'zoneIds': ['Z001'],
  'categoryIds': [],
  'fleet': {
    'fleetId': 'flt_1',
    'name': 'Nord AB',
    'role': 'owner',
    'status': 'pending',
  },
  'documents': [],
  'requiredDocuments': [],
  'version': 2,
};

Map<String, Object?> _emptyFleet() => {
  'fleet': {
    'fleetId': 'flt_1',
    'name': 'Nord AB',
    'orgNumber': '556677-8899',
    'country': 'SE',
    'cityId': 'stockholm_lan',
    'ownerDriverId': 'drv_9',
    'ownerName': 'Eva Nord',
    'status': 'pending',
    'driverCount': 1,
    'vehicleCount': 0,
    'createdAt': '2026-11-24T00:00:00Z',
    'version': 1,
  },
  'drivers': <Object>[],
  'vehicles': <Object>[],
  'invitations': <Object>[],
};

DriverAccountSession _session() {
  final api = ApiClient(
    client: MockClient((request) async {
      if (request.url.path == DriverAccountRepository.fleetPath) {
        return _json(200, _emptyFleet());
      }
      if (request.url.path == DriverAccountRepository.profilePath) {
        return _json(200, _owner);
      }
      return _json(200, {'items': <Object>[]});
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );
  return DriverAccountSession(repository: DriverAccountRepository(api))
    ..replace(DriverAccount.fromJson(Map<String, dynamic>.from(_owner)));
}

DriverRemindersStore _store() => DriverRemindersStore()
  ..replace(
    DriverReminderList.fromJson({
      'blocksOnline': 2,
      'items': [
        {
          'kind': 'fleet_no_car',
          'level': 'blocks_online',
          'fix': {'target': 'fleet_vehicles'},
        },
        {'kind': 'fleet_not_approved', 'level': 'blocks_online'},
      ],
    }),
  );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await _settle(tester);
}

/// SHOULD 1: the app's words are the contract's (texts approved by the
/// owner), in every language.
void _parity() {
  test('contract reminders.texts = the app texts (en / sv / fr)', () {
    final c =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final texts =
        ((c['driverOnboarding'] as Map)['reminders'] as Map)['texts'] as Map;
    for (final lang in ['en', 'sv', 'fr']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      for (final (contractKey, arbKey) in [
        ('fleet_no_car', 'remFleetNoCar'),
        ('fleet_no_car_body', 'remFleetNoCarDetail'),
        ('fleet_add_car', 'fleetAddCar'),
        ('fleet_not_approved', 'remFleetNotApproved'),
        ('fleet_not_approved_body', 'remFleetNotApprovedDetail'),
        ('fleet_cars_empty', 'fleetNoCarYet'),
        ('fleet_cars_empty_body', 'fleetNoCarYetBody'),
      ]) {
        expect(
          arb[arbKey],
          (texts[contractKey] as Map)[lang],
          reason: '$lang $contractKey',
        );
      }
    }
  });
}

void main() {
  _parity();
  test('v0.18.159: the app sends X-Contract-Version 0.18.159 or later', () {
    final parts = ApiClient.contractVersion.split('.').map(int.parse).toList();
    expect(parts[0] > 0 || parts[1] > 18 || parts[2] >= 159, isTrue);
  });

  for (final country in ['SE', 'FR']) {
    group(country, () {
      setUp(() => DriverLanguage.applyZone(AppLanguages.forCountry(country)));

      test('the words: red "Add your first car" with Add car; the grey '
          'fleet line says we review after the car and documents', () {
        final list = _store();
        final words = reminderWords(
          list.items[0],
          nameOf: (t) => t,
          owner: true,
          active: false,
        );
        expect(words.title, tr.remFleetNoCar);
        expect(words.detail, tr.remFleetNoCarDetail);
        expect(words.action, tr.fleetAddCar);
        final grey = reminderWords(
          list.items[1],
          nameOf: (t) => t,
          owner: true,
          ownerOfPendingFleet: true,
        );
        expect(grey.title, tr.remFleetNotApproved);
        expect(grey.detail, tr.remFleetNotApprovedDetail);
        // Review M3: a member, a rejected or a blocked fleet: title only.
        final plain = reminderWords(list.items[1], nameOf: (t) => t);
        expect(plain.title, tr.remFleetNotApproved);
        expect(plain.detail, isNull);
        expect(
          holdHeadline(
            DriverReminderList.fromJson({
              'blocksOnline': 1,
              'items': [
                {
                  'kind': 'fleet_no_car',
                  'level': 'blocks_online',
                  'fix': {'target': 'fleet_vehicles'},
                },
              ],
            }),
            nameOf: (t) => t,
            owner: true,
          ),
          tr.remFleetNoCar,
        );
      });

      testWidgets('Home: the red line first with its Add car button, the '
          'fleet line grey', (tester) async {
        final fixed = <String>[];
        await _host(
          tester,
          Scaffold(
            body: ListView(
              children: [
                ImportantRemindersBox(
                  store: _store(),
                  owner: true,
                  ownerOfPendingFleet: true,
                  active: false,
                  onFix: (r) => fixed.add(r.kind),
                ),
              ],
            ),
          ),
        );
        expect(find.text(tr.remFleetNoCar), findsOneWidget);
        expect(find.text(tr.remFleetNoCarDetail), findsOneWidget);
        expect(find.text(tr.fleetAddCar), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-reminder-0-blocksOnline')),
          findsOneWidget,
        );
        // Mockup A: the fleet line is grey (Movera acts next).
        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('home-reminder-1-blocksOnline')),
        );
        expect(
          (dot.decoration! as BoxDecoration).color,
          ImportantRemindersBox.grey,
        );
        expect(find.text(tr.remFleetNotApprovedDetail), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-reminder-0')));
        await tester.tap(find.byKey(const ValueKey('home-reminder-1')));
        expect(fixed, ['fleet_no_car']);
      });

      for (final who in ['member', 'rejected', 'blocked']) {
        testWidgets('$who: the fleet line stays red, title only', (
          tester,
        ) async {
          await _host(
            tester,
            Scaffold(
              body: ListView(
                children: [
                  ImportantRemindersBox(
                    store: _store(),
                    owner: who != 'member',
                    active: false,
                    onFix: (_) {},
                  ),
                ],
              ),
            ),
          );
          final dot = tester.widget<Container>(
            find.byKey(const ValueKey('home-reminder-1-blocksOnline')),
          );
          expect(
            (dot.decoration! as BoxDecoration).color,
            ImportantRemindersBox.red,
          );
          expect(find.text(tr.remFleetNotApproved), findsOneWidget);
          expect(find.text(tr.remFleetNotApprovedDetail), findsNothing);
        });
      }

      testWidgets('Home line tap → My fleet → Add car (the path Home uses: '
          'reminderFixPage pushed on tap)', (tester) async {
        final session = _session();
        await _host(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: ListView(
                children: [
                  ImportantRemindersBox(
                    store: _store(),
                    owner: true,
                    ownerOfPendingFleet: true,
                    onFix: (r) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => reminderFixPage(session, r, r.fix!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('home-reminder-0')));
        await _settle(tester);
        expect(find.byType(AddCarScreen), findsOneWidget);
        await tester.pageBack();
        await _settle(tester);
        expect(find.byType(MyFleetScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('fleet-no-car-card')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('the Add car fix opens My fleet with Add car on top', (
        tester,
      ) async {
        final session = _session();
        final reminder = _store().items.first;
        await _host(tester, reminderFixPage(session, reminder, reminder.fix!));
        expect(find.byType(AddCarScreen), findsOneWidget);
        await tester.pageBack();
        await _settle(tester);
        expect(find.byType(MyFleetScreen), findsOneWidget);
        expect(find.byType(AddCarScreen), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('My fleet › Cars with no car: the "No car yet" card and '
          'one Add car button that opens Add car', (tester) async {
        await _host(tester, MyFleetScreen(account: _session()));
        expect(find.byKey(const ValueKey('fleet-no-car-card')), findsOneWidget);
        expect(find.text(tr.fleetNoCarYet), findsOneWidget);
        expect(find.text(tr.fleetNoCarYetBody), findsOneWidget);
        expect(find.byKey(const ValueKey('fleet-add-car')), findsOneWidget);
        expect(find.text(tr.fleetNoCars), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('fleet-add-car')));
        await tester.tap(find.byKey(const ValueKey('fleet-add-car')));
        await _settle(tester);
        expect(find.byType(AddCarScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }
}
