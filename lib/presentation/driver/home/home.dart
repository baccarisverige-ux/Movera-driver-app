import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/home/components/app_update_sheet.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/presentation/driver/sheets/sheet_trace.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'dart:async';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/map_preview_generation.dart';
import 'package:movera/core/navigation/coalescing_map_route_refresh.dart';
import 'package:movera/core/navigation/moving_route_refresh.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind, VelocityTracker;
import 'package:movera/core/navigation/route_camera_fit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/dispatch/claim_lock.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_destination_trips.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:movera/core/dispatch/destination_filter.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/presentation/driver/content/content_card.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/routing/route_maps.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:movera/presentation/driver/home/components/driving_time_row.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/widgets/movera_line_icon.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_confirm.dart';
import 'package:movera/presentation/driver/home/components/destination_island.dart';
import 'package:movera/presentation/driver/home/components/reservation_island_face.dart';
import 'package:movera/presentation/driver/home/components/home_map_layers.dart';
import 'package:movera/widgets/movera_destination_marker.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/documents/info_session_screen.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';
import 'package:movera/presentation/driver/home/components/home_reason_card.dart';
import 'package:movera/presentation/driver/auth/widgets/slow_server_note.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart'
    show LocationServiceDisabledException;
import 'package:movera/presentation/driver/vehicles/live_vehicles_screen.dart';
import 'package:movera/presentation/driver/account/join_fleet_screen.dart';
import 'package:movera/presentation/driver/account/start_company_screen.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:movera/presentation/driver/account/fleet_invitations.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/presentation/driver/home/components/destination_set_panel.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_side_hit_slop.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/island_waiting.dart';
import 'package:movera/core/island/island_waiting_signals.dart';
import 'package:movera/core/surge/surge_map.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';
import 'package:movera/presentation/driver/home/components/trip_problem_sheet.dart';
import 'package:movera/presentation/driver/home/components/driver_sheet_nav.dart';
import 'package:movera/presentation/driver/home/components/driver_suspended_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/home_offer_sheet.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/route_fade.dart';
import 'package:movera/presentation/driver/my%20queue%20position/components/in_airport_queue.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';
import 'package:movera/widgets/offer_route_line.dart';
import 'package:movera/widgets/offer_route_marks.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/presentation/driver/sheets/movera_snap_sheet_controller.dart';
import 'package:movera/presentation/driver/overlays/map_overlay_insets.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

part 'home_offer_radar.dart';
part 'home_map_sheet.dart';
part 'home_reservation.dart';
part 'home_scheduled.dart';
part 'home_offer_rules.dart';
part 'home_account.dart';
part 'home_exclusive.dart';
part 'home_start_position.dart';
part 'home_offer_route.dart';
part 'home_offer_sound.dart';
part 'home_back.dart';
part 'home_recovery.dart';
part 'home_live.dart';
part 'home_radar_motion.dart';
part 'home_updates.dart';
part 'home_online_gate.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({
    super.key,
    this.initialOnline = false,
    this.accountPending = false,
    this.locationRepository,
    this.routeRepository,
    this.waybillRepository,
    this.sessionController,
    this.dispatchRepository,
    this.homeConfigRepository,
    this.activeRideRepository,
  });

  final bool initialOnline;
  final bool accountPending;
  final DriverLocationRepository? locationRepository;
  final RouteRepository? routeRepository;
  final WaybillRepository? waybillRepository;
  final DriverSessionController? sessionController;
  final DispatchRepository? dispatchRepository;
  final DriverHomeConfigRepository? homeConfigRepository;
  final ActiveRideRepository? activeRideRepository;

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  bool _routeVisible = true;
  bool _foreground = true;
  int _locationEpoch = 0;
  bool get _liveVisible => _routeVisible && _foreground;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _HomeAccount(
      this,
    )._refreshLiveBadgesOnce(); // round 4b: the scope is read here, not in initState
    final route = ModalRoute.of(context);
    if (route != null) {
      driverRouteObserver.subscribe(this, route);
      driverRouteObserver.pages.subscribe(_pageCover, route);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _goOnlinePulseController.stop();
      _radarSweepController.stop();
      _radarMotionController.stop();
    }
  }

  late final _pageCover = PageCover(
    covered: () => _HomeRoutes(this)._pageCovered(),
    uncovered: () => _HomeRoutes(this)._pageUncovered(),
  );
  @override
  void didPopNext() {
    _HomeRoutes(this)._backOnTop();
    _HomeAccount(this)._refreshLiveBadges();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive is still on screen: a call banner, a system dialog (driver-65).
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed) {
      _HomeRecovery(this)._rearmWallClockTimers();
      _HomeAccount(this)._refreshLiveBadges();
    }
    if (_liveVisible) {
      _HomeUpdates(this)._resumeHomeUpdates();
    } else {
      _HomeUpdates(this)._pauseHomeUpdates();
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// D-11: one Home map (and camera) for the sheet, the Radar list and the destination panel.
  final GlobalKey _homeMapKey = GlobalKey(debugLabel: 'home-map');
  final PanelController _panelController = PanelController();
  final PanelController _destinationPanelController = PanelController();
  late final AnimationController _goOnlinePulseController;
  late final AnimationController _radarSweepController;

  /// R15-4: one 10 s loop for the Radar's soft sweep (5 turns with trips
  /// found, 3 while scanning) and the black MATCH pulse (4 per loop).
  late final AnimationController _radarMotionController;
  final RadarOfferSound _offerSound = RadarOfferSound();
  bool _offerSoundQueued = false;
  double _radarWedge({required bool found}) =>
      (_radarMotionController.value * (found ? 5 : 3)) % 1;
  double get _matchPulse {
    final t = (_radarMotionController.value * 4) % 1;
    final x = t < 0.35
        ? t / 0.35
        : t < 0.7
        ? 1 - (t - 0.35) / 0.35
        : 0.0;
    return 0.5 - 0.5 * math.cos(math.pi * x);
  }

  Timer? _onlineTransitionTimer;
  final _HomeGateState _gate = _HomeGateState(); // home_online_gate.dart

  /// Puts the top island back on the hidden total after 5 s untouched.
  Timer? _islandIdleTimer;

  /// Top island at launch: 0 small (arrow and menu), 1 grown to full
  /// width, 2 its screen on.
  int _islandWake = 0;
  Timer? _islandWakeTimer;

  /// Ends the "updating" dots once the last trip's money has settled.
  Timer? _lastTripSettleTimer;

  /// Trip whose money is still updating, if any.
  String? _lastTripPendingId;

  /// Message on the island's screen right now; each gets its own number
  /// so the screen plays its switch between two messages too.
  IslandMessage? _islandMessage;
  int _islandMessageSeq = 0;
  Timer? _islandMessageTimer;

  /// R13-1: "Finding trips" and short messages while waiting online.
  late final IslandWaitingController _islandWaiting = IslandWaitingController(
    tips: () => _HomeMapSheet(this)._waitingTips(),
  )..addListener(_islandWaitingListener);
  void _islandWaitingListener() {
    if (mounted) {
      setState(() {});
    }
  }

  void _islandMessagesListener() =>
      _HomeMapSheet(this)._onIslandMessagesChanged();
  void _lastTripListener() => _HomeMapSheet(this)._onLastTripChanged();
  void _rideCheckGateListener() => _HomeOfferRadar(this)._onRideCheckGate();
  Timer? _homeSheetPositionGuardTimer;
  Timer? _offerSimulationTimer;
  Timer? _directOfferTimer;
  Timer? _outsideOfferTimeoutTimer;
  Timer? _expandedDirectOfferTimer;
  Timer? _reservationOfferTimer;
  Timer? _reservationPopupTimer;

  /// The reservation sent to Home: it rises from the dock while online.
  final _HomeReservationState _reservation = _HomeReservationState();

  /// The smart gap before accepted rides, and rides Movera assigns.
  final _HomeScheduledState _scheduled = _HomeScheduledState();
  final _HomeAccountState _account = _HomeAccountState();
  late final _HomeExclusiveState _exclusive = _HomeExclusiveState(this);
  Timer? _radarOfferTwoTimer;
  Timer? _radarOfferThreeTimer;
  Timer? _homeRadarMatchResolutionTimer;
  Timer? _homeRadarNoticeTimer;
  Timer? _homeRadarExternalClaimTimer;
  Timer? _homeRadarExternalClaimCleanupTimer;
  final Map<String, Timer> _homeRadarLostMatchTimers = <String, Timer>{};
  final Map<String, Timer> _radarOfferTimeoutTimers = <String, Timer>{};
  final Map<String, _HomeRadarMatchState> _homeRadarMatchStates =
      <String, _HomeRadarMatchState>{};
  String? _homeRadarMatchingOfferId;

  /// A won offer whose trip opens as soon as Home is on top: a Radar
  /// Match, or an Exclusive Accept won while a screen covered Home.
  _HomeDirectOffer? _claimedHomeOffer;

  /// How [_claimedHomeOffer]'s trip was matched; null for a Radar Match.
  String? _claimedHomeSource;

  /// Decision 3: a rule took the driver offline while a claim was with
  /// dispatch; it applies once the claim is answered.
  bool _offlineHeld = false;
  late final DriverLocationRepository _driverLocationService;
  late final RouteRepository _roadRouteService;
  late final WaybillRepository _waybills;
  late final DispatchRepository _dispatch;
  SurgeMapController? _surgeMap; // home_updates.dart
  Set<Polygon> _surgePolygons = const {};
  StreamSubscription<List<RideOffer>>? _radarSubscription;
  StreamSubscription<OfferWithdrawal>? _withdrawalSubscription;
  List<RideOffer> _latestDispatchOffers = const <RideOffer>[];
  late final bool _ownsDispatch;
  late final DriverHomeAdminConfig _adminHomeConfig;
  static const String _currentAppVersion = '1.0.0';
  bool _updatePromptShown = false;

  GoogleMapController? _mapController;
  final DriverCameraController _camera = DriverCameraController();
  GoogleDriverCameraPort? _cameraPort;
  RoadRoute? _cameraRoute;
  DriverLocation? _cameraLocation;
  StreamSubscription<DriverLocation>? _driverLocationSubscription;
  bool _hasLiveDriverLocation = false;
  bool _didCenterOnLiveLocation = false;
  BitmapDescriptor _driverVehicleIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueGreen,
  );
  double _driverHeading = 0;
  bool isPanelOpen = false;
  bool _blockMapGestures = false;
  bool _sheetPointerActive = false;
  double _mainPanelPosition = 0;
  final ValueNotifier<double> _panelSlidePosition = ValueNotifier<double>(0);

  /// Dispatch's time to accept an Exclusive offer (15 s by default).
  static Duration get _outsideOfferLifetime =>
      DriverOfferRules.current.exclusiveAcceptTime;

  /// How long a Radar trip can be picked once it shows in the Home list:
  /// Dispatch's time on the radar (15 s by default).
  static Duration get _radarOfferPickWindow =>
      DriverOfferRules.current.radarTime;
  static const int _maxHomeRadarOffers = 4;
  double _sheetPointerVelocity = 0;
  double _sheetPointerTravel = 0;
  double _sheetPointerStartPos = 0;
  double _sheetPointerLastY = 0;
  VelocityTracker _sheetVelocity = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );
  double _lastSnapHapticAt = -1;
  late final MoveraSnapSheetController _snapSheet;
  bool showRideRequests = false;

  /// The Radar list is sending a Match: Back keeps it open until dispatch
  /// answers, so a won trip still opens.
  final ValueNotifier<bool> _radarListClaiming = ValueNotifier<bool>(false);
  final RadarHiddenTrips _radarHidden = RadarHiddenTrips(); // u159
  /// Decision 4: the offer settings are locked while a claim is out.
  void _syncClaimLock() =>
      ClaimLock.set(mounted && _HomeOfferRules(this)._claimInFlight);
  bool isAccountActivated = true;
  bool _activationHold = false;
  late final DriverSessionController _driverSession;
  late final bool _ownsDriverSession;
  bool get _isOnline =>
      _liveVisible && _recoveryResolved && _driverSession.availableForOffers;
  bool get _isGoingOnline => _driverSession.isGoingOnline;
  // Offer orchestration lives in an extension, which cannot call setState.
  void _rebuild(VoidCallback update) {
    setState(update);
    _syncClaimLock();
  }

  void openDestinationPanel() => _HomeMapSheet(this).openDestinationPanel();
  bool _hasRideOffers = false;

  /// Green dot on the scheduled icon: on while any reservation request is
  /// still unanswered.
  bool get _hasScheduledRideOffers =>
      _adminHomeConfig.scheduledRides.hasOpenRequests &&
      ScheduledRideStore.openRequests.value > 0;

  /// What the top island's screen shows; a tap moves to the next face.
  _IslandFace _islandFace = _IslandFace.hidden;
  _HomeDirectOffer? _outsideRadarOffer;

  /// Demo: once an Exclusive offer was accepted, the next one is the cash one.
  bool _exclusiveDemoTaken = false;

  /// Q16: admin direct assigns already shown as Exclusive offers.
  final Set<String> _adminAssignsShown = <String>{};
  final List<_HomeDirectOffer> _radarHomeOffers = <_HomeDirectOffer>[];
  final List<_HomeDirectOffer> _pendingRadarHomeOffers = <_HomeDirectOffer>[];

  /// Radar offer opened in the compact list; null opens the first one.
  String? _radarExpandedOfferId;

  /// Why a Radar offer left the list, when it was not simply taken by
  /// another driver while this driver looked at it.
  final Map<String, _RadarOfferGone> _homeRadarGoneReasons =
      <String, _RadarOfferGone>{};

  /// Radar trips whose pick window ran out: still listed, Match faded.
  final Set<String> _radarOfferExpired = <String>{};

  /// D-04: when each listed Radar trip's pick window ends; a pause keeps it.
  final Map<String, DateTime> _radarOfferDeadlines = <String, DateTime>{};
  bool _destinationModeActive = false;
  bool _soonReservationReady = false;
  String? _destinationAddress;
  LatLng? _destinationPosition;
  DriverDestinationResult? _destinationTrip; // Confirmed distance and time.
  Timer? _destinationLimitTimer; // Admin's time limit (R13-9).
  _HomeDirectOffer? _destinationDemoExclusive; // Demo trip toward it.

  // ignore: prefer_final_fields
  Set<Marker> _markers = {};
  Set<Marker> _directOfferRouteMarkers = {};
  Set<Polyline> _directOfferRoutePolylines = {};
  Set<Marker> _destinationRouteMarkers = {};
  Set<Polyline> _destinationRoutePolylines = {};
  double _routeZoomStep = DriverRouteStyle.defaultZoom;
  bool _isDirectOfferRoutePreview = false;
  final MapPreviewGeneration _mapPreviews = MapPreviewGeneration();
  final _OfferRouteFrame _offerRouteFrame = _OfferRouteFrame();
  // Separate ownership for frequently refreshed GPS-to-destination roads.
  // An old routing response must never replace a route from a newer fix.
  final MapPreviewGeneration _destinationRoadRequests = MapPreviewGeneration();
  final CoalescingMapRouteRefresh _destinationRoadRefresh =
      CoalescingMapRouteRefresh();
  final MovingRouteRefresh _destinationRouteRefetch = MovingRouteRefresh();

  // Placeholder only: the map and car wait for a known position.
  static const LatLng _fallbackDriverPosition = LatLng(59.3293, 18.0686);

  /// The last position the app sent the server, else the fallback, until
  /// this screen's own GPS read lands.
  late LatLng _driverPosition =
      LiveDriverServices.instance?.reporter.lastKnownPoint?.toLatLng() ??
      _fallbackDriverPosition;
  bool _startPositionKnown = false, _startLocationFailed = false;
  Timer? _startWait;
  // Opens on the area around the driver (~10 km across), nearly flat.
  CameraPosition get _initialPosition => CameraPosition(
    target: _driverPosition,
    zoom: DriverCameraPolicy.exploreZoom,
    tilt: DriverCameraPolicy.tiltForZoom(DriverCameraPolicy.exploreZoom),
  );

  static const _HomeDirectOffer _veryCloseDirectOffer = _HomeDirectOffer(
    id: 'home-direct-close',
    category: 'Comfort',
    reason: ExclusiveReasons.nearby,
    riderName: 'Nils',
    riderTrips: 93,
    fare: '104,80 kr',
    rating: '4.96',
    pickupMinutes: 3,
    pickupKm: 0.9,
    tripMinutes: 14,
    tripKm: 7.6,
    pickup: 'Kungsgatan 42, Stockholm',
    dropoff: 'Hornstull, Stockholm',
    pickupPosition: LatLng(59.3343, 18.0615),
    dropoffPosition: LatLng(59.3157, 18.0335),
  );

  static const _HomeDirectOffer _expandedDirectOffer = _HomeDirectOffer(
    id: 'home-direct-expanded',
    category: 'Premium',
    reason: ExclusiveReasons.bestMatch,
    riderName: 'Maja',
    riderTrips: 175,
    fare: '176,20 kr',
    rating: '4.98',
    pickupMinutes: 8,
    pickupKm: 3.3,
    tripMinutes: 21,
    tripKm: 13.8,
    pickup: 'Odengatan 63, Stockholm',
    dropoff: 'Solna centrum, Solna',
    pickupPosition: LatLng(59.3449, 18.0472),
    dropoffPosition: LatLng(59.3603, 18.0009),
    cash: true,
    // A rider promotion: the rider pays 150 of the 176,20 kr fare; the
    // driver's 132,15 kr share means they owe Movera 17,85.
    cashToCollect: '150,00 kr',
  );

  late final SheetTrace _sheetTrace = SheetTrace(
    'home',
    () => _panelController.isAttached ? _panelController.panelPosition : 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    isAccountActivated =
        DriverRuntimeConfig.current.skipAccountActivation ||
        !widget.accountPending;
    _ownsDriverSession = widget.sessionController == null;
    _driverSession =
        widget.sessionController ??
        DriverSessionController(initialOnline: widget.initialOnline);
    _driverSession.addListener(_onDriverSessionChanged);
    _radarListClaiming.addListener(_syncClaimLock);
    DrivingTimeClock.instance.sync(online: _driverSession.isOnline);
    _driverLocationService =
        widget.locationRepository ?? const DriverLocationService();
    _roadRouteService = widget.routeRepository ?? RoadRouteService();
    _waybills = widget.waybillRepository ?? InMemoryWaybillRepository.instance;
    _ownsDispatch = widget.dispatchRepository == null;
    _dispatch = widget.dispatchRepository ?? DemoDispatchRepository();
    _HomeUpdates(this)._startSurgeMap();
    if (widget.sessionController != null && widget.initialOnline) {
      _driverSession.setOnline(true);
    }
    _settleServerAfterStart();
    _adminHomeConfig =
        (widget.homeConfigRepository ?? const LocalDriverHomeConfigRepository())
            .load();
    if (_adminHomeConfig.destinationMode case final rules?) {
      DestinationModeRules.current = rules;
    }
    if (_adminHomeConfig.nextTrips case final rules?) {
      NextTripRules.current = rules;
    }
    ScheduledRideStore.applyAdmin(_adminHomeConfig.scheduledRides);
    ScheduledRideStore.openRequests.addListener(_onScheduledRequests);
    _HomeAccount(this)._startAccount();
    _HomeOnlineGate(this)._startOnlineGate();
    _goOnlinePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _radarMotionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _HomeRadarMotion(this)._syncRadarAnimation(checkMotion: false);
    _snapSheet = MoveraSnapSheetController(
      panel: _panelController,
      vsync: this,
      reduceMotion: () => mounted && MediaQuery.disableAnimationsOf(context),
    );
    _HomeStartPosition(this)._restoreStartPosition();
    _HomeMapSheet(this)._prepareDriverVehicleMarker();
    _HomeMapSheet(this)._startDriverLocation();
    _HomeMapSheet(this)._startIslandWake();
    _waybills.lastListenable.addListener(_lastTripListener);
    IslandMessages.changes.addListener(_islandMessagesListener);
    RideCheckGate.listenable.addListener(_rideCheckGateListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreActiveRideIfNeeded());
      _HomeMapSheet(this)._maybeShowAppUpdatePrompt();
      _HomeMapSheet(this)._showNextIslandMessage();
      _HomeReservation(this)._scheduleReservationPopup();
      _HomeScheduled(this)._startScheduled();
    });
  }

  bool _didAttemptActiveRideRestore = false;
  bool _recoveryResolved = false;

  Future<void> _restoreActiveRideIfNeeded() async {
    if (_didAttemptActiveRideRestore) {
      return;
    }
    _didAttemptActiveRideRestore = true;
    final repo = widget.activeRideRepository;
    if (repo == null) {
      if (mounted) {
        setState(() => _recoveryResolved = true);
      }
      return;
    }
    PersistedActiveRide? snapshot;
    try {
      final journal = await CompletionJournal(active: repo).reconcile();
      if (mounted && journal == JournalReplayOutcome.quarantinedConflict) {
        IslandMessages.show(HomeIslandNotices.newerTripKept);
      } else if (mounted &&
          journal == JournalReplayOutcome.quarantinedCorrupt) {
        IslandMessages.show(HomeIslandNotices.recordSetAside);
      }
      snapshot = await repo.read() ?? await _HomeLive(this)._serverActiveTrip();
    } on ActiveRideStorageUnavailable {
      // driver-u112: blocked storage holds no trip to recover; going online
      // stays possible, and Retry reads again.
      _didAttemptActiveRideRestore = false;
      if (!mounted) {
        return;
      }
      setState(() => _recoveryResolved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr.tripStorageUnavailable),
          persist: false,
          duration: _HomeRoutes.storageRetryShown,
          action: SnackBarAction(
            label: tr.retry,
            onPressed: () => _HomeRoutes(this)._retryActiveRideRestore(),
          ),
        ),
      ); // driver-r5-37
      return;
    } on ActiveRideUnreadable {
      _didAttemptActiveRideRestore = false;
      if (mounted) {
        await _offerUnreadableTripClosure(repo);
      }
      return;
    } catch (_) {
      _didAttemptActiveRideRestore = false;
      if (mounted) {
        _HomeMapSheet(this)._tripProblem(
          HomeIslandNotices.recoveryFailed,
          tr.savedTripCouldNotBeOpened,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (snapshot == null) {
      setState(() => _recoveryResolved = true);
      return;
    }

    if (!snapshot.isFresh || !snapshot.hasVerifiedEndpoints) {
      final resume = await _HomeBack(this)._askUnresolvedTrip(snapshot);
      if (!mounted) {
        return;
      }
      if (resume != true) {
        return _HomeRecovery(this)._closeSavedTrip(repo, snapshot);
      }
    }

    setState(() => _recoveryResolved = true);
    DriverLog.info(
      'Restoring active ride ${snapshot.tripId} at ${snapshot.stage.name}',
    );
    _waybills.beginCurrent(_waybillFromSnapshot(snapshot));
    final next = snapshot.next;
    if (next != null) {
      _waybills.secureNext(_waybillFromQueued(next));
    }

    if (!mounted) {
      return;
    }
    pushSingle(
      context,
      BottomToTopTransition(
        AcceptRide.fromPersisted(
          snapshot,
          waybillRepository: _waybills,
          sessionController: _driverSession,
          locationRepository: _driverLocationService,
          routeRepository: _roadRouteService,
          activeRideRepository: repo,
          dispatchRepository: _dispatch,
        ),
      ),
    );
  }

  /// Unreadable data never decodes on retry; offer an explicit closure that
  /// keeps the raw record in quarantine instead of a dead-end Retry loop.
  Future<void> _offerUnreadableTripClosure(ActiveRideRepository repo) async {
    final close = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MoveraDialogTheme(
        child: AlertDialog(
          title: Text(tr.savedTripCannotBeRead),
          content: Text(tr.tripSavedOnThisDeviceIs),
          actions: [
            TextButton(
              onPressed: () => popOwned(context, false),
              child: Text(tr.notNow),
            ),
            FilledButton(
              onPressed: () => popOwned(context, true),
              child: Text(tr.closeUnreadableTrip),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (close != true || repo is! UnreadableRideRecovery) {
      _HomeMapSheet(this)._tripProblem(
        HomeIslandNotices.unreadableTripOpen,
        tr.savedTripCouldNotBeRead,
        action: tr.review,
      );
      return;
    }
    try {
      await (repo as UnreadableRideRecovery).quarantineUnreadable();
    } catch (_) {
      if (mounted) {
        _HomeMapSheet(this)._tripProblem(
          HomeIslandNotices.unreadableTripNotClosed,
          tr.unreadableTripCouldNotBeClosed,
        );
      }
      return;
    }
    await _restoreActiveRideIfNeeded();
  }

  WaybillRecord _waybillFromSnapshot(PersistedActiveRide snapshot) {
    return WaybillRecord(
      tripId: snapshot.tripId,
      statusLabel: WaybillRecord.currentTrip,
      issuedAt:
          snapshot.acceptedAt ??
          snapshot.savedAt ??
          DateTime.now(), // driver-u114
      fare: snapshot.fare ?? '—',
      riderFare: snapshot.riderFare,
      driverBonus: WaybillRecord.bonusLabel(snapshot.driverBonus),
      service: snapshot.category ?? 'Movera',
      riderName: snapshot.riderName ?? WaybillRecord.riderUnavailable,
      pickup: snapshot.pickupAddress ?? '',
      dropoff: snapshot.dropoffAddress ?? '',
      source: snapshot.matchedVia ?? WaybillRecord.moveraRadarSource,
      driverName:
          WaybillRecord.moveraDriverName, // driver-r5-38: as a live trip
      vehicle: WaybillRecord.vehicleUnavailable,
      licensePlate: WaybillRecord.plateUnavailable,
      passengerCapacity: 4,
      paidByCash: snapshot.paidByCash,
    );
  }

  WaybillRecord _waybillFromQueued(PersistedQueuedTrip next) {
    return WaybillRecord(
      tripId: next.tripId,
      statusLabel: WaybillRecord.nextTripSecured,
      issuedAt: DateTime.now(),
      fare: next.fare,
      service: next.category,
      riderName: next.riderName,
      pickup: next.pickup,
      dropoff: next.dropoff,
      source: 'Movera Radar',
      driverName: WaybillRecord.moveraDriverName,
      vehicle: WaybillRecord.vehicleUnavailable,
      licensePlate: WaybillRecord.plateUnavailable,
      passengerCapacity: 4,
    );
  }

  void _onDriverSessionChanged() {
    DrivingTimeClock.instance.sync(online: _driverSession.isOnline);
    _HomeUpdates(this)._syncSurgeMap();
    _HomeAccount(this)._syncDrivingLimit();
    if (!mounted) {
      return;
    }
    _HomeRadarMotion(this)._syncRadarAnimation();
    _HomeOfferRules(
      this,
    )._releaseHeldOffline(); // Decision 3: a won trip began.
    _HomeScheduled(this)._recheckLateScheduled();
    if (_driverSession.activeTripId != null && _radarHomeOffers.isNotEmpty) {
      _HomeOfferRadar(this)._cancelAllOfferTimers();
      _HomeOfferRadar(this)._clearHomeOffersAfterFrame();
    } // u116
    if (_driverSession.consumeResumeHomeAfterTrip()) {
      setState(() {
        showRideRequests = false;
      });
      return;
    }
    setState(() {});
  }

  String get _destinationShortLabel {
    final address = _destinationAddress?.trim();
    if (address == null || address.isEmpty) {
      return tr.destination;
    }
    final firstPart = address.split(',').first.trim();
    if (firstPart.length <= 24) {
      return firstPart;
    }
    return '${firstPart.substring(0, 21)}…';
  }

  void _skipActivationDemo() {
    setState(() {
      isAccountActivated = true;
      _activationHold = false;
    });
    if (_panelController.isAttached) {
      unawaited(_snapSheet.springTo(0));
    }
  }

  void _openActivationSupport() {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
    );
  }

  bool hideMainPanel = false;
  Timer? _destinationOpenTimer;

  @override
  Widget build(BuildContext context) {
    _syncOfferSound();
    // R15-5: any tap on the screen stops the radar sound.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _offerSound.tap(),
      child: LayoutViewport(
        // UI-03: Back closes the overlay on top before it leaves Home.
        child: _HomeBack(this)._backScope(
          Scaffold(
            key: _scaffoldKey,
            onDrawerChanged: (open) =>
                _HomeExclusive(this)._drawerChanged(open),
            drawer: DriverSideMenu(
              isOnline: _isOnline,
              accountActive: isAccountActivated,
              dispatchRepository: _dispatch,
            ),
            body: showRideRequests
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      AbsorbPointer(
                        child: _HomeMapSheet(this)._buildRadarMapBackdrop(),
                      ),
                      ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 9.5, sigmaY: 9.5),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(
                                    0xFF172027,
                                  ).withValues(alpha: 0.46),
                                  const Color(
                                    0xFF6F7D80,
                                  ).withValues(alpha: 0.16),
                                  const Color(
                                    0xFFF4F7F8,
                                  ).withValues(alpha: 0.24),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      PointerInterceptor(child: const SizedBox.expand()),
                      RideRequests(
                        destinationModeActive: _destinationModeActive,
                        destinationAddress: _destinationAddress,
                        destinationPosition: _destinationPosition,
                        sessionController: _driverSession,
                        waybillRepository: _waybills,
                        locationRepository: _driverLocationService,
                        routeRepository: _roadRouteService,
                        dispatchRepository: _dispatch,
                        activeRideRepository: widget.activeRideRepository,
                        offerFilter: _HomeOfferRules(this)._rideAllowed,
                        followsDestination: (o) => _HomeOfferRadar(
                          this,
                        )._followsDestination(o.dropoffPosition.toLatLng()),
                        towardPickupTime: _HomeScheduled(
                          this,
                        )._towardPickupTime,
                        claimPending: _radarListClaiming,
                        hiddenTrips: _radarHidden,
                        onCloseRides: (hasOffers) {
                          setState(() {
                            showRideRequests = false;
                            _hasRideOffers =
                                hasOffers || _radarHomeOffers.isNotEmpty;
                          });
                        },
                      ),
                    ],
                  )
                : hideMainPanel
                ? DestinationSetPanel(
                    key: const ValueKey<String>('destination-set-panel'),
                    address: _destinationAddress?.trim() ?? '',
                    controller: _destinationPanelController,
                    onClose: () {
                      setState(() {
                        hideMainPanel = false;
                      });
                    },
                    body: _HomeMapSheet(this).body(isDestinationPanel: true),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      SlidingUpPanel(
                        color: Colors.transparent,
                        backdropColor: Colors.transparent,
                        backdropOpacity: 0,
                        backdropEnabled: false,
                        backdropTapClosesPanel: false,
                        controller: _panelController,
                        margin: EdgeInsets.all(0),
                        minHeight: MoveraSheetMetrics.collapsedHeight,
                        padding: EdgeInsets.zero,
                        boxShadow: [],
                        isDraggable: _outsideRadarOffer == null,
                        // Our spring settles the sheet (see _snapHomeSheet): closed or
                        // open, never in between.
                        panelSnapping: false,
                        defaultPanelState: PanelState.CLOSED,
                        maxHeight: _HomeMapSheet(
                          this,
                        )._homeExpandedHeight(context),
                        // The map rises with the sheet, about a third as far, on the
                        // same spring.
                        parallaxEnabled: true,
                        parallaxOffset: 0.3,
                        onPanelSlide: (double pos) {
                          _mainPanelPosition = pos;
                          _panelSlidePosition.value = pos;
                          if (!_sheetPointerActive) {
                            _HomeMapSheet(
                              this,
                            )._scheduleHomeSheetPositionGuard();
                          }
                          if (pos > 0.04) {
                            _HomeMapSheet(
                              this,
                            )._closeHomeFloatingPopupsForSheet();
                          }
                          final nextPanelOpen = pos > 0.3;
                          // A settled sheet covers only its own region. The exposed map
                          // remains pinchable; block input only during a sheet drag.
                          final nextBlockMap = _sheetPointerActive;
                          if (isPanelOpen != nextPanelOpen ||
                              _blockMapGestures != nextBlockMap) {
                            setState(() {
                              isPanelOpen = nextPanelOpen;
                              _blockMapGestures = nextBlockMap;
                            });
                          }
                        },
                        onPanelOpened: () {
                          _homeSheetPositionGuardTimer?.cancel();
                          _mainPanelPosition = 1;
                          _panelSlidePosition.value = 1;
                          _HomeMapSheet(
                            this,
                          )._closeHomeFloatingPopupsForSheet();
                          _HomeMapSheet(
                            this,
                          )._setMapGesturesBlocked(_sheetPointerActive);
                        },
                        onPanelClosed: () {
                          _homeSheetPositionGuardTimer?.cancel();
                          _mainPanelPosition = 0;
                          _panelSlidePosition.value = 0;
                          _sheetPointerActive = false;
                          if (isPanelOpen) {
                            setState(() {
                              isPanelOpen = false;
                            });
                          }
                          _HomeMapSheet(this)._setMapGesturesBlocked(false);
                        },
                        // Account on hold keeps its red dock face.
                        collapsed: _HomeMapSheet(this)._inactiveDock(),
                        // The dock is the sheet's own bottom: it never moves or fades,
                        // so the sheet keeps one shape from closed to open.
                        footer: _HomeMapSheet(this)._homeDockFooter(),

                        panelBuilder: (ScrollController sc) =>
                            PointerInterceptor(
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: _HomeMapSheet(
                                  this,
                                )._onSheetPointerDown,
                                onPointerMove: _HomeMapSheet(
                                  this,
                                )._onSheetPointerMove,
                                onPointerUp: _HomeMapSheet(
                                  this,
                                )._onSheetPointerEnd,
                                onPointerCancel: _HomeMapSheet(
                                  this,
                                )._onSheetPointerEnd,
                                child: _activationHold && !isAccountActivated
                                    ? _HomeMapSheet(this)._inactiveSheetFace()
                                    : _HomeMapSheet(this).panelColumn(sc),
                              ),
                            ),
                        body: Stack(
                          fit: StackFit.expand,
                          children: [
                            AbsorbPointer(
                              absorbing: _blockMapGestures,
                              child: _HomeMapSheet(this).body(),
                            ),
                            _HomeMapSheet(this)._homeMapDim(),
                          ],
                        ),
                      ),
                      _HomeOnlineGate(this)._reasonLayer(), // over radar
                      _HomeMapSheet(this)._homeRadarLayer(),
                      // A reservation request: its sheet over the dock, its orb on top.
                      _HomeReservation(this)._reservationLayer(),
                      // An Exclusive offer: the same sheet, its grey orb on top.
                      _HomeExclusive(this)._exclusiveLayer(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _goOnline() {
    if (_driverSession.isSuspended) {
      IslandMessages.show(HomeIslandNotices.accountOnHold);
      unawaited(showDriverSuspendedSheet(context));
      return;
    }
    if (!_recoveryResolved) {
      _HomeMapSheet(this)._tripProblem(
        HomeIslandNotices.recoveryPending,
        tr.finishOrCloseSavedTripBefore,
        action: tr.openSavedTrip,
      );
      return;
    }
    if (!isAccountActivated) {
      setState(() => _activationHold = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_panelController.isAttached) {
          return;
        }
        unawaited(_snapSheet.springTo(0.28));
      });
      return;
    }
    if (_HomeAccount(this)._blocksGoingOnline()) {
      return;
    }
    if (_HomeOnlineGate(this)._blocksOnline()) {
      return;
    }

    _onlineTransitionTimer?.cancel();
    _offerSimulationTimer?.cancel();
    _directOfferTimer?.cancel();
    _HomeOfferRadar(this)._cancelAllOfferTimers();
    _expandedDirectOfferTimer?.cancel();
    _radarOfferTwoTimer?.cancel();
    _radarOfferThreeTimer?.cancel();

    setState(() {
      _driverSession.beginGoingOnline();
      _hasRideOffers = false;
      _islandFace = _IslandFace.hidden;
      _outsideRadarOffer = null;
      _radarHomeOffers.clear();
      _pendingRadarHomeOffers.clear();
      _soonReservationReady = false;
    });
    _HomeOfferRadar(this)._clearDirectOfferRoute();
    unawaited(_HomeMapSheet(this)._startDriverLocation(moveCamera: true));
    IslandMessages.show(HomeIslandNotices.online);
    // A live build asks the server while the switch animates.
    final serverAnswer = _HomeLive(this)._askServerOnline();

    _onlineTransitionTimer = Timer(
      const Duration(milliseconds: 1400),
      () async {
        if (!mounted) {
          return;
        }
        if (serverAnswer != null &&
            !await _HomeLive(this)._serverAgreed(serverAnswer)) {
          return;
        }
        setState(() {
          _driverSession.completeGoingOnline();
        });
        _HomeOfferRadar(this)._scheduleVisibleOffers();
      },
    );
  }

  Future<void> _goOffline({bool notice = true}) async {
    final radarListOpen = showRideRequests; // driver-u118: it closes too.
    _destinationOpenTimer?.cancel();
    if (notice) {
      IslandMessages.show(HomeIslandNotices.offline);
    }
    _HomeLive(this)._tellServerOffline();
    hideMainPanel = false;
    unawaited(_radarSubscription?.cancel() ?? Future<void>.value());
    _radarSubscription = null;
    unawaited(_withdrawalSubscription?.cancel());
    _latestDispatchOffers = const <RideOffer>[];
    _onlineTransitionTimer?.cancel();
    _offerSimulationTimer?.cancel();
    _directOfferTimer?.cancel();
    _HomeOfferRadar(this)._cancelAllOfferTimers();
    _expandedDirectOfferTimer?.cancel();
    _radarOfferTwoTimer?.cancel();
    _radarOfferThreeTimer?.cancel();
    _offlineHeld = false;

    setState(() {
      _driverSession.setOnline(false);
      _hasRideOffers = false;
      _outsideRadarOffer = null;
      _radarHomeOffers.clear();
      _pendingRadarHomeOffers.clear();
      _destinationModeActive = false;
      _destinationAddress = null;
      _destinationPosition = null;
      _destinationRouteMarkers = {};
      _destinationRoutePolylines = {};
      _soonReservationReady = false;
      showRideRequests = false;
    });
    _destinationLimitTimer?.cancel();
    DestinationModeSession.instance.ended();
    _HomeMapSheet(this)._clearDemoDestinationTrips();
    _HomeOfferRadar(this)._clearDirectOfferRoute();
    if (!radarListOpen) {
      await _HomeMapSheet(this)._closeDriverSheet();
    } // Its sheet is not mounted.
  }

  void _openRideOffers() {
    if (_mainPanelPosition > 0.04 || isPanelOpen) {
      return;
    }
    setState(() {
      showRideRequests = true;
      _hasRideOffers = _radarHomeOffers.isNotEmpty;
    });
  }

  void _onScheduledRequests() {
    if (mounted) {
      _HomeReservation(this)._onScheduledRequestsChanged();
    }
  }

  void _openScheduledRides() {
    pushSingle(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduledRidesScreen(dispatchRepository: _dispatch),
      ),
    );
  }

  Widget _buildGoOnlineButton() {
    return AnimatedBuilder(
      animation: _goOnlinePulseController,
      builder: (context, child) {
        final suspended = _driverSession.isSuspended;
        // Q25/Q26: resting after the driving limit, or an expired document.
        final hold = suspended ? null : _HomeAccount(this)._onlineHold();
        return _buildRadarOrb(
          title: suspended ? tr.account : tr.radar,
          status: suspended
              ? tr.orbPaused
              : hold?.status ?? (_activationHold ? tr.statusHold : tr.orbOff),
          subtitle: suspended
              ? tr.tapForDetails
              : hold?.subtitle ??
                    (_activationHold ? tr.notActive : tr.tapToScan),
          onTap: _goOnline,
          blocked: (_activationHold || hold != null) && !suspended,
          pulse: suspended ? 0 : _goOnlinePulseController.value,
        );
      },
    );
  }

  Widget _buildGoingOnlineButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _goOnlinePulseController,
        _radarSweepController,
      ]),
      builder: (context, child) {
        return _buildRadarOrb(
          title: tr.radar,
          status: tr.orbStarting,
          subtitle: tr.connecting,
          active: true,
          loading: true,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
        );
      },
    );
  }

  Widget _buildTripRadarButton() {
    // Every Radar trip open right now, the same trips the full Radar screen
    // lists when the driver taps this button. Counted once per build, not
    // on every animation frame (D-16).
    final radarTrips = _HomeOfferRadar(this)._radarTripsOpen;
    final openListed = _radarHomeOffers
        .where(
          (offer) =>
              _homeRadarMatchStates[offer.id] !=
              _HomeRadarMatchState.claimedElsewhere,
        )
        .length;
    final homeTrips = openListed + _pendingRadarHomeOffers.length;
    // Until a Radar trip reaches Home the button keeps scanning.
    final hasRadarOffer = _hasRideOffers || homeTrips > 0;
    final totalTrips = hasRadarOffer ? math.max(radarTrips, homeTrips) : 0;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _goOnlinePulseController,
        _radarSweepController,
        _radarMotionController,
      ]),
      builder: (context, child) {
        return _buildRadarOrb(
          title: totalTrips > 0
              ? tr.tripsCount(totalTrips)
              : hasRadarOffer
              ? tr.tripFound
              : tr.radar,
          status: hasRadarOffer ? tr.orbNew : tr.orbLive,
          subtitle: hasRadarOffer ? tr.tapForAll : tr.scanning,
          active: true,
          offer: hasRadarOffer,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
          wedge: _radarWedge(found: hasRadarOffer),
          statusPulse: hasRadarOffer ? _matchPulse : 0,
          onTap: hasRadarOffer ? _openRideOffers : null,
        );
      },
    );
  }

  Widget _buildRadarOrb({
    required String title,
    required String status,
    required String subtitle,
    VoidCallback? onTap,
    bool active = false,
    bool loading = false,
    bool offer = false,
    double pulse = 0,
    double sweep = 0,
    double? wedge,
    double statusPulse = 0,
    bool blocked = false,
  }) {
    return MoveraRadarOrb(
      title: title,
      status: status,
      subtitle: subtitle,
      onTap: onTap,
      active: active,
      loading: loading,
      offer: offer,
      pulse: pulse,
      sweep: sweep,
      wedge: wedge,
      statusPulse: statusPulse,
      blocked: blocked,
    );
  }

  @override
  void dispose() {
    _camera.dispose();
    final ownedRouting = _roadRouteService;
    if (widget.routeRepository == null && ownedRouting is RoadRouteService) {
      ownedRouting.dispose();
    }
    ScheduledRideStore.openRequests.removeListener(_onScheduledRequests);
    _locationEpoch++;
    _reservationPopupTimer?.cancel();
    _offerRouteFrame.dispose();
    _startWait?.cancel();
    _destinationLimitTimer?.cancel();
    _reservation.release?.cancel();
    _reservation.fade.cancel();
    _scheduled.dispose();
    _HomeAccount(this)._stopAccount();
    _HomeOnlineGate(this)._stopOnlineGate();
    WidgetsBinding.instance.removeObserver(this);
    driverRouteObserver.unsubscribe(this);
    driverRouteObserver.pages.unsubscribe(_pageCover);
    _sheetTrace.dispose();
    _destinationOpenTimer?.cancel();
    _radarSubscription?.cancel();
    _withdrawalSubscription?.cancel();
    _homeSheetPositionGuardTimer?.cancel();
    _goOnlinePulseController.dispose();
    _surgeMap?.dispose();
    _onlineTransitionTimer?.cancel();
    _islandIdleTimer?.cancel();
    _islandWakeTimer?.cancel();
    _lastTripSettleTimer?.cancel();
    _waybills.lastListenable.removeListener(_lastTripListener);
    IslandMessages.changes.removeListener(_islandMessagesListener);
    RideCheckGate.listenable.removeListener(_rideCheckGateListener);
    _islandMessageTimer?.cancel();
    _islandWaiting.dispose();
    _radarListClaiming.removeListener(_syncClaimLock);
    _radarListClaiming.dispose();
    ClaimLock.set(false);
    _offerSimulationTimer?.cancel();
    _directOfferTimer?.cancel();
    _HomeOfferRadar(this)._cancelAllOfferTimers();
    _expandedDirectOfferTimer?.cancel();
    _radarOfferTwoTimer?.cancel();
    _radarOfferThreeTimer?.cancel();
    _homeRadarMatchResolutionTimer?.cancel();
    _homeRadarNoticeTimer?.cancel();
    _homeRadarExternalClaimTimer?.cancel();
    _homeRadarExternalClaimCleanupTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _radarSweepController.dispose();
    _radarMotionController.dispose();
    _offerSound.dispose();
    _panelSlidePosition.dispose();
    _snapSheet.dispose();
    _exclusive.dispose();
    _mapController = null;
    _driverSession.removeListener(_onDriverSessionChanged);
    if (_ownsDriverSession) {
      _driverSession.dispose();
    }
    final dispatch = _dispatch;
    if (_ownsDispatch && dispatch is DemoDispatchRepository) {
      dispatch.dispose();
    }
    super.dispose();
  }
}
