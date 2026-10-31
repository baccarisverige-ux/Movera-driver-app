import 'dart:async';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/core/session/driver_route_observer.dart';

import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/logging/global_error_hooks.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/driver_log.dart';

import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/content/driver_content_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/auth/secure_token_store.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/session_gate.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/widgets/demo_mode_banner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/live_safety_alert_repository.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/push/push_registrar.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:movera/presentation/driver/push/push_explanation.dart';
import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/core/platform/safe_area_insets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  validateDriverComposition(production: driverProductionRequested);
  installGlobalErrorHooks();
  // Round 4: the zone's default language, then the driver's saved choice.
  // A slow or broken store never holds the first frame for long.
  DriverLanguage.applyZone(const DriverHomeAdminContentService().languages);
  // Contract v0.18.2 (owner 2026-10-30): the phone field starts in Sweden
  // or France from what this phone knows, and until a language is picked
  // the app speaks the phone's language ("Phone language (Recommended)").
  try {
    await StartCountryHints.load().timeout(const Duration(seconds: 2));
  } catch (_) {
    // The device region decides.
  }
  DriverLanguage.applyDevice(
    phoneLanguage: deviceLanguage(),
    startCountry: defaultPhoneCountry().iso,
  );
  try {
    await DriverLanguage.restore().timeout(const Duration(seconds: 2));
  } catch (_) {
    // The phone's language stays.
  }
  runApp(const MoveraApp());
}

/// App composition root.
///
/// Long-lived frontend dependencies are created here and injected down into
/// feature screens. When backend adapters replace the current frontend
/// implementations, screen code does not need to change.
class MoveraApp extends StatefulWidget {
  const MoveraApp({
    super.key,
    this.locationRepository,
    this.tokenStore,
    this.httpClient,
  });

  /// Defaults to the device GPS. Tests inject a scripted source so the app
  /// root never depends on host location services.
  final DriverLocationRepository? locationRepository;

  /// Round 4 sign-in: where the session's tokens live. Defaults to the
  /// secure store (Keychain/Keystore, web localStorage); tests inject a
  /// memory store.
  final TokenStore? tokenStore;

  /// The HTTP client the API calls go through. Tests inject a fake.
  final http.Client? httpClient;

  @override
  State<MoveraApp> createState() => _MoveraAppState();
}

class _MoveraAppState extends State<MoveraApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final DriverSessionRepository _sessionStore;
  late final DriverSessionController _session;
  late final WaybillRepository _waybills;
  late final DriverLocationRepository _location;
  late final RoadRouteService _routing;
  late final DispatchRepository _dispatch;
  late final DriverHomeConfigRepository _homeConfig;
  late ActiveRideRepository _activeRide;
  late final SafetyAlertRepository _safetyAlerts;
  late final RideCheckServices _rideCheck;
  late final TokenStore _tokens;
  late final http.Client _http;
  late final ApiClient _api;
  late final AuthController _auth;
  late final DriverAccountSession _account;

  /// Live builds only (MOVERA_AUTH_REQUIRED): dispatch, availability,
  /// location and trip steps through movera-server. Null in the demo.
  LiveDriverServices? _live;
  PushRegistrar? _push;

  /// Live builds: tells [LiveDriverServices] when the app is back on screen.
  AppLifecycleListener? _lifecycle;

  /// Live builds: crash and error reports to movera-server.
  CrashReportSink? _crashReports;

  @override
  void initState() {
    super.initState();
    validateDriverComposition(production: driverProductionRequested);
    // Round 4 sign-in: the real API, with the session's tokens. With
    // MOVERA_AUTH_REQUIRED off (the demo) nothing here is called until a
    // logout, which then only clears a session that was never there.
    _tokens = widget.tokenStore ?? SecureTokenStore();
    _http = widget.httpClient ?? http.Client();
    _api = ApiClient(
      client: _http,
      baseUri: DriverRuntimeConfig.current.apiBaseUri,
      tokens: _tokens,
      onSessionExpired: _sessionExpired,
    );
    // Contract v0.16.0 (owner 2026-10-29, "Add automatic and add this in
    // term and condition"): a live build sends crashes and reported errors
    // on its own, scrubbed, with the driver's token when signed in. The
    // demo has no server to send them to.
    if (DriverRuntimeConfig.current.authRequired) {
      final version = CrashReports.splitVersion(driverAppVersion);
      final reports = _crashReports = CrashReportSink(
        baseUri: DriverRuntimeConfig.current.apiBaseUri,
        client: _http,
        accessToken: _tokens.readAccess,
        appVersion: version.version,
        build: version.build,
        platform: CrashReports.platformName(),
        next: DriverLog.sink,
      );
      DriverLog.sink = reports.call;
    }
    _auth = AuthController(
      repository: AuthRepository(api: _api, tokens: _tokens),
      // Contract v0.18.2 `auth.beforeSignIn`: the signed-in calls start
      // after the sign-in, not on the sign-in screen.
      onSignedIn: () => _live?.signedIn(),
      onSignedOut: () => _live?.signedOut(),
    );
    _account = DriverAccountSession(repository: DriverAccountRepository(_api));
    _sessionStore = MemoryDriverSessionRepository();
    _session = DriverSessionController(repository: _sessionStore);
    _waybills = InMemoryWaybillRepository.instance;
    _location = widget.locationRepository ?? const DriverLocationService();
    // Live builds take driving routes from movera-server (owner decision
    // 2026-10-27); the demo keeps asking the OSRM host directly.
    _routing = RoadRouteService(
      api: DriverRuntimeConfig.current.authRequired ? _api : null,
    );
    // A live build takes its offers from the server and tells it when the
    // driver goes online, where the car is and each trip step; the demo
    // keeps its in-process dispatch.
    if (DriverRuntimeConfig.current.authRequired) {
      final live = _live = LiveDriverServices(
        client: _http,
        origin: DriverRuntimeConfig.current.apiBaseUri,
        tokens: _tokens,
        api: _api,
        location: _location,
      );
      LiveDriverServices.instance = live;
      // G3-D2: a live build never shows the demo's sample performance.
      DriverPerformanceConfig.liveBuild = true;
      // G3-D1: one real notification list (the server's), no demo list.
      DriverNotificationFeed.instance.useLive();
      // Contract v0.18.3 R7: push after sign-in (web build; see docs/push.md).
      final pushPlatform = createPushPlatform();
      final push = _push = PushRegistrar(
        platform: pushPlatform,
        api: ApiPushApi(
          _api,
          app: 'driver',
          appVersion: CrashReports.splitVersion(driverAppVersion).version,
          locale: () => DriverLanguage.current.value,
        ),
        store: PrefsPushStore(),
        explain: _explainPush,
      );
      pushPlatform.onOpen(_openPush);
      live.afterSignedIn = () => unawaited(
        push.signedIn().then((_) {
          final launch = pushPlatform.takeLaunchOpen();
          if (launch != null) _openPush(launch);
        }),
      );
      live.attach(_session);
      // Contract v0.18.5 `legal` (G1-B2): the country's terms and privacy
      // policy (no token) on start and each time the app comes back.
      final legal = DriverLegal.instance..api = _api;
      unawaited(legal.start(country: defaultPhoneCountry().iso));
      _lifecycle = AppLifecycleListener(
        onResume: () {
          live.resumed();
          unawaited(legal.refresh());
        },
      );
      _dispatch = live.dispatch;
    } else {
      _dispatch = DemoDispatchRepository();
    }
    _homeConfig = const LocalDriverHomeConfigRepository();
    _activeRide = PrefsActiveRideRepository();
    // Ride check answers (contract v0.12.0 §22): a live build reports them
    // to movera-server; the demo keeps its in-memory outbox.
    final liveServices = _live;
    _safetyAlerts = liveServices != null
        ? LiveSafetyAlertRepository(
            api: _api,
            fix: () => liveServices.reporter.lastFix,
          )
        : DemoSafetyAlertRepository();
    _rideCheck = RideCheckServices(
      alerts: _safetyAlerts,
      log: PrefsRideCheckLog(),
    );
    unawaited(_session.restore());
    // Offers follow the saved Ride-preferences choice from the first frame.
    unawaited(DriverCategoryChoice.restore());
    DriverLanguage.current.addListener(_languageChanged);
  }

  /// A new language: the app's texts are read in `build`, so every screen
  /// builds again in place (trip and offer state stay as they are).
  void _languageChanged() {
    if (!mounted) return;
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  void dispose() {
    DriverLanguage.current.removeListener(_languageChanged);
    _session.dispose();
    _routing.dispose();
    final dispatch = _dispatch;
    if (dispatch is DemoDispatchRepository) {
      dispatch.dispose();
    }
    _lifecycle?.dispose();
    final reports = _crashReports;
    if (reports != null) {
      if (reports.next != null) DriverLog.sink = reports.next!;
      reports.dispose();
    }
    final live = _live;
    if (live != null) {
      unawaited(live.dispose());
      if (identical(LiveDriverServices.instance, live)) {
        LiveDriverServices.instance = null;
      }
    }
    if (_safetyAlerts case final DemoSafetyAlertRepository demo) demo.dispose();
    if (widget.httpClient == null) _http.close();
    super.dispose();
  }

  /// The refresh was refused: the tokens are gone (ApiClient cleared them).
  /// A build that requires a session goes back to Sign in; the demo path
  /// never gets here.
  Future<void> _sessionExpired() async {
    if (!DriverRuntimeConfig.current.authRequired) return;
    _live?.signedOut();
    // Checker blocker 1 / HIGH 2: no terms screen over Sign in.
    unawaited(DriverLegal.instance.signedOut());
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    showDriverSignIn(navigator, _signIn);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            navigatorObservers: [driverRouteObserver],
            title: 'Movera Driver',
            debugShowCheckedModeBanner: false,
            locale: Locale(DriverLanguage.current.value),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // G3-D7: dialogs in Movera black/green, never default purple.
            theme: ThemeData.light(useMaterial3: true)
                .copyWith(scaffoldBackgroundColor: AppColor.bg)
                .copyWith(
                  dialogTheme: moveraDialogThemeData(
                    ThemeData.light(useMaterial3: true),
                  ).dialogTheme,
                ),
            builder: (context, child) {
              return RideCheckScope(
                services: _rideCheck,
                child: DriverRuntimeScope(
                  session: _session,
                  homeBuilder: _home,
                  logout: _logout,
                  auth: _auth,
                  signInBuilder: _signIn,
                  account: DriverRuntimeConfig.current.authRequired
                      ? _account
                      : null,
                  child: DriverContentGate(
                    session: _session,
                    navigatorKey: _navigatorKey,
                    // Owner 2026-10-31 "Go back to before": the layout
                    // before "Map under the strip". SafeAreaFromPage stays:
                    // without viewport-fit=cover the page's insets are 0.
                    child: SafeAreaFromPage(
                      child: LayoutViewport(
                        child: Column(
                          children: [
                            // A live build (round 4) has an account: no demo
                            // banner, only the status-bar inset it would take.
                            if (DriverRuntimeConfig.current.authRequired)
                              const SafeArea(
                                bottom: false,
                                child: SizedBox.shrink(),
                              )
                            else
                              const DemoModeBanner(),
                            // The banner took the status-bar inset: the
                            // screens below must not pad for it again.
                            Expanded(
                              child: Builder(
                                builder: (viewport) => MediaQuery.removePadding(
                                  context: viewport,
                                  removeTop: true,
                                  child: child ?? const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            home: _root(),
          );
        },
      ),
    );
  }

  /// The first route: Home in the demo (MOVERA_AUTH_REQUIRED off, as the
  /// GitHub Pages build runs); with a session required, Sign in until the
  /// token store holds one.
  Widget _root() => DriverRuntimeConfig.current.authRequired
      ? DriverSessionGate(
          auth: _auth,
          homeBuilder: _home,
          signInBuilder: _signIn,
          account: _account,
        )
      : _home();

  Widget _signIn() => DriverSignIn(controller: _auth);

  /// Contract v0.18.3 R7: the explanation before the system asks, once the
  /// app has a screen to show it on.
  Future<bool> _explainPush() async {
    for (var i = 0; i < 50; i++) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        return showPushExplanation(context);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// A tap on a push: the bell list, which opens the notice's deep link.
  void _openPush(PushOpen open) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ServerNotificationsScreen(
            account: _account,
            openNotificationId: open.notificationId,
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Round 4: the server's session first, while the token is still there;
    // the tokens go whatever it answers. The demo (no session required,
    // none possible) keeps its logout as it was and never touches the
    // token store.
    if (DriverRuntimeConfig.current.authRequired) {
      // Offline on the server while the token is still there.
      await _live?.presence.goOffline().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      await _push?.signingOut();
      await _auth.signOut();
      _account.clear();
    }
    await PrefsActiveRideRepository.settle();
    await CompletionJournal.settle();
    await SettingsRepository.settle();
    await clearLocalUserData();
    // The language stays: a device setting (clearLocalUserData keeps it).
    // The saved category choice is gone with the settings (driver-82).
    DriverCategoryChoice.reset();
    _activeRide = PrefsActiveRideRepository();
    _waybills.reset();
    final dispatch = _dispatch;
    if (dispatch is DemoDispatchRepository) {
      dispatch.reset();
    }
    if (_safetyAlerts case final DemoSafetyAlertRepository demo) demo.reset();
    ScheduledRideStore.reset();
    // Per-driver state kept in memory: the next driver must not see these
    // notifications (rider pickup addresses) or documents in review.
    DriverNotificationFeed.instance.reset();
    DriverRemindersStore.instance.clear();
    OnboardingSettingsStore.instance.clear();
    LocalChatMessages.reset();
    // Nor the trip chats read from the server.
    _live?.chat.reset();
    // And today's destinations (driver-r4-11).
    DestinationModeSession.instance = DestinationModeSession();
    _session.reset();
    // Last: the resets above can make the old Home, still mounted under
    // Profile, post notices (driver-r5-27).
    IslandMessages.clear();
  }

  // Round 4 (live): the hold is the server's account state; the demo
  // keeps its hold with "Skip demo".
  Widget _home() => DriverHome(
    accountPending:
        !DriverRuntimeConfig.current.authRequired || _account.onHold,
    sessionController: _session,
    waybillRepository: _waybills,
    locationRepository: _location,
    routeRepository: _routing,
    dispatchRepository: _dispatch,
    homeConfigRepository: _homeConfig,
    activeRideRepository: _activeRide,
  );
}
