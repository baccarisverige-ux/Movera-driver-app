import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:movera/presentation/driver/pay_movera/pay_movera.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.18.139 `driverPayRequest` (owner 2026-11-20 "ask driver
/// monthly to pay how much due to Movera, so adding notification and push
/// screen with link to pay", "Link sumup for exp"; TEMPORARY): the Pay
/// Movera screen — the server's amount, a reference, and a button that opens
/// the admin's payment link as it is — and the bell / push notice that opens
/// it. Rule 36: fails on main (no screen, no route read, the notice opens
/// nothing).
void main() {
  Map<String, dynamic> money(int minor, String c) => {
    'amountMinor': minor,
    'currency': c,
  };
  const link = 'https://pay.sumup.com/b2c/MOVERA1';
  Map<String, dynamic> answer({
    bool enabled = true,
    int owed = 2384,
    String currency = 'SEK',
    Object? payLink = link,
  }) => {
    'enabled': enabled,
    'owedToMovera': money(owed, currency),
    'reference': 'drv_01ALI-202611',
    'payLink': ?(enabled ? payLink : null),
    'minAmount': ?(enabled ? money(0, currency) : null),
  };

  group('PayMovera reads the answer', () {
    test('amount, reference and the https link as they come', () {
      final view = PayMovera.of(answer());
      expect(view.enabled, isTrue);
      expect(view.owedToMovera.formatted, '23,84 kr');
      expect(view.reference, 'drv_01ALI-202611');
      expect(view.payLink.toString(), link);
      expect(view.canPay, isTrue);
    });

    test('ordinary payment links open as they are', () {
      for (final ok in [
        link,
        'https://sumup.se/pay/movera?ref=1&x=%20y#top',
        'https://pay.example:8443/a/b',
      ]) {
        expect(PayMovera.of(answer(payLink: ok)).payLink.toString(), ok);
      }
    });

    test('only a plain https link is ever opened', () {
      for (final bad in [
        'http://pay.sumup.com/b2c/X',
        'javascript:alert(1)',
        'intent://pay#Intent;scheme=x;end',
        'tel:+46700000000',
        'https://',
        'https://pay.sumup.com/a b',
        // Review should-fix 1: the address he reads is where it goes.
        'https://sumup.com@evil.example/x',
        'https://user:pw@pay.sumup.com/x',
        'HTTPS://pay.sumup.com/x',
        'https://pay.sumup.com/\u0000x',
        'https://pay.sumup.com/\u200bx',
        'https://pay.sumup.com/\u202ex',
        ' https://pay.sumup.com/x',
        // Printable ASCII only, no backslash (the server's rule).
        r'https://evil.example\@pay.sumup.com/',
        'https://pay.sumup.com/\u00adx',
        'https://pay.sumup.com/\u2003x',
        'https://pay.sumup.com/\u3000x',
        'https://p\u0430y.sumup.com/x',
        '',
        42,
        'https://pay.sumup.com/${'x' * 500}',
      ]) {
        final view = PayMovera.of(answer(payLink: bad));
        expect(view.payLink, isNull, reason: '$bad');
        expect(view.canPay, isFalse, reason: '$bad');
      }
    });

    test('off: no link even if one is sent; nothing owed: nothing to pay', () {
      final off = PayMovera.of({...answer(enabled: false), 'payLink': link});
      expect(off.payLink, isNull);
      expect(PayMovera.of(answer(owed: 0)).canPay, isFalse);
    });

    test('an amount below 0 is a broken answer: an error (review should-fix '
        '2)', () {
      expect(() => PayMovera.of(answer(owed: -500)), throwsFormatException);
    });

    test('no amount or no reference: an error, never a made-up screen', () {
      expect(
        () => PayMovera.of({'enabled': true, 'reference': 'x'}),
        throwsFormatException,
      );
      expect(
        () => PayMovera.of({'enabled': true, 'owedToMovera': money(1, 'SEK')}),
        throwsFormatException,
      );
    });
  });

  Future<List<Uri>> show(
    WidgetTester tester,
    Future<PayMovera> Function() load, {
    bool opens = true,
  }) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PayMoveraScreen(
          load: load,
          openLink: (uri) async {
            opened.add(uri);
            return opens;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return opened;
  }

  Finder key(String k) => find.byKey(ValueKey<String>(k));
  String text(WidgetTester tester, String k) {
    // A SelectableText hands its key on to its inner widgets: the first is it.
    final w = tester.widgetList(key(k)).first;
    return w is SelectableText ? w.data! : (w as Text).data!;
  }

  group('Pay Movera screen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('on: the amount, the reference and a button that opens the '
        'admin link exactly as it is', (tester) async {
      final opened = await show(tester, () async => PayMovera.of(answer()));
      expect(text(tester, 'pay-movera-label'), 'You owe Movera');
      expect(text(tester, 'pay-movera-amount'), '23,84 kr');
      expect(text(tester, 'pay-movera-reference'), 'drv_01ALI-202611');
      expect(
        text(tester, 'pay-movera-how-to'),
        'The payment page opens in your browser. Enter the amount and the '
        'reference there.',
      );
      expect(
        text(tester, 'pay-movera-confirm-note'),
        'The amount goes down when Movera has confirmed your payment.',
      );
      await tester.tap(key('pay-movera-button'));
      await tester.pump();
      // No amount, no reference, nothing added to the link.
      expect(opened.map((u) => u.toString()), [link]);
      expect(key('pay-movera-link-failed'), findsNothing);
    });

    testWidgets('off: the amount and "Settled in your next payout.", no '
        'button', (tester) async {
      final opened = await show(
        tester,
        () async => PayMovera.of(answer(enabled: false)),
      );
      expect(text(tester, 'pay-movera-amount'), '23,84 kr');
      expect(
        text(tester, 'pay-movera-settles'),
        'Settled in your next payout.',
      );
      expect(key('pay-movera-button'), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('nothing owed: Settled, no button, no reference to copy', (
      tester,
    ) async {
      await show(tester, () async => PayMovera.of(answer(owed: 0)));
      expect(text(tester, 'pay-movera-label'), 'Settled');
      expect(text(tester, 'pay-movera-amount'), '0,00 kr');
      expect(key('pay-movera-button'), findsNothing);
      expect(key('pay-movera-reference'), findsNothing);
    });

    testWidgets('a link that is not https: no button (never opened)', (
      tester,
    ) async {
      final opened = await show(
        tester,
        () async => PayMovera.of(answer(payLink: 'http://pay.sumup.com/x')),
      );
      expect(key('pay-movera-button'), findsNothing);
      expect(
        text(tester, 'pay-movera-settles'),
        'Settled in your next payout.',
      );
      expect(opened, isEmpty);
    });

    testWidgets('Copy puts the reference / the amount on the clipboard', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await show(tester, () async => PayMovera.of(answer()));
      await tester.tap(key('pay-movera-copy-reference'));
      await tester.pump();
      await tester.tap(key('pay-movera-copy-amount'));
      await tester.pump();
      expect(copied, ['drv_01ALI-202611', '23,84 kr']);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('the browser could not open the page: he is told', (
      tester,
    ) async {
      await show(tester, () async => PayMovera.of(answer()), opens: false);
      await tester.tap(key('pay-movera-button'));
      await tester.pump();
      expect(key('pay-movera-link-failed'), findsOneWidget);
    });

    testWidgets('the server could not answer: a message and Retry, never an '
        'amount', (tester) async {
      var calls = 0;
      await show(tester, () async {
        calls++;
        if (calls == 1) throw StateError('down');
        return PayMovera.of(answer());
      });
      expect(key('pay-movera-unavailable'), findsOneWidget);
      expect(key('pay-movera-amount'), findsNothing);
      await tester.tap(key('pay-movera-retry'));
      await tester.pump();
      await tester.pump();
      expect(text(tester, 'pay-movera-amount'), '23,84 kr');
    });

    testWidgets('Tunis: dinars keep 3 decimals', (tester) async {
      await show(
        tester,
        () async => PayMovera.of(answer(owed: 6000, currency: 'TND')),
      );
      expect(text(tester, 'pay-movera-amount'), '6.000 DT');
    });

    for (final (lang, label, button, ref, how) in const [
      (
        'sv',
        'Du är skyldig Movera',
        'Betala Movera',
        'Referens',
        'Betalningssidan öppnas i din webbläsare. Ange beloppet och '
            'referensen där.',
      ),
      (
        'fr',
        'Vous devez à Movera',
        'Payer Movera',
        'Référence',
        'La page de paiement s’ouvre dans votre navigateur. Saisissez-y le '
            'montant et la référence.',
      ),
    ]) {
      testWidgets('$lang texts', (tester) async {
        await tester.runAsync(() => DriverLanguage.choose(lang));
        addTearDown(DriverLanguage.resetForTest);
        await show(tester, () async => PayMovera.of(answer()));
        expect(text(tester, 'pay-movera-label'), label);
        expect(
          find.descendant(
            of: key('pay-movera-button'),
            matching: find.text(button),
          ),
          findsOneWidget,
        );
        expect(find.text(ref), findsOneWidget);
        expect(text(tester, 'pay-movera-how-to'), how);
      });
    }

    testWidgets('a narrow phone with large text: no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => DriverLanguage.choose('fr'));
      addTearDown(DriverLanguage.resetForTest);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.6),
            ),
            child: PayMoveraScreen(
              load: () async => PayMovera.of(
                answer(owed: 123456789)
                  ..['reference'] = 'drv_01M6B73GE0YY2XZ4P6YG5AMJ0W-202611',
              ),
              openLink: (_) async => true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(key('pay-movera-button'), findsOneWidget);
    });
  });

  group('the monthly notice opens the screen', () {
    Map<String, Object?> row() => {
      'notificationId': 'ntf_pay',
      'kind': 'driver_pay_movera',
      'title': 'Betala Movera',
      'body': 'Du är skyldig Movera 23,84 kr. Öppna för att betala.',
      'at': '2026-11-01T09:30:00Z',
      'read': false,
      'deepLink': 'movera-driver://pay-movera',
    };

    test('driver_pay_movera is a Pay Movera notice (by kind or deep link)', () {
      final notice = ServerNotification.fromJson(row());
      expect(notice.opensPayMovera, isTrue);
      expect(notice.opensFleet, isFalse);
      expect(notice.isRefundTaken, isFalse);
      expect(
        ServerNotification.fromJson({
          ...row(),
          'kind': 'something_new',
        }).opensPayMovera,
        isTrue,
      );
      expect(
        ServerNotification.fromJson({
          ...row(),
          'kind': 'driver_trip_update',
          'deepLink': 'movera-driver://trips/t1',
        }).opensPayMovera,
        isFalse,
      );
    });

    test('its push is not an offer, trip, call or support push: it opens the '
        'bell list on the notice, which opens the screen', () {
      const open = PushOpen(
        notificationId: 'ntf_pay',
        deepLink: 'movera-driver://pay-movera',
      );
      expect(open.offerId, isNull);
      expect(open.routeChangeTripId, isNull);
      expect(open.callTripId, isNull);
      expect(open.supportTicketId, isNull);
    });

    testWidgets('a tap on the bell row shows the server words and opens Pay '
        'Movera', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/notifications') {
            return http.Response(
              jsonEncode({
                'items': [row()],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 200);
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      final account = DriverAccountSession(
        repository: DriverAccountRepository(api),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) =>
              MaterialApp(home: ServerNotificationsScreen(account: account)),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Betala Movera'), findsOneWidget);
      expect(
        find.text('Du är skyldig Movera 23,84 kr. Öppna för att betala.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Betala Movera'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PayMoveraScreen), findsOneWidget);
      // No live server in this test: the screen says so, with no amount.
      expect(key('pay-movera-unavailable'), findsOneWidget);
    });
  });
}
