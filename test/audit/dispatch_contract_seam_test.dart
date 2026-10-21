import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Audit round 4, the dispatch contract seam (`ApiDispatchRepository`,
// `OfferWire`) and the config readers: driver-r4-4, driver-r4-2,
// driver-r4-26, driver-r4-6, driver-r4-8.

/// Contract `Offer` (openapi.yaml#Offer).
Map<String, dynamic> _wire({
  String id = 'o1',
  String kind = 'radar',
  String source = 'system',
  String? reasonCode,
  String? expiresAt,
  String paymentMethod = 'card',
}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': kind,
  'status': 'open',
  'version': 1,
  'expiresAt': expiresAt ?? '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': source,
  if (reasonCode != null) 'reasonCode': reasonCode,
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': paymentMethod,
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

/// The contract adapter over a scripted server; every new
/// Idempotency-Key is a new number.
class _Api {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  final List<Object Function(http.BaseRequest request)> answers = [];
  var _keys = 0;

  /// Each request takes the next answer: an [http.Response], or an error
  /// to throw (a dropped connection).
  late final ApiDispatchRepository repo = ApiDispatchRepository(
    client: MockClient((request) async {
      requests.add(request);
      final answer = answers.removeAt(0)(request);
      if (answer is http.Response) return answer;
      throw answer;
    }),
    baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
    accessToken: () async => 'token',
    idempotencyKey: () => 'key-${++_keys}',
  );

  /// The open offers from GET /driver/offers.
  Future<void> open(List<Map<String, dynamic>> offers) async {
    answers.add((_) => _json({'items': offers, 'nextCursor': null}));
    final listed = repo.watchNearbyOffers().skip(1).first;
    repo.refreshOffers();
    await listed;
    requests.clear();
  }

  List<String?> get keys =>
      [for (final r in requests) r.headers['Idempotency-Key']];
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);
  final List<RideOffer> offers;
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(offers);
  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);
  @override
  void refreshOffers() {}
  @override
  void releaseReservation(String reservationId) {}
  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

Future<void> _until(WidgetTester tester, Finder finder, Duration limit) async {
  for (var t = Duration.zero;
      t < limit && finder.evaluate().isEmpty;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _online(WidgetTester tester, List<RideOffer> offers) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(LayoutViewport(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (_, __) => MaterialApp(
        home: DriverHome(
          sessionController: DriverSessionController(),
          dispatchRepository: _Dispatch(offers),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  group('driver-r4-4: Offer.kind, expiresAt and reasonCode', () {
    test('OfferWire keeps them', () {
      final offer = OfferWire.parse(_wire(
        kind: 'exclusive',
        reasonCode: 'nearby',
        expiresAt: '2026-10-20T12:00:15Z',
      ));
      expect(offer.kind, OfferKind.exclusive);
      expect(offer.reasonCode, 'nearby');
      expect(offer.expiresAt, DateTime.utc(2026, 10, 20, 12, 0, 15));
      expect(offer.isExclusive, isTrue);
      expect(OfferWire.parse(_wire()).isExclusive, isFalse);
    });

    testWidgets('a system kind=exclusive offer is the Exclusive sheet, '
        'with its reason', (tester) async {
      // The server lets it go in 8 s, not the app's 15 s.
      final expires = DateTime.now().add(const Duration(seconds: 8));
      await _online(tester, [
        OfferWire.parse(_wire(
          kind: 'exclusive',
          reasonCode: 'favourite',
          expiresAt: expires.toUtc().toIso8601String(),
        )),
      ]);
      final card = find.byKey(const ValueKey<String>('exclusive-offer-card-o1'));
      await _until(tester, card, const Duration(seconds: 5));
      expect(card, findsOneWidget);
      expect(find.byKey(const ValueKey<String>('radar-offer-card-o1')),
          findsNothing);
      expect(find.textContaining(RegExp(r"Rider's favourite · [0-8] s")),
          findsWidgets);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('driver-r4-2: a retried offer command keeps its Idempotency-Key', () {
    test('Accept again after no answer is the same command', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers
        ..add((_) => http.ClientException('connection dropped'))
        ..add((_) => _json({'tripId': 'trip-o1', 'status': 'accepted'}));
      expect((await api.repo.claimOffer('o1')).outcome,
          ClaimOutcome.networkError);
      expect((await api.repo.claimOffer('o1')).isSuccess, isTrue);
      expect(api.keys, ['key-1', 'key-1']);
    });

    test('a new version or a new answer is a new command', () async {
      final api = _Api();
      await api.open([_wire(), _wire(id: 'o2')]);
      api.answers
        ..add((_) => _json({
              'code': 'version_mismatch',
              'projection': {..._wire(), 'version': 2},
            }, 409))
        ..add((_) => _json({'tripId': 'trip-o1', 'status': 'accepted'}))
        ..add((_) => _json({}, 503))
        ..add((_) => _json(_wire(id: 'o2')));
      expect((await api.repo.claimOffer('o1')).isSuccess, isTrue);
      expect(await api.repo.declineOffer('o2'), isFalse);
      expect(await api.repo.declineOffer('o2'), isTrue);
      expect(api.keys, ['key-1', 'key-2', 'key-3', 'key-3']);
    });
  });

  group('driver-r4-26: the offer feed', () {
    /// GET /driver/offers/stream: a 503 first, then live feeds the test
    /// writes to and ends.
    late List<http.BaseRequest> requests;
    late List<StreamController<List<int>>> feeds;
    late Completer<void> next;
    ApiDispatchRepository feedRepo() {
      requests = [];
      feeds = [];
      next = Completer<void>();
      return ApiDispatchRepository(
        client: MockClient.streaming((request, _) async {
          requests.add(request);
          if (!next.isCompleted) next.complete();
          if (requests.length == 1) {
            return http.StreamedResponse(
                Stream.value(utf8.encode('Service Unavailable')), 503);
          }
          final feed = StreamController<List<int>>();
          feeds.add(feed);
          return http.StreamedResponse(feed.stream, 200);
        }),
        baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
        accessToken: () async => 'token',
        reconnectDelay: (_) => Duration.zero,
      );
    }

    Future<void> request(int count) async {
      while (requests.length < count) {
        next = Completer<void>();
        await next.future;
      }
      // Let the response be read.
      await pumpEventQueue();
    }

    void send(StreamController<List<int>> feed, int sequence) =>
        feed.add(utf8.encode('id: $sequence\ndata: ${jsonEncode({
          'eventId': 'e$sequence',
          'sequence': sequence,
          'kind': 'offer_created',
          'offer': _wire(id: 'o$sequence'),
        })}\n\n'));

    test('an error answer, an ended or broken feed: it reconnects after the '
        'last sequence, and says when it is not live', () async {
      final repo = feedRepo();
      addTearDown(repo.dispose);
      final live = <bool>[];
      repo.watchFeedLive().listen(live.add);
      await repo.connect();
      // 503: nothing read, tried again.
      await request(2);
      expect(repo.feedLive, isTrue);
      send(feeds.last, 1);
      await pumpEventQueue();
      expect((await repo.watchNearbyOffers().first).map((o) => o.id), ['o1']);
      // The server ends the feed: back from sequence 1.
      await feeds.last.close();
      await request(3);
      expect(requests.last.url.queryParameters['after'], '1');
      // The connection breaks: no unhandled error, back again.
      feeds.last.addError(http.ClientException('connection reset'));
      await request(4);
      expect(requests.last.url.queryParameters['after'], '1');
      expect(live, [true, false, true, false, true]);
    });
  });

  test('driver-r4-6: the v0.3 payment ids and wallet are not "Card"', () {
    String payment(String id) =>
        OfferWire.parse(_wire(paymentMethod: id)).payment;
    expect(payment('apple'), 'Apple Pay');
    expect(payment('google'), 'Google Pay');
    expect(payment('wallet'), 'Wallet');
    expect(payment('cash'), 'Cash');
  });

  test('driver-r4-8: destinationMode.perDay and nextTrips.on are read', () {
    final json = jsonDecode(
      File('contracts/fixtures/config/driver_app_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    var config = DriverAppConfig.fromJson({
      ...json,
      'destinationMode': {'perDay': 1},
      'nextTrips': {'on': false},
    });
    expect(config.destinationMode.destinationsPerDay, 1);
    expect(config.nextTrips.offerTypes, isEmpty);
    config = DriverAppConfig.fromJson(json);
    expect(config.destinationMode.destinationsPerDay, 2);
    expect(config.nextTrips.offerTypes, isNotEmpty);
  });
}
