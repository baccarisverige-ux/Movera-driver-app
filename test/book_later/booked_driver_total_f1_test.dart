import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

/// BQ-F1 (owner R2: the apps never work money out; Rules
/// audits/impact/m23-booked-drivertotal-supervisor.md F1). A booked ride
/// shows the server's driverTotal (earnings + pickup pay + Movera's bonus)
/// or "—":
/// - Accepted for later: the row is the claim's `Offer.driverTotal`, then
///   the row's `DriverReservation.driverTotal` after a resync; the phone
///   never adds the pickup pay to it (`ScheduledRideStore._withPay`).
/// - "Leave now": the trip opens with that server total once. The pickup
///   pay kept at accept is not added on top of a total that already has
///   it, and `RideOffer.reservation` no longer drops Movera's bonus by
///   falling back to `earnings`.
const _leg = PickupLeg(km: 3.5, minutes: 8);

Money _sek(int minor) => Money(minorUnits: minor, currency: 'SEK');
Money _tnd(int minor) => Money(minorUnits: minor, currency: 'TND');

Map<String, dynamic> _row(
  String tripId, {
  required Money earnings,
  Money? driverTotal,
  String status = 'accepted',
}) => {
  'tripId': tripId,
  'version': 3,
  'scheduledAt': '2026-11-20T14:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': 'Sergels torg', 'lat': 59.33, 'lng': 18.06},
  'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.31, 'lng': 18.07},
  'stops': 0,
  'distanceMeters': 8000,
  'durationSeconds': 1080,
  'earnings': earnings.toJson(),
  'driverTotal': ?driverTotal?.toJson(),
  'status': status,
  'mustBeOnlineAt': '2026-11-20T13:00:00Z',
  'canStartAt': '2026-11-20T13:00:00Z',
};

ReservationRequestPreview _preview(String tripId, Money earnings) =>
    ServerReservation.fromJson(
      _row(tripId, earnings: earnings),
    ).toPreview(dayWord: (_) => 'Today', pickupLabel: (t) => 'Today $t');

PersistedActiveRide _started(String tripId, Money total, Money bonus) =>
    PersistedActiveRide(
      tripId: tripId,
      stage: ActiveRideStage.headingToPickup,
      fare: total.formatted,
      driverBonus: bonus,
    );

LiveReservations _live(
  List<Map<String, dynamic>> accepted, {
  List<Map<String, dynamic>> open = const [],
}) => LiveReservations(
  api: ApiClient(
    client: MockClient((request) async {
      final isAccepted = request.url.query.contains('accepted');
      return http.Response(
        jsonEncode({'items': isAccepted ? accepted : open, 'nextCursor': null}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
  ),
);

void main() {
  setUp(ScheduledRideStore.reset);
  tearDown(() {
    ScheduledRideStore.reset();
    Money.forgetZone();
  });

  group('Leave now on a started booked ride: the server total, once', () {
    test('SEK: 250,00 kr stays 250,00 kr with 13,95 kr pickup pay kept', () {
      final offer = RideOffer.reservation(
        _preview('trp_sek', _sek(19950)),
        started: _started('trp_sek', _sek(25000), _sek(3000)),
      );
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: offer.driverPayLabel,
        serverTotal: offer.driverTotal,
        acceptedPickupPay: _sek(1395),
        driverBonus: offer.driverBonus,
        leg: _leg,
        live: true,
      );
      // Before: 250,00 kr + 13,95 kr = 263,95 kr (pickup pay twice).
      expect(terms.fare, '250,00 kr');
      expect(offer.driverTotal, _sek(25000));
    });

    test('TND: 15.000 DT stays 15.000 DT with 1.250 DT pickup pay kept', () {
      Money.zoneCurrency = 'TND';
      final offer = RideOffer.reservation(
        _preview('trp_tnd', _tnd(12350)),
        started: _started('trp_tnd', _tnd(15000), _tnd(1400)),
      );
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: offer.driverPayLabel,
        serverTotal: offer.driverTotal,
        acceptedPickupPay: _tnd(1250),
        driverBonus: offer.driverBonus,
        leg: _leg,
        live: true,
      );
      // Before: 15.000 DT + 1.250 DT = 16.250 DT.
      expect(terms.fare, '15.000 DT');
      expect(offer.driverTotal, _tnd(15000));
    });
  });

  group('Accepted for later: the claim result Offer.driverTotal', () {
    test('SEK: the row shows the claim total, no pickup pay added on the '
        'phone, and Leave now opens with it', () {
      ScheduledRideStore.take(
        demoReservationId,
        upcoming: true,
        pickupPay: _sek(1395),
        driverTotal: _sek(25000),
      );
      expect(
        ScheduledRideStore.acceptedPriceOf(demoReservationId),
        '250,00 kr',
      );
      expect(
        ScheduledRideStore.acceptedDriverTotal(demoReservationId),
        _sek(25000),
      );
      final offer = RideOffer.reservation(
        ScheduledRideStore.routeOf(demoReservationId)!,
        driverTotal: ScheduledRideStore.acceptedDriverTotal(demoReservationId),
      );
      expect(offer.driverTotal, _sek(25000));
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: offer.driverPayLabel,
        serverTotal: offer.driverTotal,
        acceptedPickupPay: ScheduledRideStore.acceptedPickupPay(
          demoReservationId,
        ),
        driverBonus: offer.driverBonus,
        leg: _leg,
        live: true,
      );
      expect(terms.fare, '250,00 kr');
    });

    test('TND: an assigned ride shows 15.000 DT, never 12.350 + 1.250 DT', () {
      Money.zoneCurrency = 'TND';
      final ride = _preview('trp_tnd_assigned', _tnd(12350));
      ScheduledRideStore.acceptAssigned(
        ride,
        pickupPay: _tnd(1250),
        driverTotal: _tnd(15000),
      );
      // Before: _withPay made 13.600 DT on the phone (earnings without
      // Movera's bonus, plus the pickup pay).
      expect(ScheduledRideStore.acceptedPriceOf(ride.id), '15.000 DT');
      expect(ScheduledRideStore.acceptedDriverTotal(ride.id), _tnd(15000));
    });
  });

  group('Live without a server total: "—", never worked out', () {
    test('SEK', () {
      expect(
        ScheduledRideStore.priceAfterAccept(
          '199,50 kr',
          pickupPay: _sek(1395),
          live: true,
        ),
        '—',
      );
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: '199,50 kr',
        acceptedPickupPay: _sek(1395),
        leg: _leg,
        live: true,
      );
      expect(terms.fare, '—');
    });

    test('TND', () {
      Money.zoneCurrency = 'TND';
      expect(
        ScheduledRideStore.priceAfterAccept(
          '12.350 DT',
          pickupPay: _tnd(1250),
          live: true,
        ),
        '—',
      );
      final terms = PickupPayQuote.leaveNowTermsOf(
        fare: '12.350 DT',
        acceptedPickupPay: _tnd(1250),
        leg: _leg,
        live: true,
      );
      expect(terms.fare, '—');
    });

    test('the demo keeps its own written-out sample (unchanged)', () {
      expect(
        ScheduledRideStore.priceAfterAccept(
          '199,50 kr',
          pickupPay: _sek(1395),
          live: false,
        ),
        '213,45 kr',
      );
    });
  });

  testWidgets('after a resync the row driverTotal wins (SEK and TND)', (
    tester,
  ) async {
    ScheduledRideStore.acceptAssigned(
      _preview('trp_sek_row', _sek(19950)),
      pickupPay: _sek(1395),
      driverTotal: _sek(23000),
    );
    final live = _live([
      _row('trp_sek_row', earnings: _sek(19950), driverTotal: _sek(22450)),
      _row('trp_tnd_row', earnings: _tnd(12350), driverTotal: _tnd(15000)),
    ]);
    await tester.runAsync(() => ScheduledRideStore.syncFromServer(live));
    // The server's newer number (e.g. an admin pay change), not the claim's.
    expect(ScheduledRideStore.acceptedDriverTotal('trp_sek_row'), _sek(22450));
    expect(ScheduledRideStore.acceptedDriverTotal('trp_tnd_row'), _tnd(15000));
  });

  // Supervisor should-fix 1 (audits/impact/f1-f2bc-driver-supervisor.md):
  // right after a take, before the next resync, the OPEN row's pre-accept
  // total (no pickup pay) must not win over the claim's total.
  for (final (label, open, claim, pay) in [
    ('SEK', _sek(20000), _sek(21395), _sek(1395)),
    ('TND', _tnd(12000), _tnd(13250), _tnd(1250)),
  ]) {
    testWidgets('$label: taken from the open list, the claim total wins over '
        'the open row', (tester) async {
      final id = 'trp_open_$label';
      final live = _live(
        const [],
        open: [
          _row(id, earnings: open, driverTotal: open, status: 'requested'),
        ],
      );
      await tester.runAsync(() => ScheduledRideStore.syncFromServer(live));
      expect(ScheduledRideStore.routeOf(id), isNotNull);
      ScheduledRideStore.take(
        id,
        upcoming: true,
        pickupPay: pay,
        driverTotal: claim,
      );
      expect(ScheduledRideStore.acceptedPriceOf(id), claim.formatted);
      expect(ScheduledRideStore.acceptedDriverTotal(id), claim);
    });
  }
}
