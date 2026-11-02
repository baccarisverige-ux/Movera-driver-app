import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/ratings/rider_rating.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/support/server_support_tickets.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride completed/ride_completed.dart';
import 'package:movera/presentation/driver/support/live_support_inbox.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.9.0 §16 (owner, part 3): the driver rates the rider with
/// stars, tags from the fixed list and an optional comment; help requests
/// are support tickets on the server, and Movera's answer shows here.
typedef _Seen = List<http.Request>;

ApiClient _api(_Seen seen, http.Response Function(http.Request) answer) {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  return ApiClient(
    client: MockClient((request) async {
      seen.add(request);
      return answer(request);
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object> _ticket(String id, String status, {bool answer = false}) =>
    {
      'ticketId': id,
      'openedBy': 'driver',
      'driverId': 'd1',
      'category': 'payment',
      'subject': 'Utbetalning',
      'status': status,
      'priority': 'normal',
      'createdAt': '2026-10-27T08:00:00Z',
      'updatedAt': '2026-10-27T09:00:00Z',
      'lastMessageAt': '2026-10-27T09:00:00Z',
      'messages': [
        {
          'messageId': 'm1',
          'from': 'driver',
          'text': 'Var är veckan?',
          'at': '2026-10-27T08:00:00Z',
        },
        if (answer)
          {
            'messageId': 'm2',
            'from': 'support',
            'text': 'Den kommer måndag.',
            'at': '2026-10-27T09:00:00Z',
            'adminName': 'Ada',
          },
      ],
    };

void main() {
  group('rider rating body', () {
    test('stars only, tags and a trimmed comment', () {
      expect(RiderRatingSender.body(stars: 4), {'stars': 4});
      expect(
        RiderRatingSender.body(
          stars: 5,
          tags: ['polite', 'on_time'],
          comment: '  Tack  ',
        ),
        {
          'stars': 5,
          'tags': ['polite', 'on_time'],
          'comment': 'Tack',
        },
      );
    });

    test('refuses what the server would refuse', () {
      expect(() => RiderRatingSender.body(stars: 0), throwsArgumentError);
      expect(() => RiderRatingSender.body(stars: 6), throwsArgumentError);
      expect(
        () => RiderRatingSender.body(stars: 3, tags: ['clean_car']),
        throwsArgumentError,
      );
      expect(
        () => RiderRatingSender.body(stars: 3, tags: ['polite', 'polite']),
        throwsArgumentError,
      );
      expect(
        () => RiderRatingSender.body(stars: 3, comment: 'x' * 2001),
        throwsArgumentError,
      );
    });

    test(
      'send posts to the trip; demo sends nothing; a failure says failed',
      () async {
        final seen = <http.Request>[];
        final ok = RiderRatingSender(
          api: _api(seen, (_) => _json({'ok': true})),
        );
        expect(
          await ok.send(tripId: 'trp_1', stars: 4, tags: ['clear_pickup']),
          RiderRatingOutcome.sent,
        );
        expect(seen.single.url.path, '/api/v1/trips/trp_1/rating');
        expect(jsonDecode(seen.single.body), {
          'stars': 4,
          'tags': ['clear_pickup'],
        });
        expect(
          seen.single.headers['Idempotency-Key'] ??
              seen.single.headers['idempotency-key'],
          startsWith('rating-'),
        );
        expect(
          await RiderRatingSender().send(tripId: 'trp_1', stars: 4),
          RiderRatingOutcome.demo,
        );
        final bad = RiderRatingSender(
          api: _api(
            <http.Request>[],
            (_) => _json({
              'error': {'code': 'conflict'},
            }, 409),
          ),
        );
        expect(
          await bad.send(tripId: 'trp_1', stars: 4),
          RiderRatingOutcome.failed,
        );
      },
    );

    test('every tag has words', () {
      for (final tag in RiderRatingTags.aboutRider) {
        expect(RiderRatingTags.label(tag), isNot(tag));
      }
    });
  });

  group('server tickets', () {
    test('open, mine and one', () async {
      final seen = <http.Request>[];
      final tickets = ServerSupportTickets(
        api: _api(seen, (request) {
          if (request.method == 'POST') {
            return _json(_ticket('tkt_1', 'open'), 201);
          }
          if (request.url.path.endsWith('/tkt_1')) {
            return _json(_ticket('tkt_1', 'pending', answer: true));
          }
          return _json({
            'items': [_ticket('tkt_1', 'pending')],
            'nextCursor': null,
          });
        }),
      );
      final opened = await tickets.open(
        category: 'payment',
        subject: ' Utbetalning ',
        text: ' Var är veckan? ',
      );
      expect(opened.id, 'tkt_1');
      expect(seen.first.url.path, '/api/v1/support/tickets');
      expect(jsonDecode(seen.first.body), {
        'category': 'payment',
        'subject': 'Utbetalning',
        'text': 'Var är veckan?',
      });
      expect((await tickets.mine()).single.status, 'pending');
      final one = await tickets.one('tkt_1');
      expect(one.messages.last.fromSupport, isTrue);
      expect(one.messages.last.adminName, 'Ada');
    });

    test('app categories map to the contract list', () {
      expect(ServerSupportTickets.categoryOf('Wallet & payments'), 'payment');
      expect(ServerSupportTickets.categoryOf('Account & documents'), 'account');
      expect(ServerSupportTickets.categoryOf('Something else'), 'other');
      expect(ServerSupportTickets.categoryOf('Trip & rider'), 'help');
    });
  });

  testWidgets('live inbox lists, writes and shows Movera\'s answer', (
    tester,
  ) async {
    final seen = <http.Request>[];
    var list = <Object>[];
    final tickets = ServerSupportTickets(
      api: _api(seen, (request) {
        if (request.method == 'POST') {
          list = [_ticket('tkt_1', 'open')];
          return _json(_ticket('tkt_1', 'open'), 201);
        }
        if (request.url.path.endsWith('/tkt_1')) {
          return _json(_ticket('tkt_1', 'pending', answer: true));
        }
        return _json({'items': list, 'nextCursor': null});
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: LiveSupportInbox(tickets: tickets)),
    );
    await tester.pumpAndSettle();
    expect(find.text(liveTicketStatus('x')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('live-ticket-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('live-ticket-send')));
    await tester.pumpAndSettle();
    expect(seen.where((r) => r.method == 'POST'), isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('live-ticket-subject')),
      'Utbetalning',
    );
    await tester.enterText(
      find.byKey(const ValueKey('live-ticket-message')),
      'Var är veckan?',
    );
    await tester.tap(find.byKey(const ValueKey('live-ticket-send')));
    await tester.pumpAndSettle();
    expect(
      jsonDecode(seen.firstWhere((r) => r.method == 'POST').body)['category'],
      'ride_dispute',
    );
    expect(find.byKey(const ValueKey('live-ticket-tkt_1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-ticket-tkt_1')));
    await tester.pumpAndSettle();
    expect(find.text('Den kommer måndag.'), findsOneWidget);
  });

  group('v0.18.15 support desk (owner QO-1, QO-2, QO-4)', () {
    test('write again on a ticket, and the topics that are on', () async {
      final seen = <http.Request>[];
      final tickets = ServerSupportTickets(
        api: _api(seen, (request) {
          if (request.url.path.endsWith('/topics')) {
            return _json({
              'country': 'SE',
              'topics': ['help', 'payment', 'made_up'],
            });
          }
          return _json(_ticket('tkt_1', 'open', answer: true), 201);
        }),
      );
      final next = await tickets.write('tkt_1', ' Tack! ');
      expect(seen.last.url.path, '/api/v1/support/tickets/tkt_1/messages');
      expect(jsonDecode(seen.last.body), {'text': 'Tack!'});
      expect(next.status, 'open');
      expect(await tickets.topics(), ['help', 'payment']);
    });

    test('an older server without topics gives all seven', () async {
      final tickets = ServerSupportTickets(
        api: _api(<http.Request>[], (_) => _json({}, 404)),
      );
      expect(await tickets.topics(), supportTopics);
      expect(supportTopics, hasLength(7));
    });

    test('the agent line: first name · Movera Support, never an e-mail', () {
      expect(
        supportSenderLine(
          const ServerTicketMessage(
            fromSupport: true,
            text: 'x',
            supportName: 'Ada',
          ),
        ),
        tr.supportAgentLine('Ada'),
      );
      expect(
        supportSenderLine(
          const ServerTicketMessage(
            fromSupport: true,
            text: 'x',
            adminName: 'ada@movera.se',
          ),
        ),
        tr.supportMovera,
      );
    });

    testWidgets('the driver answers in the ticket; a closed one has no box', (
      tester,
    ) async {
      final seen = <http.Request>[];
      var status = 'pending';
      final tickets = ServerSupportTickets(
        api: _api(seen, (request) {
          if (request.method == 'POST') {
            status = 'open';
            return _json(_ticket('tkt_1', 'open', answer: true), 201);
          }
          if (request.url.path.endsWith('/tkt_1')) {
            return _json(_ticket('tkt_1', status, answer: true));
          }
          return _json({
            'items': [_ticket('tkt_1', status)],
            'nextCursor': null,
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: LiveSupportInbox(tickets: tickets)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-ticket-tkt_1')));
      await tester.pumpAndSettle();
      expect(find.text(tr.supportAgentLine('Ada')), findsNothing);
      expect(find.text(tr.supportMovera), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('live-ticket-reply')),
        'Tack, den kom.',
      );
      await tester.tap(find.byKey(const ValueKey('live-ticket-reply-send')));
      await tester.pumpAndSettle();
      final post = seen.lastWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/v1/support/tickets/tkt_1/messages');
      expect(jsonDecode(post.body), {'text': 'Tack, den kom.'});
      expect(find.text(liveTicketStatus('open')), findsOneWidget);
      status = 'closed';
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-ticket-tkt_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-ticket-closed')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-ticket-reply')), findsNothing);
    });
  });

  testWidgets('live inbox: a failed load offers retry', (tester) async {
    final tickets = ServerSupportTickets(
      api: _api(
        <http.Request>[],
        (_) => _json({
          'error': {'code': 'internal'},
        }, 500),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: LiveSupportInbox(tickets: tickets)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsOneWidget);
  });

  group('ride completed sends the rating on Done', () {
    setUp(InMemoryWaybillRepository.instance.reset);
    tearDown(InMemoryWaybillRepository.instance.reset);

    testWidgets('stars, a tag and a comment go to the trip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final session = DriverSessionController(initialOnline: true);
      addTearDown(session.dispose);
      session.beginTrip('trp_9');
      final repository = InMemoryWaybillRepository.instance;
      repository.beginCurrent(
        WaybillRecord(
          tripId: 'trp_9',
          statusLabel: WaybillRecord.nextTripSecured,
          issuedAt: DateTime(2026, 10, 27),
          fare: '128,40 kr',
          service: 'Comfort',
          riderName: 'Ida',
          pickup: 'Stockholm',
          dropoff: 'Solna',
          source: WaybillRecord.demoRadarSource,
          driverName: 'Ali',
          vehicle: 'Car',
          licensePlate: 'ABC 123',
          passengerCapacity: 4,
        ),
      );
      repository.completeCurrent();
      final seen = <http.Request>[];
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home owner')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => DriverRideCompleted(
            sessionController: session,
            waybillRepository: repository,
            ratingSender: RiderRatingSender(
              api: _api(seen, (_) => _json({'ok': true})),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rider-rating-tags')), findsNothing);
      await tester.tap(find.byType(RatingBar).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rider-rating-tag-polite')));
      await tester.enterText(
        find.byKey(const ValueKey('rider-rating-comment')),
        'Trevlig',
      );
      await tester.pumpAndSettle();
      final done = find.byType(FilledButton).last;
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(seen.single.url.path, '/api/v1/trips/trp_9/rating');
      final body = jsonDecode(seen.single.body) as Map;
      expect(body['tags'], ['polite']);
      expect(body['comment'], 'Trevlig');
      expect(body['stars'], inInclusiveRange(1, 5));
      expect(find.text('Home owner'), findsOneWidget);
    });
  });
}
