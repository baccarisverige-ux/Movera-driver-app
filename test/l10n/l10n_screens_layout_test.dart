import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/presentation/driver/add%20vehicle/add_vehicle.dart';
import 'package:movera/presentation/driver/analytics/acceptance%20rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign%20in%20phone/sign_in_phone.dart';
import 'package:movera/presentation/driver/auth/sign%20in/sign_in.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/pin%20verification/pin_verification.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/presentation/driver/vehicles/vehicles.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens finished after Round 4 (sign-up, documents, scheduled
/// rides, support, promotions, vehicles and the rest of the menu) in
/// French and Swedish on a 320 px phone with text at 130 %: no overflow,
/// and each shows its own words in that language.
const _size = Size(320, 640);
const _scale = 1.3;

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  tester.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _app(String language, Widget home) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (_, __) => MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => LayoutViewport(child: child!),
    home: home,
  ),
);

Widget _opener(Future<void> Function(BuildContext) open) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(
        key: const ValueKey<String>('open'),
        onPressed: () => open(context),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// [text] somewhere on screen, also inside rich text.
Finder _words(String text) => find.textContaining(text, findRichText: true);

final _document = TrackedDocument(
  id: 'DOC-INS-418',
  title: 'Insurance letter',
  shortTitle: 'Insurance',
  expiresOn: DateTime(2030),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (language, country) in [('fr', 'FR'), ('sv', 'SE')]) {
    group('$language at 320 px, text ×$_scale', () {
      setUp(() => DriverLanguage.applyZone(AppLanguages.forCountry(country)));

      // Each screen with a text of its own that must show translated.
      final screens = <String, (Widget Function(), String Function())>{
        'Sign in': (() => const DriverSignIn(), () => tr.continueWithPhone),
        'Sign in with phone': (
          () => const DriverSignInPhone(),
          () => tr.signInWithPhone,
        ),
        'Create account': (() => const DriverCreateAccount(), () => tr.fullName),
        'Phone verification': (
          () => const DriverPhoneVerification(),
          () => tr.phoneVerification,
        ),
        'Documents': (() => const DriverDocuments(), () => tr.documents),
        'Scheduled rides': (
          () => const ScheduledRidesScreen(),
          () => tr.schedPlanAhead,
        ),
        'Support': (() => const SupportInboxScreen(), () => tr.supportYourConversations),
        'Promotions': (() => const Promotions(), () => tr.promoWeekdayPeak),
        'Vehicles': (() => const DriverVehicles(), () => tr.vehManageVehicles),
        'Add vehicle': (() => const AddVehicle(), () => tr.vehRequirements),
        'Vehicle documents': (
          () => const VehicleDocuments(
            make: 'Volvo',
            model: 'XC60',
            year: '2022',
            plate: 'ABC123',
          ),
          () => tr.vehRegistrationCertFront,
        ),
        'Preferences': (() => const Preferences(), () => tr.prefChooseRideOptions),
        'Profile': (() => const DriverProfile(), () => tr.profDemoNoVerified),
        'Notifications': (
          () => const DriverNotificationsScreen(),
          () => tr.noNotificationsYet,
        ),
        'Safety': (() => const SafetyToolKits(), () => tr.safetyTools),
        'Destination': (
          () => const DriverDestinationPicker(),
          () => tr.destTripsInYourDirection,
        ),
        'Analytics': (() => const Analytics(), () => tr.anaPreview),
        'Acceptance rate': (() => const AcceptanceRate(), () => tr.acceptRateTitle),
        'Cancellation rate': (
          () => const CancelationRate(),
          () => tr.cancelRateTitle,
        ),
        'My bank': (() => const MyBank(), () => tr.noPayoutAccountConnected),
        'Bank account': (() => const AddNewAccount(), () => tr.bankAccount),
        'Pin verification': (
          () => const PinVerification(),
          () => tr.pinVerifyAll,
        ),
        'Driving log': (() => const DrivingLogs(), () => tr.logsSampleWeek),
        'Privacy': (() => LegalDocumentScreen.privacy, () => tr.privacyPolicyTitle),
        'Terms': (() => LegalDocumentScreen.terms, () => tr.termsOfService),
      };
      for (final MapEntry(key: name, value: (screen, text)) in screens.entries) {
        testWidgets(name, (tester) async {
          _phone(tester);
          await tester.pumpWidget(_app(language, screen()));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: name);
          final words = text();
          expect(_words(words), findsWidgets, reason: '$name: $words');
        });
      }

      testWidgets('Scheduled rides, accepted tab', (tester) async {
        _phone(tester);
        ScheduledRideStore.reset();
        await tester.pumpWidget(_app(language, const ScheduledRidesScreen()));
        await _settle(tester);
        await tester.tap(find.text(tr.schedAcceptedTab));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(_words(tr.tomorrow), findsWidgets);
      });

      final sheets = <String, Future<void> Function(BuildContext)>{
        'New document': (c) => showDocumentUploadSheet(c, _document),
        'Document blocks going online': (c) => showDocumentBlockedSheet(
          c,
          TrackedDocument(
            id: 'DOC-INS-418',
            title: tr.docInsuranceLetter,
            shortTitle: tr.insurance,
            expiresOn: DateTime(2000),
          ),
        ),
        'Safety sheet': (c) => showSafetyToolKitSheet<void>(c),
      };
      for (final entry in sheets.entries) {
        testWidgets(entry.key, (tester) async {
          _phone(tester);
          await tester.pumpWidget(_app(language, _opener(entry.value)));
          await tester.tap(find.byKey(const ValueKey<String>('open')));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: entry.key);
        });
      }
    });
  }

  test('a document keeps its English words in English', () {
    expect(expiresInLabel(7), 'in 7 days');
    expect(expiresInLabel(1), 'tomorrow');
    expect(expiresInLabel(0), 'today');
    expect(documentDateLabel(DateTime(2026, 10, 22)), '22 Oct');
  });

  test('the same words in French and Swedish', () {
    DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    expect(expiresInLabel(7), 'dans 7 jours');
    expect(expiresInLabel(1), 'demain');
    DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    expect(expiresInLabel(7), 'om 7 dagar');
    expect(expiresInLabel(0), 'i dag');
  });
}
