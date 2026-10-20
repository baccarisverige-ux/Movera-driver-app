import 'dart:async';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/core/session/driver_route_observer.dart';

import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/logging/global_error_hooks.dart';

import 'package:flutter/material.dart';
import 'package:movera/widgets/demo_mode_banner.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
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
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  validateDriverComposition(production: driverProductionRequested);
  installGlobalErrorHooks();
  unawaited(MapTrafficSetting.restore());
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
  }

  @override
  void dispose() {
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
                        Expanded(child: child ?? const SizedBox.shrink()),
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
    _activeRide = PrefsActiveRideRepository();
    _waybills.reset();
    final dispatch = _dispatch;
    if (dispatch is DemoDispatchRepository) {
      dispatch.reset();
    }
    _safetyAlerts.reset();
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
