import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:movera/core/payments/stripe_keys.dart';

export 'package:movera/core/payments/stripe_keys.dart';

/// Google Pay is NOT approved by the owner yet (2026-11-20): off unless the
/// build sets `--dart-define=MOVERA_GOOGLE_PAY=true`. Card and Apple Pay only.
const bool kGooglePayEnabled = bool.fromEnvironment('MOVERA_GOOGLE_PAY');

/// Apple Pay merchant id (not a secret; the entitlement is a release step).
const String kApplePayMerchantId = 'merchant.se.movera.driver';

/// The flutter_stripe PaymentSheet for a server PaymentIntent (test or live:
/// the caller passes the server's pk_test_ or pk_live_ key). true = paid on
/// the phone, false = closed; throws on a failure. Paid for Movera is what
/// the SERVER says.
Future<bool> presentStripeSheet({
  required String clientSecret,
  required String publishableKey,
  String countryCode = 'SE',
}) async {
  Stripe.publishableKey = publishableKey;
  Stripe.merchantIdentifier = kApplePayMerchantId;
  await Stripe.instance.applySettings();
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: 'Movera',
      applePay: PaymentSheetApplePay(merchantCountryCode: countryCode),
      googlePay: kGooglePayEnabled
          ? PaymentSheetGooglePay(
              merchantCountryCode: countryCode,
              testEnv: stripeGooglePayTestEnv(publishableKey),
            )
          : null,
    ),
  );
  try {
    await Stripe.instance.presentPaymentSheet();
    return true;
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return false;
    rethrow;
  }
}
