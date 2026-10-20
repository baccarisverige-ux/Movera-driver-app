import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/finish_soon_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/rider_cancelled_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round 4: the key screens in French and Swedish on a 320 px phone with
/// text at 130 %, with no overflow. Words run longer in both languages
/// than in English, so this is where a layout breaks first.
const _size = Size(320, 640);
const _scale = 1.3;

const _offer = RadarOfferView(
  id: 'o1',
  category: 'Comfort',
  payment: 'Cash',
  rating: '4.96',
  riderTrips: 128,
  fare: '104,80 kr',
  pickupMinutes: 2,
  pickupKm: 0.65,
  tripMinutes: 9,
  tripKm: 4.2,
  pickup: 'Kungsgatan 42, Stockholm',
  dropoff: 'Hornstull, Stockholm',
  priority: true,
);

final _waybill = WaybillRecord(
  tripId: 'trip-4711',
  statusLabel: 'Completed',
  issuedAt: DateTime(2026, 10, 20, 14, 32, 5),
  fare: '104,80 kr',
  service: 'Comfort',
  riderName: 'Nils',
  pickup: 'Kungsgatan 42, Stockholm',
  dropoff: 'Hornstull, Stockholm',
  source: 'Movera Radar',
  driverName: 'Demo driver',
  vehicle: 'Volvo XC60',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
  waitingFee: '24,52 kr',
  driverBonus: '40 kr',
);

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

/// A screen that opens [open] from a button, as the app does.
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (language, country) in [('fr', 'FR'), ('sv', 'SE')]) {
    group('$language at 320 px, text ×$_scale', () {
      setUp(() => DriverLanguage.applyZone(AppLanguages.forCountry(country)));

      final screens = <String, Widget>{
        'Settings': const Settings(),
        'Side menu': const Scaffold(body: DriverSideMenu(isOnline: true)),
        'Earnings & history': DriverRideHistory(
          loadHistory: () async => const [],
        ),
        'Ride completed': const DriverRideCompleted(),
        'Radar card': Scaffold(
          body: Center(child: RadarOfferCard(offer: _offer, onMatch: () {})),
        ),
        'Exclusive sheet': const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ExclusiveRequestSheet(offer: _offer, secondsLeft: 12),
          ),
        ),
        'Reservation exclusive': const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ExclusiveRequestSheet(
              offer: _offer,
              secondsLeft: 9,
              reservation: true,
              reservationTime: '07:40',
            ),
          ),
        ),
        'Pickup': const AcceptRide(fare: '104,80 kr', category: 'Comfort'),
        'Waiting': const AcceptRide(
          initialStage: ActiveRideStage.waitingForRider,
          initialWaitSeconds: 420,
        ),
        'In trip': const AcceptRide(
          initialStage: ActiveRideStage.onTrip,
          paidByCash: true,
          cashToCollect: '104,80 kr',
        ),
      };
      for (final entry in screens.entries) {
        testWidgets(entry.key, (tester) async {
          _phone(tester);
          await tester.pumpWidget(_app(language, entry.value));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: entry.key);
        });
      }

      final sheets = <String, Future<void> Function(BuildContext)>{
        'Go offline?': (c) => showGoOfflineConfirm(c),
        'Waiting fee and no-show': (c) => showWaitingTimeSheet(
          c,
          readSeconds: () => 420,
          onNoShow: () {},
        ),
        'Cash collect': (c) => showCashCollectSheet(
          c,
          fare: '104,80 kr',
          cash: '110,00 kr',
          riderName: 'Nils',
          category: 'Comfort',
        ),
        'Finish so soon': (c) => showFinishSoonSheet(c, minutesSincePickup: 2),
        'Rider cancelled': (c) => showRiderCancelledSheet(
          c,
          riderName: 'Nils',
          wasOnTrip: true,
          fee: const Money(minorUnits: 4000),
        ),
        'Taken by Movera': (c) => showTripOutcomeSheet(
          c,
          status: TripStatus.cancelledByAdmin,
          hasNext: true,
        ),
        'Waybill': (c) => showMoveraWaybillSheet(c, _waybill),
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

      testWidgets('Home, island and radar', (tester) async {
        _phone(tester);
        IslandMessages.reset();
        ScheduledRideStore.reset();
        DriverStartPosition.clearMemory();
        await (await SharedPreferences.getInstance()).setString(
          DriverStartPosition.key,
          '{"lat":59.3326,"lng":18.0649}',
        );
        await tester.pumpWidget(const MoveraApp());
        await _settle(tester);
        expect(find.byType(DriverHome), findsOneWidget);
        // The app root runs in the zone's language.
        expect(Localizations.localeOf(tester.element(find.byType(DriverHome))),
            Locale(language));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('a new language rebuilds the open app in place', (tester) async {
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MoveraApp());
    await _settle(tester);
    final home = tester.state(find.byType(DriverHome));
    expect(tr.goOffline, 'Gå offline');
    await DriverLanguage.choose('fr');
    await _settle(tester);
    // Same Home, now in French.
    expect(tester.state(find.byType(DriverHome)), same(home));
    expect(Localizations.localeOf(tester.element(find.byType(DriverHome))),
        const Locale('fr'));
    expect(tester.takeException(), isNull);
  });
}
