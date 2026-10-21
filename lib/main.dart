import 'dart:async';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/core/session/driver_route_observer.dart';

import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/logging/global_error_hooks.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/widgets/demo_mode_banner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/settings/map_traffic_setting.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  validateDriverComposition(production: driverProductionRequested);
  installGlobalErrorHooks();
  unawaited(MapTrafficSetting.restore());
  // Round 4: the zone's default language, then the driver's saved choice.
  // A slow or broken store never holds the first frame for long.
  DriverLanguage.applyZone(const DriverHomeAdminContentService().languages);
  try {
    await DriverLanguage.restore().timeout(const Duration(seconds: 2));
  } catch (_) {
    // The zone default stays.
  }
  runApp(const MoveraApp());
}

/// App composition root.
///
/// Long-lived frontend dependencies are created here and injected down into
/// feature screens. When backend adapters replace the current frontend
/// implementations, screen code does not need to change.
class MoveraApp extends StatefulWidget {
  const MoveraApp({super.key, this.locationRepository});

  /// Defaults to the device GPS. Tests inject a scripted source so the app
  /// root never depends on host location services.
  final DriverLocationRepository? locationRepository;

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
  late final DemoSafetyAlertRepository _safetyAlerts;
  late final RideCheckServices _rideCheck;

  @override
  void initState() {
    super.initState();
    validateDriverComposition(production: driverProductionRequested);
    _sessionStore = MemoryDriverSessionRepository();
    _session = DriverSessionController(repository: _sessionStore);
    _waybills = InMemoryWaybillRepository.instance;
    _location = widget.locationRepository ?? const DriverLocationService();
    _routing = RoadRouteService();
    _dispatch = DemoDispatchRepository();
    _homeConfig = const LocalDriverHomeConfigRepository();
    _activeRide = PrefsActiveRideRepository();
    // Ride check alerts go to admin and Dispatch; demo outbox until a
    // backend exists.
    _safetyAlerts = DemoSafetyAlertRepository();
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
    _safetyAlerts.dispose();
    super.dispose();
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
            theme: ThemeData.light(useMaterial3: true)
                .copyWith(scaffoldBackgroundColor: AppColor.bg),
            builder: (context, child) {
              return RideCheckScope(
                services: _rideCheck,
                child: DriverRuntimeScope(
                  session: _session,
                  homeBuilder: _home,
                  logout: _logout,
                  child: LayoutViewport(
                    child: Column(
                      children: [
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
              );
            },
            home: _home(),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await PrefsActiveRideRepository.settle();
    await CompletionJournal.settle();
    await SettingsRepository.settle();
    await clearLocalUserData();
    MapTrafficSetting.reset();
    DriverLanguage.reset();
    // The saved category choice is gone with the settings (driver-82).
    DriverCategoryChoice.reset();
    _activeRide = PrefsActiveRideRepository();
    _waybills.reset();
    final dispatch = _dispatch;
    if (dispatch is DemoDispatchRepository) {
      dispatch.reset();
    }
    _safetyAlerts.reset();
    ScheduledRideStore.reset();
    // Per-driver state kept in memory: the next driver must not see these
    // notifications (rider pickup addresses) or documents in review.
    DriverNotificationFeed.instance.reset();
    DocumentExpiryStore.instance.reset();
    LocalChatMessages.reset();
    // And today's destinations (driver-r4-11).
    DestinationModeSession.instance = DestinationModeSession();
    _session.reset();
  }

  Widget _home() => DriverHome(
    accountPending: true,
    sessionController: _session,
    waybillRepository: _waybills,
    locationRepository: _location,
    routeRepository: _routing,
    dispatchRepository: _dispatch,
    homeConfigRepository: _homeConfig,
    activeRideRepository: _activeRide,
  );
}
