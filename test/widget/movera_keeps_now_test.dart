import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';

/// Owner 2026-11-13 "Movera commission is how much movera keep !" (contract
/// v0.18.87 `moneyBase.commissionRow`, GM decision 2026-11-14): every
/// "Movera commission" row shows what Movera keeps NOW on the trip. The
/// driver view has no moneySplit, so the row is the server's additive
/// `TripProjection.moveraKeepsNow`; without it the row is hidden — never
/// the stored `commission` (what Movera kept at the paid end, higher after
/// a later admin bonus) and never worked out on the phone.
WaybillRecord _record({String? commission, String? moveraKeepsNow}) =>
    WaybillRecord(
      tripId: 'trip-mc',
      statusLabel: WaybillRecord.completed,
      issuedAt: DateTime(2026, 11, 14, 10, 5),
      fare: '265,00 kr',
      service: 'Economy',
      riderName: 'Sara',
      pickup: 'Odengatan 1, Stockholm',
      dropoff: 'Solna centrum, Solna',
      source: WaybillRecord.localDemoSource,
      driverName: 'Ali',
      vehicle: 'Toyota',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
      riderFare: '300,00 kr',
      commission: commission,
      moveraKeepsNow: moveraKeepsNow,
    );

Future<void> _pumpCompleted(WidgetTester tester, WaybillRecord record) async {
  InMemoryWaybillRepository.instance
    ..reset()
    ..beginCurrent(record)
    ..completeCurrent();
  final session = DriverSessionController(initialOnline: true);
  addTearDown(session.dispose);
  session.beginTrip(record.tripId);
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DriverRideCompleted(
        sessionController: session,
        waybillRepository: InMemoryWaybillRepository.instance,
      ),
    ),
  );
  await tester.pumpAndSettle();
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

String? _waybillRow(WidgetTester tester, String label) {
  final rows = find.ancestor(of: find.text(label), matching: find.byType(Row));
  if (rows.evaluate().isEmpty) return null;
  return tester
      .widgetList<Text>(
        find.descendant(of: rows.first, matching: find.byType(Text)),
      )
      .map((text) => text.data)
      .last;
}

const _commissionKey = ValueKey<String>('ride-completed-commission');

void main() {
  tearDown(() {
    DriverAppTexts.language = 'en';
    InMemoryWaybillRepository.instance.reset();
  });

  group('LiveTripMoney: moveraKeepsNow', () {
    test('read from the projection, in the trip currency', () {
      final money = LiveTripMoney.tryParse({
        'fare': {'amountMinor': 30000, 'currency': 'SEK'},
        'driverEarnings': {'amountMinor': 24000, 'currency': 'SEK'},
        'commission': {'amountMinor': 6000, 'currency': 'SEK'},
        'moveraKeepsNow': {'amountMinor': 3500, 'currency': 'SEK'},
      })!;
      expect(money.moveraKeepsNow?.minorUnits, 3500);
      expect(money.commission?.minorUnits, 6000);
    });

    test('absent (a server before 0.18.87): null, never the commission', () {
      final money = LiveTripMoney.tryParse({
        'fare': {'amountMinor': 30000, 'currency': 'SEK'},
        'driverEarnings': {'amountMinor': 24000, 'currency': 'SEK'},
        'commission': {'amountMinor': 6000, 'currency': 'SEK'},
      })!;
      expect(money.moveraKeepsNow, isNull);
    });
  });

  group('Ride completed: Movera commission row', () {
    testWidgets('a 25 kr bonus after the end: shows 35 kr kept now, not 60', (
      tester,
    ) async {
      await _pumpCompleted(
        tester,
        _record(commission: '60,00 kr', moveraKeepsNow: '35,00 kr'),
      );
      final text = tester.widget<Text>(find.byKey(_commissionKey));
      expect(text.data, '−35,00 kr');
    });

    testWidgets('no moveraKeepsNow: the row is hidden (no stored fallback)', (
      tester,
    ) async {
      await _pumpCompleted(tester, _record(commission: '60,00 kr'));
      expect(find.byKey(_commissionKey), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('ride-completed-total')),
        findsOneWidget,
      );
    });
  });

  group('Waybill: Movera commission row', () {
    testWidgets('shows moveraKeepsNow', (tester) async {
      await _openWaybill(
        tester,
        _record(commission: '60,00 kr', moveraKeepsNow: '35,00 kr'),
      );
      expect(_waybillRow(tester, 'Movera commission'), '35,00 kr');
    });

    testWidgets('no moveraKeepsNow: no row, never the stored commission', (
      tester,
    ) async {
      await _openWaybill(tester, _record(commission: '60,00 kr'));
      expect(_waybillRow(tester, 'Movera commission'), isNull);
      expect(_waybillRow(tester, 'Rider pays'), '300,00 kr');
    });
  });
}
