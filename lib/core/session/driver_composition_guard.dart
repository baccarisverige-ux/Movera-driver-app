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

/// v0.18.154 P16c review S-D5 (as the rider's TransportComposition): a
/// release build that signs in to a real server must know its own version
/// (`--dart-define=MOVERA_APP_VERSION`), else the minimum-version check and
/// X-App-Version are off and old phones can never be made to update; such
/// a build stops at start.
void validateDriverAppVersion({
  required bool releaseBuild,
  required bool liveBuild,
  required String version,
}) {
  final value = version.trim();
  if (releaseBuild && liveBuild && (value.isEmpty || value == 'dev')) {
    throw StateError(
      'MOVERA_APP_VERSION is missing for the live release build',
    );
  }
}
