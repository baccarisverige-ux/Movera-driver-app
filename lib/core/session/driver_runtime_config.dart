import 'package:flutter/foundation.dart';
import 'package:movera/core/session/driver_composition_guard.dart';

/// Runtime switches chosen by the build, never inferred from the binding.
///
/// Earlier code checked whether `WidgetsBinding` was a test binding to skip
/// account activation, GPS arrival and external routing. That made tests run
/// different code than users. These switches are now explicit: the build sets
/// them with `--dart-define`, and tests set them in `flutter_test_config.dart`.
class DriverRuntimeConfig {
  const DriverRuntimeConfig({
    required this.simulatedArrival,
    required this.externalRouting,
    required this.skipAccountActivation,
    this.liveMapTicker = true,
    this.reservationPopup = true,
    this.islandHint = true,
    this.radarSound = true,
    this.adminDemoOffers = false,
    this.authRequired = false,
    this.apiBaseUrl = '',
  });

  /// Demo builds only: arrival does not require a live GPS fix within 100 m of
  /// the demo pickup, so the demo works outside Stockholm. Release builds
  /// keep the fresh, accurate GPS gate unless the demo build passes
  /// `--dart-define=MOVERA_DEMO_ARRIVAL=true` (the GitHub Pages demo does).
  /// See [simulatedArrivalFor].
  final bool simulatedArrival;

  /// Whether the active ride requests road routes from the routing service.
  final bool externalRouting;

  /// Skip the pending-account activation hold on Home.
  final bool skipAccountActivation;

  /// 33 ms (about 30 Hz) refresh of the active-ride vehicle pose on the map. Widget tests
  /// turn it off because a fake clock cannot drain a periodic timer.
  final bool liveMapTicker;

  /// Home pops up new reservation requests a few seconds after it opens.
  /// Widget tests turn it off so the sheet does not cover other Home tests.
  final bool reservationPopup;

  /// First launch: the Home island says once that its middle shows the
  /// earnings. Widget tests turn it off so the island starts on the total.
  final bool islandHint;

  /// R15-5: the radar sound while Radar offers show. Tests turn it off:
  /// their machines have no sound device.
  final bool radarSound;

  /// Q16/Q18 demo: the demo dispatch also sends admin offers (a radar
  /// group trip with a Movera bonus and a direct assign), so the Priority
  /// badge and "Assigned by Movera" can be tried. Demo builds only; tests
  /// and production leave it off.
  final bool adminDemoOffers;

  /// Round 4 sign-in: the app opens on Sign in until the driver has a
  /// session (`MOVERA_AUTH_REQUIRED=true`). Off, the GitHub Pages demo
  /// keeps opening Home as before, with no sign-in reachable.
  final bool authRequired;

  /// The API origin, no trailing slash (`MOVERA_API_BASE_URL`, e.g.
  /// `https://api.staging.movera.se`). Empty: no server; a sign-in call
  /// ends as a network error.
  final String apiBaseUrl;

  /// [apiBaseUrl] as a [Uri].
  Uri get apiBaseUri => Uri.parse(apiBaseUrl);

  /// D-12: whether a build lets the driver arrive from anywhere.
  ///
  /// A production composition never does. Otherwise an explicit
  /// `MOVERA_DEMO_ARRIVAL` define wins; without one, release builds (store,
  /// APK, iOS, web release) enforce the 100 m check and debug or profile
  /// runs stay free for local testing.
  static bool simulatedArrivalFor({
    required bool releaseBuild,
    required bool productionBuild,
    bool? demoArrivalDefine,
  }) {
    if (productionBuild) {
      return false;
    }
    return demoArrivalDefine ?? !releaseBuild;
  }

  static const bool _demoArrivalDefined = bool.hasEnvironment(
    'MOVERA_DEMO_ARRIVAL',
  );
  static const bool _demoArrivalValue = bool.fromEnvironment(
    'MOVERA_DEMO_ARRIVAL',
  );

  /// Values compiled into this build.
  static final DriverRuntimeConfig build = DriverRuntimeConfig(
    simulatedArrival: simulatedArrivalFor(
      releaseBuild: kReleaseMode,
      productionBuild: driverProductionRequested,
      demoArrivalDefine: _demoArrivalDefined ? _demoArrivalValue : null,
    ),
    externalRouting: _externalRouting,
    skipAccountActivation: _skipAccountActivation,
    adminDemoOffers: !driverProductionRequested,
    authRequired: _authRequired,
    apiBaseUrl: _apiBaseUrl,
  );

  // Web (dart2js) only allows these reads as const values.
  static const bool _externalRouting = bool.fromEnvironment(
    'MOVERA_EXTERNAL_ROUTING',
    defaultValue: true,
  );
  static const bool _skipAccountActivation = bool.fromEnvironment(
    'MOVERA_SKIP_ACTIVATION',
    defaultValue: false,
  );
  static const bool _authRequired = bool.fromEnvironment(
    'MOVERA_AUTH_REQUIRED',
    defaultValue: false,
  );
  static const String _apiBaseUrl = String.fromEnvironment(
    'MOVERA_API_BASE_URL',
    defaultValue: '',
  );

  /// Production policy: every gate enforced.
  static const DriverRuntimeConfig production = DriverRuntimeConfig(
    simulatedArrival: false,
    externalRouting: true,
    skipAccountActivation: false,
    authRequired: true,
    apiBaseUrl: _apiBaseUrl,
  );

  /// Config read by screens. Tests replace it; app code never writes it.
  static DriverRuntimeConfig current = build;
}
