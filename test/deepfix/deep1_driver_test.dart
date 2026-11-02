import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/account/fleet_car_card.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/accept%20ride/route_change_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deep-fix round 1 (2026-11-02): driver items from the live sweep and the
/// deep re-check, through the app's real paths.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DrivingTimeClock.instance.reset();
  });

  group('M-10 driving-time counter from the server', () {
    test('GET /driver/profile drivingTime sets the 12 h counter, so a '
        'reload does not start again from zero', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'driverId': 'd1',
            'accountStatus': 'active',
            'firstName': 'Test',
            'version': 4,
            'drivingTime': {
              'drivenMinutes': 40,
              'maxMinutes': 720,
              'reached': false,
              'resetAfterOfflineHours': 6,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      );
      final session = DriverAccountSession(
        repository: DriverAccountRepository(api),
      );
      final account = await session.refresh();
      expect(account.drivingTime?.drivenMinutes, 40);
      final clock = DrivingTimeClock.instance;
      expect(clock.worked, const Duration(minutes: 40));
      expect(clock.workLimit, const Duration(hours: 12));
      expect(DrivingTimeClock.hoursMinutes(clock.left), '11 h 20 min');
    });

    test('a running count keeps running from the server value', () {
      var now = DateTime(2026, 11, 2, 9);
      final clock = DrivingTimeClock(now: () => now)..start();
      now = now.add(const Duration(minutes: 1));
      clock.loadServer(drivenMinutes: 100, maxMinutes: 600);
      now = now.add(const Duration(minutes: 5));
      expect(clock.worked, const Duration(minutes: 105));
      expect(clock.workLimit, const Duration(hours: 10));
    });
  });

  group('M-5 earnings per currency', () {
    test('v0.18.14 GET /driver/earnings?currency=: one currency per '
        'report and the list for the kr / € switch', () async {
      final asked = <Uri>[];
      final api = ApiClient(
        client: MockClient((request) async {
          asked.add(request.url);
          final eur = request.url.queryParameters['currency'] == 'EUR';
          return http.Response(
            jsonEncode({
              'currency': eur ? 'EUR' : 'SEK',
              'currencies': ['SEK', 'EUR'],
              'periods': [
                {
                  'periodStart': '2026-11-02T00:00:00Z',
                  'periodEnd': '2026-11-09T00:00:00Z',
                  'net': {
                    'amountMinor': eur ? 480 : 13458,
                    'currency': eur ? 'EUR' : 'SEK',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      );
      final earnings = LiveEarnings(api: api);
      final now = DateTime.utc(2026, 11, 3);
      final first = await earnings.week(now: now);
      expect(first.currency, 'SEK');
      expect(first.currencies, ['SEK', 'EUR']);
      final euros = await earnings.week(currency: 'EUR', now: now);
      expect(asked.last.queryParameters, {'period': 'week', 'currency': 'EUR'});
      expect(euros.net, const Money(minorUnits: 480, currency: 'EUR'));
    });

    test('kr and € are summed apart, never € into kr', () {
      final text = Money.formatTotals([
        const Money(minorUnits: 13458, currency: 'SEK'),
        const Money(minorUnits: 480, currency: 'EUR'),
        const Money(minorUnits: 1000, currency: 'SEK'),
      ]);
      expect(text, '144,58 kr · 4,80 €');
    });

    test('the cash balance of SE + FR trips does not throw and keeps both', () {
      final totals = CashBalance.totals([
        CashBalance(
          fare: const Money(minorUnits: 10000, currency: 'SEK'),
          cashCollected: const Money(minorUnits: 10000, currency: 'SEK'),
          serviceFee: const Money(minorUnits: 2000, currency: 'SEK'),
        ),
        CashBalance(
          fare: const Money(minorUnits: 480, currency: 'EUR'),
          cashCollected: const Money(minorUnits: 480, currency: 'EUR'),
          serviceFee: const Money(minorUnits: 118, currency: 'EUR'),
        ),
      ]);
      expect(CashBalance.signedAll(totals), '−20,00 kr · −1,18 €');
    });
  });

  group('P2-M4 route change: one money number', () {
    const change = TripRouteChange(
      changeId: 'rc1',
      status: 'pending',
      driverEarnings: Money(minorUnits: 4956, currency: 'SEK'),
      earningsDifference: Money(minorUnits: 1200, currency: 'SEK'),
    );

    test('earnings + the pickup pay and bonus the trip already pays', () {
      // Today: earnings 37,56 kr, driverTotal 92,56 kr (55 kr pickup pay).
      final total = change.driverTotalWith(
        currentTotal: const Money(minorUnits: 9256, currency: 'SEK'),
        currentEarnings: const Money(minorUnits: 3756, currency: 'SEK'),
      );
      expect(total?.formatted, '104,56 kr');
      // Another currency: the change's own number.
      expect(
        change
            .driverTotalWith(
              currentTotal: const Money(minorUnits: 900, currency: 'EUR'),
              currentEarnings: const Money(minorUnits: 300, currency: 'EUR'),
            )
            ?.formatted,
        '49,56 kr',
      );
    });

    testWidgets('the sheet shows the one number', (tester) async {
      await _pump(
        tester,
        RouteChangeSheet(
          change: change,
          maxStops: 3,
          onAnswer: (_) async {},
          driverTotal: const Money(minorUnits: 10456, currency: 'SEK'),
        ),
      );
      final text = tester.widget<Text>(
        find.byKey(const ValueKey<String>('route-change-earnings')),
      );
      expect(text.data, contains('104,56 kr'));
      expect(text.data, isNot(contains('49,56 kr')));
    });
  });

  group('H-2 Vehicles: the server\'s active car', () {
    FleetVehicle car(String id, {String? driverId}) => FleetVehicle(
      vehicleId: id,
      make: 'Volvo',
      model: 'V60',
      year: 2022,
      color: 'black',
      plate: 'TST 001',
      seats: 4,
      categoryIds: const ['economy'],
      status: 'approved',
      version: 1,
      driverId: driverId,
    );

    testWidgets('the active car is "Your car" even when its row names no '
        'driver; another car is not', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            FleetCarCard(
              vehicle: car('veh-volvo'),
              myDriverId: 'd1',
              activeVehicleId: 'veh-volvo',
            ),
            FleetCarCard(
              vehicle: car('veh-tesla', driverId: 'd1'),
              myDriverId: 'd1',
              activeVehicleId: 'veh-volvo',
              onPick: () {},
            ),
          ],
        ),
      );
      expect(find.text(tr.fleetYourCar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('car-veh-volvo')),
          matching: find.text(tr.fleetYourCar),
        ),
        findsOneWidget,
      );
    });
    testWidgets('v0.18.14 Vehicle.active from GET /driver/vehicles marks the '
        'car, even before the profile names it', (tester) async {
      final active = FleetVehicle.fromJson({
        'vehicleId': 'veh-own',
        'make': 'Kia',
        'model': 'Niro',
        'status': 'approved',
        'active': true,
      });
      final other = FleetVehicle.fromJson({
        'vehicleId': 'veh-fleet',
        'make': 'Kia',
        'model': 'Ceed',
        'status': 'approved',
        'driverId': 'd1',
        'active': false,
      });
      expect(active.active, isTrue);
      await _pump(
        tester,
        Column(
          children: [
            FleetCarCard(vehicle: active, myDriverId: 'd1'),
            FleetCarCard(vehicle: other, myDriverId: 'd1', onPick: () {}),
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('car-veh-own')),
          matching: find.text(tr.fleetYourCar),
        ),
        findsOneWidget,
      );
      expect(find.text(tr.fleetYourCar), findsOneWidget);
    });
  });

  group('B7 toll icon', () {
    test('the coin shows the given currency, kr without a zone', () {
      expect(NavigationCuePainter.zoneTollUnit(), 'kr');
      final painter = NavigationCuePainter(
        symbol: null,
        icon: Icons.toll,
        tollUnit: '€',
      );
      expect(painter.tollUnit, '€');
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}
