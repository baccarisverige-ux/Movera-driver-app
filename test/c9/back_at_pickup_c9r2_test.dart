import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Job C9 round 2 (contract v0.18.93 `autoArrive.back` / `button` /
/// `texts.driverBack`; supervisor must-fix M2, Rules
/// audits/impact/c9-auto-arrive-supervisor.md): while the server's waiting
/// clock stands still (`waiting.away`) the driver can tap "I'm back at the
/// pickup" — the contract's "or his tap" restart. The app sends `arrive`
/// with its latest fix; the server counts it only within the trip's
/// leaveMeters (else 409 not_at_pickup, shown as "not at the pickup yet").

Map<String, dynamic> _trip(String status, int version, {bool away = true}) => {
  'tripId': 't1',
  'status': status,
  'version': version,
  'waiting': {
    'arrivedAt': '2026-11-14T10:00:00Z',
    'freeUntil': '2026-11-14T10:05:00Z',
    'noShowAt': '2026-11-14T10:05:00Z',
    'chargedSeconds': 0,
    if (away) 'away': {'since': '2026-11-14T10:02:00Z'},
  },
};

void main() {
  test('texts: autoArrive.texts.driverBack is the contract text in sv, fr '
      'and en', () {
    final contract =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final texts = (contract['autoArrive'] as Map)['texts'] as Map;
    for (final lang in ['sv', 'fr', 'en']) {
      expect(
        lookupAppLocalizations(Locale(lang)).waitingBackAtPickup,
        texts['driverBack'][lang],
        reason: lang,
      );
    }
  });

  group('LiveTripCommands.resumeWaiting', () {
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
    const LiveFix fix = {
      'lat': 59.3335,
      'lng': 18.0649,
      'accuracy': 5,
      'measuredAt': '2026-11-14T10:08:00Z',
    };
    setUp(() {
      requests = [];
      answers = [];
    });

    test('away: POST arrive with the latest fix and the trip version; the '
        'clock goes on from the answer', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(_trip('arrived', 5));
      answers.add((_) => json(200, _trip('arrived', 6, away: false)));
      final outcome = await trips.resumeWaiting('t1');
      expect(outcome.ok, isTrue);
      expect(requests.single.url.path, '/api/v1/trips/t1/arrive');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['expectedVersion'], 5);
      expect((body['location'] as Map)['lat'], 59.3335);
      expect(trips.versionOf('t1'), 6);
    });

    test('a fix already brought him back (no waiting.away): nothing is '
        'sent', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(_trip('arrived', 6, away: false));
      final outcome = await trips.resumeWaiting('t1');
      expect(outcome.ok, isTrue);
      expect(requests, isEmpty);
    });

    test('too far (beyond leaveMeters): 409 not_at_pickup says "not at the '
        'pickup yet"', () async {
      final trips = LiveTripCommands(api: api(), lastFix: () => fix)
        ..observe(_trip('arrived', 5));
      answers.add(
        (_) => json(409, {
          'code': 'invalid_transition',
          'reason': 'not_at_pickup',
          'message': 'You are not at the pickup yet.',
        }),
      );
      final outcome = await trips.resumeWaiting('t1');
      expect(outcome.ok, isFalse);
      expect(outcome.error, isA<ApiError>());
      expect(outcome.message, liveTripErrorMessage(outcome.error));
      expect(
        outcome.message,
        lookupAppLocalizations(const Locale('en')).liveTripNotAtPickup,
      );
    });
  });
}
