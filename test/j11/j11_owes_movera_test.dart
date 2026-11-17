// J11 (contract v0.18.84 `debtModel.driverOwes`, owner Q-S5-1 "Both" +
// 2026-11-13 14:54 "can recive trip but cash trip", decisions/
// session-2026-11-06.md:1244-1247): the driver app's part of the debt
// model. Over his country's owes-limit he gets no cash trips; he is never
// kept offline; a booked cash ride he already accepted stays his (server).
//
// Written to fail first on the app before J11 (origin/main ce075d67):
// the line fell to the default words, its level came from the wire, and
// the Accept refusal read as "taken by another driver".
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> get _debt =>
    _contract['debtModel'] as Map<String, dynamic>;

void _speak(String language) {
  switch (language) {
    case 'sv':
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    case 'fr':
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    default:
      DriverLanguage.resetForTest();
  }
}

const _owed = Money(minorUnits: 152000, currency: 'TND');
const _limit = Money(minorUnits: 150000, currency: 'TND');

Map<String, dynamic> _line({String level = 'due_soon'}) => {
  'kind': 'owes_movera_over_limit',
  'level': level,
  'owed': _owed.toJson(),
  'limit': _limit.toJson(),
};

String _contractLine(String language) =>
    ((_debt['texts'] as Map)['owesMoveraLine'] as Map)[language]
        .toString()
        .replaceAll('{owed}', _owed.formatted)
        .replaceAll('{limit}', _limit.formatted);

bool _atLeast(String version, String min) {
  final a = version.split('.').map(int.parse).toList();
  final b = min.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return true;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _offer({String payment = 'cash'}) => {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': DateTime.now()
      .add(const Duration(seconds: 15))
      .toUtc()
      .toIso8601String(),
  'fare': {'amountMinor': 12500, 'currency': 'TND'},
  'source': 'system',
  'pickup': {'address': 'Avenue Habib Bourguiba', 'lat': 36.80, 'lng': 10.18},
  'dropoff': {'address': 'La Marsa', 'lat': 36.88, 'lng': 10.32},
  'categoryId': 'comfort',
  'paymentMethod': payment,
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(DriverLanguage.resetForTest);

  test('J11: the app sends X-Contract-Version 0.18.84 or later, so the '
      'server sends the owes line (debtModel.oldApps)', () {
    expect(_atLeast(ApiClient.contractVersion, '0.18.84'), isTrue);
    expect(ApiClient.contractVersion, _contract['version']);
  });

  group('J11 Home line owes_movera_over_limit', () {
    test('parsed as an orange line with the server\'s owed and limit', () {
      final line = DriverReminder.fromJson(_line());
      expect(line.level, ReminderLevel.dueSoon);
      expect(line.blocksOnline, isFalse);
      expect(line.fix, isNull);
    });

    test('it never keeps him offline, whatever level is sent with it', () {
      final store = DriverRemindersStore()
        ..replace(
          DriverReminderList.fromJson({
            'items': [_line(level: 'blocks_online')],
          }),
        );
      expect(store.blocksOnline, isFalse);
      expect(store.firstBlocking, isNull);
      expect(store.items.single.level, ReminderLevel.dueSoon);
      expect(
        ((_contract['driverOnboarding'] as Map)['reminders']
            as Map)['kinds']['owes_movera_over_limit'],
        contains('never stops going online'),
      );
    });

    for (final language in ['en', 'fr', 'sv']) {
      test('[$language] the words are the contract text with the amounts', () {
        _speak(language);
        final words = reminderWords(
          DriverReminder.fromJson(_line()),
          nameOf: (_) => '',
        );
        expect(words.title, _contractLine(language));
        expect(words.action, isNull);
        expect(
          ((_contract['driverOnboarding'] as Map)['reminders']
              as Map)['texts']['owes_movera_over_limit'],
          (_debt['texts'] as Map)['owesMoveraLine'],
        );
      });
    }

    testWidgets('the Home sheet shows it orange, with no tap to fix', (
      tester,
    ) async {
      final store = DriverRemindersStore()
        ..replace(
          DriverReminderList.fromJson({
            'items': [_line()],
          }),
        );
      var fixes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImportantRemindersBox(store: store, onFix: (_) => fixes++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_contractLine('en')), findsOneWidget);
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('home-reminder-0-dueSoon')),
      );
      expect(
        (dot.decoration! as BoxDecoration).color,
        ImportantRemindersBox.orange,
      );
      await tester.tap(find.byKey(const ValueKey('home-reminder-0')));
      await tester.pumpAndSettle();
      expect(fixes, 0);
    });
  });

  group('J11 Accept refused with 409 driver_owes_movera', () {
    Future<ClaimResult> accept(Map<String, dynamic> answer) async {
      final answers = <http.Response>[
        _json({
          'items': [_offer()],
          'nextCursor': null,
        }),
        _json(answer, 409),
      ];
      final repo = ApiDispatchRepository(
        client: MockClient((_) async => answers.removeAt(0)),
        baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
        accessToken: () async => 'token',
        idempotencyKey: () => 'key-1',
      );
      final listed = repo.watchNearbyOffers().skip(1).first;
      repo.refreshOffers();
      await listed;
      return repo.claimOffer('o1');
    }

    // The J8 server's answer (src/dispatch/runtime/answers.ts acceptOffer).
    Map<String, dynamic> owes() => {
      'code': 'conflict',
      'message': 'You get no pay-in-car trips until you pay Movera.',
      'reason': 'driver_owes_movera',
      'details': ['owed:152000 TND', 'limit:150000 TND'],
      'projection': {..._offer(), 'version': 1},
    };

    test('it is gone for him, never "taken by another driver"', () async {
      final result = await accept(owes());
      expect(result.isSuccess, isFalse);
      expect(result.outcome, isNot(ClaimOutcome.alreadyClaimed));
      expect(result.outcome, ClaimOutcome.unavailable);
    });

    test('another driver winning is still "taken by another driver"', () async {
      final result = await accept({
        'code': 'conflict',
        'message': 'Taken.',
        'projection': {..._offer(), 'status': 'claimed_elsewhere'},
      });
      expect(result.outcome, ClaimOutcome.alreadyClaimed);
    });
  });
}
