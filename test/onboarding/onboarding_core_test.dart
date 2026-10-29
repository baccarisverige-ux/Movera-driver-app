// Driver group 2 "Onboarding" (owner decisions of 2026-10-29, contract
// v0.17.0 §25): the core rules, for Sweden and France. Each test names the
// decision it checks.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/onboarding/document_status.dart';
import 'package:movera/core/onboarding/document_upload.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/core/onboarding/upload_guide.dart';

import 'g2_fixtures.dart';

void main() {
  group('items 10, 12, 14, 15: the documents per country follow the admin', () {
    test('SE: lists and expiring types from the published settings', () {
      final se = OnboardingSettings.fromJson(settingsJson('SE'));
      expect(se.country, 'SE');
      expect(se.driverDocuments, [
        'terms',
        'info_session',
        'driving_license',
        'profile_photo',
        'taxi_driver_license',
      ]);
      expect(se.fleetDocuments, contains('tax_settings'));
      // Item 15: licence, taxi licence, traffic permit, registration and
      // insurance expire; terms, info session, photo, company, F-skatt and
      // bank do not.
      for (final type in [
        'driving_license',
        'taxi_driver_license',
        'taxi_traffic_permit',
        'vehicle_registration',
        'insurance',
      ]) {
        expect(se.expires(type), isTrue, reason: type);
      }
      for (final type in [
        'terms',
        'info_session',
        'profile_photo',
        'company_registration',
        'tax_settings',
        'bank_statement',
      ]) {
        expect(se.expires(type), isFalse, reason: type);
      }
      expect(se.warnDays, [30, 7, 1]);
      expect(se.blockAtExpiry, isTrue);
    });

    test(
      'FR: VTC lists; nine types expire, Kbis and bank do not (item 14)',
      () {
        final fr = OnboardingSettings.fromJson(settingsJson('FR'));
        expect(fr.driverDocuments, [
          'terms',
          'info_session',
          'vtc_card',
          'driving_license',
          'national_id',
          'profile_photo',
        ]);
        expect(fr.vehicleDocuments, contains('vtc_sticker'));
        for (final type in [
          'driving_license',
          'national_id',
          'vtc_card',
          'vehicle_registration',
          'insurance',
          'rc_pro_insurance',
          'urssaf_certificate',
          'vtc_sticker',
          'vtc_register_certificate',
        ]) {
          expect(fr.expires(type), isTrue, reason: type);
        }
        for (final type in [
          'terms',
          'info_session',
          'profile_photo',
          'company_registration',
          'bank_statement',
        ]) {
          expect(fr.expires(type), isFalse, reason: type);
        }
      },
    );

    test('a type the admin made has its own name and help in sv/fr/en', () {
      for (final country in ['SE', 'FR']) {
        final settings = OnboardingSettings.fromJson(
          settingsJson(country, custom: true),
        );
        expect(settings.driverDocuments, contains(customType));
        expect(settings.typeOf(customType)!.custom, isTrue);
        expect(settings.kindOf(customType), DocumentKind.file);
        expect(settings.nameOf(customType, 'sv'), 'Hälsointyg');
        expect(settings.nameOf(customType, 'fr'), 'Certificat médical');
        expect(settings.nameOf(customType, 'en'), 'Health certificate');
        expect(settings.helpOf(customType, 'fr'), [
          'Nom et cachet du médecin',
          'Daté de moins de 3 mois',
        ]);
      }
      // Not known anywhere: the raw type, never a crash.
      expect(
        OnboardingSettings.fromJson(
          settingsJson('SE'),
        ).nameOf('custom_zz', 'en'),
        'custom_zz',
      );
    });

    test('the store names a type with the published texts once read', () async {
      final store = OnboardingSettingsStore();
      expect(store.nameOf(customType, 'en'), customType);
      await store.refresh(
        () async =>
            OnboardingSettings.fromJson(settingsJson('FR', custom: true)),
      );
      expect(store.nameOf(customType, 'en'), 'Health certificate');
      expect(store.kindOf('info_session'), DocumentKind.adminCheck);
      store.clear();
      expect(store.settings, isNull);
    });
  });

  group('item 11: only the categories a car fits', () {
    test('SE base year 2015, FR base year 2016', () {
      final se = OnboardingSettings.fromJson(settingsJson('SE'));
      final fr = OnboardingSettings.fromJson(settingsJson('FR'));
      List<String> fits(
        OnboardingSettings s,
        int year,
        int seats,
        String fuel,
      ) => s.fittingCategories(
        CategoryCatalog.seed,
        year: year,
        seats: seats,
        fuel: fuel,
      );
      // A 2015 petrol car with 4 seats.
      expect(fits(se, 2015, 4, 'petrol'), [
        'economy',
        'priority',
        'pet',
        'child_seat',
      ]);
      expect(fits(fr, 2015, 4, 'petrol'), ['child_seat']);
      expect(fits(fr, 2016, 4, 'petrol'), contains('economy'));
      // XL needs 6 seats; Electric needs an electric car.
      expect(fits(se, 2023, 6, 'diesel'), contains('xl'));
      expect(fits(se, 2023, 4, 'diesel'), isNot(contains('xl')));
      expect(fits(se, 2023, 4, 'diesel'), isNot(contains('electric')));
      expect(fits(fr, 2023, 4, 'electric'), contains('electric'));
    });

    test('the problem words are the contract\'s', () {
      final se = OnboardingSettings.fromJson(settingsJson('SE'));
      expect(
        se.categoryProblem('economy', year: 2010, seats: 4, fuel: 'petrol'),
        'year_too_old',
      );
      expect(
        se.categoryProblem('xl', year: 2022, seats: 4, fuel: 'petrol'),
        'too_few_seats',
      );
      expect(
        se.categoryProblem('electric', year: 2022, seats: 4, fuel: 'petrol'),
        'fuel_not_allowed',
      );
      expect(
        se.categoryProblem('electric', year: 2022, seats: 4),
        'fuel_required',
      );
      expect(se.categoryProblem('economy', year: 2022, seats: 4), isNull);
      expect(
        const VehicleCategoryRule(
          category: 'pet',
          on: false,
          minYear: 2000,
          minSeats: 1,
          fuels: OnboardingSettings.fuels,
        ).problemFor(year: 2024, seats: 4, fuel: 'petrol'),
        'category_off',
      );
    });

    test('four car photos are asked; the car request sends the fuel', () {
      final se = OnboardingSettings.fromJson(settingsJson('SE'));
      expect(se.carPhotos, OnboardingSettings.photoTypes);
      expect(
        OnboardingSettings.fromJson({
          ...settingsJson('FR'),
          'vehicles': {
            ...(settingsJson('FR')['vehicles'] as Map),
            'photosNeeded': false,
          },
        }).carPhotos,
        isEmpty,
      );
      const car = NewVehicle(
        make: 'Volvo',
        model: 'V90',
        year: 2021,
        color: 'Black',
        plate: 'abc 123',
        seats: 4,
        categoryIds: ['economy'],
        fuel: 'hybrid',
      );
      expect(car.toJson()['fuel'], 'hybrid');
      expect(
        FleetVehicle.fromJson(const {
          'vehicleId': 'v',
          'fuel': 'electric',
        }).fuel,
        'electric',
      );
      for (final type in OnboardingSettings.photoTypes) {
        expect(DriverOnboardingRules.documentTypes[type]?.owner, 'vehicle');
      }
    });
  });

  group('items 1 and 3: expiry shown from the admin\'s warning day', () {
    final now = DateTime.utc(2026, 10, 29, 10);
    String shown(String stored, DateTime? expiresAt, {int warn = 30}) =>
        shownDocumentStatus(
          kind: DocumentKind.file,
          stored: stored,
          expiresAt: expiresAt,
          warnDays: warn,
          now: now,
        );

    test('orange from 30 days before, red at the end date', () {
      expect(shown('approved', now.add(const Duration(days: 31))), 'approved');
      expect(shown('approved', now.add(const Duration(days: 30))), 'expiring');
      expect(shown('approved', now.add(const Duration(hours: 2))), 'expiring');
      expect(shown('approved', now), 'expired');
      expect(shown('approved', null), 'approved');
      expect(shown('missing', null), 'needed');
      expect(shown('in_review', now), 'in_review');
      // The admin's own warning day (e.g. 14) is followed.
      expect(
        shown('approved', now.add(const Duration(days: 20)), warn: 14),
        'approved',
      );
    });

    test(
      'the 30 / 7 / 1 day pushes and Finish your sign-up open Documents',
      () {
        for (final kind in [
          'document_expiring',
          'document_expired',
          'finish_sign_up',
        ]) {
          expect(
            ServerNotification.fromJson({'kind': kind}).opensDocuments,
            isTrue,
            reason: kind,
          );
        }
        expect(
          ServerNotification.fromJson({
            'kind': 'fleet_invitation',
          }).opensDocuments,
          isFalse,
        );
      },
    );

    test('daysLeft is whole days rounded up (0 = expired)', () {
      expect(documentDaysLeft(now.add(const Duration(hours: 1)), now), 1);
      expect(documentDaysLeft(now.add(const Duration(days: 7)), now), 7);
      expect(documentDaysLeft(now.subtract(const Duration(days: 1)), now), 0);
    });

    test('item 8: the info session waits for Movera; terms are approved', () {
      expect(
        shownDocumentStatus(
          kind: DocumentKind.adminCheck,
          stored: 'missing',
          now: now,
        ),
        'waiting_for_movera',
      );
      expect(
        shownDocumentStatus(
          kind: DocumentKind.adminCheck,
          stored: 'approved',
          now: now,
        ),
        'approved',
      );
      expect(
        shownDocumentStatus(
          kind: DocumentKind.acceptance,
          stored: 'missing',
          now: now,
        ),
        'approved',
      );
    });
  });

  group('items 2, 3, 9: the Home reminders', () {
    final list = DriverReminderList.fromJson({
      'items': [
        {
          'kind': 'document_in_review',
          'level': 'waiting',
          'documentType': 'insurance',
        },
        {
          'kind': 'document_expiring',
          'level': 'due_soon',
          'scope': 'driver',
          'documentType': 'driving_license',
          'daysLeft': 12,
          'expiresAt': '2026-11-10T00:00:00Z',
          'fix': {'target': 'document', 'documentType': 'driving_license'},
        },
        {
          'kind': 'fleet_no_approved_car',
          'level': 'blocks_online',
          'fix': {'target': 'fleet_vehicles'},
        },
        {'kind': 'something_new', 'level': 'odd'},
      ],
      'blocksOnline': 1,
    });

    test('red first, then orange, then waiting; one red blocks', () {
      expect(list.items.map((r) => r.level), [
        ReminderLevel.blocksOnline,
        ReminderLevel.dueSoon,
        ReminderLevel.waiting,
        ReminderLevel.waiting,
      ]);
      expect(list.blocksOnline, 1);
      expect(list.firstBlocking!.kind, 'fleet_no_approved_car');
      expect(list.items[1].fix!.target, ReminderFixTarget.document);
      expect(list.items[1].expiresAt, DateTime.utc(2026, 11, 10));
      expect(list.items[0].fix!.target, ReminderFixTarget.fleetVehicles);
      expect(ReminderFix.fromJson({'target': 'nope'}), isNull);
    });

    test('the store keeps the last list and says when it blocks', () async {
      final store = DriverRemindersStore();
      expect(store.blocksOnline, isFalse);
      await store.refresh(() async => list);
      expect(store.loaded, isTrue);
      expect(store.blocksOnline, isTrue);
      await expectLater(
        store.refresh(() async => throw StateError('offline')),
        throwsStateError,
      );
      expect(store.items, hasLength(4));
      store.clear();
      expect(store.items, isEmpty);
    });

    for (final (country, owner, member) in [
      (
        'SE',
        'Lägg till en bil eller slutför dess dokument under Mitt åkeri. Förarna kan gå online när en bil är godkänd.',
        'Du kan gå online när åkeriägaren har en godkänd bil som du kan välja.',
      ),
      (
        'FR',
        'Ajoutez une voiture ou terminez ses documents dans Ma flotte. Les chauffeurs pourront passer en ligne dès qu’une voiture est validée.',
        'Vous pourrez passer en ligne quand le gérant de votre flotte aura une voiture validée à choisir.',
      ),
    ]) {
      test('$country: the words of each line, fleet owner and member', () {
        DriverLanguage.applyZone(AppLanguages.forCountry(country));
        String name(String type) =>
            DriverOnboardingRules.documentName(type, tr.localeName);
        final noCar = list.firstBlocking!;
        expect(reminderWords(noCar, nameOf: name, owner: true).detail, owner);
        expect(reminderWords(noCar, nameOf: name).detail, member);
        expect(
          reminderWords(noCar, nameOf: name).title,
          tr.remFleetNoApprovedCar,
        );
        final expiring = reminderWords(list.items[1], nameOf: name);
        expect(
          expiring.title,
          tr.remDocumentExpiring(name('driving_license'), tr.inDaysCount(12)),
        );
        expect(expiring.action, tr.remUploadNew);
        final car = reminderWords(
          const DriverReminder(
            kind: 'document_expired',
            level: ReminderLevel.blocksOnline,
            scope: 'vehicle',
            vehicleId: 'veh_1',
            documentType: 'insurance',
          ),
          nameOf: name,
          carName: (_) => 'ABC 123',
        );
        expect(
          car.title,
          tr.remDocumentExpired('${name('insurance')} · ABC 123'),
        );
        expect(car.detail, tr.remCantGoOnlineUntil);
        for (final kind in [
          'document_needed',
          'document_rejected',
          'document_in_review',
          'info_session_waiting',
          'admin_check_waiting',
          'account_not_active',
          'fleet_not_approved',
          'no_vehicle',
          'other',
        ]) {
          final words = reminderWords(
            DriverReminder(
              kind: kind,
              level: ReminderLevel.waiting,
              documentType: 'info_session',
              reviewNote: 'Blurry',
            ),
            nameOf: name,
          );
          expect(words.title, isNotEmpty, reason: kind);
        }
      });
    }
  });

  group('items 1 and 9: why going online is refused', () {
    ApiError refused(String reason, [List<String> details = const []]) =>
        ApiError(
          statusCode: 409,
          code: reason == 'documents_expired'
              ? 'documents_not_approved'
              : 'invalid_transition',
          message: 'x',
          reason: reason,
          details: details,
        );

    for (final country in ['SE', 'FR']) {
      test(
        '$country: an expired document and a fleet with no approved car',
        () {
          DriverLanguage.applyZone(AppLanguages.forCountry(country));
          expect(
            liveAvailabilityErrorMessage(
              refused('documents_expired', ['driver:driving_license']),
              online: true,
            ),
            tr.liveOnlineDocumentsExpired(
              DriverOnboardingRules.documentName(
                'driving_license',
                tr.localeName,
              ),
            ),
          );
          expect(
            liveAvailabilityErrorMessage(
              refused('fleet_no_approved_car'),
              online: true,
            ),
            tr.remFleetNoApprovedCar,
          );
        },
      );
    }
  });

  group('items 5 and 6: camera blocked, slow upload', () {
    test('a refused camera or photo library is recognised', () {
      expect(
        isCameraBlocked(PlatformException(code: 'camera_access_denied')),
        isTrue,
      );
      expect(
        isCameraBlocked(PlatformException(code: 'photo_access_denied')),
        isTrue,
      );
      expect(
        isCameraBlocked(Exception('NotAllowedError: Permission denied')),
        isTrue,
      );
      expect(
        isCameraBlocked(PlatformException(code: 'no_available_camera')),
        isFalse,
      );
      expect(isCameraBlocked(StateError('closed')), isFalse);
    });

    test('photos are shrunk and an upload waits up to 60 s', () {
      expect(DocumentUploadPolicy.timeout, const Duration(seconds: 60));
      expect(DocumentUploadPolicy.photoMaxSide, lessThanOrEqualTo(1600));
      expect(DocumentUploadPolicy.photoQuality, lessThan(88));
    });

    testWidgets('an upload that takes 40 s still arrives (was cut at 15 s)', (
      tester,
    ) async {
      final server = FakeServer({
        'POST ${DriverAccountRepository.documentsPath}': (_) async {
          await Future<void>.delayed(const Duration(seconds: 40));
          return jsonResponse(201, {
            'documentId': 'doc_1',
            'ownerId': 'drv_1',
            'type': 'driving_license',
            'status': 'in_review',
            'version': 1,
          });
        },
      });
      final repository = server.session().repository;
      AccountDocument? done;
      Object? failed;
      unawaited(
        repository
            .uploadDocument(
              type: 'driving_license',
              bytes: Uint8List.fromList([1, 2, 3]),
              fileName: 'a.jpg',
              mediaType: 'image/jpeg',
            )
            .then((d) => done = d, onError: (Object e) => failed = e),
      );
      await tester.pump(const Duration(seconds: 41));
      expect(failed, isNull);
      expect(done?.status, 'in_review');
    });

    testWidgets('after 60 s it stops (the photo is kept by the screen)', (
      tester,
    ) async {
      final server = FakeServer({
        'POST ${DriverAccountRepository.documentsPath}': (_) =>
            Completer<http.Response>().future,
      });
      Object? failed;
      unawaited(
        server
            .session()
            .repository
            .uploadDocument(
              type: 'driving_license',
              bytes: Uint8List.fromList([1]),
              fileName: 'a.jpg',
              mediaType: 'image/jpeg',
            )
            .then((_) {}, onError: (Object e) => failed = e),
      );
      await tester.pump(const Duration(seconds: 59));
      expect(failed, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect((failed as ApiError?)?.code, ApiError.timeout);
    });
  });

  group('item 7: Start my own company', () {
    test(
      'POST /driver/fleet/start-company { expectedVersion, company }',
      () async {
        final server = FakeServer({
          'POST ${DriverAccountRepository.startCompanyPath}': (_) async =>
              jsonResponse(200, {
                ...profileJson(
                  accountType: 'fleet',
                  role: 'owner',
                  status: 'on_hold',
                  fleetStatus: 'pending',
                ),
              }),
        });
        final account = await server.session().repository.startCompany(
          const FleetCompany(
            name: ' Berg Taxi ',
            orgNumber: '556677-8899',
            address: 'Gatan 1',
          ),
          3,
        );
        final body =
            jsonDecode(server.requests.single.body) as Map<String, dynamic>;
        expect(body['expectedVersion'], 3);
        expect(body['company'], {
          'name': 'Berg Taxi',
          'orgNumber': '556677-8899',
          'address': 'Gatan 1',
        });
        expect(server.requests.single.headers['idempotency-key'], isNotEmpty);
        expect(account.isFleetAccount, isTrue);
        expect(account.accountStatus, 'on_hold');
        expect(account.fleet!.isOwner, isTrue);
      },
    );
  });

  group('items 8 and 13: the info session content slot', () {
    test('driver-info-session is read in SE and FR', () {
      final content = DriverContent.fromJson({
        'items': [
          {
            'slot': 'driver-info-session',
            'zoneId': 'FR-PC',
            'version': 2,
            'title': 'Session',
            'text': {
              'sv': 'Boka på https://movera.example/boka',
              'fr': 'Réservez sur https://movera.example/reserver',
              'en': 'Book at https://movera.example/book',
            },
          },
        ],
      });
      final item = content.infoSessionAt(DateTime.utc(2026, 10, 29))!;
      expect(item.textIn('fr'), contains('/reserver'));
      expect(item.textIn('sv'), contains('/boka'));
      expect(DriverContentSlots.all, contains('driver-info-session'));
    });
  });

  group('item 4: the upload guide per document and country', () {
    test('SE and FR lists differ where the papers differ', () {
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      final se = UploadGuides.forType('company_registration', country: 'SE');
      expect(se.checklist.first, tr.guideSeRegistrationBolagsverket);
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      final fr = UploadGuides.forType('company_registration', country: 'FR');
      expect(fr.checklist.first, tr.guideKbisRecent);
      expect(fr.title, 'Extrait Kbis ou avis SIRENE (moins de 3 mois)');
    });

    test('every contract type has a drawing and a list; unknown ones too', () {
      for (final type in [
        ...DriverOnboardingRules.documentTypes.keys,
        'custom_unknown1',
      ]) {
        for (final country in ['SE', 'FR']) {
          final guide = UploadGuides.forType(type, country: country);
          expect(guide.checklist, isNotEmpty, reason: '$type $country');
          expect(guide.tips, isNotEmpty, reason: '$type $country');
        }
      }
      expect(
        UploadGuides.exampleOf('vehicle_photo_side'),
        GuideExample.carSide,
      );
      expect(UploadGuides.exampleOf('custom_unknown1'), GuideExample.paper);
    });

    test('the admin\'s help text is the checklist (custom types too)', () {
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      final settings = OnboardingSettings.fromJson(
        settingsJson('FR', custom: true),
      );
      final guide = UploadGuides.forType(
        customType,
        country: 'FR',
        settings: settings,
      );
      expect(guide.title, 'Certificat médical');
      expect(guide.warnDays, 30);
      final early = OnboardingSettings.fromJson({
        ...settingsJson('SE'),
        'expiry': {
          'warnDays': [14, 3],
          'blockAtExpiry': true,
        },
      });
      expect(
        UploadGuides.forType(
          'driving_license',
          country: 'SE',
          settings: early,
        ).warnDays,
        14,
      );
      expect(
        UploadGuides.forType(
          'insurance',
          country: 'SE',
          settings: early,
        ).warnDays,
        early.vehicleWarnDays,
      );
      expect(guide.fromAdmin, isTrue);
      expect(guide.expires, isTrue);
      expect(guide.checklist, [
        'Nom et cachet du médecin',
        'Daté de moins de 3 mois',
      ]);
    });
  });
}
