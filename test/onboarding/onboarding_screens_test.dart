// Driver group 2 "Onboarding" (owner decisions of 2026-10-29, contract
// v0.17.0 §25): the screens, in Sweden (sv) and France (fr).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/add_car_screen.dart';
import 'package:movera/presentation/driver/account/fleet_car_card.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/info_session_screen.dart';
import 'package:movera/presentation/driver/documents/live_documents_screen.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';

import 'g2_fixtures.dart';

class _Picker implements DocumentFilePicker {
  _Picker({this.file, this.cameraError});

  final PickedDocumentFile? file;
  final Object? cameraError;
  final List<String> calls = [];

  @override
  Future<PickedDocumentFile?> takePhoto() async {
    calls.add('camera');
    if (cameraError != null) throw cameraError!;
    return file;
  }

  @override
  Future<PickedDocumentFile?> choosePhoto() async {
    calls.add('gallery');
    return file;
  }

  @override
  Future<PickedDocumentFile?> chooseFile() async {
    calls.add('file');
    return file;
  }
}

final _photo = PickedDocumentFile(
  bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]),
  fileName: 'licence.jpg',
  mediaType: 'image/jpeg',
);

http.Response _uploaded(String type) => jsonResponse(201, {
  'documentId': 'doc_new',
  'ownerId': 'drv_1',
  'type': type,
  'status': 'in_review',
  'version': 1,
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(WidgetTester tester, Widget page) async {
  phone(tester);
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

void main() {
  for (final country in ['SE', 'FR']) {
    group('$country (${country == 'FR' ? 'fr' : 'sv'})', () {
      setUp(() => DriverLanguage.applyZone(AppLanguages.forCountry(country)));

      // Items 2, 3, 9: the Home sheet box.
      testWidgets('Important reminders (N): opens and closes, one line each, '
          'red / orange / grey, tap-to-fix', (tester) async {
        final store = DriverRemindersStore()
          ..replace(
            DriverReminderList.fromJson({
              'items': [
                {
                  'kind': 'document_expiring',
                  'level': 'due_soon',
                  'documentType': 'driving_license',
                  'daysLeft': 30,
                  'fix': {
                    'target': 'document',
                    'documentType': 'driving_license',
                  },
                },
                {
                  'kind': 'fleet_no_approved_car',
                  'level': 'blocks_online',
                  'fix': {'target': 'fleet_vehicles'},
                },
                {
                  'kind': 'info_session_waiting',
                  'level': 'waiting',
                  'documentType': 'info_session',
                  'status': 'waiting_for_movera',
                  'fix': {'target': 'info_session'},
                },
                {'kind': 'account_not_active', 'level': 'blocks_online'},
              ],
            }),
          );
        final fixed = <String>[];
        await _host(
          tester,
          Scaffold(
            body: ListView(
              children: [
                ImportantRemindersBox(
                  store: store,
                  owner: true,
                  onFix: (r) => fixed.add(r.kind),
                ),
              ],
            ),
          ),
        );
        expect(find.text(tr.remTitle(4)), findsOneWidget);
        // Red lines first.
        expect(
          find.byKey(const ValueKey('home-reminder-0-blocksOnline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-reminder-1-blocksOnline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-reminder-2-dueSoon')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-reminder-3-waiting')),
          findsOneWidget,
        );
        expect(find.text(tr.remFleetNoApprovedCar), findsOneWidget);
        expect(find.text(tr.remFleetNoApprovedCarOwner), findsOneWidget);
        expect(find.text(tr.remAccountNotActive), findsOneWidget);
        expect(find.text(tr.swDocumentStatusWaitingForMovera), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-reminder-0')));
        await tester.tap(find.byKey(const ValueKey('home-reminder-2')));
        await tester.tap(find.byKey(const ValueKey('home-reminder-3')));
        // account_not_active has no fix: nothing happens.
        await tester.tap(find.byKey(const ValueKey('home-reminder-1')));
        expect(fixed, [
          'fleet_no_approved_car',
          'document_expiring',
          'info_session_waiting',
        ]);
        await tester.tap(find.byKey(const ValueKey('home-reminders-toggle')));
        await tester.pump();
        expect(find.byKey(const ValueKey('home-reminder-0')), findsNothing);
        expect(find.text(tr.remTitle(4)), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-reminders-toggle')));
        await tester.pump();
        expect(find.byKey(const ValueKey('home-reminder-0')), findsOneWidget);
        // Nothing to remind: no box at all.
        store.replace(DriverReminderList.empty);
        await tester.pump();
        expect(find.byKey(const ValueKey('home-reminders')), findsNothing);
      });

      // Items 4, 6: guide, one Upload button, shrink + wait + Try again.
      testWidgets('upload guide: drawing, checklist, tips; a failed upload '
          'keeps the photo and Try again sends it', (tester) async {
        var attempt = 0;
        final server = FakeServer({
          'POST ${DriverAccountRepository.documentsPath}': (_) async {
            attempt++;
            if (attempt == 1) {
              return jsonResponse(503, {
                'code': 'unavailable',
                'message': 'x',
                'requestId': 'r',
                'retryable': true,
              });
            }
            await Future<void>.delayed(const Duration(seconds: 30));
            return _uploaded('driving_license');
          },
        });
        final picker = _Picker(file: _photo);
        Object? popped;
        phone(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => UploadGuideScreen(
                        account: server.session(),
                        type: 'driving_license',
                        ownerId: 'drv_1',
                        isCar: false,
                        country: country,
                        status: 'needed',
                        filePicker: picker,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text(tr.guideExampleLabel), findsWidgets);
        expect(
          find.byKey(const ValueKey('guide-example-card')),
          findsOneWidget,
        );
        expect(find.text(tr.guideLicenceBothSides), findsOneWidget);
        expect(
          find.text(
            country == 'FR'
                ? tr.guideLicenceCategoryB3Years
                : tr.guideLicenceCategoryB,
          ),
          findsOneWidget,
        );
        // Tips are closed until tapped.
        expect(find.text(tr.tipNoGlare), findsNothing);
        await tester.tap(find.text(tr.guideTipsTitle));
        await tester.pumpAndSettle();
        expect(find.text(tr.tipNoGlare), findsOneWidget);
        // One Upload button: Take photo / Photo library / Choose file.
        await _tapKey(tester, 'guide-upload');
        expect(find.text(tr.guidePickTakePhoto), findsOneWidget);
        expect(find.text(tr.guidePickLibrary), findsOneWidget);
        expect(find.text(tr.guidePickFile), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('doc-pick-camera')));
        await _settle(tester);
        await tester.pumpAndSettle();
        expect(attempt, 1);
        expect(find.byKey(const ValueKey('guide-kept')), findsOneWidget);
        expect(find.byKey(const ValueKey('guide-picked')), findsOneWidget);
        // Try again: the same photo, no new pick; 30 s is waited for.
        await _tapKey(tester, 'guide-try-again');
        expect(find.text(tr.guideUploadingSlow), findsOneWidget);
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();
        expect(attempt, 2);
        expect(picker.calls, ['camera']);
        expect(
          server.requests.last.bodyBytes.length,
          greaterThan(_photo.bytes.length),
        );
        expect((popped as AccountDocument?)?.status, 'in_review');
      });

      // Item 5: camera blocked.
      testWidgets('camera blocked: message, Open Settings and Choose file', (
        tester,
      ) async {
        final server = FakeServer({
          'POST ${DriverAccountRepository.documentsPath}': (_) async =>
              _uploaded('profile_photo'),
        });
        final picker = _Picker(
          file: _photo,
          cameraError: PlatformException(code: 'camera_access_denied'),
        );
        var settings = 0;
        await _host(
          tester,
          UploadGuideScreen(
            account: server.session(),
            type: 'profile_photo',
            ownerId: 'drv_1',
            isCar: false,
            country: country,
            filePicker: picker,
            openSettings: () async {
              settings++;
              return true;
            },
          ),
        );
        await _tapKey(tester, 'guide-upload');
        await tester.tap(find.byKey(const ValueKey('doc-pick-camera')));
        await _settle(tester);
        expect(find.text(tr.guideCameraBlockedTitle), findsOneWidget);
        expect(find.text(tr.guideCameraBlockedBody), findsOneWidget);
        await _tapKey(tester, 'guide-open-settings');
        expect(settings, 1);
        await _tapKey(tester, 'guide-choose-file');
        expect(picker.calls, ['camera', 'file']);
        expect(server.requests, hasLength(1));
      });

      // Item 14: a type the admin made, rendered from the published data.
      testWidgets('an admin-made type: its name and help text are the guide', (
        tester,
      ) async {
        OnboardingSettingsStore.instance.use(
          OnboardingSettings.fromJson(settingsJson(country, custom: true)),
        );
        await _host(
          tester,
          UploadGuideScreen(
            type: customType,
            ownerId: '',
            isCar: false,
            country: country,
          ),
        );
        expect(
          find.text(country == 'FR' ? 'Certificat médical' : 'Hälsointyg'),
          findsWidgets,
        );
        expect(
          find.text(
            country == 'FR'
                ? 'Nom et cachet du médecin'
                : 'Läkarens namn och stämpel',
          ),
          findsOneWidget,
        );
        expect(find.text(tr.guideExpiryNote(30)), findsOneWidget);
      });

      // Items 8, 13: How to book + Waiting for Movera.
      testWidgets('info session: How to book from the content slot, '
          'Waiting for Movera', (tester) async {
        final content = DriverContentStore(cache: MemoryDriverContentCache());
        await content.use(
          DriverContent.fromJson({
            'items': [
              {
                'slot': 'driver-info-session',
                'zoneId': country == 'FR' ? 'FR-PC' : 'Z001',
                'version': 1,
                'title': country == 'FR' ? 'Session Movera' : 'Movera-möte',
                'text': {
                  'sv': 'Boka här: https://movera.example/boka',
                  'fr': 'Réservez ici : https://movera.example/reserver',
                  'en': 'Book here: https://movera.example/book',
                },
              },
            ],
          }),
        );
        final opened = <Uri>[];
        await _host(
          tester,
          InfoSessionScreen(
            status: 'waiting_for_movera',
            content: content,
            openLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        );
        expect(find.text(tr.infoHowToBook), findsOneWidget);
        expect(find.text(tr.swDocumentStatusWaitingForMovera), findsOneWidget);
        expect(
          find.text(country == 'FR' ? 'Session Movera' : 'Movera-möte'),
          findsOneWidget,
        );
        await _tapKey(tester, 'info-session-link');
        expect(opened.single.path, country == 'FR' ? '/reserver' : '/boka');
      });

      // Item 7: Start my own company.
      testWidgets('My fleet › Start my own company: the account becomes a '
          'fleet waiting for Movera', (tester) async {
        var profile = profileJson(country: country);
        final server = FakeServer({
          'GET ${DriverAccountRepository.profilePath}': (_) async =>
              jsonResponse(200, profile),
          'GET ${DriverAccountRepository.fleetPath}': (_) async =>
              jsonResponse(200, {
                'fleet': {
                  'fleetId': 'flt_1',
                  'name': 'Nord Taxi',
                  'orgNumber': '5566778899',
                  'country': country,
                  'cityId': 'x',
                  'ownerName': 'Ola',
                  'status': 'approved',
                  'driverCount': 2,
                  'vehicleCount': 0,
                  'version': 1,
                },
                'drivers': [],
                'vehicles': [],
              }),
          'POST ${DriverAccountRepository.startCompanyPath}': (_) async {
            profile = profileJson(
              country: country,
              accountType: 'fleet',
              role: 'owner',
              status: 'on_hold',
              fleetStatus: 'pending',
            );
            return jsonResponse(200, profile);
          },
        });
        final session = server.session();
        await _host(tester, MyFleetScreen(account: session));
        // Item 9: the member's fleet has no car that can be picked.
        expect(
          find.byKey(const ValueKey('fleet-no-approved-car')),
          findsOneWidget,
        );
        expect(find.text(tr.remFleetNoApprovedCarMember), findsOneWidget);
        await _tapKey(tester, 'fleet-start-company-open');
        await tester.pumpAndSettle();
        expect(find.text(tr.startCompanyIntro), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('start-company-name')),
          'Berg Taxi',
        );
        await tester.enterText(
          find.byKey(const ValueKey('start-company-org')),
          country == 'FR' ? '123 456 789' : '556677-8899',
        );
        await tester.enterText(
          find.byKey(const ValueKey('start-company-address')),
          'Gatan 1',
        );
        await tester.pump();
        await _tapKey(tester, 'start-company-send');
        await tester.tap(find.byKey(const ValueKey('confirm-yes')));
        await tester.pumpAndSettle();
        final sent = server.requests.where(
          (r) => r.url.path == DriverAccountRepository.startCompanyPath,
        );
        final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
        expect(body['expectedVersion'], 3);
        expect((body['company'] as Map)['name'], 'Berg Taxi');
        expect(session.account!.isFleetAccount, isTrue);
        expect(session.account!.accountStatus, 'on_hold');
      });

      // Item 11: only fitting categories, then 4 photos.
      testWidgets('Add car: only the car types the car fits, then 4 photos', (
        tester,
      ) async {
        final server = FakeServer({
          'GET ${DriverAccountRepository.onboardingSettingsPath}': (_) async =>
              jsonResponse(200, settingsJson(country)),
          'POST ${DriverAccountRepository.vehiclesPath}': (request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return jsonResponse(201, {
              'vehicleId': 'veh_9',
              'make': body['make'],
              'model': body['model'],
              'year': body['year'],
              'color': body['color'],
              'plate': body['plate'],
              'seats': body['seats'],
              'categoryIds': body['categoryIds'],
              'fuel': body['fuel'],
              'status': 'pending',
              'version': 1,
              'requiredDocuments': [
                'vehicle_registration',
                'insurance',
                ...OnboardingSettings.photoTypes,
              ],
            });
          },
        });
        await _host(tester, AddCarScreen(account: server.session()));
        await tester.enterText(find.byKey(const ValueKey('car-make')), 'Volvo');
        await tester.enterText(find.byKey(const ValueKey('car-model')), 'V60');
        await tester.enterText(find.byKey(const ValueKey('car-year')), '2015');
        await tester.enterText(find.byKey(const ValueKey('car-color')), 'Grey');
        await tester.enterText(
          find.byKey(const ValueKey('car-plate')),
          'abc123',
        );
        await _tapKey(tester, 'car-fuel-petrol');
        // SE takes a 2015 car as Movera (economy); FR's base year is 2016.
        if (country == 'SE') {
          expect(
            find.byKey(const ValueKey('car-type-economy')),
            findsOneWidget,
          );
        } else {
          expect(find.byKey(const ValueKey('car-type-economy')), findsNothing);
        }
        expect(find.byKey(const ValueKey('car-type-comfort')), findsNothing);
        expect(find.byKey(const ValueKey('car-type-electric')), findsNothing);
        await tester.enterText(find.byKey(const ValueKey('car-year')), '2023');
        await tester.pump();
        expect(find.byKey(const ValueKey('car-type-comfort')), findsOneWidget);
        expect(find.byKey(const ValueKey('car-type-xl')), findsNothing);
        await _tapKey(tester, 'car-type-comfort');
        await _tapKey(tester, 'car-save');
        await tester.pumpAndSettle();
        final post = server.requests.firstWhere((r) => r.method == 'POST');
        final body = jsonDecode(post.body) as Map<String, dynamic>;
        expect(body['categoryIds'], ['comfort']);
        expect(body['fuel'], 'petrol');
        expect(find.byKey(const ValueKey('car-photos')), findsOneWidget);
        for (final type in OnboardingSettings.photoTypes) {
          expect(find.byKey(ValueKey('car-photo-$type')), findsOneWidget);
        }
      });

      // Item 14 + "already decided": the live list renders a custom type;
      // the info session waits; a car without approved documents can't be
      // driven and is not pickable.
      testWidgets('Documents: custom type by name; info session waits', (
        tester,
      ) async {
        final server = FakeServer({
          'GET ${DriverAccountRepository.profilePath}': (_) async =>
              jsonResponse(200, {
                ...profileJson(country: country),
                'requiredDocuments': [
                  'info_session',
                  'driving_license',
                  customType,
                ],
                'documents': [
                  {
                    'documentId': 'd1',
                    'type': 'driving_license',
                    'status': 'approved',
                    'expiresAt': DateTime.now()
                        .toUtc()
                        .add(const Duration(days: 10))
                        .toIso8601String(),
                  },
                ],
              }),
          'GET ${DriverAccountRepository.documentsPath}': (_) async =>
              jsonResponse(200, {'items': []}),
          'GET ${DriverAccountRepository.vehiclesPath}': (_) async =>
              jsonResponse(200, {'items': []}),
          'GET ${DriverAccountRepository.onboardingSettingsPath}': (_) async =>
              jsonResponse(200, settingsJson(country, custom: true)),
        });
        await _host(tester, LiveDocumentsScreen(account: server.session()));
        await tester.pumpAndSettle();
        expect(
          find.text(country == 'FR' ? 'Certificat médical' : 'Hälsointyg'),
          findsOneWidget,
        );
        expect(find.text(tr.swDocumentStatusWaitingForMovera), findsOneWidget);
        // Approved, 10 days left: orange "expiring".
        expect(find.text(tr.swDocumentStatusExpiring), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('doc-row-drv_1-info_session')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('info-session')), findsOneWidget);
      });

      // Owner decision 19: car documents are the fleet owner's only.
      for (final owner in [false, true]) {
        testWidgets('Documents: car sections only for the fleet owner '
            '(${owner ? 'owner' : 'member'})', (tester) async {
          final server = FakeServer({
            'GET ${DriverAccountRepository.profilePath}': (_) async =>
                jsonResponse(
                  200,
                  profileJson(
                    country: country,
                    accountType: owner ? 'fleet' : 'driver',
                    role: owner ? 'owner' : 'member',
                  ),
                ),
            'GET ${DriverAccountRepository.documentsPath}': (_) async =>
                jsonResponse(200, {'items': []}),
            'GET ${DriverAccountRepository.vehiclesPath}': (_) async =>
                jsonResponse(200, {
                  'items': [
                    {
                      'vehicleId': 'veh_1',
                      'make': 'Volvo',
                      'model': 'V60',
                      'year': 2021,
                      'plate': 'TST 001',
                      'status': 'approved',
                      'requiredDocuments': [
                        'vehicle_registration',
                        'insurance',
                      ],
                    },
                  ],
                }),
            'GET ${DriverAccountRepository.onboardingSettingsPath}':
                (_) async => jsonResponse(200, settingsJson(country)),
          });
          await _host(tester, LiveDocumentsScreen(account: server.session()));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('doc-row-veh_1-insurance')),
            owner ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('doc-row-drv_1-driving_license')),
            findsOneWidget,
          );
        });
      }

      testWidgets('a member gets no car-document reminders; the owner does', (
        tester,
      ) async {
        final list = DriverReminderList.fromJson({
          'items': [
            {
              'kind': 'document_needed',
              'level': 'blocks_online',
              'scope': 'vehicle',
              'vehicleId': 'veh_1',
              'documentType': 'insurance',
            },
            {
              'kind': 'document_needed',
              'level': 'blocks_online',
              'scope': 'driver',
              'documentType': 'driving_license',
            },
          ],
        });
        expect(list.forViewer(owner: false).items.map((r) => r.scope), [
          'driver',
        ]);
        expect(list.forViewer(owner: true).items, hasLength(2));
      });

      testWidgets('a member sees every fleet car; only drivable ones are '
          'pickable, the others say why', (tester) async {
        FleetVehicle car(String id, String status, List<String> docs) =>
            FleetVehicle.fromJson({
              'vehicleId': id,
              'make': 'Volvo',
              'model': 'V60',
              'plate': id,
              'status': status,
              'documents': [
                for (final t in docs)
                  {'documentId': t, 'type': t, 'status': 'approved'},
              ],
              'requiredDocuments': ['insurance', 'vehicle_photo_front'],
            });
        await _host(
          tester,
          Scaffold(
            body: ListView(
              children: [
                for (final c in [
                  car('ok', 'approved', ['insurance', 'vehicle_photo_front']),
                  car('docs', 'approved', ['insurance']),
                  car('new', 'pending', const []),
                  // v0.18.0: a member gets no car documents, only the
                  // server's pickable / notPickableReason.
                  FleetVehicle.fromJson(const {
                    'vehicleId': 'srv',
                    'plate': 'srv',
                    'status': 'approved',
                    'pickable': false,
                    'notPickableReason': 'vehicle_documents_not_approved',
                  }),
                  FleetVehicle.fromJson(const {
                    'vehicleId': 'srvok',
                    'plate': 'srvok',
                    'status': 'approved',
                    'pickable': true,
                  }),
                ])
                  FleetCarCard(
                    vehicle: c,
                    myDriverId: 'drv_1',
                    owner: false,
                    onPick: () {},
                  ),
              ],
            ),
          ),
        );
        expect(find.byKey(const ValueKey('car-pick-ok')), findsOneWidget);
        expect(find.byKey(const ValueKey('car-pick-srv')), findsNothing);
        expect(find.byKey(const ValueKey('car-pick-srvok')), findsOneWidget);
        expect(find.byKey(const ValueKey('car-pick-docs')), findsNothing);
        expect(find.byKey(const ValueKey('car-pick-new')), findsNothing);
        expect(find.text(tr.vehDocsMissingOwnerUploads), findsNWidgets(2));
        expect(find.text(tr.vehNotApprovedCantDrive), findsOneWidget);
        // A member is not shown which car documents are missing.
        expect(find.textContaining('Photo'), findsNothing);
      });

      testWidgets('a car without approved documents: Can\'t be driven, '
          'not pickable', (tester) async {
        final car = FleetVehicle.fromJson(const {
          'vehicleId': 'veh_1',
          'make': 'Volvo',
          'model': 'XC60',
          'year': 2022,
          'plate': 'ABC123',
          'status': 'approved',
          'documents': [
            {'documentId': 'x', 'type': 'insurance', 'status': 'approved'},
          ],
          'requiredDocuments': ['insurance', 'vehicle_photo_front'],
        });
        await _host(
          tester,
          Scaffold(
            body: FleetCarCard(
              vehicle: car,
              myDriverId: 'drv_1',
              onPick: () {},
            ),
          ),
        );
        expect(find.text(tr.vehDocsMissingCantDrive), findsOneWidget);
        expect(find.byKey(const ValueKey('car-pick-veh_1')), findsNothing);
      });
    });
  }

  // Shared helper sanity: the test session reads the profile.
  testWidgets('fixtures: a session reads the profile', (tester) async {
    final server = FakeServer({
      'GET ${DriverAccountRepository.profilePath}': (_) async =>
          jsonResponse(200, profileJson()),
    });
    final DriverAccountSession session = server.session();
    await tester.runAsync(session.refresh);
    expect(session.account!.firstName, 'Eva');
  });
}
