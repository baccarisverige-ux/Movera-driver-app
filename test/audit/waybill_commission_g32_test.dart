import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// G32 (owner 2026-11-12 ~16:05, "all details in waybill"): the offer card
/// shows only what the driver gets; the waybill shows everything: what
/// the rider pays, Movera's commission (the server's `commission`), what
/// the driver gets and how the rider pays.
WaybillRecord _record({
  String fare = '152,80 kr',
  String? riderFare = '184,00 kr',
  String? commission,
  bool cash = true,
}) {
  return WaybillRecord(
    tripId: 'trip-g32',
    statusLabel: WaybillRecord.completed,
    issuedAt: DateTime(2026, 11, 12, 16, 5),
    fare: fare,
    service: 'Movera',
    riderName: 'Sara',
    pickup: 'Odengatan 1',
    dropoff: 'Solna',
    source: WaybillRecord.moveraRadarSource,
    driverName: 'Ali',
    vehicle: 'Toyota',
    licensePlate: 'ABC 123',
    passengerCapacity: 4,
    paidByCash: cash,
    riderFare: riderFare,
    commission: commission,
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

/// The value on the waybill row labelled [label]; null without the row.
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

RadarOfferView _offer() => const RadarOfferView(
  id: 'o-g32',
  category: 'Comfort',
  payment: 'Cash',
  rating: '4.9',
  fare: '184,00 kr',
  driverEarnings: '152,80 kr',
  pickupMinutes: 3,
  pickupKm: 1.2,
  tripMinutes: 14,
  tripKm: 8.4,
  pickup: 'Odengatan 1',
  dropoff: 'Solna',
);

void main() {
  group('G32: the waybill shows every money line', () {
    testWidgets('Movera commission is the server\'s value', (tester) async {
      // The server's commission (fare − old fee − earnings − pickup pay −
      // bonus) differs from 184,00 − 152,80 here: the row must be the
      // server's number, not one worked out on the phone.
      await _openWaybill(tester, _record(commission: '28,20 kr'));
      expect(_row(tester, 'Rider pays'), '184,00 kr');
      expect(_row(tester, 'Movera commission'), '28,20 kr');
      expect(_row(tester, 'Your earnings'), '152,80 kr');
      expect(_row(tester, 'Payment'), 'Cash');
    });

    testWidgets('rows read rider pays, commission, then what he gets', (
      tester,
    ) async {
      await _openWaybill(tester, _record(commission: '31,20 kr'));
      final pays = tester.getTopLeft(find.text('Rider pays')).dy;
      final commission = tester.getTopLeft(find.text('Movera commission')).dy;
      final gets = tester.getTopLeft(find.text('Your earnings')).dy;
      expect(pays < commission && commission < gets, isTrue);
    });

    testWidgets('without the server\'s value: the fare less his money', (
      tester,
    ) async {
      await _openWaybill(tester, _record());
      expect(_row(tester, 'Movera commission'), '31,20 kr');
    });

    testWidgets('no commission row when neither is known', (tester) async {
      await _openWaybill(tester, _record(riderFare: null));
      expect(_row(tester, 'Movera commission'), isNull);
      expect(_row(tester, 'Your earnings'), '152,80 kr');
    });

    test('the live projection carries the commission to the waybill', () {
      final money = LiveTripMoney.tryParse({
        'fare': {'amountMinor': 18400, 'currency': 'SEK'},
        'driverEarnings': {'amountMinor': 15280, 'currency': 'SEK'},
        'commission': {'amountMinor': 2820, 'currency': 'SEK'},
      })!;
      expect(money.commission?.minorUnits, 2820);
    });
  });

  group('G32: the offer card shows only what the driver gets', () {
    testWidgets('Radar card: no rider fare', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RadarOfferCard(
              offer: _offer(),
              details: const OfferCardDetails(),
              onMatch: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      bool shows(String text) => find
          .byWidgetPredicate(
            (w) =>
                (w is RichText && w.text.toPlainText().contains(text)) ||
                (w is Text && (w.data ?? '').contains(text)),
          )
          .evaluate()
          .isNotEmpty;
      expect(shows('152'), isTrue);
      expect(shows('184'), isFalse);
      expect(shows('Rider pays'), isFalse);
      expect(shows('collect'), isFalse);
    });

    testWidgets('Exclusive sheet: no rider fare', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExclusiveRequestSheet(
                offer: _offer(),
                secondsLeft: 12,
                details: const OfferCardDetails(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      bool shows(String text) => find
          .byWidgetPredicate(
            (w) =>
                (w is RichText && w.text.toPlainText().contains(text)) ||
                (w is Text && (w.data ?? '').contains(text)),
          )
          .evaluate()
          .isNotEmpty;
      expect(shows('152'), isTrue);
      expect(shows('184'), isFalse);
      expect(shows('collect'), isFalse);
    });
  });
}
