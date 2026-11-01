import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';

Map<String, Object> _m(int minor, [String currency = 'SEK']) => {
  'amountMinor': minor,
  'currency': currency,
};

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(home: screen),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

WaybillRecord _record({
  List<EarningsLine> lines = const [],
  TripTipInfo? tip,
  Money? debt,
  String? endedBy,
  String riderFare = '318,00 kr',
  String fare = '60,05 kr',
}) => WaybillRecord(
  tripId: 'trp_g8',
  statusLabel: WaybillRecord.completed,
  issuedAt: DateTime(2026, 11, 1, 12),
  fare: fare,
  service: 'Movera',
  riderName: 'Anna',
  pickup: 'A, Stockholm',
  dropoff: 'B, Stockholm',
  source: WaybillRecord.exclusiveOfferSource,
  driverName: 'D',
  vehicle: 'V',
  licensePlate: 'P',
  passengerCapacity: 4,
  riderFare: riderFare,
  earningsBreakdown: lines,
  tip: tip,
  debtCollected: debt,
  endedEarlyBy: endedBy,
);

void main() {
  group('G8 money (contract 0.18.10)', () {
    test('driverTotal is the one money number, with its lines', () {
      final money = LiveTripMoney.tryParse({
        'fare': _m(31800),
        'driverEarnings': _m(5645),
        'pickupPay': _m(360),
        'driverTotal': _m(6005),
        'earningsBreakdown': [
          {'code': 'trip', 'amount': _m(5645)},
          {'code': 'pickup_pay', 'amount': _m(360)},
        ],
        'debtCollected': _m(24000),
        'tip': {'amount': _m(2000), 'method': 'cash'},
      })!;
      expect(money.driverPay, Money.ore(6005));
      expect(money.earningsBreakdown.map((l) => l.code), [
        'trip',
        'pickup_pay',
      ]);
      expect(money.debtCollected, Money.ore(24000));
      expect(money.tip!.cash, isTrue);
    });

    test('an older server keeps earnings + pickup pay + bonus', () {
      final money = LiveTripMoney.tryParse({
        'fare': _m(10000),
        'driverEarnings': _m(8000),
        'pickupPay': _m(300),
      })!;
      expect(money.driverPay, Money.ore(8300));
      expect(money.finish, isNull);
    });

    test('the rider ended early: finish with the cash to collect', () {
      final money = LiveTripMoney.tryParse({
        'status': 'cancelled_by_rider',
        'fare': _m(5400),
        'driverEarnings': _m(4300),
        'finish': {
          'endedEarly': true,
          'endedBy': 'rider',
          'total': _m(5400),
          'cashToCollect': _m(5400),
          'driverTotal': _m(4300),
          'ratingAllowed': true,
        },
      })!;
      expect(money.finish!.riderEndedEarly, isTrue);
      expect(money.finish!.ratingAllowed, isTrue);
      expect(money.cash, Money.ore(5400));
      expect(money.driverPay, Money.ore(4300));
    });

    test('France: euros', () {
      final money = LiveTripMoney.tryParse({
        'fare': _m(1300, 'EUR'),
        'driverEarnings': _m(1000, 'EUR'),
        'driverTotal': _m(1200, 'EUR'),
        'tip': {'amount': _m(200, 'EUR'), 'method': 'cash'},
      })!;
      expect(money.driverPay.currency, 'EUR');
      expect(money.tip!.amount.currency, 'EUR');
    });

    test('CompletePreview reads driverTotal and repriced', () {
      final preview = CompletePreview.tryParse({
        'total': _m(9300),
        'cashDue': _m(9300),
        'earlyEnd': true,
        'driverEarnings': _m(7000),
        'driverTotal': _m(7360),
        'earningsBreakdown': [
          {'code': 'trip', 'amount': _m(7000)},
          {'code': 'pickup_pay', 'amount': _m(360)},
        ],
        'repriced': false,
      })!;
      expect(preview.yourShare, Money.ore(7360));
      expect(preview.repriced, isFalse);
      expect(preview.earningsBreakdown, hasLength(2));
    });
  });

  group('G8 screens', () {
    testWidgets('cash sheet: "Finish ride", never the brand name; your share', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: CashCollectSheet(
            fare: '73,60 kr',
            cash: '93,00 kr',
            riderName: 'Anna',
            category: 'Movera',
            earlyEndNote: 'The booked price applies.',
          ),
        ),
      );
      expect(find.text('Finish Movera'), findsNothing);
      expect(find.text('Finish ride'), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);
      expect(find.text('The booked price applies.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cash-not-yet')), findsOneWidget);
    });

    testWidgets('cash sheet after the rider ended: amount, no Not yet', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: CashCollectSheet(
            fare: '43,00 kr',
            cash: '54,00 kr',
            riderName: 'Anna',
            riderEnded: true,
          ),
        ),
      );
      expect(
        find.text('The rider ended the trip. Collect 54 kr.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cash-not-yet')), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('finished: old debt is its own line, not commission', (
      tester,
    ) async {
      final waybills = InMemoryWaybillRepository.instance..reset();
      waybills.beginCurrent(
        _record(
          debt: Money.ore(24000),
          lines: [
            EarningsLine('trip', Money.ore(5645)),
            EarningsLine('pickup_pay', Money.ore(360)),
          ],
          endedBy: 'rider',
        ),
      );
      waybills.completeCurrent();
      await _pump(tester, DriverRideCompleted(waybillRepository: waybills));
      final commission = tester.widget<Text>(
        find.byKey(const ValueKey('ride-completed-commission')),
      );
      expect(commission.data, '−${Money.ore(1795).formatted}');
      expect(find.byKey(const ValueKey('ride-completed-debt')), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ride-completed-line-pickup_pay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ride-completed-early')),
        findsOneWidget,
      );
      waybills.reset();
    });

    testWidgets('finished: the tip is the driver\'s, outside commission', (
      tester,
    ) async {
      final waybills = InMemoryWaybillRepository.instance..reset();
      waybills.beginCurrent(
        _record(
          riderFare: '100,00 kr',
          fare: '100,00 kr',
          tip: TripTipInfo(amount: Money.ore(2000), method: 'cash'),
        ),
      );
      waybills.completeCurrent();
      await _pump(tester, DriverRideCompleted(waybillRepository: waybills));
      final commission = tester.widget<Text>(
        find.byKey(const ValueKey('ride-completed-commission')),
      );
      expect(commission.data, '−${Money.ore(2000).formatted}');
      expect(find.byKey(const ValueKey('ride-completed-tip')), findsOneWidget);
      expect(
        find.text('The rider gives you a 20 kr tip in cash.'),
        findsOneWidget,
      );
      waybills.reset();
    });
  });

  testWidgets('history: a tip given after the trip comes from the receipt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'trp_tip',
              riderName: 'Anna',
              whenLabel: '01/11/2026, 12:00',
              pickup: 'A',
              dropoff: 'B',
              fare: '80,00 kr',
              category: 'Comfort',
              paymentMethod: 'Cash',
            ),
            loadRideChecks: (_) async => const [],
            loadPath: (_) async => null,
            loadTip: (record) async {
              asked.add(record.tripId);
              return '20,00 kr';
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(asked, ['trp_tip']);
    expect(find.text('20,00 kr'), findsOneWidget);
  });
}
