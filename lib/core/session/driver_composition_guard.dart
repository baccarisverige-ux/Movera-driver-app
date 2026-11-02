import 'package:movera/core/session/driver_runtime_config.dart';

/// The current composition contains preview-only session/dispatch adapters.
const driverProductionRequested = bool.fromEnvironment(
  'MOVERA_PRODUCTION',
  defaultValue: false,
);
void validateDriverComposition({required bool production}) {
  if (production) {
    throw StateError(
      'Production Driver composition is unavailable: configure and verify real session, dispatch, realtime and routing adapters first.',
    );
  }
}

/// Demo-only things (fake ride checks, sample earnings, the sample
/// airport queue, demo admin offers, "demo" wording). Off on production
/// and on every build that signs in to a real server
/// (`MOVERA_AUTH_REQUIRED`, the `/live/` build): the live build never sets
/// `MOVERA_PRODUCTION`, so that flag alone must not decide (audit B1).
bool get driverDemoFeatures =>
    !driverProductionRequested && !DriverRuntimeConfig.current.authRequired;
