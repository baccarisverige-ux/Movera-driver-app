// Audit round 5, the low bugs (Wave 6b).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

void main() {
  test('driver-r5-8: admin\'s scheduled-rides "until" is a local time', () {
    final access = ScheduledRidesDriverAccess.fromJson(
        {'on': false, 'until': '2026-10-23T22:30:00Z'});
    expect(access.until!.isUtc, isFalse,
        reason: 'the notice formats its date: a UTC date can be a day early');
    expect(access.until!.isAtSameMomentAs(DateTime.utc(2026, 10, 23, 22, 30)),
        isTrue);
  });

  testWidgets('driver-r5-21: a stalled accept ends as a network error',
      (tester) async {
    final stalled = Completer<http.Response>();
    final repo = ApiDispatchRepository(
      client: MockClient((request) async => request.method == 'GET'
          ? http.Response(jsonEncode({'items': [_wireOffer], 'nextCursor': null}),
              200, headers: {'content-type': 'application/json'})
          : stalled.future),
      baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
      accessToken: () async => 'token',
    );
    final listed = repo.watchNearbyOffers().skip(1).first;
    repo.refreshOffers();
    await tester.runAsync(() => listed);
    ClaimResult? result;
    unawaited(repo.claimOffer('o1').then((r) => result = r));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(result?.outcome, ClaimOutcome.networkError,
        reason: 'before: the claim waited for the socket forever');
  });
}

/// Contract `Offer` (openapi.yaml#Offer).
const _wireOffer = {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};
