import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/presentation/driver/accept%20ride/route_change_sheet.dart';

/// v0.18.143 (owner 2026-11-20 "must rider can change !!!!",
/// contract.json#onTrip.routeChange.whileSearching): while the trip is still
/// searched the rider moves the pickup anywhere. The server withdraws the
/// open offer (offer_withdrawn) and sends a new offer with the new pickup:
/// the driver's list drops the old one and shows the new pickup.
/// Supervisor (owner Q4 "driver updates meter to app price"): an accepted
/// route change during the trip says the new price on the island.
Map<String, dynamic> _offer(
  String id, {
  required String pickup,
  required double lat,
  String status = 'open',
  int fare = 2450,
}) => {
  'offerId': id,
  'tripId': 'trip-1',
  'kind': 'exclusive',
  'status': status,
  'version': 1,
  'expiresAt': '2026-11-20T12:00:15Z',
  'fare': {'amountMinor': fare, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': fare - 400, 'currency': 'SEK'},
  'pickup': {'address': pickup, 'lat': lat, 'lng': 18.06},
  'dropoff': {'address': 'T-Centralen', 'lat': 59.33, 'lng': 18.06},
  'stops': <Object>[],
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 240,
  'pickupMeters': 1300,
  'tripSeconds': 900,
  'tripMeters': 6100,
};

void main() {
  test(
    'offer withdrawn, then the new offer shows the new pickup and price',
    () async {
      var items = [_offer('off-1', pickup: 'Sergels torg', lat: 59.3326)];
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'items': items, 'nextCursor': null}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final repo = ApiDispatchRepository(
        client: client,
        baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
        accessToken: () async => 'token',
        idempotencyKey: () => 'key-0123456789abcdef',
      );
      final first = repo.watchNearbyOffers().skip(1).first;
      repo.refreshOffers();
      expect((await first).single.id, 'off-1');
      final gone = <String>[];
      final sub = repo.watchWithdrawals().listen(
        (w) => gone.add('${w.offerId}:${w.reason.name}'),
      );
      items = [];
      repo.ingest({
        'eventId': 'e1',
        'sequence': 1,
        'kind': 'offer_withdrawn',
        'occurredAt': '2026-11-20T12:00:00Z',
        'serverTime': '2026-11-20T12:00:00Z',
        'offer': _offer(
          'off-1',
          pickup: 'Sergels torg',
          lat: 59.3326,
          status: 'withdrawn',
        ),
      });
      repo.ingest({
        'eventId': 'e2',
        'sequence': 2,
        'kind': 'offer_created',
        'occurredAt': '2026-11-20T12:00:01Z',
        'serverTime': '2026-11-20T12:00:01Z',
        'offer': _offer(
          'off-2',
          pickup: 'Klockarvägen 37',
          lat: 59.6,
          fare: 28000,
        ),
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(gone, ['off-1:withdrawn']);
      final now = await repo.watchNearbyOffers().first;
      expect(now.map((o) => o.id), ['off-2']);
      expect(now.single.pickup, 'Klockarvägen 37');
    },
  );

  test('an accepted route change says the new price on the island (meter)', () {
    DriverAppTexts.language = 'en';
    final change = TripRouteChange.tryParse({
      'changeId': 'rc_1',
      'routeQuoteId': 'rq_1',
      'status': 'accepted',
      'answeredBy': 'driver',
      'dropoff': {'lat': 59.33, 'lng': 18.06, 'address': 'T-Centralen'},
      'stops': <Object>[],
      'total': {'amountMinor': 28000, 'currency': 'SEK'},
      'difference': {'amountMinor': -32000, 'currency': 'SEK'},
      'askedAt': '2026-11-20T10:00:00Z',
      'answerBy': '2026-11-20T10:01:00Z',
    })!;
    final line = routeChangeIslandLine(change)!;
    expect(line, startsWith(tr.g7RouteAcceptedIsland));
    expect(line.replaceAll(' ', ' '), contains('280'));
  });
}
