import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/payments/stripe_sheet.dart';
import 'package:movera/presentation/driver/pay_movera/pay_movera.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DRAFT contract driverPayRequest.stripe (owner 2026-11-20 "Stripe is used
/// for exactly TWO things: ... (2) the DRIVER paying his monthly invoice to
/// Movera"): the Pay Movera button pays by Stripe for the server's amount;
/// the link button is gone while the server says stripe: true; paid is what
/// the server's owed says afterwards.
void main() {
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  Map<String, dynamic> answer({int owed = 2384, bool stripe = true}) => {
    'enabled': true,
    'owedToMovera': money(owed),
    'reference': 'drv_01ALI-202611',
    'payLink': 'https://pay.sumup.com/b2c/MOVERA1',
    'minAmount': money(0),
    'stripe': stripe,
  };
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'StripeDriverPayment: the server secret and its test or live publishable key (live mode, owner 2026-11-21)',
    () {
      final ok = StripeDriverPayment.of({
        'paymentIntentId': 'pi_1',
        'amount': money(2384),
        'status': 'requires_payment',
        'clientSecret': 'pi_1_secret',
        'publishableKey': 'pk_test_x',
        'createdAt': '2026-11-01T09:30:00Z',
      });
      expect(ok.amount.minorUnits, 2384);
      final live = StripeDriverPayment.of({
        'amount': money(1),
        'clientSecret': 's',
        'publishableKey': 'pk_live_FAKE_not_real',
      });
      expect(live.publishableKey, 'pk_live_FAKE_not_real');
      for (final bad in ['sk_live_FAKE', 'rk_live_FAKE', 'pk_FAKE', '']) {
        expect(
          () => StripeDriverPayment.of({
            'amount': money(1),
            'clientSecret': 's',
            'publishableKey': bad,
          }),
          throwsFormatException,
        );
      }
      expect(stripeGooglePayTestEnv('pk_test_FAKE'), isTrue);
      expect(stripeGooglePayTestEnv('pk_live_FAKE'), isFalse);
      expect(kGooglePayEnabled, isFalse);
      expect(kApplePayMerchantId, 'merchant.se.movera.driver');
      expect(PayMovera.of(answer()).canPayByCard, isTrue);
      expect(
        PayMovera.of({...answer(), 'enabled': false}).canPayByCard,
        isFalse,
      );
    },
  );

  Future<List<String>> show(
    WidgetTester tester, {
    required bool paid,
    required List<Map<String, dynamic>> answers,
  }) async {
    final shown = <String>[];
    var n = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PayMoveraScreen(
          load: () async =>
              PayMovera.of(answers[n < answers.length - 1 ? n++ : n]),
          openLink: (_) async => throw StateError('the link must not open'),
          startCard: () async => StripeDriverPayment.of({
            'amount': money(2384),
            'clientSecret': 'pi_1_secret',
            'publishableKey': 'pk_test_x',
          }),
          presentCard: (intent) async {
            shown.add(intent.clientSecret);
            return paid;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return shown;
  }

  testWidgets(
    'stripe: true: "Pay 23,84 kr by card", no link button; after the sheet the server says 0: Paid',
    (tester) async {
      final shown = await show(
        tester,
        paid: true,
        answers: [answer(), answer(owed: 0)],
      );
      expect(key('pay-movera-button'), findsNothing);
      expect(find.text('Pay 23,84 kr by card'), findsOneWidget);
      await tester.tap(key('pay-movera-card-button'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text('The payment did not go through. Try again.'),
        findsNothing,
      );
      expect(shown, ['pi_1_secret']);
      expect(find.text('Paid. Thank you.'), findsOneWidget);
    },
  );

  testWidgets(
    'the sheet said paid but the server still shows the amount: "checking", never paid',
    (tester) async {
      await show(tester, paid: true, answers: [answer(), answer()]);
      await tester.tap(key('pay-movera-card-button'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text('The payment did not go through. Try again.'),
        findsNothing,
      );
      expect(
        find.text('Payment received. We are checking it.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('stripe: false keeps the link button', (tester) async {
    await show(tester, paid: false, answers: [answer(stripe: false)]);
    expect(key('pay-movera-button'), findsOneWidget);
    expect(key('pay-movera-card-button'), findsNothing);
  });
  testWidgets(
    'review MUST 1+2: paid on the sheet, reload fails: "checking"; the button stays off while owed has not dropped',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PayMoveraScreen(
            load: () async {
              calls++;
              if (calls == 2) throw StateError('offline');
              return PayMovera.of(answer());
            },
            startCard: () async => StripeDriverPayment.of({
              'amount': money(2384),
              'clientSecret': 'pi_1_secret',
              'publishableKey': 'pk_test_x',
            }),
            presentCard: (_) async => true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(key('pay-movera-card-button'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.text('Payment received. We are checking it.'),
        findsOneWidget,
      );
      expect(
        find.text('The payment did not go through. Try again.'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'the server amount differs from the one shown: no sheet, a notice, the screen reloads',
    (tester) async {
      var sheets = 0;
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PayMoveraScreen(
            load: () async {
              loads++;
              return PayMovera.of(answer());
            },
            startCard: () async => StripeDriverPayment.of({
              'amount': money(3000),
              'clientSecret': 's',
              'publishableKey': 'pk_test_x',
            }),
            presentCard: (_) async {
              sheets++;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(key('pay-movera-card-button'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(sheets, 0);
      expect(loads, 2); // the screen read the server again
      expect(
        find.text('The amount changed. Check it and try again.'),
        findsOneWidget,
      );
    },
  );
  test(
    'owner 2026-11-20: Stripe replaces the SumUp link: on with no link still pays by card; the link is never shown',
    () {
      final view = PayMovera.of(
        {...answer(), 'payLink': null}..remove('payLink'),
      );
      expect(view.canPayByCard, isTrue);
      expect(view.payLink, isNull);
      expect(view.canPay, isFalse);
    },
  );
}
