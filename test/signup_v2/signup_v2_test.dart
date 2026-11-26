import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/document_scanner.dart';
import 'package:movera/presentation/driver/signup/signup_checklist_screen.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_documents_screen.dart';
import 'package:movera/presentation/driver/signup/signup_entry.dart';
import 'package:movera/presentation/driver/signup/signup_info_screen.dart';
import 'package:movera/presentation/driver/signup/signup_profile_screen.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.18.166 (`contract.json#signupV2`; owner 2026-11-26 "Oui,
/// tout construire", "Peut pas", "Oui, ajouter l'adresse (Recommandé)"):
/// the new sign-up against a fake movera-server. With `SIGNUP_SHOTS=dir`
/// the fr and sv screens are also written as PNG files for the owner.
final String? _shots = Platform.environment['SIGNUP_SHOTS'];
final String _suffix = Platform.environment['SIGNUP_SHOTS_SUFFIX'] ?? '';

class _Server {
  _Server({this.photoStatus});

  String? photoStatus;
  final List<Map<String, dynamic>> countries = [];
  final List<Map<String, dynamic>> onboarding = [];
  final List<String> uploads = [];
  final List<int> uploadSizes = [];
  String country = 'FR';

  Map<String, Object?> profile({String status = 'pending'}) => {
    'driverId': 'drv_1',
    'accountStatus': status,
    'onlineStatus': 'offline',
    'firstName': '',
    'country': country,
    'cityId': country == 'SE' ? 'stockholm_lan' : 'paris',
    'zoneIds': [],
    'categoryIds': [],
    'documents': [
      if (photoStatus != null)
        {'documentId': 'doc_p', 'type': 'profile_photo', 'status': photoStatus},
      for (final type in uploads)
        if (type != 'profile_photo')
          {'documentId': 'doc_$type', 'type': type, 'status': 'in_review'},
    ],
    'version': 2,
  };

  http.Client get client => MockClient((request) async {
    http.Response json(int status, Map<String, Object?> map) => http.Response(
      jsonEncode(map),
      status,
      headers: {'content-type': 'application/json'},
    );
    final path = request.url.path;
    if (path == DriverAccountRepository.documentsPath &&
        request.method == 'POST') {
      final text = latin1.decode(request.bodyBytes);
      final type = RegExp(
        r'name="type"\r\n\r\n([a-z_]+)',
      ).firstMatch(text)!.group(1)!;
      if (type == 'profile_photo' &&
          (photoStatus == 'approved' || photoStatus == 'expired')) {
        return json(409, {
          'code': 'invalid_transition',
          'message': 'locked',
          'reason': 'profile_photo_locked',
        });
      }
      uploads.add(type);
      uploadSizes.add(request.bodyBytes.length);
      if (type == 'profile_photo') photoStatus = 'in_review';
      return json(201, {
        'documentId': 'doc_$type',
        'ownerId': 'drv_1',
        'type': type,
        'status': 'in_review',
        'version': 1,
      });
    }
    if (path == DriverAccountRepository.countryPath) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      countries.add(body);
      country = body['country'] as String;
      return json(200, profile());
    }
    if (path == DriverAccountRepository.onboardingPath) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      onboarding.add(body);
      return json(200, profile(status: 'on_hold'));
    }
    if (path.endsWith('/driver/profile')) return json(200, profile());
    return json(404, {'code': 'not_found', 'message': 'x'});
  });
}

class _Picker implements DocumentFilePicker {
  _Picker(this.pages);
  final List<PickedDocumentFile> pages;
  @override
  Future<PickedDocumentFile?> takePhoto() async => pages.removeAt(0);
  @override
  Future<PickedDocumentFile?> choosePhoto() async => pages.removeAt(0);
  @override
  Future<PickedDocumentFile?> chooseFile() async => pages.removeAt(0);
}

class _Scanner implements DocumentScanner {
  _Scanner(this.pages);
  final List<PickedDocumentFile> pages;
  @override
  bool get available => true;
  @override
  Future<PickedDocumentFile?> scanOnePage() async => pages.removeAt(0);
}

class _Places implements DestinationSearch {
  @override
  Future<List<DestinationPlace>> search(String query, {GeoPoint? near}) async =>
      query.toLowerCase().startsWith('storg')
      ? const [
          DestinationPlace(
            id: 's1',
            name: 'Storgatan 1',
            address: 'Storgatan 1, 111 22 Stockholm, Sverige',
          ),
          DestinationPlace(
            id: 's2',
            name: 'Storgatan 10',
            address: 'Storgatan 10, 114 55 Stockholm, Sverige',
          ),
        ]
      : const [
          DestinationPlace(
            id: 's1',
            name: '12 Rue de Rivoli',
            address: '12 Rue de Rivoli, 75004 Paris, France',
          ),
          DestinationPlace(
            id: 's2',
            name: '12 Rue des Rosiers',
            address: '12 Rue des Rosiers, 75004 Paris, France',
          ),
        ];
  @override
  Future<DestinationPlace?> resolve(DestinationPlace place) async => place;
}

PickedDocumentFile _page(int shade, {int w = 640, int h = 400}) {
  final page = img.Image(width: w, height: h);
  img.fill(page, color: img.ColorRgb8(shade, shade, 240));
  return PickedDocumentFile(
    bytes: img.encodePng(page),
    fileName: 'p$shade.png',
    mediaType: 'image/png',
  );
}

const _fr = OnboardingSettings(
  country: 'FR',
  driverDocuments: [
    'terms',
    'info_session',
    'vtc_card',
    'driving_license',
    'national_id',
    'profile_photo',
  ],
  fleetDocuments: [
    'company_registration',
    'vtc_register_certificate',
    'rc_pro_insurance',
    'bank_statement',
  ],
);
const _se = OnboardingSettings(
  country: 'SE',
  driverDocuments: [
    'terms',
    'info_session',
    'driving_license',
    'profile_photo',
    'taxi_driver_license',
  ],
  fleetDocuments: [
    'company_registration',
    'taxi_traffic_permit',
    'tax_settings',
    'bank_statement',
  ],
);

DriverAccountSession _session(_Server server) {
  final api = ApiClient(
    client: server.client,
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );
  return DriverAccountSession(repository: DriverAccountRepository(api))
    ..replace(
      DriverAccount.fromJson(
        server.profile()
          ..['country'] = null
          ..['cityId'] = null,
      ),
    );
}

SignupFlow _flow(
  _Server server, {
  required String phone,
  List<String>? home,
  List<PickedDocumentFile>? pages,
}) {
  SharedPreferences.setMockInitialValues({});
  return SignupFlow(
    account: _session(server),
    phone: phone,
    onHome: (_) => home?.add('home'),
    draft: DetailsDraft(repository: SettingsRepository()),
    picker: _Picker(pages ?? []),
    scanner: _Scanner(pages ?? []),
    places: _Places(),
    settingsLoader: (c) async => c == 'SE' ? _se : _fr,
    joiner: joinSidesHere,
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: child));
  await _settle(tester);
}

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  group('rules', () {
    test('personnummer: Luhn, dash optional, date; country from phone', () {
      expect(normalizePersonalNumber('198503121231'), '19850312-1231');
      expect(normalizePersonalNumber('19850312-1232'), isNull);
      expect(normalizePersonalNumber('19851312-1231'), isNull);
      expect(dateOfPersonalNumber('19850312-1231'), '1985-03-12');
      expect(isoOfTypedDate('04/05/1990'), '1990-05-04');
      expect(isoOfTypedDate('31/02/1990'), isNull);
      expect(countryOfPhone('+46701234567'), 'SE');
      expect(countryOfPhone('+33612345678'), 'FR');
      expect(countryOfPhone('+21612345678'), isNull);
      expect(countryOfPoint(59.33, 18.06), 'SE');
      expect(countryOfPoint(48.85, 2.35), 'FR');
    });

    test('a suggestion fills street, postal code and city (SE and FR)', () {
      final fr = parseSuggestedAddress(
        '12 Rue de Rivoli',
        '12 Rue de Rivoli, 75004 Paris, France',
      );
      expect(
        (fr.street, fr.postalCode, fr.city),
        ('12 Rue de Rivoli', '75004', 'Paris'),
      );
      final se = parseSuggestedAddress(
        'Storgatan 1',
        'Storgatan 1, 111 22 Stockholm, Sverige',
      );
      expect((se.postalCode, se.city), ('111 22', 'Stockholm'));
    });

    test('sign-up fields and recto verso default as the contract', () {
      final contract =
          jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>;
      final sv2 = contract['signupV2'] as Map<String, dynamic>;
      final defaults = (sv2['signUpFields'] as Map)['defaults'] as Map;
      for (final country in ['SE', 'FR']) {
        final s = OnboardingSettings(country: country);
        for (final MapEntry(:key, :value)
            in (defaults[country] as Map).entries) {
          expect(
            s.signUpField(key as String).on,
            (value as Map)['on'],
            reason: '$country $key',
          );
          expect(
            s.signUpField(key).required,
            value['required'],
            reason: '$country $key',
          );
        }
        expect(
          s.twoSidedTypes,
          ((sv2['twoSided'] as Map)['defaults'] as Map)[country],
        );
      }
      final labels = sv2['accountTypeLabels'] as Map;
      DriverAppTexts.language = 'fr';
      expect(accountTypeLabel('fleet', 'FR'), (labels['fleet'] as Map)['fr']);
      DriverAppTexts.language = 'sv';
      expect(accountTypeLabel('driver', 'SE'), (labels['driver'] as Map)['sv']);
    });

    test('every text exists in en, fr and sv', () {
      for (final MapEntry(:key, :value) in signupTextTable.entries) {
        expect(value.keys.toSet(), {'en', 'fr', 'sv'}, reason: key);
      }
    });

    test('recto and verso are joined into one JPEG, recto above', () async {
      final joined = await joinSides(_page(10), _page(200));
      expect(joined.mediaType, 'image/jpeg');
      final read = img.decodeJpg(joined.bytes)!;
      expect(read.height, greaterThan(read.width));
      expect(read.getPixel(5, 5).r, lessThan(60));
      expect(read.getPixel(5, read.height - 5).r, greaterThan(150));
      final pdf = PickedDocumentFile(
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        fileName: 'a.pdf',
        mediaType: 'application/pdf',
      );
      expect(
        () => joinSides(pdf, _page(1)),
        throwsA(isA<UnsupportedSidesError>()),
      );
    });
  });

  testWidgets(
    'France: country from +33, one region picked, fields, address suggestion, Continue saves country + region',
    (tester) async {
      DriverAppTexts.language = 'fr';
      final server = _Server();
      final flow = _flow(server, phone: '+33612345678');
      await _pump(tester, SignupInfoScreen(flow: flow));
      expect(find.text('France'), findsOneWidget);
      expect(find.text("Choisi d'après votre numéro +33"), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-personalNumber')), findsNothing);
      expect(find.byKey(const ValueKey('signup-dateOfBirth')), findsOneWidget);
      // Nothing filled: stays, says what is missing.
      await _tap(tester, 'signup-info-continue');
      expect(server.countries, isEmpty);
      await _type(tester, 'signup-firstName', 'Luc');
      await _type(tester, 'signup-lastName', 'Martin');
      await _type(tester, 'signup-email', 'luc@example.fr');
      await _type(tester, 'signup-dateOfBirth', '01/04/1988');
      await _type(tester, 'signup-address', '12 rue de');
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      await _tap(tester, 'address-suggestion-s1');
      expect(find.text('75004'), findsOneWidget);
      await _tap(tester, 'signup-info-continue');
      expect(server.countries.single, {'country': 'FR', 'cityId': 'paris'});
      expect(
        find.byKey(const ValueKey('signup-checklist-screen')),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      expect(flow.data.dateOfBirth, '1988-04-01');
    },
  );

  testWidgets(
    'Sweden: personnummer checked and gives the date of birth; address required',
    (tester) async {
      DriverAppTexts.language = 'sv';
      final server = _Server();
      final flow = _flow(server, phone: '+46701234567');
      await _pump(tester, SignupInfoScreen(flow: flow));
      expect(find.text('Sverige'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-dateOfBirth')), findsNothing);
      await _type(tester, 'signup-firstName', 'Ana');
      await _type(tester, 'signup-lastName', 'Berg');
      await _type(tester, 'signup-email', 'ana@example.se');
      await _type(tester, 'signup-personalNumber', '19850312-1232');
      await _type(tester, 'signup-taxiLicenseNumber', 'TX 123');
      await _tap(tester, 'signup-info-continue');
      expect(find.text(st('badPersonalNumber')), findsOneWidget);
      expect(server.countries, isEmpty);
      await _type(tester, 'signup-personalNumber', '198503121231');
      await _type(tester, 'signup-address', 'Storgatan 1');
      await _type(tester, 'signup-postalCode', '111 22');
      await _type(tester, 'signup-city', 'Stockholm');
      await _tap(tester, 'signup-info-continue');
      expect(server.countries.single['country'], 'SE');
      expect(flow.data.personalNumber, '19850312-1231');
      expect(flow.data.dateOfBirth, '1985-03-12');
    },
  );

  testWidgets(
    'checklist: send needs the 3 items, works with no document, sends address + accountType; later goes Home',
    (tester) async {
      DriverAppTexts.language = 'fr';
      final server = _Server();
      final home = <String>[];
      final flow = _flow(
        server,
        phone: '+33612345678',
        home: home,
        pages: [_page(90)],
      );
      flow.data
        ..country = 'FR'
        ..cityId = 'paris'
        ..firstName = 'Luc'
        ..lastName = 'Martin'
        ..email = 'luc@example.fr'
        ..dateOfBirth = '1988-04-01'
        ..street = '12 Rue de Rivoli'
        ..postalCode = '75004'
        ..city = 'Paris'
        ..language = 'fr'
        ..detailsDone = true;
      await _pump(tester, SignupChecklistScreen(flow: flow));
      await _tap(tester, 'signup-send');
      expect(find.text(st('finishFirst')), findsOneWidget);
      expect(server.onboarding, isEmpty);
      // Photo: tap the circle, gallery, sent.
      await _tap(tester, 'checklist-photo');
      await _tap(tester, 'profile-photo-circle');
      await _tap(tester, 'photo-source-gallery');
      expect(server.uploads, ['profile_photo']);
      expect(find.text(st('photoSent')), findsOneWidget);
      // Vous êtes: sans Kbis.
      await _tap(tester, 'signup-account-type');
      await _tap(tester, 'account-type-driver');
      expect(find.text('Chauffeur sans Kbis'), findsOneWidget);
      await _tap(tester, 'signup-profile-done');
      expect(find.text('3/3'), findsOneWidget);
      await _tap(tester, 'signup-send');
      final sent = server.onboarding.single;
      expect(sent['accountType'], 'driver');
      expect(sent['address'], {
        'street': '12 Rue de Rivoli',
        'postalCode': '75004',
        'city': 'Paris',
      });
      expect(sent.containsKey('personalNumber'), isFalse);
      expect(home, ['home']);
    },
  );

  testWidgets(
    'profile photo approved: locked, no change entry (owner "Peut pas")',
    (tester) async {
      DriverAppTexts.language = 'fr';
      final server = _Server(photoStatus: 'approved');
      final flow = _flow(server, phone: '+33612345678', pages: [_page(1)]);
      await _pump(tester, SignupProfileScreen(flow: flow));
      expect(find.text(st('photoLocked')), findsOneWidget);
      await _tap(tester, 'profile-photo-circle');
      expect(find.byKey(const ValueKey('photo-source-gallery')), findsNothing);
      expect(server.uploads, isEmpty);
    },
  );

  testWidgets(
    'documents: recto verso = 2 steps, Vérifier, one joined file; Envoyé only after the server',
    (tester) async {
      DriverAppTexts.language = 'fr';
      final server = _Server();
      final flow = _flow(
        server,
        phone: '+33612345678',
        pages: [_page(20), _page(220), _page(120)],
      );
      flow.data
        ..country = 'FR'
        ..accountType = 'fleet';
      await _pump(tester, SignupDocumentsScreen(flow: flow));
      expect(find.text('Votre société'), findsOneWidget);
      expect(find.byKey(const ValueKey('doc-row-info_session')), findsNothing);
      await _tap(tester, 'doc-add-driving_license');
      expect(find.text(st('scanner')), findsOneWidget);
      await _tap(tester, 'add-option-scan');
      expect(find.byKey(const ValueKey('doc-step-1')), findsOneWidget);
      await _tap(tester, 'doc-open-scanner');
      expect(find.byKey(const ValueKey('doc-step-2')), findsOneWidget);
      expect(find.text('✓ ${st('frontSaved')}'), findsOneWidget);
      await _tap(tester, 'doc-open-scanner');
      expect(find.byKey(const ValueKey('doc-verify')), findsOneWidget);
      expect(server.uploads, isEmpty);
      await _tap(tester, 'doc-send');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await _settle(tester);
      expect(server.uploads, ['driving_license']);
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('doc-row-driving_license')),
        findsOneWidget,
      );
      // A one-page company paper: one photo, no verso.
      await _tap(tester, 'doc-add-company_registration');
      await _tap(tester, 'add-option-pick');
      await _tap(tester, 'doc-pick-gallery');
      expect(find.byKey(const ValueKey('doc-verify')), findsOneWidget);
      await _tap(tester, 'doc-send');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _settle(tester);
      expect(server.uploads.last, 'company_registration');
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
    },
  );

  testWidgets(
    'entry: Vos informations first, the checklist once that step is done',
    (tester) async {
      final server = _Server();
      final flow = _flow(server, phone: '+33612345678');
      await _pump(
        tester,
        SignupEntry(
          account: flow.account,
          phone: '+33612345678',
          onHome: (_) {},
          flow: flow,
        ),
      );
      expect(find.byKey(const ValueKey('signup-info-screen')), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------- PNGs
  testWidgets('screenshots fr + sv (SIGNUP_SHOTS)', (tester) async {
    if (_shots == null) return;
    await _loadFonts();
    for (final lang in ['fr', 'sv']) {
      DriverAppTexts.language = lang;
      final se = lang == 'sv';
      final phone = se ? '+46701234567' : '+33612345678';
      Future<void> shot(
        String name,
        Widget screen, {
        Future<void> Function()? before,
        double height = 844,
      }) async {
        tester.view.physicalSize = Size(390, height);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('shot'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'Urbanist',
                fontFamilyFallback: const ['DejaVu'],
              ),
              home: screen,
            ),
          ),
        );
        await _settle(tester);
        if (before != null) await before();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shot')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$_shots/$lang-$name$_suffix.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      // 1 · Vos informations (long screen: whole form)
      final server = _Server();
      final flow = _flow(server, phone: phone);
      await shot(
        '1-vos-informations',
        SignupInfoScreen(flow: flow),
        height: 1240,
        before: () async {
          await _type(tester, 'signup-firstName', se ? 'Ana' : 'Luc');
          await _type(tester, 'signup-lastName', se ? 'Berg' : 'Martin');
          await _type(
            tester,
            'signup-email',
            se ? 'ana@exempel.se' : 'luc@exemple.fr',
          );
          if (se) {
            await _type(tester, 'signup-personalNumber', '19850312-1231');
            await _type(tester, 'signup-taxiLicenseNumber', 'TX 12345');
          } else {
            await _type(tester, 'signup-dateOfBirth', '01/04/1988');
          }
          await _type(
            tester,
            'signup-address',
            se ? 'Storgatan 1' : '12 rue de',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await _settle(tester);
          FocusManager.instance.primaryFocus?.unfocus();
          await _settle(tester);
        },
      );
      // 1b · the Région sheet
      final s1b = _Server();
      await shot(
        '1b-region',
        SignupInfoScreen(flow: _flow(s1b, phone: phone)),
        before: () async {
          await _tap(tester, 'signup-country');
        },
      );
      // 2 · La liste
      final s2 = _Server(photoStatus: null);
      final f2 = _flow(s2, phone: phone)
        ..data.detailsDone = true
        ..data.country = se ? 'SE' : 'FR';
      await shot('2-liste', SignupChecklistScreen(flow: f2));
      // 3 · Photo et statut + the Vous êtes sheet
      final f3 = _flow(_Server(), phone: phone)
        ..data.country = se ? 'SE' : 'FR';
      await shot('3-votre-profil', SignupProfileScreen(flow: f3));
      await shot(
        '3b-vous-etes',
        SignupProfileScreen(flow: f3, openAccountType: true),
      );
      // 3c · photo approved: locked
      final f3c = _flow(_Server(photoStatus: 'approved'), phone: phone)
        ..data.country = se ? 'SE' : 'FR'
        ..data.accountType = 'driver';
      await shot('3c-photo-validee', SignupProfileScreen(flow: f3c));
      // 4 · Documents (with company)
      final f4 = _flow(_Server(), phone: phone)
        ..data.country = se ? 'SE' : 'FR'
        ..data.accountType = 'fleet';
      await shot('4-documents', SignupDocumentsScreen(flow: f4), height: 1100);
      // 5 · Ajouter sheet (recto verso) and one-page sheet
      final f5 =
          _flow(
              _Server(),
              phone: phone,
              pages: [_page(30), _page(200), _page(120)],
            )
            ..data.country = se ? 'SE' : 'FR'
            ..data.accountType = 'fleet';
      await shot(
        '5-ajouter-recto-verso',
        SignupDocumentsScreen(flow: f5),
        before: () async {
          await _tap(tester, 'doc-add-driving_license');
        },
      );
      final f5b = _flow(_Server(), phone: phone)
        ..data.country = se ? 'SE' : 'FR'
        ..data.accountType = 'fleet';
      await shot(
        '5b-ajouter-une-page',
        SignupDocumentsScreen(flow: f5b),
        before: () async {
          await _tap(tester, 'doc-add-company_registration');
        },
      );
      // 6 · Recto 1/2, Verso 2/2, Vérifier
      DocumentAddScreen add() => DocumentAddScreen(
        flow: _flow(_Server(), phone: phone, pages: [_page(40), _page(180)])
          ..data.country = se ? 'SE' : 'FR',
        type: 'driving_license',
        name: se ? 'Körkort' : 'Permis de conduire',
        twoSided: true,
        mode: 'scan',
      );
      await shot('6-recto-1-sur-2', add());
      await shot(
        '7-verso-2-sur-2',
        add(),
        before: () async => _tap(tester, 'doc-open-scanner'),
      );
      await shot(
        '8-verifier',
        add(),
        height: 900,
        before: () async {
          await _tap(tester, 'doc-open-scanner');
          await _tap(tester, 'doc-open-scanner');
          for (final e in find.byType(Image).evaluate()) {
            await tester.runAsync(
              () => precacheImage((e.widget as Image).image, e),
            );
          }
          await _settle(tester);
        },
      );
    }
  });
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File(f);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  await load('Urbanist', [
    for (final w in [500, 600, 800]) 'assets/fonts/urbanist/Urbanist-$w.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/var/tmp/fl/flutter';
  await load('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  // Test only: a fallback with the check and cross signs (phones have one).
  await load('DejaVu', ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']);
  await load('Roboto', [
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ]);
}
