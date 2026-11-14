import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

/// S5 J5d (contract v0.18.82 `moneyBase.commission`, B2.4 / S07 M5): the
/// Ride completed screen shows Movera's commission AS THE SERVER SENT IT
/// (`TripProjection.commission`, kept on the record) and never works it out
/// on the phone. Before: `paid − get − debt + tip`, which also took Movera's
/// own pay change to the driver out of the commission.
Money _sek(int minor) => Money(minorUnits: minor, currency: 'SEK');
Money _tnd(int minor) => Money(minorUnits: minor, currency: 'TND');

WaybillRecord _record({
  required Money riderFare,
  required Money driverTotal,
  required Money? commission,
  List<EarningsLine> lines = const [],
}) => WaybillRecord(
  tripId: 'trip-j5d',
  statusLabel: WaybillRecord.completed,
  issuedAt: DateTime(2026, 11, 13, 14, 5),
  fare: driverTotal.formatted,
  service: 'Economy',
  riderName: 'Sara',
  pickup: 'Odengatan 1, Stockholm',
  dropoff: 'Solna centrum, Solna',
  source: WaybillRecord.localDemoSource,
  driverName: 'Ali',
  vehicle: 'Toyota',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
  riderFare: riderFare.formatted,
  earningsBreakdown: lines,
  commission: commission?.formatted,
);

Future<void> _pump(WidgetTester tester, WaybillRecord record) async {
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

String _text(WidgetTester tester, String key) {
  final widget = tester.widget<Text>(find.byKey(ValueKey<String>(key)));
  return widget.data ?? widget.textSpan!.toPlainText();
}

void main() {
  tearDown(() {
    DriverAppTexts.language = 'en';
    InMemoryWaybillRepository.instance.reset();
  });

  testWidgets(
    'run P6 + Movera pay change: 95 kr trip, server commission 24,73 kr is shown, not 95 − 80,27',
    (tester) async {
      // Earnings 69,22 + pickup pay 1,05 + Movera's +10,00 kr pay change.
      await _pump(
        tester,
        _record(
          riderFare: _sek(9500),
          driverTotal: _sek(8027),
          commission: _sek(2473),
          lines: [
            EarningsLine('trip', _sek(6922)),
            EarningsLine('pickup_pay', _sek(105)),
            EarningsLine('adjustment', _sek(1000)),
          ],
        ),
      );
      expect(_text(tester, 'ride-completed-total'), '95,00 kr');
      expect(_text(tester, 'ride-completed-commission'), '−24,73 kr');
      expect(_text(tester, 'ride-completed-fare'), '80,27 kr');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a big Movera bonus: the server\'s negative commission shows as +',
    (tester) async {
      await _pump(
        tester,
        _record(
          riderFare: _sek(10000),
          driverTotal: _sek(11000),
          commission: _sek(-1000),
        ),
      );
      expect(_text(tester, 'ride-completed-commission'), '+10,00 kr');
    },
  );

  testWidgets('Tunisia (TND, 3 decimals): the server\'s 2.750 DT', (
    tester,
  ) async {
    await _pump(
      tester,
      _record(
        riderFare: _tnd(12500),
        driverTotal: _tnd(10250),
        commission: _tnd(2750),
        lines: [
          EarningsLine('trip', _tnd(9000)),
          EarningsLine('pickup_pay', _tnd(750)),
          EarningsLine('adjustment', _tnd(500)),
        ],
      ),
    );
    expect(
      _text(tester, 'ride-completed-commission'),
      '−${_tnd(2750).formatted}',
    );
    expect(_text(tester, 'ride-completed-fare'), _tnd(10250).formatted);
  });
}
