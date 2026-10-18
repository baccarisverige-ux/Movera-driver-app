import 'package:movera/presentation/driver/home/components/app_update_sheet.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/presentation/driver/sheets/sheet_trace.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'dart:async';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/map_preview_generation.dart';
import 'package:movera/core/navigation/coalescing_map_route_refresh.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:movera/widgets/exclusive_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/documents/document_expiry.dart';
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
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:movera/widgets/led_count_badge.dart';
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
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/home/components/destination_set_panel.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/trip_problem_sheet.dart';
import 'package:movera/presentation/driver/home/components/driver_sheet_nav.dart';
import 'package:movera/presentation/driver/home/components/driver_suspended_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
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
import 'package:movera/widgets/offer_route_pins.dart';
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
    final route = ModalRoute.of(context);
    if (route != null) { driverRouteObserver.subscribe(this, route); }
    if(MediaQuery.disableAnimationsOf(context)) { _goOnlinePulseController.stop(); _radarSweepController.stop(); }
  }
  @override
  void didPushNext() { _routeVisible = false; _pauseHomeUpdates(); }
  @override
  void didPopNext() {
    _routeVisible = true;
    _resumeHomeUpdates();
    // A covering ride may have handed storage to a queued trip before it
    // closed. Re-check ownership so a persisted trip is never hidden behind
    // an available Home.
    if (_recoveryResolved && _driverSession.activeTripId == null) {
      _didAttemptActiveRideRestore = false;
      unawaited(_restoreActiveRideIfNeeded());
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_liveVisible) { _resumeHomeUpdates(); } else { _pauseHomeUpdates(); }
  }
  void _pauseHomeUpdates() {
    _camera.suspend();
    _locationEpoch++;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _radarSubscription?.cancel();_radarSubscription=null;
    _HomeOfferRadar(this)._cancelAllOfferTimers(preserveClaim: true);
    _offerSimulationTimer?.cancel(); _directOfferTimer?.cancel();
    _expandedDirectOfferTimer?.cancel(); _radarOfferTwoTimer?.cancel(); _radarOfferThreeTimer?.cancel();
    _goOnlinePulseController.stop(); _radarSweepController.stop();
  }
  void _resumeHomeUpdates() {
    if (!mounted || !_liveVisible) { return; }
    _camera.resume();
    unawaited(_HomeMapSheet(this)._startDriverLocation());
    _HomeOfferRadar(this)._scheduleVisibleOffers();
    if(!MediaQuery.disableAnimationsOf(context)) { _goOnlinePulseController.repeat(reverse: true); _radarSweepController.repeat(); }
    setState(() {});
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PanelController _panelController = PanelController();
  final PanelController _destinationPanelController = PanelController();
  late final AnimationController _goOnlinePulseController;
  late final AnimationController _radarSweepController;
  Timer? _onlineTransitionTimer;

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
  Timer? _homeRadarLostMatchTimer;
  final Map<String, Timer> _radarOfferTimeoutTimers = <String, Timer>{};
  final Map<String, _HomeRadarMatchState> _homeRadarMatchStates =
      <String, _HomeRadarMatchState>{};
  String? _homeRadarMatchingOfferId;
  _HomeDirectOffer? _claimedHomeOffer;
  late final DriverLocationRepository _driverLocationService;
  late final RouteRepository _roadRouteService;
  late final WaybillRepository _waybills;
  late final DispatchRepository _dispatch;
  StreamSubscription<List<RideOffer>>? _radarSubscription;
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
  BitmapDescriptor _driverVehicleIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  double _driverHeading = 0;
  bool isPanelOpen = false;
  bool _blockMapGestures = false;
  bool _sheetPointerActive = false;
  double _mainPanelPosition = 0;
  final ValueNotifier<double> _panelSlidePosition = ValueNotifier<double>(0);

  /// Dispatch's time to accept an Exclusive offer (15 s by default).
  static Duration get _outsideOfferLifetime => DriverOfferRules.current.exclusiveAcceptTime;

  /// How long a Radar trip can be picked once it shows in the Home list:
  /// Dispatch's time on the radar (15 s by default).
  static Duration get _radarOfferPickWindow => DriverOfferRules.current.radarTime;
  static const int _maxHomeRadarOffers = 4;
  double _sheetPointerVelocity = 0;
  double _sheetPointerTravel = 0;
  double _sheetPointerStartPos = 0;
  double _sheetPointerLastY = 0;
  int _sheetPointerLastMs = 0;
  double _lastSnapHapticAt = -1;
  late final MoveraSnapSheetController _snapSheet;
  bool showRideRequests = false;
  bool isAccountActivated = true;
  bool _activationHold = false;
  Color? _sheetTone;
  bool _sheetToneShown = false;
  Timer? _sheetToneTimer;
  late final DriverSessionController _driverSession;
  late final bool _ownsDriverSession;
  bool get _isOnline => _liveVisible && _recoveryResolved && _driverSession.availableForOffers;
  bool get _isGoingOnline => _driverSession.isGoingOnline;
  // Offer orchestration lives in an extension, which cannot call setState.
  void _rebuild(VoidCallback update) => setState(update);
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
  bool _destinationModeActive = false;
  bool _soonReservationReady = false;
  String? _destinationAddress;
  LatLng? _destinationPosition;
  DriverDestinationResult? _destinationTrip; // Confirmed distance and time.
  DateTime? _destinationUntil; // "Destination mode until 02:40".

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
  final CoalescingMapRouteRefresh _destinationRoadRefresh = CoalescingMapRouteRefresh();

  // Placeholder only: the map and car wait for a known position.
  static const LatLng _fallbackDriverPosition = LatLng(59.3293, 18.0686);
  LatLng _driverPosition = _fallbackDriverPosition;
  bool _startPositionKnown = false, _startLocationFailed = false;
  Timer? _startWait;
  CameraPosition get _initialPosition => CameraPosition(target: _driverPosition, zoom: 14.0);

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
    // A rider promotion: Movera owes the driver 26,20.
    cashToCollect: '150,00 kr',
  );

  late final SheetTrace _sheetTrace = SheetTrace('home', () => _panelController.isAttached ? _panelController.panelPosition : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    isAccountActivated = DriverRuntimeConfig.current.skipAccountActivation ||
        !widget.accountPending;
    _ownsDriverSession = widget.sessionController == null;
    _driverSession = widget.sessionController ??
        DriverSessionController(initialOnline: widget.initialOnline);
    _driverSession.addListener(_onDriverSessionChanged);
    DrivingTimeClock.instance.sync(online: _driverSession.isOnline);
    _driverLocationService =
        widget.locationRepository ?? const DriverLocationService();
    _roadRouteService = widget.routeRepository ?? RoadRouteService();
    _waybills =
        widget.waybillRepository ?? InMemoryWaybillRepository.instance;
    _ownsDispatch = widget.dispatchRepository == null;
    _dispatch = widget.dispatchRepository ?? DemoDispatchRepository();
    if (widget.sessionController != null && widget.initialOnline) {
      _driverSession.setOnline(true);
    }
    _adminHomeConfig = (widget.homeConfigRepository ??
            const LocalDriverHomeConfigRepository())
        .load();
    final access = _adminHomeConfig.scheduledRides.driverAccess;
    if (!identical(ScheduledRideStore.driverAccess, access)) { ScheduledRideStore.driverAccess = access; }
    ScheduledRideStore.openRequests.addListener(_onScheduledRequests);
    _HomeAccount(this)._startAccount();
    _goOnlinePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _snapSheet = MoveraSnapSheetController(panel: _panelController, vsync: this, reduceMotion: () => mounted && MediaQuery.disableAnimationsOf(context));
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
    if (_didAttemptActiveRideRestore) { return; }
    _didAttemptActiveRideRestore = true;
    final repo = widget.activeRideRepository;
    if (repo == null) { if (mounted) { setState(() => _recoveryResolved = true); } return; }
    PersistedActiveRide? snapshot;
    try {
      final journal = await CompletionJournal(active: repo).reconcile();
      if (mounted && journal == JournalReplayOutcome.quarantinedConflict) {
        IslandMessages.show(HomeIslandNotices.newerTripKept);
      } else if (mounted && journal == JournalReplayOutcome.quarantinedCorrupt) {
        IslandMessages.show(HomeIslandNotices.recordSetAside);
      }
      snapshot = await repo.read();
    } on ActiveRideUnreadable {
      _didAttemptActiveRideRestore = false;
      if (mounted) { await _offerUnreadableTripClosure(repo); }
      return;
    } catch (_) {
      _didAttemptActiveRideRestore = false;
      if(mounted) {
        _HomeMapSheet(this)._tripProblem(HomeIslandNotices.recoveryFailed,
            'The saved trip could not be opened.');
      }
      return;
    }
    if (!mounted) { return; }
    if (snapshot == null) { setState(() => _recoveryResolved = true); return; }

    if (!snapshot.isFresh || !snapshot.hasVerifiedEndpoints) {
      final resume = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(title: const Text('Unresolved trip'),
          content: Text(snapshot!.hasVerifiedEndpoints ? 'This saved trip is older than six hours. Resume it or close it explicitly.' : 'Saved route coordinates are unavailable. Close this trip explicitly before accepting another.'),
          actions: [TextButton(onPressed: () => popOwned(context, false), child: const Text('Close trip')),
            FilledButton(onPressed: snapshot.hasVerifiedEndpoints ? () => popOwned(context, true) : null, child: const Text('Resume trip'))]));
      if (!mounted) { return; }
      if (resume != true) {
        try {
          if (repo is TerminalRideRepository) { await (repo as TerminalRideRepository).markTerminal(snapshot.tripId, TripStatus.cancelledByDriver); }
          if (repo is TerminalRideRepository) { await (repo as TerminalRideRepository).clearForTrip(snapshot.tripId); } else { await repo.clear(); }
          if (mounted) { setState(() => _recoveryResolved = true); }
        } catch (_) {
          _didAttemptActiveRideRestore = false;
          if (mounted) {
            _HomeMapSheet(this)._tripProblem(
                HomeIslandNotices.savedTripNotClosed,
                'The saved trip could not be closed.');
          }
        }
        return;
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

    if (!mounted) { return; }
    pushSingle(context,
      BottomToTopTransition(
        AcceptRide.fromPersisted(
          snapshot,
          waybillRepository: _waybills,
          sessionController: _driverSession,
          locationRepository: _driverLocationService,
          routeRepository: _roadRouteService,
          activeRideRepository: repo,
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
      builder: (context) => AlertDialog(
        title: const Text('Saved trip cannot be read'),
        content: const Text(
          'The trip saved on this device is damaged or from another app version. '
          'Close it to continue. A copy is kept on this device for support.',
        ),
        actions: [
          TextButton(
            onPressed: () => popOwned(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => popOwned(context, true),
            child: const Text('Close unreadable trip'),
          ),
        ],
      ),
    );
    if (!mounted) { return; }
    if (close != true || repo is! UnreadableRideRecovery) {
      _HomeMapSheet(this)._tripProblem(HomeIslandNotices.unreadableTripOpen,
          'A saved trip could not be read. Close it to go online.',
          action: 'Review');
      return;
    }
    try {
      await (repo as UnreadableRideRecovery).quarantineUnreadable();
    } catch (_) {
      if (mounted) {
        _HomeMapSheet(this)._tripProblem(
            HomeIslandNotices.unreadableTripNotClosed,
            'The unreadable trip could not be closed.');
      }
      return;
    }
    await _restoreActiveRideIfNeeded();
  }

  WaybillRecord _waybillFromSnapshot(PersistedActiveRide snapshot) {
    return WaybillRecord(
      tripId: snapshot.tripId,
      statusLabel: 'Current trip',
      issuedAt: snapshot.savedAt ?? DateTime.now(),
      fare: snapshot.fare ?? '—',
      service: snapshot.category ?? 'Movera',
      riderName: snapshot.riderName ?? 'Rider data unavailable',
      pickup: snapshot.pickupAddress ?? '',
      dropoff: snapshot.dropoffAddress ?? '',
      source: snapshot.matchedVia ?? 'Movera Radar',
      driverName: 'Demo driver — identity unavailable',
      vehicle: 'Vehicle data unavailable',
      licensePlate: 'Plate unavailable',
      passengerCapacity: 4,
    );
  }

  WaybillRecord _waybillFromQueued(PersistedQueuedTrip next) {
    return WaybillRecord(
      tripId: next.tripId,
      statusLabel: 'Next trip secured',
      issuedAt: DateTime.now(),
      fare: next.fare,
      service: next.category,
      riderName: next.riderName,
      pickup: next.pickup,
      dropoff: next.dropoff,
      source: 'Movera Radar',
      driverName: 'Demo driver — identity unavailable',
      vehicle: 'Vehicle data unavailable',
      licensePlate: 'Plate unavailable',
      passengerCapacity: 4,
    );
  }

  void _onDriverSessionChanged() {
    DrivingTimeClock.instance.sync(online: _driverSession.isOnline);
    _HomeAccount(this)._syncDrivingLimit();
    if (!mounted) { return; }
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
    if (address == null || address.isEmpty) { return 'Destination'; }
    final firstPart = address.split(',').first.trim();
    if (firstPart.length <= 24) { return firstPart; }
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

  void _openActivationDocuments() {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const DriverDocuments()),
    );
  }

  bool hideMainPanel = false;
  Timer? _destinationOpenTimer;

  @override
  Widget build(BuildContext context) {
    return LayoutViewport(
      child: Scaffold(
      key: _scaffoldKey,
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
                            const Color(0xFF172027).withValues(alpha: 0.46),
                            const Color(0xFF6F7D80).withValues(alpha: 0.16),
                            const Color(0xFFF4F7F8).withValues(alpha: 0.24),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                PointerInterceptor(
                  child: const SizedBox.expand(),
                ),
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
                  towardPickupTime: _HomeScheduled(this)._towardPickupTime,
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
              maxHeight: _HomeMapSheet(this)._homeExpandedHeight(context),
              // The map rises with the sheet, about a third as far, on the
              // same spring.
              parallaxEnabled: true,
              parallaxOffset: 0.3,
              onPanelSlide: (double pos) {
                _mainPanelPosition = pos;
                _panelSlidePosition.value = pos;
                if (!_sheetPointerActive) {
                  _HomeMapSheet(this)._scheduleHomeSheetPositionGuard();
                }
                if (pos > 0.04) {
                  _HomeMapSheet(this)._closeHomeFloatingPopupsForSheet();
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
                _HomeMapSheet(this)._closeHomeFloatingPopupsForSheet();
                _HomeMapSheet(this)._setMapGesturesBlocked(_sheetPointerActive);
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

              panelBuilder: (ScrollController sc) => PointerInterceptor(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _HomeMapSheet(this)._onSheetPointerDown,
                    onPointerMove: _HomeMapSheet(this)._onSheetPointerMove,
                    onPointerUp: _HomeMapSheet(this)._onSheetPointerEnd,
                    onPointerCancel: _HomeMapSheet(this)._onSheetPointerEnd,
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
          _HomeMapSheet(this)._homeRadarLayer(),
          // A reservation request: its sheet over the dock, its orb on top.
          _HomeReservation(this)._reservationLayer(),
              ],
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
    if(!_recoveryResolved) {
      _HomeMapSheet(this)._tripProblem(HomeIslandNotices.recoveryPending,
          'Finish or close the saved trip before going online.',
          action: 'Open saved trip');
      return;
    }
    if (!isAccountActivated) {
      setState(() => _activationHold = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_panelController.isAttached) { return; }
        unawaited(_snapSheet.springTo(0.28));
      });
      return;
    }
    if (_HomeAccount(this)._blocksGoingOnline()) { return; }

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
    _HomeMapSheet(this)._flashSheet(const Color(0xFF1C6B45));
    _HomeOfferRadar(this)._clearDirectOfferRoute();
    unawaited(_HomeMapSheet(this)._startDriverLocation(moveCamera: true));
    IslandMessages.show(HomeIslandNotices.online);

    _onlineTransitionTimer = Timer(
      const Duration(milliseconds: 1400),
      () {
        if (!mounted) { return; }
        setState(() {
          _driverSession.completeGoingOnline();
        });
        _HomeOfferRadar(this)._scheduleVisibleOffers();
      },
    );
  }

  Future<void> _goOffline() async {
    _destinationOpenTimer?.cancel();
    IslandMessages.show(HomeIslandNotices.offline);
    hideMainPanel = false;
    unawaited(_radarSubscription?.cancel() ?? Future<void>.value());
    _radarSubscription = null;
    _latestDispatchOffers = const <RideOffer>[];
    _HomeMapSheet(this)._flashSheet(MoveraRadarOrb.holdSheet);
    _onlineTransitionTimer?.cancel();
    _offerSimulationTimer?.cancel();
    _directOfferTimer?.cancel();
    _HomeOfferRadar(this)._cancelAllOfferTimers();
    _expandedDirectOfferTimer?.cancel();
    _radarOfferTwoTimer?.cancel();
    _radarOfferThreeTimer?.cancel();

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
    });
    _HomeOfferRadar(this)._clearDirectOfferRoute();
    await _HomeMapSheet(this)._closeDriverSheet();
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
    if (mounted) { _HomeReservation(this)._onScheduledRequestsChanged(); }
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
          title: suspended ? "Account" : "Radar",
          status: suspended
              ? "PAUSED"
              : hold?.status ?? (_activationHold
                  ? "HOLD"
                  : "OFF"),
          subtitle: suspended
              ? "Tap for details"
              : hold?.subtitle ?? (_activationHold
                  ? "Not active"
                  : "Tap to scan"),
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
          title: "Radar",
          status: "STARTING",
          subtitle: "Connecting",
          active: true,
          loading: true,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
        );
      },
    );
  }

  Widget _buildTripRadarButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _goOnlinePulseController,
        _radarSweepController,
      ]),
      builder: (context, child) {
        // Every Radar trip open right now, the same trips the full Radar
        // screen lists when the driver taps this button.
        final radarTrips = _latestDispatchOffers
            .where((offer) =>
                offer.isNearby &&
                (!_destinationModeActive || offer.followsDestination) && _HomeOfferRules(this)._rideAllowed(offer))
            .length;
        final openListed = _radarHomeOffers
            .where((offer) =>
                _homeRadarMatchStates[offer.id] !=
                _HomeRadarMatchState.claimedElsewhere)
            .length;
        final homeTrips = openListed + _pendingRadarHomeOffers.length;
        // Until a Radar trip reaches Home the button keeps scanning.
        final hasRadarOffer = _hasRideOffers || homeTrips > 0;
        final totalTrips = hasRadarOffer
            ? math.max(radarTrips, homeTrips)
            : 0;

        return _buildRadarOrb(
          title: totalTrips > 0
              ? "$totalTrips trip${totalTrips == 1 ? '' : 's'}"
              : hasRadarOffer
              ? "Trip found"
              : "Radar",
          status: hasRadarOffer ? "NEW" : "LIVE",
          subtitle: hasRadarOffer ? "Tap for all" : "Scanning",
          active: true,
          offer: hasRadarOffer,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
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
      blocked: blocked,
    );
  }

  @override
  void dispose() {
    _camera.dispose();
    final ownedRouting = _roadRouteService;
    if (widget.routeRepository == null && ownedRouting is RoadRouteService) { ownedRouting.dispose(); }
    ScheduledRideStore.openRequests.removeListener(_onScheduledRequests);
    _locationEpoch++;
    _reservationPopupTimer?.cancel(); _offerRouteFrame.refit?.cancel(); _startWait?.cancel();
    _reservation.release?.cancel();
    _scheduled.dispose();
    _HomeAccount(this)._stopAccount();
    WidgetsBinding.instance.removeObserver(this);
    driverRouteObserver.unsubscribe(this);
    _sheetTrace.dispose();
    _destinationOpenTimer?.cancel();
    _radarSubscription?.cancel();
    _homeSheetPositionGuardTimer?.cancel();
    _sheetToneTimer?.cancel();
    _goOnlinePulseController.dispose();
    _onlineTransitionTimer?.cancel();
    _islandIdleTimer?.cancel();
    _islandWakeTimer?.cancel();
    _lastTripSettleTimer?.cancel();
    _waybills.lastListenable.removeListener(_lastTripListener);
    IslandMessages.changes.removeListener(_islandMessagesListener);
    RideCheckGate.listenable.removeListener(_rideCheckGateListener);
    _islandMessageTimer?.cancel();
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
    _homeRadarLostMatchTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _radarSweepController.dispose();
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
