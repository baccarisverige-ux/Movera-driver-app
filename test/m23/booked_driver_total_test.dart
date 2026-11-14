import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

/// BQ-M23 (contract v0.18.96, `contract.json#priceDisplay.bookedRide`;
/// owner s06:1164 "on the offer when come he see only how much he get"):
/// the Booked rides list, its ride sheet and "Keep it at the new time?"
/// show only the server's `DriverReservation.driverTotal` (earnings +
/// pickup pay + Movera's bonus); "—" without it; the phone never works
/// money out. Before this job the list showed `earnings` (the trip line
/// without the bonus and pickup pay).
Map<String, dynamic> _row({
  Map<String, Object?>? driverTotal,
  String currency = 'SEK',
  int earnings = 18950,
  Map<String, Object?>? reservation,
}) => {
  'tripId': 'trp_m23',
  'version': 3,
  'scheduledAt': '2026-11-20T14:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
  'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
  'stops': 0,
  'distanceMeters': 8000,
  'durationSeconds': 1080,
  'earnings': {'amountMinor': earnings, 'currency': currency},
  'driverTotal': ?driverTotal,
  'status': 'accepted',
  'mustBeOnlineAt': '2026-11-20T13:00:00Z',
  'canStartAt': '2026-11-20T13:00:00Z',
  'reservation': ?reservation,
};

ReservationRequestPreview _preview(ServerReservation r) =>
    r.toPreview(dayWord: (_) => 'Today', pickupLabel: (t) => 'Today $t');

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  test('SEK: the list shows driverTotal (with bonus + pickup pay), never '
      'earnings', () {
    final ride = ServerReservation.fromJson(
      _row(driverTotal: {'amountMinor': 22450, 'currency': 'SEK'}),
    );
    expect(ride.driverPayLabel, '224,50 kr');
    expect(_preview(ride).driverPayLabel, '224,50 kr');
    // The trip line stays parsed (contract: kept, not shown).
    expect(ride.earnings.formatted, '189,50 kr');
  });

  test('SEK whole amount keeps its decimals: 65,00 kr', () {
    final ride = ServerReservation.fromJson(
      _row(
        earnings: 6000,
        driverTotal: {'amountMinor': 6500, 'currency': 'SEK'},
      ),
    );
    expect(_preview(ride).driverPayLabel, '65,00 kr');
  });

  test('TND (3 decimals): 15.000 DT as the server sent it', () {
    final ride = ServerReservation.fromJson(
      _row(
        currency: 'TND',
        earnings: 12350,
        driverTotal: {'amountMinor': 15000, 'currency': 'TND'},
      ),
    );
    expect(ride.driverPayLabel, '15.000 DT');
    expect(_preview(ride).driverPayLabel, '15.000 DT');
  });

  test('absent (a server before v0.18.96): "—", never earnings, never '
      'phone maths', () {
    final ride = ServerReservation.fromJson(_row());
    expect(ride.driverTotal, isNull);
    expect(ride.driverPayLabel, '—');
    expect(_preview(ride).driverPayLabel, '—');
  });

  test('a bad driverTotal does not drop the row; it shows "—"', () {
    final ride = ServerReservation.fromJson(
      _row(driverTotal: {'amountMinor': '224.50', 'currency': 'SEK'}),
    );
    expect(ride.tripId, 'trp_m23');
    expect(ride.driverPayLabel, '—');
  });

  testWidgets('the ride sheet shows only driverTotal', (tester) async {
    final ride = ServerReservation.fromJson(
      _row(driverTotal: {'amountMinor': 22450, 'currency': 'SEK'}),
    );
    await _pump(
      tester,
      ReservationRequestSheet(
        request: _preview(ride),
        clock: () => DateTime(2026, 11, 20, 8),
      ),
    );
    final fare = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reservation-fare')),
    );
    expect(fare.textSpan!.toPlainText(), '224,50 kr');
    expect(find.textContaining('189,50', findRichText: true), findsNothing);
  });

  testWidgets('the ride sheet without driverTotal shows "—"', (tester) async {
    final ride = ServerReservation.fromJson(_row());
    await _pump(
      tester,
      ReservationRequestSheet(
        request: _preview(ride),
        clock: () => DateTime(2026, 11, 20, 8),
      ),
    );
    expect(find.textContaining('189,50', findRichText: true), findsNothing);
    expect(find.textContaining('—', findRichText: true), findsWidgets);
  });

  testWidgets('Keep it at the new time? shows the new driverTotal (TND)', (
    tester,
  ) async {
    final ride = ServerReservation.fromJson(
      _row(
        currency: 'TND',
        earnings: 12350,
        driverTotal: {'amountMinor': 15000, 'currency': 'TND'},
        reservation: {
          'changeAsk': {
            'until': '2026-11-20T07:15:00Z',
            'previousAt': '2026-11-20T08:30:00Z',
          },
        },
      ),
    );
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => askKeepAtNewTime(context, ride),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('15.000 DT'), findsOneWidget);
    expect(find.textContaining('12.350'), findsNothing);
  });
}
