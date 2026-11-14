import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';

/// BQ-F1b (owner R2; owner s06:1164 "the waybill shows all the details"):
/// the waybill keeps the server's own money lines. The bonus row is the
/// server's `driverBonus`, the pickup pay row the server's `pickupPay`
/// (contract `Offer.driverBonus`/`Offer.pickupPay`, `TripProjection
/// .driverBonus`/`.pickupPay`), never one number added up on the phone.
const _leg = PickupLeg(km: 6.4, minutes: 12);

WaybillRecord _record({String? bonus, String? pickupPay}) => WaybillRecord(
  tripId: 'trip-f1b',
  statusLabel: WaybillRecord.currentTrip,
  issuedAt: DateTime(2026, 11, 14, 22, 55),
  fare: '263,95 kr',
  service: 'Movera',
  riderName: 'Sara',
  pickup: 'Odengatan 1',
  dropoff: 'Solna',
  source: WaybillRecord.moveraRadarSource,
  driverName: 'Ali',
  vehicle: 'Toyota',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
  driverBonus: bonus,
  pickupPay: pickupPay,
);

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

String? _row(WidgetTester tester, String label) {
  final rows = find.ancestor(of: find.text(label), matching: find.byType(Row));
  if (rows.evaluate().isEmpty) return null;
  return tester
      .widgetList<Text>(
        find.descendant(of: rows.first, matching: find.byType(Text)),
      )
      .map((text) => text.data)
      .last;
}

void main() {
  final cases = <({String currency, int bonus, int pickup, int total})>[
    (currency: 'SEK', bonus: 4000, pickup: 1395, total: 26395),
    (currency: 'TND', bonus: 2000, pickup: 1250, total: 16250),
  ];

  for (final c in cases) {
    Money m(int minor) => Money(minorUnits: minor, currency: c.currency);

    group(c.currency, () {
      test('accept (live): bonus and pickup pay are two server lines', () {
        final terms =
            PickupPayQuote(
              pay: m(c.pickup),
              leg: _leg,
              serverTotal: m(c.total),
            ).termsOf(
              fare: m(c.total - c.pickup).formatted,
              driverBonus: m(c.bonus),
              live: true,
            );
        expect(terms.fare, m(c.total).formatted);
        expect(terms.driverBonus, m(c.bonus));
        expect(terms.pickupPay, m(c.pickup));
      });

      test('accept (live) with no pickup pay: no pickup pay line', () {
        final terms =
            PickupPayQuote(
              pay: m(0),
              leg: _leg,
              serverTotal: m(c.total),
            ).termsOf(
              fare: m(c.total).formatted,
              driverBonus: m(c.bonus),
              live: true,
            );
        expect(terms.driverBonus, m(c.bonus));
        expect(terms.pickupPay, isNull);
      });

      test('Leave now (live): server bonus and server pickup pay', () {
        for (final total in [m(c.total), null]) {
          final terms = PickupPayQuote.leaveNowTermsOf(
            fare: m(c.total - c.pickup).formatted,
            leg: _leg,
            serverTotal: total,
            acceptedPickupPay: m(c.pickup),
            driverBonus: m(c.bonus),
            live: true,
          );
          expect(terms.fare, total?.formatted ?? '—');
          expect(terms.driverBonus, m(c.bonus));
          expect(terms.pickupPay, m(c.pickup));
        }
      });

      test('demo keeps its own sample sum, never on live', () {
        final terms = PickupPayQuote(pay: m(c.pickup), leg: _leg).termsOf(
          fare: m(c.total - c.pickup).formatted,
          driverBonus: m(c.bonus),
          live: false,
        );
        expect(terms.driverBonus, m(c.bonus + c.pickup));
        expect(terms.pickupPay, isNull);
      });

      test('the started trip carries the server pickupPay to Leave now', () {
        final trip = LiveActiveTrip.snapshotOf({
          'tripId': 'trp_${c.currency}',
          'status': 'accepted',
          'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'A'},
          'dropoff': {'lat': 59.35, 'lng': 18.07, 'address': 'B'},
          'fare': m(c.total).toJson(),
          'driverTotal': m(c.total).toJson(),
          'driverBonus': m(c.bonus).toJson(),
          'pickupPay': m(c.pickup).toJson(),
        })!;
        expect(trip.pickupPay, m(c.pickup));
        expect(trip.driverBonus, m(c.bonus));
        // Kept across a restore.
        expect(
          PersistedActiveRide.fromJson(trip.toJson())!.pickupPay,
          m(c.pickup),
        );
        final preview = ServerReservation.fromJson({
          'tripId': 'trp_${c.currency}',
          'version': 3,
          'scheduledAt': '2026-11-20T14:00:00Z',
          'categoryId': 'economy',
          'rideType': 'normal',
          'pickup': {'address': 'A', 'lat': 59.33, 'lng': 18.06},
          'dropoff': {'address': 'B', 'lat': 59.35, 'lng': 18.07},
          'stops': 0,
          'distanceMeters': 8000,
          'durationSeconds': 1080,
          'earnings': m(c.total - c.pickup).toJson(),
          'status': 'accepted',
          'mustBeOnlineAt': '2026-11-20T13:00:00Z',
          'canStartAt': '2026-11-20T13:00:00Z',
        }).toPreview(dayWord: (_) => 'Today', pickupLabel: (t) => 'Today $t');
        final ReservationRequestPreview p = preview;
        final offer = RideOffer.reservation(p, started: trip);
        expect(offer.pickupPay, m(c.pickup));
        expect(offer.driverBonus, m(c.bonus));
      });

      test('finish: the waybill lines become the server projection\'s', () {
        final money = LiveTripMoney.tryParse({
          'fare': m(c.total * 2).toJson(),
          'driverEarnings': m(c.total - c.pickup - c.bonus).toJson(),
          'pickupPay': m(c.pickup).toJson(),
          'driverBonus': m(c.bonus).toJson(),
          'driverTotal': m(c.total).toJson(),
        })!;
        final record = _record(bonus: 'old', pickupPay: 'old').withServerLines(
          driverBonus: money.driverBonus,
          pickupPay: money.pickupPay,
        );
        expect(record.driverBonus, m(c.bonus).formattedShort);
        expect(record.pickupPay, m(c.pickup).formattedShort);
        final cleared = record.withServerLines();
        expect(cleared.driverBonus, isNull);
        expect(cleared.pickupPay, isNull);
      });

      testWidgets('waybill shows the bonus and pickup pay rows', (
        tester,
      ) async {
        await _openWaybill(
          tester,
          _record(
            bonus: WaybillRecord.bonusLabel(m(c.bonus)),
            pickupPay: WaybillRecord.bonusLabel(m(c.pickup)),
          ),
        );
        expect(_row(tester, 'Bonus'), m(c.bonus).formattedShort);
        expect(_row(tester, 'Pickup'), m(c.pickup).formattedShort);
      });
    });
  }

  testWidgets('no bonus or pickup pay rows without the server lines', (
    tester,
  ) async {
    await _openWaybill(tester, _record());
    expect(_row(tester, 'Bonus'), isNull);
    expect(_row(tester, 'Pickup'), isNull);
  });
}
