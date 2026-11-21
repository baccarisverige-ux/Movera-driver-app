// Contract v0.18.136 stripeFees.keys (DRAFT): no plugin here, so the data
// layer can check the server's key without the Stripe SDK.
/// Live mode (owner 2026-11-21, contract stripeFees.keys): the server sends
/// the publishable key of ITS mode (pk_test_ or pk_live_); the app never
/// assumes a mode and uses the key as is. Anything else = not usable.
bool isStripePublishableKey(String key) =>
    key.startsWith('pk_test_') || key.startsWith('pk_live_');

/// Google Pay's test environment only for a test key (Google Pay stays off
/// unless kGooglePayEnabled).
bool stripeGooglePayTestEnv(String publishableKey) =>
    publishableKey.startsWith('pk_test_');
