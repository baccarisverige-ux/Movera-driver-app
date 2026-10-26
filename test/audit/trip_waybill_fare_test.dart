import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';

WaybillRecord _record({
  String fare = '118,39 kr',
  String? waitingFee = '18,39 kr',
  String? driverBonus,
}) {
  return WaybillRecord(
    tripId: 'trip-wait',
    statusLabel: WaybillRecord.completed,
    issuedAt: DateTime(2026, 10, 21, 14, 5),
    fare: fare,
    service: 'Movera',
    riderName: 'Sara',
    pickup: 'Odengatan 1',
    dropoff: 'Solna',
    source: WaybillRecord.localDemoSource,
    driverName: 'Ali',
    vehicle: 'Toyota',
    licensePlate: 'ABC 123',
    passengerCapacity: 4,
    waitingFee: waitingFee,
    driverBonus: driverBonus,
  );
}

Future<void> _openWaybill(WidgetTester tester, WaybillRecord record) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey<String>('open'),
            onPressed: () => showMoveraWaybillSheet(context, record),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

/// The value on the waybill row labelled [label].
String? _row(WidgetTester tester, String label) {
  final rows = find.ancestor(of: find.text(label), matching: find.byType(Row));
  if (rows.evaluate().isEmpty) return null;
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: rows.first, matching: find.byType(Text)),
      )
      .map((text) => text.data)
      .toList();
  return texts.last;
}

void main() {
  group('driver-32: a fare of 1 000 kr or more', () {
    test('the waybill reads every digit group of a grouped fare', () {
      final label = Money.ore(123450).formatted;
      expect(label, '1 234,50 kr');
      final payment = WaybillPayment.fromFare(label)!;
      expect(payment.fare, '1 234,50 kr');
      expect(payment.serviceFee, '308,63 kr');
      expect(payment.earnings, '925,87 kr');
    });

    test('the net-fare offer card shows the driver share of the whole fare',
        () {
      const details = OfferCardDetails(netFare: true);
      expect(
        details.fare('1 234,50 kr', commissionRate: 0.25),
        '925,87 kr',
      );
    });

    test('short fares keep their format', () {
      expect(WaybillPayment.fromFare('139,00 kr')!.earnings, '104,25 kr');
      expect(WaybillPayment.fromFare('126.75 kr')!.earnings, '95.06 kr');
      expect(WaybillPayment.fromFare('—'), isNull);
    });
  });

  // Owner decision 2026-10-26: the record's fare is the driver's own money
  // after Movera's commission, so the waybill shows no rider fare and no
  // fee row; the waiting fee and the bonus are parts of the earnings.
  group('driver-u52: the waiting fee is all the driver\'s', () {
    testWidgets('no fee is taken off the earnings again', (tester) async {
      await _openWaybill(tester, _record());
      expect(_row(tester, 'Movera fee'), isNull);
      expect(_row(tester, 'Fare'), isNull);
      expect(_row(tester, 'Paid by the passenger'), isNull);
      expect(_row(tester, 'Your earnings'), '118,39 kr');
      expect(find.textContaining('*'), findsNothing);
    });

    testWidgets('the bonus is a part of the earnings, on its own row',
        (tester) async {
      await _openWaybill(
        tester,
        _record(fare: '158,39 kr', driverBonus: '40 kr'),
      );
      expect(_row(tester, 'Movera fee'), isNull);
      expect(_row(tester, 'Movera bonus'), '+40 kr');
      expect(_row(tester, 'Your earnings'), '158,39 kr');
      expect(find.text('incl. +40 kr Movera bonus'), findsOneWidget);
    });

    testWidgets('a trip without waiting shows its earnings whole',
        (tester) async {
      await _openWaybill(tester, _record(fare: '100,00 kr', waitingFee: null));
      expect(_row(tester, 'Movera fee'), isNull);
      expect(_row(tester, 'Your earnings'), '100,00 kr');
    });
  });

  group('driver-u50: the waiting fee is not in the base', () {
    testWidgets('base without the wait, the wait on its own row',
        (tester) async {
      await _openWaybill(tester, _record());
      expect(_row(tester, 'Base · Movera'), '100,00 kr');
      expect(_row(tester, 'Waiting time'), '+18,39 kr');
    });

    testWidgets('no waiting row without a waiting fee', (tester) async {
      await _openWaybill(tester, _record(fare: '100,00 kr', waitingFee: null));
      expect(_row(tester, 'Base · Movera'), '100,00 kr');
      expect(_row(tester, 'Waiting time'), isNull);
    });
  });
}
