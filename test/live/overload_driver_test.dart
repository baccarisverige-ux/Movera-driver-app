// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

/// Fix plan 2026-11-13 (supervisor 4, driver): how the driver app behaves
/// when the server is overloaded (G34 load tests: answers late by up to
/// the 10 s pool wait). D1: a lost Accept whose checks are answered late
/// still opens the trip the server gave him. A fake server only.

final _base = Uri.parse('https://api.test.movera.invalid/api/v1');

Map<String, dynamic> _offer({
  String id = 'o1',
  String status = 'open',
  required DateTime expiresAt,
}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': 'exclusive',
  'status': status,
  'version': 1,
  'expiresAt': expiresAt.toUtc().toIso8601String(),
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'A', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'B', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A stopwatch that reads fake time.
class _FakeWatch implements Stopwatch {
  _FakeWatch(this._async);
  final FakeAsync _async;
  Duration _from = Duration.zero;

  @override
  void start() => _from = _async.elapsed;

  @override
  Duration get elapsed => _async.elapsed - _from;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('a lost Accept answer on a busy server', () {
    // The server took the Accept, but answers only after 9 s (its pool
    // queue; acceptAnswerTimeout is 8 s). Each "did my accept go through?"
    // check is answered after 3 s (busy, but well inside the 20 s window).
    test('a check answered after 3 s still opens the trip (it is his)', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 13, 12);
        DateTime now() => start.add(async.elapsed);
        final sent = <String>[];
        late ApiDispatchRepository repo;
        repo = ApiDispatchRepository(
          client: MockClient((request) async {
            sent.add('${request.method} ${request.url.path}');
            final path = request.url.path;
            if (path.endsWith('/driver/offers')) {
              return _json({
                'items': [
                  _offer(expiresAt: start.add(const Duration(seconds: 15))),
                ],
                'nextCursor': null,
              });
            }
            if (path.endsWith('/accept')) {
              await Future<void>.delayed(const Duration(seconds: 9));
              return _json({'tripId': 'trip-o1', 'status': 'driver_to_pickup'});
            }
            // GET /driver/offers/o1: OfferCheck, claimed with his trip.
            await Future<void>.delayed(const Duration(seconds: 3));
            return _json({
              'offer': _offer(
                status: 'claimed',
                expiresAt: start.add(const Duration(seconds: 15)),
              ),
              'trip': {'tripId': 'trip-o1', 'status': 'driver_to_pickup'},
            });
          }),
          baseUri: _base,
          accessToken: () async => 'token',
          now: now,
          stopwatch: () => _FakeWatch(async),
        );
        repo.refreshOffers();
        async.flushMicrotasks();

        ClaimResult? result;
        repo.claimOffer('o1').then((value) => result = value);
        async.elapse(const Duration(seconds: 40));

        expect(result, isNotNull);
        expect(
          result!.outcome,
          ClaimOutcome.success,
          reason:
              'the server claimed the offer for him; a 3 s answer to the '
              'check must not end as "No connection"',
        );
        final checks = sent
            .where((s) => s == 'GET /api/v1/driver/offers/o1')
            .length;
        expect(
          checks,
          lessThanOrEqualTo(2),
          reason: 'no pile of abandoned checks on a busy server',
        );
        repo.dispose();
      });
    });
  });
}
