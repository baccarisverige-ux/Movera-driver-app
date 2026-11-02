import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/ride/pickup_pin.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept%20ride/pickup_pin_sheet.dart';

/// Driver group 6 (contract v0.18.8 `arrivedWaiting`): the server's waiting
/// rules only, the rider's PIN before Start, one-off island alerts and the
/// free wait at each stop.
void main() {
  tearDown(() {
    DriverAppTexts.language = 'en';
    WaitingRules.current = const WaitingRules();
  });

  Map<String, dynamic> terms({
    List<Object> rules = const [],
    int stopFree = 0,
    String currency = 'SEK',
  }) => {
    'currency': currency,
    'freeWaitMin': 15,
    'noShowAfterMin': 20,
    'waitPerMin': {'amountMinor': 1226, 'currency': currency},
    'noShowFee': {'amountMinor': 6500, 'currency': currency},
    'noShowDriverSharePct': 80,
    'waitingRules': rules,
    'stopFreeWaitMin': stopFree,
  };

  group('1. the server\'s waiting numbers only', () {
    test('trip terms carry the server rules and the stop free wait', () {
      final live = TripLiveDetails.fromProjection({
        'tripId': 't1',
        'status': 'arrived',
        'version': 4,
        'terms': terms(rules: ['airport', 'nonsense', 7], stopFree: 3),
      });
      expect(live.terms!.waiting.freeMinutes, 15);
      expect(live.terms!.waiting.noShowAfterMinutes, 20);
      expect(live.terms!.waiting.ruleLabels, ['airport']);
      expect(live.terms!.stopFreeWaitMinutes, 3);
    });

    test('an older trip without the new fields keeps 0 and no rule', () {
      final old = terms()
        ..remove('waitingRules')
        ..remove('stopFreeWaitMin');
      final parsed = TripTerms.tryParse(old)!;
      expect(parsed.stopFreeWaitMinutes, 0);
      expect(parsed.waiting.rule, '');
    });

    test('waiting.rules and alerts are read from the projection', () {
      final waiting = TripWaitingNow.tryParse({
        'arrivedAt': '2026-11-01T10:00:00Z',
        'freeUntil': '2026-11-01T10:01:00Z',
        'rules': ['far_pickup', 'event'],
        'alerts': [
          {'kind': 'paid_waiting_started', 'at': '2026-11-01T10:01:00Z'},
          {'kind': 'unknown', 'at': '2026-11-01T10:02:00Z'},
        ],
      })!;
      expect(waiting.rules, ['far_pickup', 'event']);
      expect(waiting.alerts, {TripWaitingNow.paidWaitingStarted});
      expect(TripWaitingNow.tryParse({})!.rules, isNull);
    });

    for (final (language, airport, far) in [
      ('sv', 'Hämtning på flygplats', 'Upphämtning över 7,5 km bort'),
      (
        'fr',
        'Prise en charge à l’aéroport',
        'Prise en charge à plus de 7,5 km',
      ),
      ('en', 'Airport pickup', 'Pickup over 7.5 km away'),
    ]) {
      test('rule labels in $language, far km from the served config', () {
        DriverAppTexts.language = language;
        DriverAppConfig.fromJson({
          'currency': 'SEK',
          'waiting': {
            'farPickup': {'on': true, 'km': 7.5},
          },
        }).apply();
        final shown = WaitingRules.current.termsFor().withRules(const [
          'airport',
          'far_pickup',
        ]);
        expect(shown.rule, '$airport · $far');
      });
    }

    test('the served far / airport rules never change the app\'s terms', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'EUR',
        'waiting': {
          'freeWaitMin': 5,
          'noShowAfterMin': 5,
          'perMin': {'amountMinor': 110, 'currency': 'EUR'},
          'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
          'farPickup': {'on': true, 'km': 5, 'freeWaitMin': 1},
          'rideTypes': {
            'airport': {'freeWaitMin': 15, 'noShowAfterMin': 20},
          },
        },
      });
      final terms = config.waiting.termsFor(category: 'economy');
      expect(terms.freeMinutes, 5);
      expect(terms.noShowAfterMinutes, 5);
      expect(terms.rule, '');
    });
  });

  group('2. the rider\'s PIN before Start', () {
    test('pin_wrong / pin_locked / pin_required in plain words', () {
      final wrong = PickupPinOutcome.fromError(
        const ApiError(
          code: 'invalid_request',
          message: 'x',
          reason: 'pin_wrong',
          statusCode: 400,
          details: ['attemptsLeft=2'],
        ),
      );
      final locked = PickupPinOutcome.fromError(
        const ApiError(
          code: 'rate_limited',
          message: 'x',
          reason: 'pin_locked',
          statusCode: 429,
          retryAfter: Duration(seconds: 61),
        ),
      );
      final required = PickupPinOutcome.fromError(
        const ApiError(
          code: 'invalid_transition',
          message: 'x',
          reason: 'pin_required',
          statusCode: 409,
        ),
      );
      final other = PickupPinOutcome.fromError(
        const ApiError(code: 'conflict', message: 'x', statusCode: 409),
        fallback: 'Try again',
      );
      expect(wrong.result, PickupPinResult.wrong);
      expect(wrong.attemptsLeft, 2);
      expect(locked.lockedMinutes, 2);
      expect(required.aboutPin, isTrue);
      final blocked = PickupPinOutcome.fromError(
        const ApiError(
          code: 'rate_limited',
          message: 'x',
          reason: 'pin_blocked',
          statusCode: 429,
        ),
      );
      final notNow = PickupPinOutcome.fromError(
        const ApiError(
          code: 'invalid_transition',
          message: 'x',
          reason: 'pin_not_now',
          statusCode: 409,
        ),
      );
      expect(blocked.result, PickupPinResult.blocked);
      expect(notNow.result, PickupPinResult.notNow);
      expect(other.aboutPin, isFalse);
      expect(other.text, 'Try again');
      for (final (language, w, l, r, b) in [
        (
          'sv',
          'Fel kod. 2 försök kvar',
          'För många försök. Försök igen om 2 min',
          'Fråga resenären efter den fyrsiffriga koden',
          'För många fel koder. Ring Movera support',
        ),
        (
          'fr',
          'Code incorrect. Encore 2 essais',
          'Trop d’essais. Réessayez dans 2 min',
          'Demandez au passager son code à 4 chiffres',
          'Trop de codes incorrects. Appelez le support Movera',
        ),
        (
          'en',
          'Wrong code. 2 tries left',
          'Too many tries. Try again in 2 min',
          'Ask the rider for the 4-digit code',
          'Too many wrong codes. Call Movera support',
        ),
      ]) {
        DriverAppTexts.language = language;
        expect(blocked.text, b);
        expect(wrong.text, w);
        expect(locked.text, l);
        expect(required.text, r);
      }
    });

    test('a PIN is exactly four digits', () {
      expect(PickupPinOutcome.valid('0420'), isTrue);
      expect(PickupPinOutcome.valid('123'), isFalse);
      expect(PickupPinOutcome.valid('12a4'), isFalse);
      expect(PickupPinOutcome.attemptsLeftOf(['x', 'attemptsLeft=0']), 0);
    });

    group('on the server', () {
      final origin = Uri.parse('https://api.test.movera.se');
      late List<http.Request> requests;
      late List<FutureOr<http.Response> Function(http.Request)> answers;

      http.Response json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

      ApiClient api() => ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return answers.removeAt(0)(request);
        }),
        baseUri: origin,
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      );

      setUp(() {
        requests = [];
        answers = [];
      });

      Map<String, dynamic> trip(String status, int version) => {
        'tripId': 't1',
        'status': status,
        'version': version,
        'pinRequired': true,
        'pinVerified': status != 'arrived',
      };

      test('pin/verify first, then board and start from its version', () async {
        final trips = LiveTripCommands(api: api())..observe(trip('arrived', 5));
        expect(trips.needsPin('t1'), isTrue);
        answers
          ..add(
            (_) => json(200, {
              'verifiedPinToken': 'tok',
              'expiresAt': '2026-11-01T12:00:00Z',
              'version': 6,
            }),
          )
          ..add((_) => json(200, trip('rider_onboard', 7)))
          ..add((_) => json(200, trip('in_trip', 8)));
        final outcome = await trips.start('t1', pin: '0420');
        expect(outcome.ok, isTrue);
        expect(requests.map((r) => r.url.path), [
          '/api/v1/trips/t1/pin/verify',
          '/api/v1/trips/t1/board',
          '/api/v1/trips/t1/start',
        ]);
        expect(jsonDecode(requests[0].body), {'pin': '0420'});
        expect(jsonDecode(requests[1].body), {'expectedVersion': 6});
        expect(jsonDecode(requests[2].body), {'expectedVersion': 7});
        // Without it the server skips the PIN (round 1 compat).
        for (final request in requests) {
          expect(request.headers['X-Contract-Version'], '0.18.10');
        }
        expect(trips.needsPin('t1'), isFalse);
      });

      test('pin_wrong and pin_locked come back as PIN refusals', () async {
        final trips = LiveTripCommands(api: api())..observe(trip('arrived', 5));
        answers
          ..add(
            (_) => json(400, {
              'code': 'invalid_request',
              'reason': 'pin_wrong',
              'message': 'Wrong PIN',
              'details': ['attemptsLeft=4'],
            }),
          )
          ..add(
            (_) => json(429, {
              'code': 'rate_limited',
              'reason': 'pin_locked',
              'message': 'Locked',
              'retryAfterSeconds': 240,
            }),
          );
        final wrong = PickupPinOutcome.fromError(
          (await trips.start('t1', pin: '1111')).error,
        );
        expect(wrong.result, PickupPinResult.wrong);
        expect(wrong.attemptsLeft, 4);
        final locked = PickupPinOutcome.fromError(
          (await trips.start('t1', pin: '2222')).error,
        );
        expect(locked.result, PickupPinResult.locked);
        expect(locked.lockedFor, const Duration(seconds: 240));
        expect(locked.lockedMinutes, 4);
      });

      test('a trip without the switch needs no PIN', () {
        final trips = LiveTripCommands(api: api())
          ..observe({'tripId': 't2', 'status': 'arrived', 'version': 2});
        expect(trips.needsPin('t2'), isFalse);
      });
    });

    Future<Future<bool>> openSheet(
      WidgetTester tester,
      Future<PickupPinOutcome> Function(String pin) submit, {
      PickupPinOutcome? first,
    }) async {
      late Future<bool> result;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => result = showPickupPinSheet(
                    context,
                    submit: submit,
                    first: first,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('the PIN step: a wrong code, then the right one', (
      tester,
    ) async {
      final sent = <String>[];
      final result = await openSheet(tester, (pin) async {
        sent.add(pin);
        return pin == '0420'
            ? const PickupPinOutcome.ok()
            : const PickupPinOutcome(PickupPinResult.wrong, attemptsLeft: 3);
      });
      expect(find.text('Ask the rider for the 4-digit code'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('pickup-pin-confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('pickup-pin-field')),
        '1111',
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Wrong code. 3 tries left'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pickup-pin-field')),
        '0420',
      );
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(sent, ['1111', '0420']);
      expect(await result, isTrue);
      expect(find.byType(PickupPinSheet), findsNothing);
    });

    testWidgets('blocked: the field stays closed, call support', (
      tester,
    ) async {
      await openSheet(
        tester,
        (_) async => const PickupPinOutcome.ok(),
        first: const PickupPinOutcome(PickupPinResult.blocked),
      );
      expect(
        find.text('Too many wrong codes. Call Movera support'),
        findsOneWidget,
      );
      final field = find.byKey(const ValueKey('pickup-pin-field'));
      expect(tester.widget<TextField>(field).enabled, isFalse);
      await tester.pump(const Duration(minutes: 30));
      expect(tester.widget<TextField>(field).enabled, isFalse);
    });

    testWidgets('locked: the field waits until the lock is over (sv)', (
      tester,
    ) async {
      DriverAppTexts.language = 'sv';
      await openSheet(
        tester,
        (_) async => const PickupPinOutcome.ok(),
        first: const PickupPinOutcome(
          PickupPinResult.locked,
          lockedFor: Duration(seconds: 90),
        ),
      );
      expect(
        find.text('För många försök. Försök igen om 2 min'),
        findsOneWidget,
      );
      final field = find.byKey(const ValueKey('pickup-pin-field'));
      expect(tester.widget<TextField>(field).enabled, isFalse);
      await tester.pump(const Duration(seconds: 91));
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(find.text('Skriv fyra siffror'), findsOneWidget);
    });
  });

  group('3. island messages, no sound', () {
    TripIslandInput waiting({String? alert, int key = 0}) => TripIslandInput(
      status: 'Waiting',
      address: 'Kungsgatan 1',
      waitingMessage: 'Free wait',
      arrived: true,
      waitingSeconds: 400,
      alert: alert,
      alertKey: key,
    );

    testWidgets('a new alert is said once, then the island goes back', (
      tester,
    ) async {
      final island = TripIslandController(waiting());
      island.update(waiting(alert: 'Paid waiting has started', key: 1));
      expect(island.face.title, 'Paid waiting has started');
      // The same key again (a later projection) is not news.
      await tester.pump(const Duration(seconds: 3));
      island.update(waiting(alert: 'Paid waiting has started', key: 1));
      expect(island.face.title, 'Paid waiting has started');
      await tester.pump(const Duration(seconds: 2));
      expect(island.face.title, isNot('Paid waiting has started'));
      island.dispose();
    });

    for (final (language, paid, noShow) in [
      ('sv', 'Betald väntetid har börjat', 'Du kan nu markera utebliven kund'),
      (
        'fr',
        'L’attente payante a commencé',
        'Vous pouvez maintenant signaler un client absent',
      ),
      ('en', 'Paid waiting has started', 'You can now mark a no-show'),
    ]) {
      test('alert words in $language', () {
        DriverAppTexts.language = language;
        expect(tr.g6AlertPaid, paid);
        expect(tr.g6AlertNoShow, noShow);
      });
    }
  });

  group('4. free wait at each stop', () {
    for (final (language, text) in [
      ('sv', 'Gratis väntan vid stopp: 3 min'),
      ('fr', 'Attente gratuite à l’arrêt : 3 min'),
      ('en', 'Free wait at this stop: 3 min'),
    ]) {
      test('the stop line in $language', () {
        DriverAppTexts.language = language;
        expect(tr.g6StopFreeWait(3), text);
      });
    }
  });
}
