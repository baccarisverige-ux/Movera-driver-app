import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/money/money.dart';

/// Contract v0.4.0 `Offer` for an admin offer (§3.1).
Map<String, dynamic> _offer({
  String id = 'off-1',
  String trip = 'trip-1',
  int version = 3,
  String kind = 'assigned',
  String? groupId,
  String status = 'open',
}) => {
  'offerId': id,
  'tripId': trip,
  'kind': kind,
  'status': status,
  'version': version,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 2450, 'currency': 'EUR'},
  'driverEarnings': {'amountMinor': 2000, 'currency': 'EUR'},
  'driverBonus': {'amountMinor': 300, 'currency': 'EUR'},
  'priority': true,
  'source': 'admin',
  if (groupId != null) 'groupId': groupId,
  'pickup': {'address': 'Rue de Rivoli 1, Paris', 'lat': 48.86, 'lng': 2.34},
  'dropoff': {'address': 'Gare de Lyon, Paris', 'lat': 48.84, 'lng': 2.37},
  'stops': <Object>[],
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 240,
  'pickupMeters': 1300,
  'tripSeconds': 900,
  'tripMeters': 6100,
  'riderRating': 4.9,
  'riderTrips': 12,
};

class _Server {
  final List<http.Request> requests = <http.Request>[];
  http.Response Function(http.Request request) answer =
      (_) => http.Response('{}', 200);

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    return answer(request);
  });

  ApiDispatchRepository repository() => ApiDispatchRepository(
    client: client,
    baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
    accessToken: () async => 'token',
    idempotencyKey: () => 'key-0123456789abcdef',
  );
}

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<ApiDispatchRepository> _withOffers(
  _Server server,
  List<Map<String, dynamic>> offers,
) async {
  server.answer = (_) => _json({'items': offers, 'nextCursor': null}, 200);
  final repo = server.repository();
  final first = repo.watchNearbyOffers().skip(1).first;
  repo.refreshOffers();
  await first;
  server.requests.clear();
  return repo;
}

void main() {
  group('Demo dispatch (in process)', () {
    test('admin offers are claimed and declined through dispatch', () async {
      final demo = DemoDispatchRepository(
        claimDelay: Duration.zero,
        adminOffers: true,
      );
      addTearDown(demo.dispose);
      final claim = await demo.claimOffer(DemoAdminOffers.directAssign.id);
      expect(claim.isSuccess, isTrue);
      expect(claim.offer?.driverBonus, const Money(minorUnits: 3000));

      expect(await demo.declineOffer(DemoAdminOffers.radarGroup.id), isTrue);
      // Gone: a second No and an Accept both find nothing.
      expect(await demo.declineOffer(DemoAdminOffers.radarGroup.id), isFalse);
      expect(
        (await demo.claimOffer(DemoAdminOffers.radarGroup.id)).outcome,
        ClaimOutcome.unavailable,
      );
    });

    test('another driver of the group accepts first: withdrawn, then gone',
        () async {
      final demo = DemoDispatchRepository(
        adminOffers: true,
        groupRaceDelay: const Duration(milliseconds: 10),
      );
      addTearDown(demo.dispose);
      final order = <String>[];
      final gone = demo.watchWithdrawals().listen(
        (w) => order.add('withdrawn ${w.offerId} ${w.reason.name}'),
      );
      final lists = demo.watchNearbyOffers().listen((offers) {
        if (!offers.any((o) => o.id == DemoAdminOffers.radarGroupTaken.id)) {
          order.add('list without it');
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await gone.cancel();
      await lists.cancel();
      expect(order.take(2), [
        'withdrawn admin-group-2 claimedElsewhere',
        'list without it',
      ]);
    });
  });

  group('API dispatch (contract endpoints)', () {
    test('the open offers are read from GET /driver/offers', () async {
      final server = _Server();
      final repo = await _withOffers(server, [
        _offer(),
        _offer(id: 'off-2', trip: 'trip-2', kind: 'radar', groupId: 'g-1'),
      ]);
      final offers = await repo.watchNearbyOffers().first;
      expect(offers, hasLength(2));
      final direct = offers.first;
      expect(direct.isAdminDirectAssign, isTrue);
      expect(direct.tripId, 'trip-1');
      expect(direct.version, 3);
      expect(direct.fareLabel, '24,50 €');
      expect(direct.driverBonus, const Money(minorUnits: 300, currency: 'EUR'));
      expect(direct.isPriority, isTrue);
      expect(direct.category, 'Comfort');
      expect(offers.last.isRadarGroup, isTrue);
    });

    test('Accept is POST /offers/{id}/accept with the offer version', () async {
      final server = _Server();
      final repo = await _withOffers(server, [_offer()]);
      server.answer = (_) => _json({
        'tripId': 'trip-1',
        'status': 'accepted',
        'version': 4,
      }, 200);
      final result = await repo.claimOffer('off-1');
      expect(result.isSuccess, isTrue);
      expect(result.offer?.tripId, 'trip-1');
      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/offers/off-1/accept');
      expect(jsonDecode(request.body), {'expectedVersion': 3});
      expect(request.headers['Idempotency-Key'], 'key-0123456789abcdef');
      expect(request.headers['X-Api-Version'], '0.4');
      expect(request.headers['Authorization'], 'Bearer token');
      expect(await repo.watchNearbyOffers().first, isEmpty);
    });

    test('another driver won: 409 claimed_elsewhere is "already claimed"',
        () async {
      final server = _Server();
      final repo = await _withOffers(server, [
        _offer(kind: 'radar', groupId: 'g-1'),
      ]);
      final withdrawn = repo.watchWithdrawals().first;
      server.answer = (_) => _json({
        'code': 'conflict',
        'message': 'Taken',
        'requestId': 'r',
        'retryable': false,
        'projection': _offer(kind: 'radar', groupId: 'g-1', status: 'claimed_elsewhere'),
      }, 409);
      final result = await repo.claimOffer('off-1');
      expect(result.outcome, ClaimOutcome.alreadyClaimed);
      expect((await withdrawn).reason, OfferGoneReason.claimedElsewhere);
    });

    test('a stale version is retried once with the server version', () async {
      final server = _Server();
      final repo = await _withOffers(server, [_offer()]);
      var calls = 0;
      server.answer = (_) => ++calls == 1
          ? _json({
              'code': 'version_mismatch',
              'message': 'stale',
              'requestId': 'r',
              'retryable': false,
              'projection': _offer(version: 5),
            }, 409)
          : _json({'tripId': 'trip-1', 'status': 'accepted', 'version': 6}, 200);
      expect((await repo.claimOffer('off-1')).isSuccess, isTrue);
      expect(
        server.requests.map((r) => jsonDecode(r.body)['expectedVersion']),
        [3, 5],
      );
    });

    test('No is POST /offers/{id}/decline with the offer version', () async {
      final server = _Server();
      final repo = await _withOffers(server, [_offer()]);
      server.answer = (_) => _json(_offer(status: 'declined'), 200);
      expect(await repo.declineOffer('off-1'), isTrue);
      final request = server.requests.single;
      expect(request.url.path, '/api/v1/offers/off-1/decline');
      expect(jsonDecode(request.body), {'expectedVersion': 3});
      expect(request.headers['Idempotency-Key'], isNotNull);
      expect(await repo.watchNearbyOffers().first, isEmpty);
    });

    test('offer_withdrawn and assignment_locked take offers away', () async {
      final server = _Server();
      final repo = await _withOffers(server, [
        _offer(kind: 'radar', groupId: 'g-1'),
        _offer(id: 'off-2', trip: 'trip-2', kind: 'radar', groupId: 'g-2'),
      ]);
      final reasons = <String>[];
      final sub = repo.watchWithdrawals().listen(
        (w) => reasons.add('${w.offerId}:${w.reason.name}'),
      );
      repo.ingest({
        'eventId': 'e1',
        'sequence': 1,
        'kind': 'offer_withdrawn',
        'occurredAt': '2026-10-20T12:00:00Z',
        'serverTime': '2026-10-20T12:00:00Z',
        'offer': _offer(kind: 'radar', groupId: 'g-1', status: 'claimed_elsewhere'),
      });
      // A replay of the same sequence changes nothing.
      repo.ingest({
        'eventId': 'e1',
        'sequence': 1,
        'kind': 'offer_created',
        'occurredAt': '2026-10-20T12:00:00Z',
        'serverTime': '2026-10-20T12:00:00Z',
        'offer': _offer(kind: 'radar', groupId: 'g-1'),
      });
      repo.ingest({
        'eventId': 'e2',
        'sequence': 2,
        'kind': 'assignment_locked',
        'tripId': 'trip-2',
        'occurredAt': '2026-10-20T12:00:01Z',
        'serverTime': '2026-10-20T12:00:01Z',
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(reasons, ['off-1:claimedElsewhere', 'off-2:claimedElsewhere']);
      expect(await repo.watchNearbyOffers().first, isEmpty);
      expect(repo.lastSequence, 2);
    });
  });

  test('offer reasons read from the wire', () {
    expect(OfferGoneReason.fromWire('claimed_elsewhere'),
        OfferGoneReason.claimedElsewhere);
    expect(OfferGoneReason.fromWire('expired'), OfferGoneReason.expired);
    expect(OfferGoneReason.fromWire('withdrawn'), OfferGoneReason.withdrawn);
  });
}
