// Driver group 2 re-check fixes (owner decisions R1–R10 of 2026-10-30,
// `decisions/driver-g2.md` "Full live test 2026-10-30", contract v0.18.3
// §28): the driver-app parts R2, R4, R5, R6, R8 and R10, in sv / fr / en.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/core/onboarding/upload_guide.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/documents/live_documents_screen.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'g2_fixtures.dart';

/// The app in [language] (`sv`, `fr`, `en`).
void _speak(String language) {
  switch (language) {
    case 'sv':
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    case 'fr':
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    default:
      DriverLanguage.resetForTest();
  }
}

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
}) async {
  phone(tester, size: size);
  await tester.pumpWidget(MaterialApp(home: page));
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

const _languages = ['sv', 'fr', 'en'];

void main() {
  // R2 "Year rule for every car (Recommended)".
  group('R2 car rules', () {
    test('Booster Seat (child_seat, no rule of its own) needs the base '
        'year too: SE 2015, FR 2016', () {
      final se = OnboardingSettings.fromJson(settingsJson('SE'));
      final fr = OnboardingSettings.fromJson(settingsJson('FR'));
      expect(se.baseYear, 2015);
      expect(fr.baseYear, 2016);
      expect(
        fr.categoryProblem('child_seat', year: 2015, seats: 4, fuel: 'petrol'),
        'year_too_old',
      );
      expect(
        se.categoryProblem('child_seat', year: 2012, seats: 4, fuel: 'petrol'),
        'year_too_old',
      );
      expect(
        se.categoryProblem('child_seat', year: 2015, seats: 4, fuel: 'petrol'),
        isNull,
      );
      expect(OnboardingSettings.extraCategories, [
        ...((_contract['driverOnboarding'] as Map)['vehicleRules']
                as Map)['extraCategories']
            as List,
      ]);
    });

    for (final language in _languages) {
      testWidgets('[$language] no ride-type choice on Add car (owner '
          'G2-D5.3; replaces the R2 Booster Seat chip check)', (tester) async {
        _speak(language);
        final server = FakeServer({
          'GET ${DriverAccountRepository.onboardingSettingsPath}': (_) async =>
              jsonResponse(200, settingsJson('SE')),
        });
        // Tall enough for the whole form in every language.
        await _host(
          tester,
          AddCarScreen(account: server.session()),
          size: const Size(390, 1600),
        );
        await tester.enterText(find.byKey(const ValueKey('car-make')), 'Volvo');
        await tester.enterText(find.byKey(const ValueKey('car-model')), 'V60');
        await tester.enterText(find.byKey(const ValueKey('car-year')), '2020');
        await tester.enterText(find.byKey(const ValueKey('car-color')), 'Grey');
        await tester.enterText(
          find.byKey(const ValueKey('car-plate')),
          'abc123',
        );
        await _tapKey(tester, 'car-fuel-petrol');
        // v0.18.5 (owner G2-D5.3): no chips at all, Booster Seat included;
        // the hint says Movera gives the ride types, in this language.
        expect(find.byKey(const ValueKey('car-type-child_seat')), findsNothing);
        expect(find.byKey(const ValueKey('car-type-economy')), findsNothing);
        expect(find.text(tr.carTypesByMovera), findsOneWidget);
      });

      test('[$language] 400 category_not_allowed says each problem', () {
        _speak(language);
        final message = accountErrorMessage(
          const ApiError(
            code: 'invalid_request',
            message: 'x',
            statusCode: 400,
            reason: 'category_not_allowed',
            details: [
              'child_seat:extra_needs_ride',
              'car:year_too_old',
              'economy:too_few_seats',
            ],
          ),
          fallback: 'fallback',
          baseYear: 2016,
        );
        expect(message, contains(tr.carRulesNotMet));
        expect(
          message,
          contains(
            tr.carProblemLine(
              tr.categoryBoosterSeat,
              tr.carProblemExtraNeedsRide,
            ),
          ),
        );
        expect(
          message,
          contains(
            tr.carProblemLine(
              tr.carWholeCar,
              tr.carProblemYearTooOldBase(2016),
            ),
          ),
        );
        expect(
          message,
          contains(tr.carProblemLine('Movera', tr.carProblemTooFewSeats)),
        );
        expect(message, isNot(contains('child_seat')));
      });
    }
  });

  // R4 "Red 'Join a fleet' line (Recommended)".
  group('R4 no fleet', () {
    for (final language in _languages) {
      testWidgets('[$language] a red line with Join a fleet and Start my own '
          'company buttons', (tester) async {
        _speak(language);
        final texts =
            (((_contract['driverOnboarding'] as Map)['reminders']
                    as Map)['texts']
                as Map);
        final store = DriverRemindersStore()
          ..replace(
            DriverReminderList.fromJson({
              'items': [
                {
                  'kind': 'no_fleet',
                  'level': 'blocks_online',
                  'fix': {'target': 'join_fleet'},
                  'actions': [
                    {'target': 'join_fleet'},
                    {'target': 'start_company'},
                  ],
                },
              ],
            }),
          );
        final actions = <ReminderFixTarget>[];
        await _host(
          tester,
          Scaffold(
            body: ImportantRemindersBox(
              store: store,
              onFix: (_) {},
              onAction: (_, action) => actions.add(action.target),
            ),
          ),
        );
        expect(
          find.text((texts['no_fleet'] as Map)[language] as String),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-reminder-0-blocksOnline')),
          findsOneWidget,
        );
        final join = find.byKey(
          const ValueKey('home-reminder-0-action-joinFleet'),
        );
        final start = find.byKey(
          const ValueKey('home-reminder-0-action-startCompany'),
        );
        final labels = (texts['actions'] as Map);
        expect(
          find.descendant(
            of: join,
            matching: find.text(
              (labels['join_fleet'] as Map)[language] as String,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: start,
            matching: find.text(
              (labels['start_company'] as Map)[language] as String,
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(join);
        await tester.tap(start);
        expect(actions, [
          ReminderFixTarget.joinFleet,
          ReminderFixTarget.startCompany,
        ]);
      });
    }
  });

  // R5 "Name per country (Recommended)".
  group('R5 names per country', () {
    test('the app\'s names are the contract\'s nameByCountry', () {
      final types =
          ((_contract['driverOnboarding'] as Map)['documents'] as Map)['types']
              as Map;
      for (final MapEntry(key: type, value: info) in types.entries) {
        final byCountry = (info as Map)['nameByCountry'] as Map? ?? const {};
        for (final MapEntry(key: country, value: names) in byCountry.entries) {
          for (final language in _languages) {
            expect(
              DriverOnboardingRules.documentName(
                type as String,
                language,
                country: country as String,
              ),
              (names as Map)[language],
              reason: '$type $country $language',
            );
          }
        }
      }
    });

    test('before the settings are read, the bank statement follows the '
        'country, not the language', () {
      final store = OnboardingSettingsStore.instance;
      store.country = 'SE';
      expect(
        store.nameOf('bank_statement', 'fr'),
        'Relevé bancaire de l’entreprise',
      );
      store.country = 'FR';
      expect(store.nameOf('bank_statement', 'fr'), 'RIB de la société');
      expect(
        store.nameOf('bank_statement', 'sv'),
        'Företagets bankuppgifter (RIB)',
      );
    });

    test('the server\'s name (the country\'s) wins', () {
      final json = settingsJson('SE');
      (json['documentTypes'] as Map)['bank_statement'] = {
        'owner': 'driver',
        'kind': 'file',
        'name': {
          'sv': 'Kontobevis',
          'fr': 'Relevé bancaire de l’entreprise',
          'en': 'Company bank account statement',
        },
      };
      final settings = OnboardingSettings.fromJson(json);
      expect(
        settings.nameOf('bank_statement', 'fr'),
        'Relevé bancaire de l’entreprise',
      );
    });
  });

  // R6 "Update + notice (Recommended)".
  group('R6 refresh and bell notices', () {
    test('review notices: deep links to the document or My fleet', () {
      ServerNotification notice(String kind, String link) =>
          ServerNotification.fromJson({
            'notificationId': 'n1',
            'kind': kind,
            'title': 't',
            'body': 'b',
            'at': '2026-10-30T10:00:00Z',
            'read': false,
            'deepLink': link,
          });
      final rejected = notice(
        'document_rejected',
        'movera-driver://documents/insurance?vehicleId=veh_1',
      );
      expect(rejected.opensDocuments, isTrue);
      expect(rejected.documentLink?.type, 'insurance');
      expect(rejected.documentLink?.vehicleId, 'veh_1');
      final approved = notice(
        'document_approved',
        'movera-driver://documents/driving_license',
      );
      expect(approved.opensDocuments, isTrue);
      expect(approved.documentLink?.vehicleId, isNull);
      for (final kind in [
        'vehicle_approved',
        'vehicle_rejected',
        'vehicle_blocked',
      ]) {
        expect(notice(kind, 'movera-driver://fleet').opensFleet, isTrue);
      }
    });

    testWidgets('a rejected document\'s notice opens its upload guide', (
      tester,
    ) async {
      final server = FakeServer({
        'GET ${DriverAccountRepository.notificationsPath}': (_) async =>
            jsonResponse(200, {
              'items': [
                {
                  'notificationId': 'n1',
                  'kind': 'document_rejected',
                  'title': 'Körkort godkändes inte',
                  'body': 'Anledning: suddigt. Ladda upp ett nytt.',
                  'at': '2026-10-30T10:00:00Z',
                  'read': false,
                  'deepLink': 'movera-driver://documents/driving_license',
                },
              ],
            }),
        'POST ${DriverAccountRepository.notificationsPath}/n1/read':
            (_) async => jsonResponse(204, {}),
      });
      final session = server.session()
        ..replace(DriverAccount.fromJson(profileJson(status: 'on_hold')));
      await _host(tester, ServerNotificationsScreen(account: session));
      expect(find.text('Körkort godkändes inte'), findsOneWidget);
      await _tapKey(tester, 'notification-n1');
      final guide = tester.widget<UploadGuideScreen>(
        find.byType(UploadGuideScreen),
      );
      expect(guide.type, 'driving_license');
      expect(guide.isCar, isFalse);
      expect(guide.status, 'rejected');
    });

    testWidgets('Documents reads the list again every 60 s and when the app '
        'returns', (tester) async {
      var reads = 0;
      var status = 'in_review';
      final server = FakeServer({
        'GET ${DriverAccountRepository.profilePath}': (_) async =>
            jsonResponse(200, profileJson(status: 'on_hold')),
        'GET ${DriverAccountRepository.documentsPath}': (_) async {
          reads++;
          return jsonResponse(200, {
            'items': [
              {
                'documentId': 'd1',
                'ownerId': 'drv_1',
                'type': 'driving_license',
                'status': status,
                'version': 1,
              },
            ],
          });
        },
        'GET ${DriverAccountRepository.vehiclesPath}': (_) async =>
            jsonResponse(200, {'items': []}),
        'GET ${DriverAccountRepository.onboardingSettingsPath}': (_) async =>
            jsonResponse(200, settingsJson('SE')),
        'GET ${DriverAccountRepository.remindersPath}': (_) async =>
            jsonResponse(200, {'items': []}),
      });
      await _host(tester, LiveDocumentsScreen(account: server.session()));
      expect(reads, 1);
      expect(find.text(tr.swDocumentStatusInReview), findsWidgets);
      // The admin approves it; 60 s later the screen shows it.
      status = 'approved';
      await tester.pump(const Duration(seconds: 61));
      await _settle(tester);
      expect(reads, 2);
      expect(find.text(tr.swDocumentStatusApproved), findsWidgets);
      expect(
        server.requests.where(
          (r) => r.url.path == DriverAccountRepository.remindersPath,
        ),
        isNotEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
      expect(reads, 3);
    });
  });

  // R8 "Admin edits all text (Recommended)".
  group('R8 upload guide text', () {
    for (final language in _languages) {
      test('[$language] the admin\'s checklist and tips, else the app\'s', () {
        _speak(language);
        final json = settingsJson('FR');
        final types = json['documentTypes'] as Map;
        types['vtc_card'] = <String, dynamic>{
          ...(types['vtc_card'] as Map),
          'guide': {
            'checklist': [
              {
                'sv': 'Kortnummer',
                'fr': 'Numéro de carte',
                'en': 'Card number',
              },
            ],
            'tips': [
              {'sv': 'Inget blänk', 'fr': 'Sans reflet', 'en': 'No glare'},
            ],
          },
        };
        types['driving_license'] = <String, dynamic>{
          ...(types['driving_license'] as Map),
          'guide': {'checklist': [], 'tips': []},
        };
        final settings = OnboardingSettings.fromJson(json);
        final admin = UploadGuides.forType(
          'vtc_card',
          country: 'FR',
          settings: settings,
        );
        final words = {
          'sv': ('Kortnummer', 'Inget blänk'),
          'fr': ('Numéro de carte', 'Sans reflet'),
          'en': ('Card number', 'No glare'),
        }[language]!;
        expect(admin.checklist, [words.$1]);
        expect(admin.tips, [words.$2]);
        expect(admin.fromAdmin, isTrue);
        final fallback = UploadGuides.forType(
          'driving_license',
          country: 'FR',
          settings: settings,
        );
        expect(fallback.checklist, contains(tr.guideLicenceBothSides));
        expect(fallback.tips, contains(tr.tipNoGlare));
        expect(fallback.fromAdmin, isFalse);
      });
    }
  });

  // R10 "Fix all (Recommended)".
  group('R10 small fixes', () {
    String name(String type) =>
        OnboardingSettingsStore.instance.nameOf(type, tr.localeName);

    test('"Bank details were rejected" (en); sv / fr unchanged', () {
      const reminder = DriverReminder(
        kind: 'document_rejected',
        level: ReminderLevel.blocksOnline,
        documentType: 'bank_statement',
      );
      DriverLanguage.resetForTest();
      expect(
        reminderWords(reminder, nameOf: (_) => 'Bank details').title,
        'Bank details were rejected',
      );
      expect(
        reminderWords(
          const DriverReminder(
            kind: 'document_rejected',
            level: ReminderLevel.blocksOnline,
            documentType: 'driving_license',
          ),
          nameOf: (_) => 'Driving licence',
        ).title,
        'Driving licence was rejected',
      );
      _speak('sv');
      expect(
        reminderWords(reminder, nameOf: (_) => 'Kontobevis').title,
        'Kontobevis godkändes inte',
      );
      _speak('fr');
      expect(
        reminderWords(reminder, nameOf: (_) => 'RIB de la société').title,
        'Refusé : RIB de la société',
      );
    });

    for (final language in _languages) {
      test('[$language] the hold line names the real first reason', () {
        _speak(language);
        final uploaded = DriverReminderList.fromJson({
          'items': [
            {
              'kind': 'document_in_review',
              'level': 'waiting',
              'documentType': 'driving_license',
            },
          ],
        });
        final noFleet = DriverReminderList.fromJson({
          'items': [
            {'kind': 'no_fleet', 'level': 'blocks_online'},
          ],
        });
        final noCar = DriverReminderList.fromJson({
          'items': [
            {'kind': 'no_vehicle', 'level': 'blocks_online'},
          ],
        });
        expect(holdHeadline(uploaded, nameOf: name), tr.holdAccountChecking);
        expect(holdHeadline(noFleet, nameOf: name), tr.remNoFleet);
        // Not active: no "before you go online".
        expect(holdHeadline(noCar, nameOf: name), tr.remNoVehicleNotActive);
        for (final text in [
          tr.holdAccountChecking,
          tr.remNoVehicleNotActive,
          tr.remNoFleet,
        ]) {
          expect(text, isNot(contains(tr.holdBeingChecked)));
        }
        expect(tr.holdAccountChecking, isNot(equals(tr.holdBeingChecked)));
      });

      testWidgets('[$language] My fleet does not say "in My fleet"', (
        tester,
      ) async {
        _speak(language);
        final server = FakeServer({
          'GET ${DriverAccountRepository.profilePath}': (_) async =>
              jsonResponse(
                200,
                profileJson(
                  accountType: 'fleet',
                  role: 'owner',
                  status: 'on_hold',
                ),
              ),
          'GET ${DriverAccountRepository.fleetPath}': (_) async =>
              jsonResponse(200, {
                'fleet': {
                  'fleetId': 'flt_1',
                  'name': 'Nord Taxi',
                  'status': 'approved',
                  'version': 1,
                },
                'drivers': [],
                'vehicles': [
                  {
                    'vehicleId': 'veh_1',
                    'make': 'Toyota',
                    'model': 'Prius',
                    'year': 2020,
                    'color': 'White',
                    'plate': 'TST G2A',
                    'seats': 4,
                    'categoryIds': ['economy'],
                    'status': 'pending',
                    'version': 1,
                  },
                ],
              }),
          'GET ${DriverAccountRepository.fleetInvitationsPath}': (_) async =>
              jsonResponse(200, {'items': []}),
        });
        final session = server.session();
        await session.refresh();
        await _host(tester, MyFleetScreen(account: session));
        final note = find.byKey(const ValueKey('fleet-no-approved-car'));
        expect(note, findsOneWidget);
        expect(
          find.descendant(
            of: note,
            matching: find.text(tr.fleetNoApprovedCarOwnerHere),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: note,
            matching: find.text(tr.remFleetNoApprovedCarOwner),
          ),
          findsNothing,
        );
        expect(tr.fleetNoApprovedCarOwnerHere, isNot(contains(tr.myFleet)));
      });
    }

    testWidgets('details: the phone row comes back after a reload', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      Future<void> open({String? phone}) async {
        tester.view.physicalSize = const Size(390, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: DriverDetailsScreen(
              account: _pendingSession(),
              onDone: (_) {},
              clock: () => DateTime(2026, 10, 30),
              phone: phone,
              draft: DetailsDraft(repository: settings),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await open(phone: '+46701740609');
      expect(find.byKey(const ValueKey('details-phone')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await SettingsRepository.settle();
      // The app is reloaded: the sign-in's phone is gone.
      await open();
      expect(find.byKey(const ValueKey('details-phone')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final language in _languages) {
      testWidgets('[$language] details: 19900505 becomes 1990-05-05; a date '
          'that does not exist is refused', (tester) async {
        _speak(language);
        tester.view.physicalSize = const Size(390, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          MaterialApp(
            home: DriverDetailsScreen(
              account: _pendingSession(),
              onDone: (_) {},
              clock: () => DateTime(2026, 10, 30),
              draft: DetailsDraft(repository: SettingsRepository()),
            ),
          ),
        );
        await tester.pump();
        final dob = find.byKey(const ValueKey('details-dob'));
        await tester.ensureVisible(dob);
        await tester.enterText(dob, '19900505');
        await tester.pump();
        expect(tester.widget<TextField>(dob).controller!.text, '1990-05-05');
        await tester.enterText(dob, '19901345');
        await tester.pump();
        final continueButton = find.byKey(const ValueKey('details-continue'));
        await tester.ensureVisible(continueButton);
        await tester.tap(continueButton);
        await tester.pump();
        expect(find.text(tr.acctInvalidDate), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}

DriverAccountSession _pendingSession() {
  final api = ApiClient(
    client: MockClient(
      (_) async => http.Response(
        '{"code":"not_found","message":"x"}',
        404,
        headers: {'content-type': 'application/json'},
      ),
    ),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );
  return DriverAccountSession(repository: DriverAccountRepository(api))
    ..replace(
      const DriverAccount(
        driverId: 'drv_1',
        accountStatus: 'pending',
        firstName: '',
        version: 1,
      ),
    );
}
