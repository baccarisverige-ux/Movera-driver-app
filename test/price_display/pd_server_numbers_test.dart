import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept ride/route_change_sheet.dart';
import 'package:movera/presentation/driver/accept ride/waiting_time_sheet.dart';

import 'live_fake.dart';

/// Price audit 2026-11-14 gaps 2, 11, 13, 16 and 17 (Rules
/// audits/price-display-2026-11-14/REPORT.md; contract v0.18.89 §90): a
/// live driver app shows only the server's money numbers. With the
/// server's field: that number. Without it: "—" or no line, never maths on
/// the phone.
Map<String, Object?> _m(int minor, [String currency = 'SEK']) => {
  'amountMinor': minor,
  'currency': currency,
};

Map<String, dynamic> _offer({Map<String, Object?> extra = const {}}) => {
  'offerId': 'o1',
  'tripId': 'trp_1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'fare': _m(12000, 'EUR'),
  'driverEarnings': _m(9000, 'EUR'),
  'source': 'system',
  'pickup': {'address': 'Rue A', 'lat': 48.85, 'lng': 2.35},
  'dropoff': {'address': 'Rue B', 'lat': 48.86, 'lng': 2.36},
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
  ...extra,
};

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(home: Scaffold(body: screen)),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(uninstallLive);

  group('Offer.driverTotal (gap 1/2, v0.18.89)', () {
    test('parsed, and the only number the card shows', () {
      final offer = OfferWire.parse(
        _offer(
          extra: {
            'pickupPay': _m(250, 'EUR'),
            'driverTotal': _m(9250, 'EUR'),
            'cashToCollect': _m(12000, 'EUR'),
          },
        ),
      );
      expect(offer.driverTotal, const Money(minorUnits: 9250, currency: 'EUR'));
      expect(
        offer.cashToCollect,
        const Money(minorUnits: 12000, currency: 'EUR'),
      );
      final quote = PickupPayCalculator.quote(
        category: offer.category,
        kind: PickupPayOfferKind.radar,
        leg: const PickupLeg(km: 1, minutes: 3),
        serverPay: offer.pickupPay,
        serverTotal: offer.driverTotal,
      );
      expect(quote.totalOf(offer.driverPayLabel), '92,50 €');
      // Accept keeps the card's number; the pickup pay stays Movera's bonus.
      final terms = quote.termsOf(fare: offer.driverPayLabel);
      expect(terms.fare, '92,50 €');
      expect(terms.driverBonus, const Money(minorUnits: 250, currency: 'EUR'));
    });

    test('live cash offer without cashToCollect: no cash worked out', () {
      installLive();
      final offer = OfferWire.parse(
        _offer(extra: {'driverBonus': _m(500, 'EUR')}),
      );
      expect(offer.riderCash, isNull);
      expect(offer.riderCashLabel, isNull);
    });
  });

  group('gap 11: collect and cash', () {
    test('driverPay is the server driverTotal only', () {
      final without = LiveTripMoney.tryParse({
        'fare': _m(20000),
        'driverEarnings': _m(15000),
        'pickupPay': _m(1000),
        'driverBonus': _m(500),
      })!;
      expect(without.driverPay, isNull);
      final withTotal = LiveTripMoney.tryParse({
        'fare': _m(20000),
        'driverEarnings': _m(15000),
        'pickupPay': _m(1000),
        'driverTotal': _m(16000),
        'cashToCollect': _m(20000),
        'finish': {'endedEarly': false, 'owedToMovera': _m(4000)},
      })!;
      expect(withTotal.driverPay?.formatted, '160,00 kr');
      expect(withTotal.cashToCollect?.formatted, '200,00 kr');
      expect(withTotal.owedToMovera?.formatted, '40,00 kr');
    });

    testWidgets('live collect sheet: no balance line without the server', (
      tester,
    ) async {
      installLive();
      await _pump(
        tester,
        const CashCollectSheet(
          fare: '150,00 kr',
          cash: '250,00 kr',
          riderName: 'Anna',
        ),
      );
      expect(find.text('You owe Movera'), findsNothing);
      expect(find.text('−100,00 kr'), findsNothing);
      // The share and the cash still show.
      expect(find.text('150,00 kr'), findsWidgets);
    });

    testWidgets("live collect sheet: the server's owedToMovera", (
      tester,
    ) async {
      installLive();
      await _pump(
        tester,
        const CashCollectSheet(
          fare: '150,00 kr',
          cash: '250,00 kr',
          riderName: 'Anna',
          owedToMovera: Money(minorUnits: 9000, currency: 'SEK'),
        ),
      );
      expect(find.text('You owe Movera'), findsOneWidget);
      // The server's number, not 250 − 150 worked out here.
      expect(find.text('−90,00 kr'), findsOneWidget);
    });
  });

  group('gap 13: owed to Movera', () {
    const record = TripHistoryRecord(
      tripId: 't1',
      riderName: 'Anna',
      whenLabel: 'Today',
      pickup: 'A',
      dropoff: 'B',
      fare: '150,00 kr',
      category: 'Movera',
      paymentMethod: 'Cash',
      cashCollected: '250,00 kr',
    );

    test('live without the server number: no balance', () {
      installLive();
      expect(record.cashBalance, isNull);
    });

    test("the server's owedToMovera when it is there", () {
      installLive();
      const withServer = TripHistoryRecord(
        tripId: 't1',
        riderName: 'Anna',
        whenLabel: 'Today',
        pickup: 'A',
        dropoff: 'B',
        fare: '150,00 kr',
        category: 'Movera',
        paymentMethod: 'Cash',
        cashCollected: '250,00 kr',
        owedToMovera: '90,00 kr',
      );
      final balance = withServer.cashBalance!;
      expect(balance.signedLabel, '−90,00 kr');
      expect(balance.driverOwesMovera, isTrue);
      expect(
        CashBalance.fromServer(
          fare: const Money(minorUnits: 100, currency: 'TND'),
          cashCollected: const Money(minorUnits: 100, currency: 'TND'),
          owedToMovera: const Money(minorUnits: -1500, currency: 'TND'),
        ).signedLabel,
        '+1.500 DT',
      );
    });
  });

  group('gap 16: route change', () {
    test('TripRouteChange.driverTotal from the server', () {
      final change = TripRouteChange.tryParse({
        'changeId': 'rc1',
        'status': 'pending',
        'driverEarnings': _m(4956),
        'driverTotal': _m(10456),
      })!;
      expect(change.driverTotal?.formatted, '104,56 kr');
    });

    testWidgets('no driverTotal: no money line (never earnings alone)', (
      tester,
    ) async {
      final change = TripRouteChange.tryParse({
        'changeId': 'rc1',
        'status': 'pending',
        'driverEarnings': _m(4956),
        'earningsDifference': _m(1200),
      })!;
      await _pump(
        tester,
        RouteChangeSheet(change: change, maxStops: 3, onAnswer: (_) async {}),
      );
      expect(find.byKey(const ValueKey('route-change-earnings')), findsNothing);
    });
  });

  group('gap 17: waiting and no-show', () {
    testWidgets('live: no waiting money counted up, no share worked out', (
      tester,
    ) async {
      installLive();
      final terms = WaitingTerms(
        freeMinutes: 3,
        perMinute: const Money(minorUnits: 500, currency: 'SEK'),
        noShowAfterMinutes: 5,
        noShowFee: const Money(minorUnits: 9000, currency: 'SEK'),
        driverShareNoShowPercent: 50,
      );
      await _pump(
        tester,
        WaitingTimeSheet(readSeconds: () => 420, terms: terms, onNoShow: () {}),
      );
      expect(find.byKey(const ValueKey('waiting-fee-counter')), findsNothing);
      // 50 % of 90 kr is never worked out on the phone.
      expect(find.textContaining('45,00 kr'), findsNothing);
    });

    testWidgets("live: the server's noShowDriverShare", (tester) async {
      installLive();
      final terms = WaitingTerms(
        freeMinutes: 3,
        perMinute: const Money(minorUnits: 500, currency: 'SEK'),
        noShowAfterMinutes: 5,
        noShowFee: const Money(minorUnits: 9000, currency: 'SEK'),
        driverShareNoShowPercent: 50,
      );
      await _pump(
        tester,
        WaitingTimeSheet(
          readSeconds: () => 420,
          terms: terms,
          onNoShow: () {},
          noShowDriverShare: const Money(minorUnits: 4200, currency: 'SEK'),
        ),
      );
      expect(find.textContaining('42,00 kr'), findsWidgets);
    });
  });
}
