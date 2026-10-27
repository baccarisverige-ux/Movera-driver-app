import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

/// Owner decision 2026-10-27: Ride completed shows exactly three money
/// lines, Trip total, Movera commission (minus) and You get, and they add
/// up. No waiting, pickup pay or bonus line.
WaybillRecord _record({String? riderFare = '184,00 kr'}) => WaybillRecord(
  tripId: 'trip-rc',
  statusLabel: WaybillRecord.completed,
  issuedAt: DateTime(2026, 10, 27, 14, 5),
  // Earnings 131,20 + pickup pay 6,80 + waiting 9,00 + bonus 20,00.
  fare: '167,00 kr',
  service: 'Comfort',
  riderName: 'Sara',
  pickup: 'Odengatan 1, Stockholm',
  dropoff: 'Solna centrum, Solna',
  source: WaybillRecord.localDemoSource,
  driverName: 'Ali',
  vehicle: 'Toyota',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
  waitingFee: '9,00 kr',
  driverBonus: '20 kr',
  riderFare: riderFare,
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

  testWidgets('three lines that add up, nothing else', (tester) async {
    await _pump(tester, _record());
    expect(find.text('Trip total'), findsOneWidget);
    expect(find.text('Movera commission'), findsOneWidget);
    expect(find.text('You get'), findsOneWidget);
    expect(_text(tester, 'ride-completed-total'), '184,00 kr');
    expect(_text(tester, 'ride-completed-commission'), '−17,00 kr');
    expect(_text(tester, 'ride-completed-fare'), '167,00 kr');
    for (final gone in ['waiting', 'pickup', 'bonus', 'paid by Movera']) {
      expect(
        find.textContaining(gone, findRichText: true),
        findsNothing,
        reason: gone,
      );
    }
    expect(find.textContaining('9,00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swedish texts', (tester) async {
    DriverAppTexts.language = 'sv';
    await _pump(tester, _record());
    expect(find.text('Resans totalpris'), findsOneWidget);
    expect(find.text('Moveras provision'), findsOneWidget);
    expect(find.text('Du får'), findsOneWidget);
  });

  testWidgets('an older save without the rider fare shows the amount only', (
    tester,
  ) async {
    await _pump(tester, _record(riderFare: null));
    expect(find.byKey(const ValueKey('ride-completed-money')), findsNothing);
    expect(_text(tester, 'ride-completed-fare'), '167,00 kr');
  });
}
