import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round 4 (owner Q48/Q49): the zone's default language, the driver's
/// saved choice, and admin's texts on top.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the zone default', () {
    test('Sweden is Swedish, France and Tunisia French', () {
      for (final (country, language) in [
        ('SE', 'sv'),
        ('FR', 'fr'),
        ('TN', 'fr'),
      ]) {
        final config = DriverAppConfig.fromJson({'country': country});
        DriverLanguage.applyZone(config.languages);
        expect(DriverLanguage.current.value, language, reason: country);
        expect(DriverAppTexts.language, language);
      }
    });

    test("the zone's languages.default.driver wins over the country", () {
      final config = DriverAppConfig.fromJson({
        'country': 'SE',
        'languages': {
          'available': ['en', 'fr', 'sv'],
          'default': {'rider': 'sv', 'driver': 'en', 'admin': 'sv'},
        },
      });
      DriverLanguage.applyZone(config.languages);
      expect(DriverLanguage.current.value, 'en');
      expect(tr.goOffline, 'Go offline');
    });

    test('the demo zone (Greater Stockholm) opens in Swedish', () {
      DriverLanguage.applyZone(const DriverHomeAdminContentService().languages);
      expect(DriverLanguage.current.value, 'sv');
      expect(tr.goOffline, 'Gå offline');
    });

    test('Settings lists only the zone languages, codes first', () {
      DriverLanguage.applyZone(
        const AppLanguages(
          available: ['fr', 'en'],
          rider: 'fr',
          driver: 'fr',
          admin: 'fr',
        ),
      );
      expect(DriverLanguage.available, ['fr', 'en']);
      expect(DriverLanguage.label('fr'), 'FR · Français');
      expect(DriverLanguage.label('sv'), 'SV · Svenska');
      expect(DriverLanguage.label('en'), 'EN · English');
    });
  });

  group("the driver's choice", () {
    test('is saved, reloaded after a restart and wins', () async {
      final store = SettingsRepository();
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(DriverLanguage.current.value, 'sv');
      await DriverLanguage.choose('fr', store);
      expect(DriverLanguage.current.value, 'fr');
      expect(tr.goOffline, 'Hors ligne');

      // A new app start: memory is gone, the zone default comes first.
      DriverLanguage.resetForTest();
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(DriverLanguage.current.value, 'sv');
      expect(await DriverLanguage.restore(SettingsRepository()), 'fr');
      expect(DriverLanguage.choice, 'fr');
      expect(DriverAppTexts.language, 'fr');

      // A new zone default does not undo the choice.
      DriverLanguage.applyZone(AppLanguages.forCountry('TN'));
      expect(DriverLanguage.current.value, 'fr');
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(DriverLanguage.current.value, 'fr');
    });

    test('an unknown or broken saved value keeps the zone default', () async {
      SharedPreferences.setMockInitialValues({
        '${SettingsRepository.sectionPrefix}${DriverLanguage.section}':
            '{"schemaVersion":1,"values":{"code":"de"}}',
      });
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      expect(await DriverLanguage.restore(), 'fr');
      expect(DriverLanguage.choice, isNull);

      SharedPreferences.setMockInitialValues({
        '${SettingsRepository.sectionPrefix}${DriverLanguage.section}': '{',
      });
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(await DriverLanguage.restore(), 'sv');
    });

    test('a language the app has not got is refused', () async {
      await expectLater(DriverLanguage.choose('ar'), throwsArgumentError);
      expect(DriverLanguage.current.value, 'en');
    });
  });

  group('admin texts stay on top', () {
    test('admin text for the language wins; otherwise the app text', () {
      DriverAppTexts.overrides = const DriverAppTextOverrides({
        'fr': {'offer.accept': 'Je prends'},
        'en': {'island.online': 'Radar is on'},
      });
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      expect(driverText(DriverTexts.offerAccept), 'Je prends');
      // The English override is not used in French.
      expect(driverText(DriverTexts.islandOnline), 'Radar en ligne');
      expect(driverText(DriverTexts.offerKmAway, {'km': '2.3'}), 'À 2.3 km');

      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(driverText(DriverTexts.offerAccept), 'Acceptera');
      expect(driverText(DriverTexts.islandTakenByOther),
          'Tagen av en annan förare');
    });

    test('the default cancel reasons follow the app language', () {
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      final reasons = CancelReasons.current.of(
        CancelReasonGroup.driverBeforeTrip,
      );
      expect(reasons.first.code, 'rider_requested_cancel');
      expect(reasons.first.title, 'Passageraren bad om avbokning');
      expect(
        CancelReasons.current.byCode('rider_no_show')!.title,
        'Passageraren kom inte',
      );
      // Admin's own list in Swedish is shown as written.
      const swedish = CancelReasons(
        language: 'sv',
        groups: {
          CancelReasonGroup.driverBeforeTrip: [
            CancelReason(code: 'rider_requested_cancel', title: 'Bad om det'),
          ],
        },
      );
      expect(
        swedish.of(CancelReasonGroup.driverBeforeTrip).single.title,
        'Bad om det',
      );
    });

    test('round 2/3 texts: Priority, Assigned by Movera, Go offline?', () {
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      expect(tr.priority, 'Prioritaire');
      expect(ExclusiveReasons.text(ExclusiveReasons.assigned),
          'Attribuée par Movera');
      expect(tr.goOfflineQuestion, 'Passer hors ligne ?');
      expect(tr.waitingFeePerMinuteFormattedMin('12,26 kr'),
          'frais d’attente · 12,26 kr / min');
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
      expect(tr.priority, 'Prioriterad');
      expect(ExclusiveReasons.text(ExclusiveReasons.nearby),
          'Bara för dig · i närheten');
    });
  });

  test('the offline notice says 10 missed offers in every language '
      '(owner decision 35)', () {
    DriverLanguage.resetForTest();
    DriverAppTexts.overrides = const DriverAppTextOverrides();
    String notice() => HomeIslandNotices.offlineAfterMissed(
      DriverOfferRules.defaultAutoOfflineAfter,
    ).title;
    expect(notice(), 'Offline: 10 offers missed');
    DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    expect(notice(), 'Offline: 10 missade erbjudanden');
    expect(HomeIslandNotices.lastMissedBeforeOffline.title,
        'Nästa missade erbjudande: offline');
    DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    expect(notice(), 'Hors ligne\u00a0: 10 offres manquées');
  });

  test('dates and times follow the language', () {
    final at = DateTime(2026, 10, 20, 14, 5);
    DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    expect(DriverDates.time(at), '14:05');
    expect(DriverDates.dayMonth(at), '20 okt.');
    expect(DriverDates.weekday(at), 'tisdag');
    expect(DriverDates.numericDate(at), '2026-10-20');
    DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    expect(DriverDates.dayMonth(at), '20 oct.');
    expect(DriverDates.weekday(at), 'mardi');
    expect(DriverDates.numericDate(at), '20/10/2026');
    expect(DriverDates.monthYear(at), 'octobre 2026');
    DriverLanguage.resetForTest();
    // English keeps what the app always showed.
    expect(DriverDates.dayMonth(at), '20 Oct');
    expect(DriverDates.numericDate(at), '20/10/2026');
    expect(DriverDates.monthYear(at), '10/2026');
  });

  testWidgets('Settings: pick a language, it is used and saved', (
    tester,
  ) async {
    DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: DriverLanguage.current,
        builder: (context, code, _) => MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Settings(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Språk'), findsOneWidget);
    expect(find.text('SV · Svenska'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('settings-language')));
    await tester.pumpAndSettle();
    expect(find.text('FR · Français'), findsOneWidget);
    expect(find.text('EN · English'), findsOneWidget);
    expect(find.text('Standard för din zon'), findsOneWidget);

    await tester.tap(find.text('FR · Français'));
    await tester.pumpAndSettle();
    expect(DriverLanguage.current.value, 'fr');
    expect(find.text('FR · Français'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Réglages de l’app'), findsOneWidget);
    await SettingsRepository.settle();
    final saved = await SettingsRepository().read(DriverLanguage.section);
    expect(saved[DriverLanguage.key], 'fr');
  });
}
