import 'package:movera/widgets/owned_external_action.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/presentation/driver/sheets/sheet_trace.dart';
import 'package:movera/core/location/location_freshness.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'dart:async';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/driver_map_zoom_change_detector.dart';
import 'package:movera/core/navigation/map_zoom_sheet_settle.dart';
import 'package:movera/core/navigation/route_camera_geometry.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/demo_trip_drive.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/navigation/live_vehicle_animator.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/safety/rider_contact.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/widgets/pickup_pay_line.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/accept%20ride/rider_cancelled_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/overlays/map_overlay_insets.dart';
import 'package:movera/presentation/driver/sheets/movera_snap_sheet_controller.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';
import 'package:movera/widgets/movera_line_icon.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

part 'accept_ride_trip.dart';
part 'accept_ride_panel.dart';

class AcceptRide extends StatefulWidget {
  const AcceptRide({
    super.key,
    this.offerId = 'demo-radar-offer',
    this.riderName = 'Angelica',
    this.riderRating = 4.9,
    this.riderTrips = 312,
    this.fare = '—',
    this.paidByCash = false,
    this.cashToCollect,
    this.category = 'Movera',
    this.matchedVia = 'Demo Radar',
    this.pickupAddress = 'Odlarvägen 22',
    this.pickupArea = 'Enhörna',
    this.dropoffAddress = 'T-Centralen, Stockholm',
    this.stopAddresses = const <String>[],
    this.stopPositions = const <LatLng>[],
    this.pickupPosition = const LatLng(59.3279, 18.0615),
    this.dropoffPosition = const LatLng(59.3326, 18.0649),
    this.locationRepository,
    this.routeRepository,
    this.waybillRepository,
    this.sessionController,
    this.activeRideRepository,
    this.realtime,
    this.initialStage = ActiveRideStage.headingToPickup,
    this.initialWaitSeconds = 0,
    this.waitNow,
    this.launchExternalMap,
    this.restoredSnapshot,
    this.destinationModeActive = false,
    this.destinationAddress,
    this.destinationPosition,
    this.rideCheck,
    this.pickupKm,
  });

  /// How far the pickup was when the trip was accepted, for the waiting
  /// rule by pickup distance (Q20); null when not known.
  final double? pickupKm;

  final Future<bool> Function(Uri)? launchExternalMap;

  /// Ride check services; the app's [RideCheckScope] when omitted.
  final RideCheckServices? rideCheck;
  final String offerId;
  /// Clock for elapsed waiting time; injectable for lifecycle verification.
  final DateTime Function()? waitNow;
  final String riderName;
  final double riderRating;
  final int riderTrips;
  final String fare;

  /// Cash in the car; otherwise paid by card. Shown as a logo in the bar.
  final bool paidByCash;

  /// R8-4: on a cash trip, the cash to take from the rider when it is not
  /// [fare] (rider promotions). Null: the fare.
  final String? cashToCollect;
  final String category;
  final String matchedVia;
  final String pickupAddress;
  final String pickupArea;
  final String dropoffAddress;
  final List<String> stopAddresses;
  final List<LatLng> stopPositions;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final DriverLocationRepository? locationRepository;
  final RouteRepository? routeRepository;
  final WaybillRepository? waybillRepository;
  final DriverSessionController? sessionController;
  final ActiveRideRepository? activeRideRepository;
  final DriverRealtime? realtime;
  final ActiveRideStage initialStage;
  final int initialWaitSeconds;
  final PersistedActiveRide? restoredSnapshot;
  final bool destinationModeActive;
  final String? destinationAddress;
  final LatLng? destinationPosition;

  factory AcceptRide.fromQueuedWaybill(
    WaybillRecord record, {
    Key? key,
    DriverLocationRepository? locationRepository,
    RouteRepository? routeRepository,
    WaybillRepository? waybillRepository,
    DriverSessionController? sessionController,
    ActiveRideRepository? activeRideRepository,
  }) {
    final pickup = record.pickup;
    return AcceptRide(
      key: key,
      offerId: record.tripId,
      riderName: record.riderName,
      fare: record.fare,
      category: record.service,
      matchedVia: record.source,
      pickupAddress: pickup,
      pickupArea: pickup.split(',').last.trim(),
      dropoffAddress: record.dropoff,
      locationRepository: locationRepository,
      routeRepository: routeRepository,
      waybillRepository: waybillRepository,
      sessionController: sessionController,
      activeRideRepository: activeRideRepository,
    );
  }

  factory AcceptRide.fromPersisted(
    PersistedActiveRide snapshot, {
    Key? key,
    DriverLocationRepository? locationRepository,
    RouteRepository? routeRepository,
    WaybillRepository? waybillRepository,
    DriverSessionController? sessionController,
    ActiveRideRepository? activeRideRepository,
    DriverRealtime? realtime,
  }) {
    if (!snapshot.hasVerifiedEndpoints) { throw StateError('Saved trip requires verified pickup and drop-off coordinates'); }
    final pickup = snapshot.pickupAddress ?? 'Address unavailable';
    return AcceptRide(
      key: key,
      offerId: snapshot.tripId,
      riderName: snapshot.riderName ?? 'Rider data unavailable',
      riderRating: snapshot.riderRating ?? 4.9,
      riderTrips: snapshot.riderTrips ?? 312,
      fare: snapshot.fare ?? '—',
      paidByCash: snapshot.paidByCash,
      cashToCollect: snapshot.cashToCollect,
      category: snapshot.category ?? 'Movera',
      matchedVia: snapshot.matchedVia ?? 'Demo Radar',
      pickupAddress: pickup,
      pickupArea: snapshot.pickupArea ?? pickup.split(',').last.trim(),
      dropoffAddress: snapshot.dropoffAddress ?? 'Stockholm',
      stopAddresses: snapshot.stopAddresses,
      stopPositions: snapshot.stopPoints.map((point) => point.toLatLng()).toList(),
      pickupPosition: LatLng(
        snapshot.pickupLat!,
        snapshot.pickupLng!,
      ),
      dropoffPosition: LatLng(
        snapshot.dropoffLat!,
        snapshot.dropoffLng!,
      ),
      locationRepository: locationRepository,
      routeRepository: routeRepository,
      waybillRepository: waybillRepository,
      sessionController: sessionController,
      activeRideRepository: activeRideRepository,
      realtime: realtime,
      initialStage: snapshot.stage,
      initialWaitSeconds: snapshot.waitSeconds ?? 0,
      restoredSnapshot: snapshot,
      destinationModeActive: snapshot.destinationModeActive,
      destinationAddress: snapshot.destinationAddress,
      destinationPosition: snapshot.destinationPoint?.toLatLng(),
    );
  }

  @override
  State<AcceptRide> createState() => _AcceptRideState();
}

enum _OnTripRadarState { off, scanning, offerAvailable, matching, secured, stopped }

class _NextTripRadarOffer {
  const _NextTripRadarOffer({
    required this.id,
    required this.category,
    required this.fare,
    required this.rating,
    required this.pickupMinutes,
    required this.tripMinutes,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.pickupPosition,
    required this.dropoffPosition,
    this.pickupKm = 1.6,
  });

  final String id;
  final String category;
  final String fare;
  final double rating;
  final int pickupMinutes;

  /// From the current trip's drop-off to this pickup.
  final double pickupKm;

  /// Pickup pay, worked out each time the offer shows.
  PickupPayQuote get pickupPay => PickupPayCalculator.quote(
    category: category,
    kind: PickupPayOfferKind.nextTripWhileDriving,
    leg: PickupLeg(km: pickupKm, minutes: pickupMinutes),
  );

  /// The fare plus the pickup pay: one total.
  String get shownFare => pickupPay.totalOf(fare);
  final int tripMinutes;
  final String riderName;
  final String pickup;
  final String dropoff;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
}

class _TripCancellationReason {
  const _TripCancellationReason({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.counts = true,
  });

  final String code;
  final String title;
  final String subtitle;
  final MoveraMark icon;

  /// False: "Doesn't count" in the cancel rate (Q21).
  final bool counts;

  /// The line under the title; a reason that doesn't count says so.
  String get detail => counts
      ? subtitle
      : [if (subtitle.isNotEmpty) subtitle, 'Doesn’t count'].join(' · ');
}

class _AcceptRideState extends State<AcceptRide>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final DriverRealtimeSequenceGate _realtimeGate = DriverRealtimeSequenceGate();
  static const Color _ink = Color(0xFF252E3A);
  static const Color _panel = Color(0xFFFFFFFF);
  static const Color _canvas = Color(0xFFF4F6F7);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _green = Color(0xFF19865C);
  static const Color _line = Color(0xFFE5E9EB);
  static const double _nextTripRadarRadiusMeters = 30000;

  /// Q21: the reasons come from the admin's list for this country and
  /// language; the app only adds an icon to each.
  static const Map<String, MoveraMark> _reasonIcons = {
    'rider_requested_cancel': MoveraMark.user,
    'rider_not_at_pickup': MoveraMark.pin,
    'unsafe_pickup': MoveraMark.warning,
    'vehicle_issue_before_start': MoveraMark.car,
    'driver_emergency_before_start': MoveraMark.bolt,
    'rider_no_show': MoveraMark.user,
    'rider_requested_early_end': MoveraMark.user,
    'safety_concern_on_trip': MoveraMark.shield,
    'vehicle_issue_on_trip': MoveraMark.car,
    'accident_or_road_emergency': MoveraMark.warning,
    'rider_behavior': MoveraMark.message,
    'trip_or_destination_issue': MoveraMark.route,
  };

  static _TripCancellationReason _reason(CancelReason reason) =>
      _TripCancellationReason(
        code: reason.code,
        title: reason.title,
        subtitle: reason.subtitle,
        icon: _reasonIcons[reason.code] ?? MoveraMark.more,
        counts: reason.counts,
      );

  static List<_TripCancellationReason> get _preTripCancellationReasons => [
    for (final reason
        in CancelReasons.current.of(CancelReasonGroup.driverBeforeTrip))
      _reason(reason),
  ];

  static _TripCancellationReason get _noShowReason =>
      _reason(CancelReasons.current.noShow);

  static List<_TripCancellationReason> get _onTripCancellationReasons => [
    for (final reason
        in CancelReasons.current.of(CancelReasonGroup.driverDuringTrip))
      _reason(reason),
  ];

  static const LatLng _fallbackDriverPosition = LatLng(59.3262, 18.0595);

  static const _NextTripRadarOffer _demoNextTripOffer =
      _NextTripRadarOffer(
    id: 'on-trip-radar-demo-1',
    category: 'Comfort',
    fare: '128,40 kr',
    rating: 4.94,
    pickupMinutes: 4,
    pickupKm: 1.6,
    tripMinutes: 16,
    riderName: 'Maya',
    pickup: 'Vasagatan 10, Stockholm',
    dropoff: 'Södermalm, Stockholm',
    pickupPosition: LatLng(59.3328, 18.0587),
    dropoffPosition: LatLng(59.3142, 18.0735),
  );



  late final DriverLocationRepository _locationService;
  late final RouteRepository _routeService;
  late final WaybillRepository _waybills;
  late final NavigationController _navigation;
  late final LiveVehicleAnimator _vehicle;
  BitmapDescriptor _driverVehicleIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  Map<RouteMarkKind, BitmapDescriptor> _pinIcons = const {};
  final GlobalKey<ScaffoldState> _rideScaffoldKey = GlobalKey<ScaffoldState>();
  // Manual browsing keeps the collapsed dock visible; recenter pulses.
  bool _browsing = false;
  // Last two-finger touch or wheel on the map, used to detect manual zoom.
  DateTime? _lastMapZoom;
  final DriverMapZoomChangeDetector _manualZoomDetector =
      DriverMapZoomChangeDetector(initialZoom: 15.8);
  int _mapPointers = 0;
  final MapZoomSheetSettle _mapZoomSettle = MapZoomSheetSettle();
  double _browseReturnPos = 0;
  void _finishBrowseSheetCollapse() {
    if (!mounted || !_browsing || !_ridePanelController.isAttached ||
        _browseReturnPos <= 0.001) { return; }
    unawaited(_snapSheet.springTo(0));
  }
  late final AnimationController _browsePulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  // Destination mode can be set from the island during the trip too.
  late bool _destinationActive = widget.destinationModeActive;
  late String? _destinationAddress = widget.destinationAddress;
  late LatLng? _destinationPosition = widget.destinationPosition;
  final PanelController _ridePanelController = PanelController();
  final ValueNotifier<double> _ridePanelPosition = ValueNotifier<double>(0);
  late final MoveraSnapSheetController _snapSheet;
  double _ridePointerVelocity = 0;
  double _ridePointerLastY = 0;
  // Where a drag on the sheet started and how far the finger moved.
  double _ridePointerStartPos = 0;
  double _ridePointerTravel = 0;
  // Measured middle sheet: down to the stage's main action.
  final GlobalKey _middleActionKey = GlobalKey();
  final GlobalKey _ridePanelKey = GlobalKey();
  double? _middleMeasured;
  int _ridePointerLastMs = 0;
  bool _ridePointerActive = false;
  Timer? _rideSheetPositionGuardTimer;

  final DriverCameraController _camera = DriverCameraController();
  GoogleDriverCameraPort? _cameraPort;
  StreamSubscription<DriverLocation>? _positionSubscription;
  late final ActiveRideController _rideLifecycle = ActiveRideController(
    tripId: widget.offerId,
    repository: widget.activeRideRepository,
    initialStage: widget.initialStage,
  );
  ActiveRideStage get _stage => _rideLifecycle.stage;
  // Trip orchestration lives in an extension, which cannot call setState.
  void _rebuild(VoidCallback update) => setState(update);
  Timer? _waitTimer;
  StreamSubscription<DriverRealtimeEvent>? _realtimeSubscription;
  late final VoidCallback _onNavigationChangedListener =
      _AcceptRideTrip(this)._onNavigationChanged;
  late final VoidCallback _syncNavigationStageListener =
      _AcceptRideTrip(this)._syncNavigationStage;
  late final void Function(CameraPosition) _onCameraMoveListener =
      _AcceptRideTrip(this)._onCameraMove;
  late final DriverRealtime _realtime;
  late final bool _ownsRealtime;
  bool _riderOnTheWay = false;
  bool _handlingRiderCancellation = false;
  Timer? _nextTripRadarDemoTimer;
  Timer? _nextTripRadarMatchTimer;
  Timer? _nextTripOfferExpiry;
  /// An Exclusive offer while driving a rider: Dispatch's time to accept.
  static Duration get _onTripOfferLifetime => DriverOfferRules.current.exclusiveAcceptTime;
  DateTime? _lastGpsAppliedAt;
  DateTime? _lastSnapshotAt;
  bool _liveUpdatesPaused = false;
  int _waitSeconds = 0;
  DateTime? _waitAnchorAt;
  int _waitAnchorSeconds = 0;
  int _stopCursor = 0;
  bool _paidStopWait = false;
  DateTime? _onTripStartedAt;
  _OnTripRadarState _onTripRadarState = _OnTripRadarState.off;
  _NextTripRadarOffer? _nextTripRadarOffer;
  bool _onTripRadarDeclined = false;

  LatLng _driverPosition = _fallbackDriverPosition;
  List<GeoPoint> _roadGeoPoints = <GeoPoint>[];
  double? _routeDurationSeconds;
  bool _hasLiveLocation = false;
  DriverLocation? _lastLocation;
  int _locationEpoch = 0;
  bool _stageTransitioning = false;
  DriverRealtimeEvent? _pendingProjection;
  bool _drainingProjection = false;
  Timer? _projectionRetry;
  String _vehicleLabel = 'Vehicle data unavailable';
  String _vehiclePlate = 'Plate unavailable';
  static const Duration _projectionRetryBase = Duration(seconds: 1);
  static const Duration _projectionRetryMax = Duration(seconds: 30);
  Duration _projectionRetryDelay = _projectionRetryBase;
  final _externalMapAction = OwnedExternalAction();
  bool _completionInFlight = false;
  bool _cancellationInFlight = false;
  bool _blockMapGestures = false;
  late final AnimationController _radarPulseController;
  late final AnimationController _radarSweepController;
  String? _locationStatus;
  // Ride check: the safety card that opens when a trip looks wrong.
  RideCheckServices? _rideCheckServices;
  late final RideCheckController _rideCheck;
  late final RideCheckDetector _rideCheckDetector;
  Timer? _rideCheckTicker;
  /// Island demo: the next Finish opens "Finished far from drop-off".
  bool _rideCheckFinishDemo = false;
  StreamSubscription<DateTime>? _hardStops;

  late final SheetTrace _sheetTrace = SheetTrace('active', () => _ridePanelController.isAttached ? _ridePanelController.panelPosition : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A RideCheck demo trip drives its own scripted GPS (DemoTripDrive).
    _locationService = DemoTripDrive.forTrip(widget.offerId,
            pickup: GeoPointMaps.fromLatLng(widget.pickupPosition),
            dropoff: GeoPointMaps.fromLatLng(widget.dropoffPosition)) ??
        widget.locationRepository ?? const DriverLocationService();
    _routeService = widget.routeRepository ?? RoadRouteService();
    _waybills =
        widget.waybillRepository ?? InMemoryWaybillRepository.instance;
    _navigation = NavigationController(routeRepository: _routeService);
    _navigation.addListener(_onNavigationChangedListener);
    _ownsRealtime = widget.realtime == null;
    _realtime = widget.realtime ?? MemoryDriverRealtime();
    _realtimeSubscription =
        _realtime.subscribe(widget.offerId).listen(_AcceptRideTrip(this)._onRealtimeEvent, onError: (Object error) {
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip updates disconnected. Reconnecting is required.'))); }
        });
    unawaited(_AcceptRideTrip(this)._resyncTrip());
    _rideLifecycle.snapshotBuilder = _AcceptRideTrip(this)._buildSnapshot;
    _rideLifecycle.addListener(_AcceptRideTrip(this)._onPersistenceChanged);
    _rideLifecycle.addListener(_syncNavigationStageListener);
    _syncNavigationStageListener();
    _AcceptRideTrip(this)._restoreQueuedNextFromSnapshot();
    final restored = widget.restoredSnapshot;
    _stopCursor = math.min(math.max(0, restored?.stopIndex ?? 0), widget.stopAddresses.length);
    _paidStopWait = restored?.paidStopWait == true;
    _onTripStartedAt = restored?.startedAt;
    _waitSeconds = widget.initialWaitSeconds;
    // The waiting clocks on this trip follow its terms.
    WaitingTerms.active = _waitTerms;
    if (restored?.savedAt != null &&
        (widget.initialStage == ActiveRideStage.waitingForRider || _paidStopWait)) {
      final elapsed = DateTime.now().difference(restored!.savedAt!).inSeconds;
      _waitSeconds += math.max(0, elapsed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { return; }
      widget.sessionController?.beginTrip(widget.offerId);
      if(_waybills.current?.tripId != widget.offerId) { _waybills.beginCurrent(_AcceptRideTrip(this)._buildCurrentWaybill()); }
      if (widget.restoredSnapshot?.next != null && _nextTripRadarOffer != null) {
        _waybills.secureNext(_AcceptRideTrip(this)._buildNextWaybill(_nextTripRadarOffer!));
      }
      _AcceptRideTrip(this)._resumeStageSideEffects();
      // Keep the trip dock visible at its lowest resting position.
      if (_ridePanelController.isAttached && !_incomingOfferOpen) {
        _ridePanelController.panelPosition = 0;
      }
      _rideLifecycle.persistNow();
      unawaited(_AcceptRideTrip(this)._loadVehicleIdentity());
    });
    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _snapSheet = MoveraSnapSheetController(
      reduceMotion: () => mounted && MediaQuery.disableAnimationsOf(context),
      panel: _ridePanelController,
      vsync: this,
    );
    _vehicle = LiveVehicleAnimator(
      reduceMotion: () => mounted && MediaQuery.disableAnimationsOf(context),
      vsync: this,
      initial: const LiveVehiclePose(
        position: _fallbackDriverPosition,
        headingDegrees: 0,
      ),
    );
    unawaited(_AcceptRideTrip(this)._prepareDriverVehicleMarker());
    _AcceptRideTrip(this)._startLiveLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideCheckServices == null) {
      final services = widget.rideCheck ?? RideCheckScope.read(context) ?? RideCheckServices.fallback;
      _rideCheckServices = services;
      _rideCheckDetector = RideCheckDetector(rules: services.rules);
      _rideCheck = RideCheckController(services: services, tripId: widget.offerId,
        tripDetails: _AcceptRideTrip(this)._safetyAlertTrip);
      _rideCheckTicker = Timer.periodic(const Duration(seconds: 20), (_) => _AcceptRideTrip(this)._rideCheckTick());
      _hardStops = services.hardStops?.listen(_AcceptRideTrip(this)._rideCheckHardStop);
    }
    if(MediaQuery.disableAnimationsOf(context)) { _radarPulseController.stop(); _radarSweepController.stop(); }
    else if(!_liveUpdatesPaused) { _radarPulseController.repeat(reverse:true); _radarSweepController.repeat(); }
  }

  @override
  void dispose() {
    _rideCheckTicker?.cancel();
    _hardStops?.cancel();
    _rideCheck.dispose();
    _camera.dispose();
    final ownedRouting = _routeService;
    if (widget.routeRepository == null && ownedRouting is RoadRouteService) { ownedRouting.dispose(); }
    _browsePulse.dispose();
    _locationEpoch++;
    _projectionRetry?.cancel();
    _sheetTrace.dispose();
    _rideSheetPositionGuardTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _waitTimer?.cancel();
    _realtimeSubscription?.cancel();
    _realtime.unsubscribe();
    if (_ownsRealtime) {
      _realtime.dispose();
    }
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
    _radarPulseController.dispose();
    _radarSweepController.dispose();
    _positionSubscription?.cancel();
    _rideLifecycle.removeListener(_syncNavigationStageListener);
    _rideLifecycle.dispose();
    _navigation.removeListener(_onNavigationChangedListener);
    _navigation.dispose();
    _vehicle.dispose();
    _snapSheet.dispose();
    _ridePanelPosition.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _AcceptRideTrip(this)._resumeLiveUpdates();
        unawaited(_AcceptRideTrip(this)._resyncTrip());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _rideLifecycle.persistNow();
        _AcceptRideTrip(this)._pauseLiveUpdates();
    }
  }








  LatLng? get _routeTarget {
    if (_stage == ActiveRideStage.onTrip &&
        _stopCursor < widget.stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    if (_stage == ActiveRideStage.onTrip) { return widget.dropoffPosition; }
    return widget.pickupPosition;
  }


  bool get _arrivalDemo => DriverRuntimeConfig.current.simulatedArrival;

  /// A RideCheck demo trip: its scripted GPS is the trip's own position.
  DemoTripDrive? get _demoDrive {
    final location = _locationService;
    return location is DemoTripDrive ? location : null;
  }

  LatLng? get _arrivalTarget {
    if (_stage == ActiveRideStage.headingToPickup) { return widget.pickupPosition; }
    if (_stage == ActiveRideStage.onTrip &&
        !_paidStopWait &&
        _stopCursor < widget.stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    return null;
  }

  bool get _nearArrivalTarget {
    final target = _arrivalTarget;
    if (target == null) { return false; }
    if (_arrivalDemo) { return true; }
    if (!_hasLiveLocation || _lastLocation?.isUsableAt(DateTime.now()) != true) { return false; }
    return GeoPointMaps.fromLatLng(_driverPosition).distanceMetersTo(
          GeoPointMaps.fromLatLng(target),
        ) <=
        100;
  }

  bool get _countingWait =>
      _stage == ActiveRideStage.waitingForRider || _paidStopWait;

  static const double _arrivalApproachThresholdMeters = 300;

  LatLng? get _approachTarget {
    if (_stage == ActiveRideStage.headingToPickup ||
        _stage == ActiveRideStage.waitingForRider) {
      return widget.pickupPosition;
    }
    if (_stage == ActiveRideStage.onTrip &&
        _stopCursor < widget.stopAddresses.length) {
      return _AcceptRideTrip(this)._stopPoint(_stopCursor);
    }
    if (_stage == ActiveRideStage.onTrip) {
      return widget.dropoffPosition;
    }
    return null;
  }

  ArrivalPointKind get _approachKind {
    if (_stage == ActiveRideStage.headingToPickup ||
        _stage == ActiveRideStage.waitingForRider) {
      return ArrivalPointKind.pickup;
    }
    if (_stopCursor < widget.stopAddresses.length) {
      return ArrivalPointKind.stop;
    }
    return ArrivalPointKind.destination;
  }

  String get _approachLabel {
    return switch (_approachKind) {
      ArrivalPointKind.pickup => 'Pickup',
      ArrivalPointKind.stop => 'Stop ${_stopCursor + 1}',
      ArrivalPointKind.destination => 'Destination',
    };
  }

  String get _approachAddress {
    return switch (_approachKind) {
      ArrivalPointKind.pickup => widget.pickupAddress,
      ArrivalPointKind.stop => widget.stopAddresses[_stopCursor],
      ArrivalPointKind.destination => widget.dropoffAddress,
    };
  }

  double? get _approachDistanceMeters {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return 0;
    }
    final target = _approachTarget;
    if (target == null ||
        !_hasLiveLocation ||
        _lastLocation?.isUsableAt(DateTime.now()) != true) {
      return null;
    }
    return GeoPointMaps.fromLatLng(_driverPosition).distanceMetersTo(
      GeoPointMaps.fromLatLng(target),
    );
  }

  bool get _showArrivalApproach {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return true;
    }
    final distance = _approachDistanceMeters;
    return distance != null && distance <= _arrivalApproachThresholdMeters;
  }

  bool get _arrivalApproachArrived {
    if (_stage == ActiveRideStage.waitingForRider || _paidStopWait) {
      return true;
    }
    final distance = _approachDistanceMeters;
    return distance != null && distance <= 25;
  }

  Set<Polyline> get _polylines {
    if (_roadGeoPoints.length < 2) { return {}; }
    final geometry = RouteCameraGeometry(_roadGeoPoints);
    final along = _camera.alongMeters;
    return {
      if (along > 0) Polyline(
        polylineId: const PolylineId('traveled-road-route'),
        points: geometry.traveled(along).map((p) => p.toLatLng()).toList(),
        width: 3,
        color: RouteMarkPins.ink.withValues(alpha: .18),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('active-road-route'),
        points: geometry.remaining(along).map((p) => p.toLatLng()).toList(),
        width: DriverRouteStyle.width,
        color: DriverRouteStyle.color,
        geodesic: false,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }



  bool get _allowExternalRouting => DriverRuntimeConfig.current.externalRouting;




  /// One line under the time and distance in the collapsed trip bar.
  String get _tripBarStatus {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return 'Picking up ${widget.riderName}';
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? '${widget.riderName} is on the way'
            : 'Waiting for ${widget.riderName}';
      case ActiveRideStage.onTrip:
        if (_paidStopWait) { return 'Waiting at stop ${_stopCursor + 1}'; }
        if (_stopCursor < widget.stopAddresses.length) {
          return 'Heading to stop ${_stopCursor + 1}';
        }
        return 'Dropping off ${widget.riderName}';
    }
  }

  /// First line of the trip sheet: the next thing to do.
  String get _tripBarInstruction {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return 'Pick up ${widget.riderName}';
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? '${widget.riderName} is on the way'
            : 'Waiting for ${widget.riderName}';
      case ActiveRideStage.onTrip:
        if (_paidStopWait) { return 'Waiting at stop ${_stopCursor + 1}'; }
        if (_stopCursor < widget.stopAddresses.length) {
          return 'Drive to stop ${_stopCursor + 1}';
        }
        return 'Drop off ${widget.riderName}';
    }
  }

  /// Second line: where. Location problems show on the island.
  String get _tripBarAddress => _nextStopAddress;

  /// Share of the way to the next point already driven; null while
  /// waiting or before a road route exists.
  double? get _legFraction {
    if (_countingWait || _routeDurationSeconds == null) { return null; }
    final remaining = _remainingMeters;
    if (remaining == null) { return null; }
    // Measured against the longest distance seen on this step, so a
    // reroute from the driver's new position does not reset the line.
    final key = '${_stage.name}-$_stopCursor';
    if (_legKey != key || remaining > _legTotalMeters) {
      _legKey = key;
      _legTotalMeters = remaining;
    }
    if (_legTotalMeters <= 0) { return null; }
    return (1 - remaining / _legTotalMeters).clamp(0.0, 1.0);
  }
  String? _legKey;
  double _legTotalMeters = 0;

  /// Road distance still to drive to the next point.
  double? get _remainingMeters {
    final total = _navigation.route?.distanceMeters;
    if (total == null || total <= 0) { return null; }
    return total * (1 - (_navigation.routeFraction ?? 0));
  }

  String get _routeEtaText {
    final seconds = _routeDurationSeconds;
    // Until a road route arrives, a calm word instead of a placeholder.
    if (seconds == null) { return 'En route'; }
    final left = seconds * (1 - (_navigation.routeFraction ?? 0));
    final minutes = math.max(1, (left / 60).ceil());
    return '$minutes min';
  }

  bool get _tripEndedTooQuickly {
    final started = _onTripStartedAt;
    if (started == null) { return false; }
    return DateTime.now().difference(started) < const Duration(seconds: 90);
  }


  bool get _pendingTerminal => _pendingProjection?.kind==DriverRealtimeKind.riderCancelled || _pendingProjection?.status?.isTerminal==true;
















  bool get _onTripRadarOn =>
      _onTripRadarState == _OnTripRadarState.scanning ||
      _onTripRadarState == _OnTripRadarState.offerAvailable ||
      _onTripRadarState == _OnTripRadarState.matching ||
      _onTripRadarState == _OnTripRadarState.secured;


  _NextTripRadarOffer get _uniqueDemoNext => _NextTripRadarOffer(
    id:'${widget.offerId}-next',category:_demoNextTripOffer.category,fare:_demoNextTripOffer.fare,rating:_demoNextTripOffer.rating,
    pickupMinutes:_demoNextTripOffer.pickupMinutes,pickupKm:_demoNextTripOffer.pickupKm,tripMinutes:_demoNextTripOffer.tripMinutes,riderName:_demoNextTripOffer.riderName,
    pickup:_demoNextTripOffer.pickup,dropoff:_demoNextTripOffer.dropoff,pickupPosition:_demoNextTripOffer.pickupPosition,dropoffPosition:_demoNextTripOffer.dropoffPosition);






  bool get _incomingOfferOpen =>
      _stage == ActiveRideStage.onTrip &&
      _onTripRadarState == _OnTripRadarState.offerAvailable &&
      _nextTripRadarOffer != null;









  /// Q19/Q20: free wait, price per minute, no-show time and fee, and the
  /// driver's share, from the waiting rules for this pickup (distance,
  /// ride type, category).
  late final WaitingTerms _waitTerms = WaitingRules.current.termsFor(
    category: widget.category,
    type: WaitingRules.typeOf(
      matchedVia: widget.matchedVia,
      pickupAddress: widget.pickupAddress,
    ),
    pickupKm: widget.pickupKm,
  );
  /// Q24: the last leg of a cash trip, cash not collected yet: the main
  /// button is "Collect cash" instead of the slide.
  bool get _collectsCashNow =>
      widget.paidByCash &&
      _stage == ActiveRideStage.onTrip &&
      !_paidStopWait &&
      _stopCursor >= widget.stopAddresses.length;

  /// R8-4: the cash taken from the rider; the fare unless a promotion
  /// changed it.
  String get _cashToCollect => widget.cashToCollect ?? widget.fare;
  int get _includedWaitSeconds => _waitTerms.freeSeconds;
  int get _noShowWaitSeconds => _waitTerms.noShowSeconds;

  bool get _inIncludedWait =>
      !_paidStopWait && _waitSeconds < _includedWaitSeconds;

  String get _waitBarStatus {
    if (_paidStopWait) { return 'Paid wait at stop ${_stopCursor + 1}'; }
    if (_inIncludedWait) { return 'Included wait · then paid'; }
    if (_waitSeconds < _noShowWaitSeconds) { return 'Paid wait running'; }
    return 'Paid wait · no-show available';
  }

  /// Share of the pickup wait window used (free minutes, then paid up to
  /// the no-show point); null at a stop, where waiting is paid throughout.
  Color get _waitBarColor {
    if (_inIncludedWait) { return _ink; }
    if (!_paidStopWait && _waitSeconds >= _noShowWaitSeconds) {
      return const Color(0xFF9E2B33);
    }
    return const Color(0xFF146B45);
  }


  String get _slideLabel {
    // Q30: the main trip buttons read admin's Driver app texts.
    if (_paidStopWait) {
      final next = _stopCursor + 2;
      if (next <= widget.stopAddresses.length) {
        return driverText(DriverTexts.tripGoToStop, {
          'stop': _AcceptRideTrip(this)._stopWord(next),
        });
      }
      return driverText(DriverTexts.tripGoToDropoff);
    }
    return driverText(switch (_stage) {
      ActiveRideStage.headingToPickup => DriverTexts.tripArrived,
      ActiveRideStage.waitingForRider => widget.stopAddresses.isEmpty
          ? DriverTexts.tripStart
          : DriverTexts.tripStartFirstStop,
      ActiveRideStage.onTrip => _stopCursor < widget.stopAddresses.length
          ? DriverTexts.tripArriveAtStop
          : DriverTexts.tripComplete,
    });
  }

  String get _slideConfirmedLabel {
    if (_paidStopWait) {
      return _stopCursor + 1 < widget.stopAddresses.length
          ? 'Next stop'
          : 'To drop-off';
    }
    return switch (_stage) {
      ActiveRideStage.headingToPickup => 'Waiting',
      ActiveRideStage.waitingForRider => 'Trip started',
      ActiveRideStage.onTrip => 'Trip completed',
    };
  }


  String get _onwardAddress {
    if (_stopCursor < widget.stopAddresses.length &&
        (_stage == ActiveRideStage.onTrip ||
            _stage == ActiveRideStage.waitingForRider)) {
      return widget.stopAddresses[_stopCursor];
    }
    return widget.dropoffAddress;
  }

  String get _nextStopAddress {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return widget.pickupAddress;
      case ActiveRideStage.waitingForRider:
      case ActiveRideStage.onTrip:
        return _onwardAddress;
    }
  }

  String get _nextStopDetail {
    switch (_stage) {
      case ActiveRideStage.headingToPickup:
        return 'Pick up ${widget.riderName}';
      case ActiveRideStage.waitingForRider:
        return _riderOnTheWay
            ? '${widget.riderName} is on the way'
            : 'Hold for ${widget.riderName}';
      case ActiveRideStage.onTrip:
        if (widget.stopAddresses.isEmpty) { return widget.riderName; }
        if (widget.stopAddresses.length == 1) { return 'Then drop-off'; }
        return 'Stop 1 of ${widget.stopAddresses.length}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutViewport(
      child: PopScope(
        canPop: false,
        child: Scaffold(
      key: _rideScaffoldKey,
      // The menu opens from the island, not by swiping over the map.
      drawer: const DriverSideMenu(isOnline: true),
      drawerEnableOpenDragGesture: false,
      backgroundColor: _canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxHeight;
          final collapsed = MoveraSheetMetrics.activeCollapsedTotal(
            MediaQuery.paddingOf(context).bottom,
          );
          final safeTop = MediaQuery.paddingOf(context).top;
          final bannerReserve = safeTop + 210;
          final expanded = math.min(
            MoveraSheetMetrics.expandedHeight(viewport),
            math.max(collapsed + 160, viewport - bannerReserve),
          );
          final snap = MoveraSheetMetrics.activeSnapPoint(
            collapsed: collapsed,
            middle: _AcceptRidePanel(this)._rideMiddleTotal(context),
            expanded: expanded,
          );

          final offerOpen = _incomingOfferOpen;
          // Browsing keeps the collapsed sheet visible.
          final sheetFloor = collapsed;
          return Stack(
            children: [
              SlidingUpPanel(
            controller: _ridePanelController,
            minHeight: offerOpen ? 0 : sheetFloor,
            maxHeight: offerOpen ? 1 : expanded,
            snapPoint: snap,
            panelSnapping: false,
            defaultPanelState: PanelState.CLOSED,
            isDraggable: !offerOpen,
            color: Colors.transparent,
            boxShadow: const [],
            backdropEnabled: false,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            onPanelSlide: (pos) {
              _ridePanelPosition.value = pos;
              if (!_ridePointerActive) {
                _AcceptRidePanel(this)._scheduleRideSheetPositionGuard();
              }
            },
            onPanelOpened: () {
              _rideSheetPositionGuardTimer?.cancel();
              _ridePanelPosition.value = 1;
            },
            onPanelClosed: () {
              _rideSheetPositionGuardTimer?.cancel();
              _ridePanelPosition.value = 0;
            },
            panel: offerOpen
                ? const SizedBox.shrink()
                : _AcceptRidePanel(this)._mapOverlay(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _AcceptRidePanel(this)._onRideSheetPointerDown,
                onPointerMove: _AcceptRidePanel(this)._onRideSheetPointerMove,
                onPointerUp: _AcceptRidePanel(this)._onRideSheetPointerEnd,
                onPointerCancel: _AcceptRidePanel(this)._onRideSheetPointerEnd,
                child: KeyedSubtree(
                  key: _ridePanelKey,
                  child: _AcceptRidePanel(this)._buildRidePanel(),
                ),
              ),
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                AbsorbPointer(
                  absorbing: _blockMapGestures,
                  child: Listener(
                  onPointerDown: (event) {
                    _mapZoomSettle.pointerDown(event.pointer);
                    _mapPointers = _mapZoomSettle.activePointers;
                    if (_mapPointers >= 2) { _lastMapZoom = DateTime.now(); }
                  },
                  onPointerMove: (_) {
                    if (_mapPointers >= 2) { _lastMapZoom = DateTime.now(); }
                  },
                  onPointerUp: (event) {
                    if (_mapZoomSettle.pointerEnded(event.pointer)) {
                      _finishBrowseSheetCollapse();
                    }
                    _mapPointers = _mapZoomSettle.activePointers;
                  },
                  onPointerCancel: (event) {
                    if (_mapZoomSettle.pointerEnded(event.pointer)) {
                      _finishBrowseSheetCollapse();
                    }
                    _mapPointers = _mapZoomSettle.activePointers;
                  },
                  onPointerSignal: (_) => _lastMapZoom = DateTime.now(),
                  child: _ThrottledVehicleMap(
                    key: const ValueKey<String>('active-ride-throttled-map'),
                    vehicle: _vehicle,
                    vehicleIcon: _driverVehicleIcon,
                    stage: _stage,
                    pickupPosition: widget.pickupPosition,
                    dropoffPosition: widget.dropoffPosition,
                    pickupAddress: widget.pickupAddress,
                    dropoffAddress: widget.dropoffAddress,
                    stopPositions: widget.stopPositions,
                    stopCursor: _stopCursor,
                    pinIcons: _pinIcons,
                    polylines: _polylines,
                    padding: MapOverlayInsets.forActiveRide(
                      safeTop: safeTop,
                      collapsedSheet: collapsed,
                    ).drivingInsets(MediaQuery.sizeOf(context).height,
                      following: _camera.isGuidance &&
                          _camera.mode == DriverCameraMode.following),
                    cameraAnchor: _camera.isGuidance &&
                        _camera.mode == DriverCameraMode.following ? .72 : .5,
                    blockGestures: _blockMapGestures,
                    initialTarget: _driverPosition,
                    onCameraMove: _onCameraMoveListener,
                    onCameraIdle: () => _cameraPort?.onIdle(),
                    onUserGesture: () {
                      _rebuild(_camera.userGesture);
                      if (!MediaQuery.disableAnimationsOf(context)) {
                        _browsePulse.repeat();
                      }
                      _navigation.pauseFollow();
                    },
                    onMapCreated: (controller) {
                      _cameraPort = GoogleDriverCameraPort(controller,
                        onStatus: (status) {
                          if (status != null && mounted && ModalRoute.of(context)?.isCurrent == true) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status),
                              action: SnackBarAction(label: 'Retry', onPressed: _camera.recenter)));
                          }
                        },
                        onFrame: (position) {
                          if (_camera.mode == DriverCameraMode.following &&
                              _camera.isGuidance) {
                            _vehicle.snapTo(position.target, _camera.vehicleCourse);
                          }
                        },
                        initialPosition: CameraPosition(target: _driverPosition,
                          zoom: 15.8),
                        reducedMotion: MediaQuery.disableAnimationsOf(context));
                      _camera.attach(_cameraPort!);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) { unawaited(_AcceptRideTrip(this)._fitRoute()); }
                      });
                    },
                  ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _AcceptRidePanel(this)._mapOverlay(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_navigation, _rideCheck]),
                      // The Ride check card grows out of the island and covers it.
                      builder: (context, _) => IgnorePointer(ignoring: _rideCheck.covering, child: Opacity(
                        opacity: _rideCheck.covering ? 0 : 1, child: AdaptiveTripIsland(
                        banner: _navigation.snapshot.banner,
                        status: _navigation.snapshot.status ?? _islandStatus,
                        address: _showArrivalApproach ? _approachAddress : _nextStopAddress,
                        detail: _nextStopDetail,
                        eta: _routeEtaText,
                        arrival: _showArrivalApproach ? _approachLabel : null,
                        arrived: _arrivalApproachArrived,
                        progress: _legFraction ?? 0,
                        waitingSeconds: _countingWait ? _waitSeconds : null,
                        paidSeconds: _countingWait ? (_paidStopWait ? _waitSeconds : math.max(0, _waitSeconds - _includedWaitSeconds)) : null,
                        waitingAtStop: _paidStopWait,
                        navigationStatus: _locationStatus ?? _navigation.snapshot.status,
                        reroutes: _navigation.reroutes,
                        waitingMessage: _tripBarStatus,
                        paidWait: _paidStopWait || (_countingWait && !_inIncludedWait),
                        paidByCash: widget.paidByCash,
                        lastTripLabel: _waybills.last?.fare ?? DigitalIslandParts.sampleLastTrip,
                        radarVisible: _stage == ActiveRideStage.onTrip,
                        radarOn: _onTripRadarOn,
                        onRadar: _AcceptRideTrip(this)._toggleOnTripRadar,
                        onMenu: () => _rideScaffoldKey.currentState?.openDrawer(),
                        onSearch: _openDestinationPicker,
                        onHistory: () => pushSingle(context,
                          MaterialPageRoute<void>(builder: (_) => const DriverRideHistory())),
                        onRoute: _AcceptRidePanel(this)._showTripOptions,
                        onSafety: () => showSafetyToolKitSheet(context),
                        onWait: _AcceptRidePanel(this)._openWaitingTime,
                        rideCheck: _rideCheck.active,
                        onRideCheckDemo: driverProductionRequested ? null : _AcceptRideTrip(this)._openRideCheckDemo,
                      ))),
                    ),
                  ),
                ),
                // The map buttons ride on top of the sheet and leave once
                // it opens past the middle.
                ValueListenableBuilder<double>(
                  valueListenable: _ridePanelPosition,
                  builder: (context, pos, controls) {
                    final lift = math.min(pos, snap) * (expanded - collapsed);
                    final hidden = pos > snap + 0.04;
                    return Positioned(
                      key: const ValueKey<String>('active-ride-map-controls'),
                      right: 14,
                      bottom: math.max(sheetFloor, MediaQuery.paddingOf(context).bottom) + lift + 16,
                      child: IgnorePointer(
                        ignoring: hidden,
                        child: AnimatedOpacity(
                          opacity: hidden ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: controls,
                        ),
                      ),
                    );
                  },
                  child: _AcceptRidePanel(this)._mapOverlay(child: _AcceptRidePanel(this)._buildMapControls()),
                ),
              ],
            ),
              ),
              if (offerOpen)
                Positioned(
                  key: const ValueKey<String>('on-trip-radar-layer'),
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.paddingOf(context).bottom + 12,
                  child: _AcceptRidePanel(this)._buildIncomingRideCard(),
                ),
              // Above the sheet and offers; nothing under it works until
              // the driver answers.
              Positioned.fill(child: ListenableBuilder(listenable: _rideCheck,
                builder: (context, _) => !_rideCheck.active ? const SizedBox.shrink()
                    : _AcceptRidePanel(this)._mapOverlay(child: RideCheckLayer(
                        key: const ValueKey<String>('ride-check-layer'),
                        controller: _rideCheck,
                        top: AdaptiveTripIsland.islandTop(context),
                        maxHeight: viewport - AdaptiveTripIsland.islandTop(context) -
                            math.max(12.0, MediaQuery.paddingOf(context).bottom + 8),
                      )))),
            ],
          );
        },
      ),
    ),
    ),
    );
  }


  bool get _freshRadarLocation => _hasLiveLocation && _lastLocation?.isUsableAt(DateTime.now()) == true && hasFreshLocation(
    GeoPointMaps.fromLatLng(_driverPosition), _lastGpsAppliedAt, DateTime.now());

















}

class _ThrottledVehicleMap extends StatefulWidget {
  const _ThrottledVehicleMap({
    super.key,
    required this.vehicle,
    required this.vehicleIcon,
    required this.stage,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.pickupAddress,
    required this.stopPositions,
    required this.stopCursor,
    required this.pinIcons,
    required this.dropoffAddress,
    required this.polylines,
    required this.padding,
    required this.cameraAnchor,
    required this.blockGestures,
    required this.initialTarget,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onUserGesture,
  });

  final LiveVehicleAnimator vehicle;
  final BitmapDescriptor vehicleIcon;
  final ActiveRideStage stage;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final String pickupAddress;
  final String dropoffAddress;
  final List<LatLng> stopPositions;
  final int stopCursor;
  final Map<RouteMarkKind, BitmapDescriptor> pinIcons;
  final Set<Polyline> polylines;
  final EdgeInsets padding;
  final double cameraAnchor;
  final bool blockGestures;
  final LatLng initialTarget;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;
  final VoidCallback onUserGesture;

  @override
  State<_ThrottledVehicleMap> createState() => _ThrottledVehicleMapState();
}

class _ThrottledVehicleMapState extends State<_ThrottledVehicleMap> {
  Timer? _ticker;
  late LiveVehiclePose _pose;

  @override
  void initState() {
    super.initState();
    _pose = widget.vehicle.current;
    if (!DriverRuntimeConfig.current.liveMapTicker) { return; }
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) { return; }
      final next = widget.vehicle.current;
      if (next.position.latitude == _pose.position.latitude &&
          next.position.longitude == _pose.position.longitude &&
          next.headingDegrees == _pose.headingDegrees) {
        return;
      }
      setState(() => _pose = next);
    });
  }

  @override
  void didUpdateWidget(covariant _ThrottledVehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.vehicle, widget.vehicle)) {
      _pose = widget.vehicle.current;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('driver'),
        position: _pose.position,
        rotation: _pose.headingDegrees,
        flat: true,
        anchor: MoveraVehicleMarker.anchor,
        zIndexInt: 12,
        icon: widget.vehicleIcon,
        // No default map bubble on the car.
        consumeTapEvents: true,
        infoWindow: const InfoWindow(title: 'Driver camera vehicle'),
      ),
    };
    Marker pin(String id, LatLng at, RouteMarkKind kind) => Marker(
          markerId: MarkerId(id),
          position: at,
          icon: widget.pinIcons[kind] ?? BitmapDescriptor.defaultMarker,
          anchor: RouteMarkPins.pinAnchor,
          zIndexInt: 8,
          consumeTapEvents: true,
        );

    // Pins in the colour of what they mark: green pickup, orange stops,
    // black drop-off.
    if (widget.stage != ActiveRideStage.onTrip) {
      markers.add(pin('pickup', widget.pickupPosition, RouteMarkKind.pickup));
    } else {
      for (var i = widget.stopCursor; i < widget.stopPositions.length; i++) {
        markers.add(pin('stop-$i', widget.stopPositions[i], RouteMarkKind.stop));
      }
      markers.add(pin('dropoff', widget.dropoffPosition, RouteMarkKind.dropoff));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomGoogleMap(
        key: const ValueKey<String>('active-ride-map'),
        initialPosition: CameraPosition(
          target: widget.initialTarget,
          zoom: 15.8,
        ),
        markers: _markers,
        polylines: widget.polylines,
        cameraAnchor: widget.cameraAnchor,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
          webCameraControlEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        trafficEnabled: true,
        buildingsEnabled: true,
        indoorViewEnabled: false,
        scrollGesturesEnabled: !widget.blockGestures,
        zoomGesturesEnabled: !widget.blockGestures,
        rotateGesturesEnabled: !widget.blockGestures,
        tiltGesturesEnabled: !widget.blockGestures,
        mapType: MapType.normal,
        padding: widget.padding,
        onCameraMove: widget.onCameraMove,
        onCameraIdle: widget.onCameraIdle,
        onUserGesture: widget.onUserGesture,
        onMapCreated: widget.onMapCreated,
      ),
    );
  }
}

class _SlideRideAction extends StatefulWidget {
  const _SlideRideAction({
    super.key,
    required this.semanticsKey,
    required this.label,
    required this.confirmedLabel,
    required this.accent,
    required this.onConfirmed,
  });

  final Key semanticsKey;
  final String label;
  final String confirmedLabel;

  /// Colour of the track once the action is confirmed.
  final Color accent;
  final Future<void> Function() onConfirmed;

  @override
  State<_SlideRideAction> createState() => _SlideRideActionState();
}

class _SlideRideActionState extends State<_SlideRideAction> {
  static const double _height = 58;
  static const double _thumb = 58;
  static const double _trigger = 0.78;

  double _fraction = 0;
  bool _dragging = false;
  bool _confirmed = false;
  bool _confirming = false;

  @override
  void didUpdateWidget(covariant _SlideRideAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label == widget.label &&
        oldWidget.accent == widget.accent) {
      return;
    }
    _fraction = 0;
    _dragging = true;
    _confirmed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _confirmed || _fraction != 0) { return; }
      setState(() => _dragging = false);
    });
  }

  void _update(double delta, double maxTravel) {
    if (_confirmed || _confirming || maxTravel <= 0) { return; }
    final next = (_fraction + (delta / maxTravel)).clamp(0.0, 1.0);
    setState(() {
      _dragging = true;
      _fraction = next >= _trigger ? 1 : next;
    });
  }

  void _cancelDrag() {
    if (_confirming || !mounted) { return; }
    setState(() { _dragging = false; _fraction = 0; _confirmed = false; });
  }

  Future<void> _finish() async {
    if (_confirming) { return; }
    if (_fraction < _trigger) { _cancelDrag(); return; }
    setState(() { _confirmed = true; _confirming = true; _dragging = false; _fraction = 1; });
    HapticFeedback.mediumImpact();
    try {
      await widget.onConfirmed();
    } catch (_) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The action could not be completed. Please retry.'))); }
    } finally {
      if (mounted) { setState(() { _confirmed = false; _confirming = false; _fraction = 0; _dragging = false; }); }
    }
  }

  Future<void> _accessibleConfirm() async {
    if(_confirming) { return; }
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:Text(widget.label.replaceFirst('Slide to ','')),
      content:const Text('Confirm this trip action?'),
      actions:[TextButton(onPressed:()=>popOwned(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>popOwned(context,true),child:const Text('Confirm'))]));
    if(!mounted || confirmed!=true || _confirming) { return; }
    _fraction=1;
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: widget.semanticsKey,
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTravel = math.max(0.0, constraints.maxWidth - _thumb);

          return Semantics(
            button:true, enabled:!_confirming,
            label:widget.label.replaceFirst('Slide to ',''),
            onTap:_confirming ? null : _accessibleConfirm,
            child:FocusableActionDetector(
              shortcuts:const <ShortcutActivator,Intent>{SingleActivator(LogicalKeyboardKey.enter):ActivateIntent(),SingleActivator(LogicalKeyboardKey.space):ActivateIntent()},
              actions:<Type,Action<Intent>>{ActivateIntent:CallbackAction<ActivateIntent>(onInvoke:(_) { _accessibleConfirm();return null; })},
              child:GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) =>
                _update(details.delta.dx, maxTravel),
            onHorizontalDragEnd: (_) => _finish(),
            onHorizontalDragCancel: _cancelDrag,
            // Light track with a black square thumb carrying an arrow.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _confirmed ? widget.accent : const Color(0xFFEEEFF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: _dragging
                              ? Duration.zero
                              : const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: _thumb + maxTravel * _fraction,
                          color: const Color(0xFF111614).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _thumb + 8,
                    right: 12,
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds:180),
                      child: Text(
                        _confirmed ? widget.confirmedLabel : widget.label,
                        key: ValueKey<String>(
                          _confirmed ? widget.confirmedLabel : widget.label,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _confirmed ? Colors.white : const Color(0xFF111614),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: maxTravel * _fraction,
                    top: 0,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111614),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _confirmed
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )));
        },
      ),
    );
  }
}
