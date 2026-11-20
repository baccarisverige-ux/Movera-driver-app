import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/profile/delete_account.dart';

/// Contract v0.18.134 (`contract.json#accountDeletion.driver`; owner button
/// 2026-11-20 "Accept, keep debt (Rec.)"): Profile > Delete my account. A
/// confirm step, then `POST /driver/account/deletion`; 202 = closed (signed
/// out, phone wiped); 409 `deletion_open_trip` = "finish or cancel first".
void main() {
  late List<http.Request> seen;
  late FutureOr<http.Response> Function(http.Request) answer;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  DriverAccountSession session() {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      seen.add(request);
      return answer(request);
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    return DriverAccountSession(repository: DriverAccountRepository(api));
  }

  setUp(() => seen = []);

  test(
    'the repository posts to the driver route and reads the answer',
    () async {
      answer = (_) => json(202, {
        'status': 'requested',
        'requestedAt': '2026-11-20T10:00:00Z',
        'eraseDueAt': '2026-12-20T10:00:00Z',
      });
      final result = await session().repository.requestAccountDeletion();
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/api/v1/driver/account/deletion');
      expect(seen.single.headers['idempotency-key'], isNotEmpty);
      expect(result.status, 'requested');
      expect(result.eraseDueAt, DateTime.utc(2026, 12, 20, 10));
    },
  );

  Future<void> host(
    WidgetTester tester,
    DriverAccountSession s, {
    required VoidCallback onDeleted,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountScreen(
          account: s,
          onDeleted: (_) async => onDeleted(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is sent before the confirm step; Cancel sends nothing', (
    tester,
  ) async {
    answer = (_) => json(202, {'status': 'requested'});
    var deleted = 0;
    await host(tester, session(), onDeleted: () => deleted++);
    expect(find.text(tr.acctDeleteTitle), findsWidgets);
    expect(find.text(tr.acctDeleteKept), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-account-button')));
    await tester.pumpAndSettle();
    expect(seen, isEmpty);
    await tester.tap(find.byKey(const ValueKey('delete-account-cancel')));
    await tester.pumpAndSettle();
    expect(seen, isEmpty);
    expect(deleted, 0);
  });

  testWidgets('confirm sends one request and signs out', (tester) async {
    answer = (_) => json(202, {'status': 'requested'});
    var deleted = 0;
    await host(tester, session(), onDeleted: () => deleted++);
    await tester.tap(find.byKey(const ValueKey('delete-account-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(
      seen.where((r) => r.url.path == '/api/v1/driver/account/deletion').length,
      1,
    );
    expect(deleted, 1);
  });

  testWidgets(
    '409 deletion_open_trip shows finish or cancel first, stays signed in',
    (tester) async {
      answer = (_) => json(409, {
        'code': 'conflict',
        'reason': 'deletion_open_trip',
        'message': 'x',
        'requestId': 'r',
      });
      var deleted = 0;
      await host(tester, session(), onDeleted: () => deleted++);
      await tester.tap(find.byKey(const ValueKey('delete-account-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(tr.acctDeleteOpenTrip), findsOneWidget);
      expect(deleted, 0);
    },
  );

  test('the public deletion page is in web/ (published with GitHub Pages)', () {
    final page = File('web/delete-account.html').readAsStringSync();
    expect(page, contains('Delete my account'));
    expect(page, contains('Radera mitt konto'));
    expect(page, contains('Supprimer mon compte'));
    // No e-mail address or phone number on the page (Rules: no addresses).
    expect(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(page), isFalse);
    expect(RegExp(r'\+\d{8,}').hasMatch(page), isFalse);
  });
}
