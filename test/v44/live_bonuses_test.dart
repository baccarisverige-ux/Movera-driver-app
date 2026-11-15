import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_bonuses.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/money/money.dart';

/// BQ-V44 (contract v0.18.110): reading `DriverBonus`, the opened call in
/// batches of 50, and `EarningsPeriod.bonus` as a part of net.
void main() {
  Map<String, Object?> item({
    String id = 'b1',
    Object? measure = 'trips',
    Object? state = 'active',
    Object? done = 3,
    Object? target = 10,
    Object? amount,
    Object? startDate = '2026-11-10',
    Map<String, Object?>? names,
    bool isNew = false,
  }) => {
    'bonusId': id,
    'names': names ?? {'sv': 'Rusning', 'fr': 'Pointe', 'en': 'Rush'},
    'measure': measure,
    'state': state,
    'startDate': startDate,
    'endDate': '2026-11-30',
    'timeZone': 'Europe/Stockholm',
    'amount': amount ?? {'amountMinor': 15000, 'currency': 'SEK'},
    'progress': {'done': done, 'target': target},
    'earned': false,
    'isNew': isNew,
  };

  group('DriverBonus.tryParse', () {
    test('reads the server fields as they come (SEK and TND)', () {
      final sek = DriverBonus.tryParse(
        item(measure: 'online_hours', done: 260, target: 600),
      )!;
      expect(sek.measure, BonusMeasure.onlineHours);
      expect(sek.done, 260);
      expect(sek.target, 600);
      expect(sek.amount.formatted, '150,00 kr');
      expect(sek.startDate, DateTime(2026, 11, 10));
      final tnd = DriverBonus.tryParse(
        item(amount: {'amountMinor': 20000, 'currency': 'TND'}, state: 'ended'),
      )!;
      expect(tnd.amount.formatted, '20.000 DT');
      expect(tnd.state, BonusState.ended);
    });

    test('a broken item is left out, never half shown', () {
      expect(DriverBonus.tryParse(item(measure: 'steps')), isNull);
      expect(DriverBonus.tryParse(item(state: 'gone')), isNull);
      expect(DriverBonus.tryParse(item(done: 1.5)), isNull);
      expect(DriverBonus.tryParse(item(target: 0)), isNull);
      expect(DriverBonus.tryParse(item(done: -1)), isNull);
      expect(DriverBonus.tryParse(item(startDate: '10/11/2026')), isNull);
      expect(
        DriverBonus.tryParse(
          item(amount: {'amountMinor': 1, 'currency': 'USD'}),
        ),
        isNull,
      );
    });

    test('the name in the app language, else English, else any', () {
      final b = DriverBonus.tryParse(
        item(names: {'sv': '', 'fr': 'Pointe', 'en': 'Rush'}),
      )!;
      expect(b.nameIn('fr'), 'Pointe');
      expect(b.nameIn('sv'), 'Rush');
      final only = DriverBonus.tryParse(
        item(names: {'sv': 'Bara', 'fr': '', 'en': ' '}),
      )!;
      expect(only.nameIn('en'), 'Bara');
    });
  });

  group('LiveBonuses', () {
    late List<http.Request> seen;
    late http.Response Function(http.Request) answer;

    LiveBonuses bonuses() {
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      return LiveBonuses(
        api: ApiClient(
          client: MockClient((request) async {
            seen.add(request);
            return answer(request);
          }),
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: tokens,
        ),
      );
    }

    setUp(() => seen = []);

    test(
      'hasNew follows isNew; opened sends 50 ids at most per call',
      () async {
        answer = (r) => r.method == 'GET'
            ? http.Response(
                jsonEncode({
                  'items': [item(isNew: true), 'junk', item(id: 'b2')],
                }),
                200,
                headers: {'content-type': 'application/json'},
              )
            : http.Response('', 204);
        final live = bonuses();
        final list = await live.list();
        expect(list.map((b) => b.bonusId), ['b1', 'b2']);
        expect(live.hasNew.value, isTrue);
        await live.opened([for (var i = 0; i < 51; i++) 'id$i', 'id0']);
        final posts = seen.where((r) => r.method == 'POST').toList();
        expect(posts, hasLength(2));
        expect((jsonDecode(posts[0].body)['bonusIds'] as List).length, 50);
        expect(jsonDecode(posts[1].body)['bonusIds'], ['id50']);
        expect(live.hasNew.value, isFalse);
        await live.opened(const []);
        expect(seen.where((r) => r.method == 'POST'), hasLength(2));
      },
    );

    test('a failed read or opened call keeps the badge as it was', () async {
      answer = (r) => http.Response(
        jsonEncode({
          'code': 'unavailable',
          'message': 'down',
          'requestId': 'x',
          'retryable': true,
        }),
        503,
        headers: {'content-type': 'application/json'},
      );
      final live = bonuses()..hasNew.value = true;
      await live.refreshBadge();
      expect(live.hasNew.value, isTrue);
      await live.opened(['b1']);
      expect(live.hasNew.value, isTrue);
      await expectLater(live.list(), throwsA(anything));
    });
  });

  group('EarningsTotals.bonus', () {
    Map<String, Object?> m(int minor, String c) => {
      'amountMinor': minor,
      'currency': c,
    };

    test('summed for its own line; net stays the server\'s', () {
      final totals = EarningsTotals.of({
        'currency': 'TND',
        'periods': [
          {'tripCount': 1, 'net': m(64000, 'TND'), 'tips': m(0, 'TND')},
          {
            'tripCount': 1,
            'net': m(20000, 'TND'),
            'tips': m(0, 'TND'),
            'bonus': m(20000, 'TND'),
          },
        ],
      });
      expect(totals.net, const Money(minorUnits: 84000, currency: 'TND'));
      expect(totals.bonus, const Money(minorUnits: 20000, currency: 'TND'));
    });

    test('null from a server that does not send it', () {
      final totals = EarningsTotals.of({
        'currency': 'SEK',
        'periods': [
          {'tripCount': 1, 'net': m(100, 'SEK'), 'tips': m(0, 'SEK')},
        ],
      });
      expect(totals.bonus, isNull);
    });
  });
}
