import 'package:movera/presentation/driver/accept ride/route_change_sheet.dart';
import 'package:movera/widgets/initials_avatar.dart';
import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_external_action.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/presentation/driver/sheets/sheet_trace.dart';
import 'package:movera/core/location/location_freshness.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/open_trip_screens.dart';
import 'package:movera/core/content/driver_app_texts.dart';

import 'dart:async';

import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/driver_map_zoom_change_detector.dart';
import 'package:movera/core/navigation/map_zoom_sheet_settle.dart';
import 'package:movera/core/navigation/trip_camera_sheet_inset.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_step_busy.dart';
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
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/presentation/common/chat/trip_call.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/next_trip_gate.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/pickup_pin.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/accept%20ride/pickup_pin_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_card.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_radar_dock.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_sheet_motion.dart';
import 'package:movera/presentation/driver/accept%20ride/finish_soon_sheet.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_route_lines.dart';
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
import 'package:movera/presentation/driver/deferred_screens.dart';
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
part 'accept_ride_trip_chat.dart';
part 'accept_ride_trip_outcome.dart';
part 'accept_ride_trip_drive.dart';
part 'accept_ride_trip_next.dart';
part 'accept_ride_server_next.dart';
part 'accept_ride_trip_cover.dart';
part 'accept_ride_panel.dart';
part 'accept_ride_panel_clean.dart';
part 'accept_ride_offer_card.dart';
part 'accept_ride_trip_options.dart';
part 'accept_ride_sheet.dart';
part 'accept_ride_late_eta.dart';
part 'accept_ride_live.dart';
part 'accept_ride_pickup.dart';
part 'accept_ride_route_change.dart';
part 'accept_ride_state_getters.dart';
part 'accept_ride_widgets.dart';

class AcceptRide extends StatefulWidget {
  const AcceptRide({
    super.key,
    this.offerId,
    String? tripId,
    this.riderName = 'Angelica',
    // G4 decision 3: no made-up rating; none shows "New".
    this.riderRating,
    this.riderTrips = 0,
    this.fare = '—',
    this.paidByCash = false,
    this.cashToCollect,
    this.riderFare,
    this.driverBonus,
    this.category = 'Movera',
    this.matchedVia = WaybillRecord.demoRadarSource,
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
    this.bags = 0,
    this.dispatchRepository,
    this.scheduledPickupAt,
    this.scheduledRideId,
    this.bookedTime,
  }) : tripId = tripId ?? 'demo-radar-offer';

  /// A scheduled ride opened at "Leave now": its pickup time, on
  /// [ScheduledClock.instance]. While heading to the pickup the trip
  /// watches the ETA to it (`reservations.lateEta`). Null: any other trip,
  /// never watched.
  final DateTime? scheduledPickupAt;

  /// That reservation's id; empty for a sample ride.
  final String? scheduledRideId;
  final String? bookedTime; // "Booked ride" badge (owner 2026-11-03)

  /// Bags the rider said they bring; the trip island mentions them.
  final int bags;

  /// How far the pickup was when the trip was accepted, for the waiting
  /// rule by pickup distance (Q20); null when not known.
  final double? pickupKm;

  final Future<bool> Function(Uri)? launchExternalMap;

  /// Ride check services; the app's [RideCheckScope] when omitted.
  final RideCheckServices? rideCheck;

  /// X9: the trip (contract `tripId`). Realtime, persistence, waybills and
  /// the session all key on it. Without one, a bare widget (tests, demo)
  /// uses a fixed demo id.
  final String tripId;

  /// The dispatch offer the driver claimed for this trip, when there was
  /// one. Never used as the trip's id.
  final String? offerId;

  /// UI-04: the in-trip menu claims and releases reservations through the
  /// same dispatch as Home.
  final DispatchRepository? dispatchRepository;

  /// Clock for elapsed waiting time and the next-trip offer's time to
  /// accept; injectable for lifecycle verification.
  final DateTime Function()? waitNow;
  final String riderName;

  /// Null when dispatch sent no usable rating (driver-u133).
  final double? riderRating;
  final int riderTrips;

  /// The driver's own money for the trip, e.g. "83,26 kr": the offer's
  /// `driverPay` with the card's pickup pay in it (owner decision
  /// 2026-10-26, "price must be after commission that show to driver").
  /// The trip card, the waybill, the finish screen and history all show
  /// it; the rider's fare is never shown.
  final String fare;

  /// Cash in the car; otherwise paid by card. Shown as a logo in the bar.
  final bool paidByCash;

  /// R8-4: on a cash trip, the cash to take from the rider: their own
  /// fare (`RideOffer.riderCash`), never [fare]. Null only on a trip saved
  /// before [fare] became the driver's pay.
  final String? cashToCollect;

  /// Owner N11: what the rider pays ("208,00 kr"), for the waybill only.
  final String? riderFare;

  /// Q16/Q18: Movera's bonus already in [fare]; earnings say "incl. +X".
  final Money? driverBonus;
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
    DispatchRepository? dispatchRepository,
  }) {
    final pickup = record.pickup;
    return AcceptRide(
      key: key,
      tripId: record.tripId,
      riderName: record.riderName,
      fare: record.fare,
      riderFare: record.riderFare,
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
      dispatchRepository: dispatchRepository,
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
    DispatchRepository? dispatchRepository,
    DriverRealtime? realtime,
  }) {
    if (!snapshot.hasVerifiedEndpoints) {
      throw StateError(
        'Saved trip requires verified pickup and drop-off coordinates',
      );
    }
    final pickup = snapshot.pickupAddress ?? tr.addressUnavailable;
    return AcceptRide(
      key: key,
      tripId: snapshot.tripId,
      riderName: snapshot.riderName ?? tr.riderDataUnavailable,
      riderRating: snapshot.riderRating,
      riderTrips: snapshot.riderTrips ?? 0,
      fare: snapshot.fare ?? '—',
      paidByCash: snapshot.paidByCash,
      cashToCollect: snapshot.cashToCollect,
      riderFare: snapshot.riderFare,
      driverBonus: snapshot.driverBonus,
      category: snapshot.category ?? 'Movera',
      matchedVia: snapshot.matchedVia ?? WaybillRecord.demoRadarSource,
      pickupAddress: pickup,
      pickupArea: snapshot.pickupArea ?? pickup.split(',').last.trim(),
      dropoffAddress: snapshot.dropoffAddress ?? 'Stockholm',
      stopAddresses: snapshot.stopAddresses,
      stopPositions: snapshot.stopPoints
          .map((point) => point.toLatLng())
          .toList(),
      pickupPosition: LatLng(snapshot.pickupLat!, snapshot.pickupLng!),
      dropoffPosition: LatLng(snapshot.dropoffLat!, snapshot.dropoffLng!),
      locationRepository: locationRepository,
      routeRepository: routeRepository,
      waybillRepository: waybillRepository,
      sessionController: sessionController,
      activeRideRepository: activeRideRepository,
      dispatchRepository: dispatchRepository,
      realtime: realtime,
      initialStage: snapshot.stage,
      initialWaitSeconds: snapshot.waitSeconds ?? 0,
      restoredSnapshot: snapshot,
      destinationModeActive: snapshot.destinationModeActive,
      destinationAddress: snapshot.destinationAddress,
      destinationPosition: snapshot.destinationPoint?.toLatLng(),
      scheduledPickupAt: snapshot.scheduledPickupAt,
      scheduledRideId: snapshot.scheduledRideId,
      pickupKm: snapshot.pickupKm,
      bags: snapshot.bags,
    );
  }

  @override
  State<AcceptRide> createState() => _AcceptRideState();
}

enum _OnTripRadarState {
  off,
  scanning,
  offerAvailable,
  matching,
  secured,
  stopped,
}

class _TripCancellationReason {
  const _TripCancellationReason({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String code;
  final String title;
  final String subtitle;
  final MoveraMark icon;

  /// The line under the title. L-c (owner 2026-11-06): every give-back
  /// counts, so no reason says "Doesn't count".
  String get detail => subtitle;
}

class _AcceptRideState extends State<AcceptRide>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  bool _sawOpenTrip = false; // G9 live: trip seen open here.
  final DriverRealtimeSequenceGate _realtimeGate = DriverRealtimeSequenceGate();
  static const Color _ink = Color(0xFF252E3A);
  static const Color _panel = Color(0xFFFFFFFF);
  static const Color _canvas = Color(0xFFF4F6F7);
  static const Color _muted = Color(0xFF7D898F);
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
      );

  static List<_TripCancellationReason> get _preTripCancellationReasons => [
    for (final reason in CancelReasons.current.of(
      CancelReasonGroup.driverBeforeTrip,
    ))
      _reason(reason),
  ];

  static _TripCancellationReason get _noShowReason =>
      _reason(CancelReasons.current.shown(CancelReasons.current.noShow));

  static List<_TripCancellationReason> get _onTripCancellationReasons => [
    for (final reason in CancelReasons.current.of(
      CancelReasonGroup.driverDuringTrip,
    ))
      _reason(reason),
  ];

  /// R13: cancelling the secured next trip during a trip.
  static List<_TripCancellationReason> get _nextTripCancellationReasons => [
    for (final reason in CancelReasons.current.of(
      CancelReasonGroup.driverNextTrip,
    ))
      _reason(reason),
  ];

  static const _NextTripRadarOffer _demoNextTripOffer = _NextTripRadarOffer(
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
  // Until the arrow is drawn: one transparent pixel, never a Google pin.
  BitmapDescriptor _driverVehicleIcon = MoveraVehicleMarker.placeholder;
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
  late final TripSheetMotion _tripMotion = _AcceptRidePanel(
    this,
  )._newTripMotion();
  // Measured middle sheet: down to the stage's main action.
  final GlobalKey _middleActionKey = GlobalKey();
  final GlobalKey _ridePanelKey = GlobalKey();
  double? _middleMeasured;
  double? _fullMeasured;
  final GlobalKey _fullScrollKey = GlobalKey();
  final GlobalKey _fullContentKey = GlobalKey();
  bool _ridePointerActive = false;
  Timer? _rideSheetPositionGuardTimer;

  final DriverCameraController _camera = DriverCameraController()
    ..autoResumeAfter = DriverCameraController.tripAutoResume;
  final TripCameraSheetInset _cameraSheet = TripCameraSheetInset();
  GoogleDriverCameraPort? _cameraPort;
  StreamSubscription<DriverLocation>? _positionSubscription;
  late final ActiveRideController _rideLifecycle = ActiveRideController(
    tripId: widget.tripId,
    repository: widget.activeRideRepository,
    initialStage: widget.initialStage,
  );
  ActiveRideStage get _stage => _rideLifecycle.stage;

  /// Finder A4: the step button is disabled with a spinner while [request]
  /// runs.
  Future<T> _whileStepBusy<T>(Future<T> Function() request) async {
    if (mounted) setState(() => _stepBusy = true);
    try {
      return await request();
    } finally {
      if (mounted) setState(() => _stepBusy = false);
    }
  }

  // Trip orchestration lives in an extension, which cannot call setState.
  void _rebuild(VoidCallback update) {
    setState(update);
    _AcceptRideTrip(this)._syncRouteLines();
  }

  double _routeZoomStep = DriverRouteStyle.defaultZoom;

  /// D-07/D-08: the map's route lines; a GPS fix redraws only the map.
  final TripRouteLines _routeLines = TripRouteLines();
  Timer? _waitTimer;
  StreamSubscription<DriverRealtimeEvent>? _realtimeSubscription;
  late final VoidCallback _onNavigationChangedListener = _AcceptRideTrip(
    this,
  )._onNavigationChanged;
  late final VoidCallback _onRideCheckGateListener = _AcceptRideTrip(
    this,
  )._onRideCheckGate;
  late final VoidCallback _syncNavigationStageListener = _AcceptRideTrip(
    this,
  )._syncNavigationStage;
  late final void Function(CameraPosition) _onCameraMoveListener =
      _AcceptRideTrip(this)._onCameraMove;
  late final DriverRealtime _realtime;
  late final bool _ownsRealtime;
  bool _riderOnTheWay = false;
  bool _handlingRiderCancellation = false;
  Timer? _nextTripRadarDemoTimer;
  Timer? _nextTripRadarMatchTimer;
  Timer? _nextTripOfferExpiry;
  DateTime? _nextTripOfferDeadline; // D-05: kept across a pause.
  /// An Exclusive offer while driving a rider: Dispatch's time to accept.
  static Duration get _onTripOfferLifetime =>
      DriverOfferRules.current.exclusiveAcceptTime;
  DateTime? _lastGpsAppliedAt;
  DateTime? _lastSnapshotAt;
  int _shownSaveFailures = 0; // driver-u72
  bool _liveUpdatesPaused = false;
  bool _tripCovered = false; // driver-u80: a route covers the trip.
  bool _menuOpen = false; // driver-r5-33: so does the side menu.
  bool _tripHidden = false; // driver-r5-31: a full screen does (not a sheet).
  int _waitSeconds = 0;

  /// Paid seconds of waits already over (Q42); [_acceptedAt]: contract
  /// `acceptedAt`, kept across restores (Q12).
  int _paidWaitSeconds = 0;
  late DateTime _acceptedAt;
  DateTime? _waitAnchorAt;
  int _waitAnchorSeconds = 0;
  int _stopCursor = 0;
  bool _paidStopWait = false;
  DateTime? _onTripStartedAt;
  _OnTripRadarState _onTripRadarState = _OnTripRadarState.off;
  _NextTripRadarOffer? _nextTripRadarOffer;
  bool _onTripRadarDeclined = false;
  late final _serverNext = _ServerNextOffers(this); // 2026-11-08

  /// R10-2: a next-trip offer came while a Ride check was open; it waits
  /// for the answer from this moment, and drops once its time has passed.
  DateTime? _nextTripOfferHeldAt;

  /// Where the car starts before this screen's first live fix: the last
  /// position the app sent the server (the driver was online before the
  /// offer), else the pickup the driver is heading to. Never a fixed point in
  /// Stockholm, which showed wrong for a second everywhere else (owner,
  /// 2026-10-26).
  late LatLng _driverPosition =
      LiveDriverServices.instance?.reporter.lastKnownPoint?.toLatLng() ??
      _pickupPosition;

  // Contract v0.18.7 (G5, see accept_ride_pickup.dart): the projection's
  // extras, the pickup (moved by `pickup_moved`), and the 10 s poll.
  TripLiveDetails? _live;
  late LatLng _pickupPosition = widget.pickupPosition;

  _ChangedRoute? _changedRoute; // G7, accept_ride_route_change.dart
  final Set<String> _routeChangesSeen = {}, _serverChecksOpened = {};
  // Strip line (moved pickup) and G6 island alert, each said once per key.
  int _islandNoticeKey = 0, _waitingAlertKey = 0;
  String? _islandNotice, _waitingAlert;
  final Set<String> _waitingAlertsShown = <String>{};
  Timer? _followPoll;

  List<GeoPoint> _roadGeoPoints = <GeoPoint>[];
  double? _routeDurationSeconds;

  /// The road route was asked from a live fix, not the fallback position.
  bool _routeFromLiveFix = false;
  bool _hasLiveLocation = false, _preciseLocationOff = false;
  DriverLocation? _lastLocation;
  int _locationEpoch = 0;
  bool _stageTransitioning = false;
  DriverRealtimeEvent? _pendingProjection, _ownCompletionEcho;
  bool _drainingProjection = false;
  Timer? _projectionRetry;
  Timer? _heldJumpConfirm;
  String _vehicleLabel = WaybillRecord.vehicleUnavailable;
  String _vehiclePlate = WaybillRecord.plateUnavailable;

  /// Owner N11: the signed-in driver (live), the brand name in the demo.
  String _driverName = WaybillRecord.moveraDriverName;
  String? _resolvedPickup; // Owner N11: looked up from the coordinates.
  String get _pickupAddress => _resolvedPickup ?? widget.pickupAddress;
  static const Duration _projectionRetryBase = Duration(seconds: 1);
  static const Duration _projectionRetryMax = Duration(seconds: 30);
  Duration _projectionRetryDelay = _projectionRetryBase;
  final _externalMapAction = OwnedExternalAction();
  bool _completionInFlight = false;

  /// Finder A4: a step's request (arrive, price, complete) is running; the
  /// step button shows it ([_whileStepBusy]).
  bool _stepBusy = false;
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

  /// Late ETA: the next check of a scheduled trip's ETA to its pickup.
  Timer? _lateEtaTimer;

  /// Late ETA: the ride is being given to another driver.
  bool _lateEtaReassigning = false;

  /// Late ETA: an ETA was known at least once on this trip.
  bool _lateEtaMeasured = false;
  late final VoidCallback _syncLateEtaListener = _AcceptRideLateEta(
    this,
  )._syncLateEtaWatch;

  late final SheetTrace _sheetTrace = SheetTrace(
    'active',
    () => _ridePanelController.isAttached
        ? _ridePanelController.panelPosition
        : 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A RideCheck demo trip drives its own scripted GPS (DemoTripDrive).
    _locationService =
        DemoTripDrive.forTrip(
          widget.tripId,
          pickup: GeoPointMaps.fromLatLng(_pickupPosition),
          dropoff: GeoPointMaps.fromLatLng(_dropoffPosition),
        ) ??
        widget.locationRepository ??
        const DriverLocationService();
    _routeService =
        widget.routeRepository ??
        RoadRouteService(api: LiveDriverServices.instance?.api);
    _waybills = widget.waybillRepository ?? InMemoryWaybillRepository.instance;
    _navigation = NavigationController(routeRepository: _routeService);
    _navigation.addListener(_onNavigationChangedListener);
    RideCheckGate.listenable.addListener(_onRideCheckGateListener);
    _ownsRealtime = widget.realtime == null;
    // A live build follows the server's trip events; the demo its own bus.
    _realtime =
        widget.realtime ??
        LiveDriverServices.instance?.realtime() ??
        MemoryDriverRealtime();
    _AcceptRideLive(this)._beginLiveTrip();
    _serverNext.start();
    _AcceptRidePickup(this)._beginPickupWaiting();
    _realtimeSubscription = _realtime
        .subscribe(widget.tripId)
        .listen(
          _AcceptRideTrip(this)._onRealtimeEvent,
          onError: (Object error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    tr.tripUpdatesDisconnectedReconnectingIsRequired,
                  ),
                ),
              );
            }
          },
        );
    unawaited(_AcceptRideTrip(this)._resyncTrip());
    _rideLifecycle.snapshotBuilder = _AcceptRideTrip(this)._buildSnapshot;
    _AcceptRideTrip(this)._setUpTripCamera();
    _rideLifecycle.addListener(_AcceptRideTrip(this)._onPersistenceChanged);
    _rideLifecycle.addListener(_syncNavigationStageListener);
    _syncNavigationStageListener();
    _rideLifecycle.addListener(_syncLateEtaListener);
    _AcceptRideTrip(this)._restoreQueuedNextFromSnapshot();
    _AcceptRideTrip(this)._restoreDestinationFromSnapshot();
    final restored = widget.restoredSnapshot;
    _stopCursor = math.min(
      math.max(0, restored?.stopIndex ?? 0),
      _stopAddresses.length,
    );
    _paidStopWait = restored?.paidStopWait == true;
    _onTripStartedAt = restored?.startedAt;
    _waitSeconds = widget.initialWaitSeconds;
    _paidWaitSeconds = restored?.paidWaitSeconds ?? 0;
    _acceptedAt = restored?.acceptedAt ?? DateTime.now();
    // The waiting clocks on this trip follow its terms.
    WaitingTerms.active = _waitTerms;
    // driver-u58: past the freshness window the app was dead, not waiting.
    if (restored?.savedAt != null &&
        restored!.isFresh &&
        (widget.initialStage == ActiveRideStage.waitingForRider ||
            _paidStopWait)) {
      final elapsed = DateTime.now().difference(restored.savedAt!).inSeconds;
      _waitSeconds += math.max(0, elapsed);
    }
    _AcceptRideRouteChange(this)._restoreServerStops();
    OpenTripScreens.add(widget.tripId, _bringToFront);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.sessionController?.beginTrip(widget.tripId);
      if (_waybills.current?.tripId != widget.tripId) {
        _waybills.beginCurrent(_AcceptRideTrip(this)._buildCurrentWaybill());
      }
      if (widget.restoredSnapshot?.next != null &&
          _nextTripRadarOffer != null) {
        _waybills.secureNext(
          _AcceptRideTrip(this)._buildNextWaybill(_nextTripRadarOffer!),
        );
      }
      _AcceptRideTrip(this)._resumeStageSideEffects();
      // Keep the trip dock visible at its lowest resting position.
      if (_ridePanelController.isAttached && !_incomingOfferOpen) {
        _ridePanelController.panelPosition = 0;
      }
      _rideLifecycle.persistNow();
      unawaited(_AcceptRideTrip(this)._loadVehicleIdentity());
      unawaited(_AcceptRideLive(this)._resolvePickupAddress());
      // Right after "Leave now" opened the trip: the first ETA check.
      _AcceptRideLateEta(this)._syncLateEtaWatch(checkNow: true);
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
      initial: LiveVehiclePose(position: _driverPosition, headingDegrees: 0),
    );
    unawaited(_AcceptRideTrip(this)._prepareDriverVehicleMarker());
    _AcceptRideTrip(this)._startLiveLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideCheckServices == null) {
      final services =
          widget.rideCheck ??
          RideCheckScope.read(context) ??
          RideCheckServices.fallback;
      _rideCheckServices = services;
      _rideCheckDetector =
          RideCheckDetector(
              rules: services.rules,
            ) // u44: once per trip, also restored
            ..restoreFired(
              widget.restoredSnapshot?.rideCheckFired ?? const <String>[],
            );
      _rideCheck = RideCheckController(
        services: services,
        tripId: widget.tripId,
        tripDetails: _AcceptRideTrip(this)._safetyAlertTrip,
      );
      _rideCheckTicker = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _AcceptRideTrip(this)._rideCheckTick(),
      );
      _hardStops = services.hardStops?.listen(
        _AcceptRideTrip(this)._rideCheckHardStop,
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _radarPulseController.stop();
      _radarSweepController.stop();
    } else if (!_liveUpdatesPaused) {
      _radarPulseController.repeat(reverse: true);
      _radarSweepController.repeat();
    }
    final route = ModalRoute.of(context);
    if (route != null) {
      driverRouteObserver.subscribe(this, route);
      driverRouteObserver.pages.subscribe(_screenCover, route);
    }
  }

  late final _screenCover = PageCover(
    covered: () => _AcceptRideTrip(this)._hideTrip(),
    uncovered: () => _AcceptRideTrip(this)._showTrip(),
  );
  @override
  void didPushNext() => _AcceptRideTrip(this)._coverTrip(); // driver-u80
  @override
  void didPopNext() => _AcceptRideTrip(this)._uncoverTrip();

  /// S6 I-1: a trip push tap brings this screen back on top.
  late final VoidCallback _bringToFront = _AcceptRideRouteChange(
    this,
  )._bringTripToFront;

  @override
  void dispose() {
    OpenTripScreens.remove(widget.tripId, _bringToFront);
    driverRouteObserver.unsubscribe(this);
    driverRouteObserver.pages.unsubscribe(_screenCover);
    RideCheckGate.listenable.removeListener(_onRideCheckGateListener);
    _rideCheckTicker?.cancel();
    _hardStops?.cancel();
    _rideCheck.dispose();
    _camera.dispose();
    _cameraSheet.dispose();
    final ownedRouting = _routeService;
    if (widget.routeRepository == null && ownedRouting is RoadRouteService) {
      ownedRouting.dispose();
    }
    _browsePulse.dispose();
    _locationEpoch++;
    _projectionRetry?.cancel();
    _heldJumpConfirm?.cancel();
    _sheetTrace.dispose();
    _rideSheetPositionGuardTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _waitTimer?.cancel();
    _followPoll?.cancel();
    _realtimeSubscription?.cancel();
    _realtime.unsubscribe();
    if (_ownsRealtime) {
      _realtime.dispose();
    }
    _nextTripRadarDemoTimer?.cancel();
    _nextTripRadarMatchTimer?.cancel();
    _nextTripOfferExpiry?.cancel();
    _serverNext.dispose();
    _radarPulseController.dispose();
    _radarSweepController.dispose();
    _positionSubscription?.cancel();
    _rideLifecycle.removeListener(_syncNavigationStageListener);
    _rideLifecycle.removeListener(_syncLateEtaListener);
    _lateEtaTimer?.cancel();
    _lateEtaTimer = null;
    _rideLifecycle.dispose();
    _navigation.removeListener(_onNavigationChangedListener);
    _navigation.dispose();
    _vehicle.dispose();
    _routeLines.dispose();
    _snapSheet.dispose();
    _tripMotion.dispose();
    _ridePanelPosition.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // S6 I-2: back from hidden, the stream may be half open: reopen it.
        final wasHidden = _liveUpdatesPaused;
        _AcceptRideTrip(this)._resumeLiveUpdates();
        unawaited(_AcceptRideTrip(this)._resyncTrip(reopen: wasHidden));
      // driver-r4-32: inactive (a shade, a prompt, a call banner) is still on
      // screen: save the trip, keep GPS and the camera.
      case AppLifecycleState.inactive:
        _rideLifecycle.persistNow();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _rideLifecycle.persistNow();
        _AcceptRideTrip(this)._pauseLiveUpdates();
        // driver-u41: no background capture; inactive (a shade) still records.
        unawaited(_rideCheck.appBackgrounded());
    }
  }

  static const double _arrivalApproachThresholdMeters = 300;
  String? _legKey;
  double _legTotalMeters = 0;

  /// Q19/Q20: the zone's served terms until the trip's own arrive (G6:
  /// far / airport / event / scheduled rules are the server's only).
  late final WaitingTerms _zoneWaitTerms = WaitingRules.current.termsFor(
    category: widget.category,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutViewport(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          key: _rideScaffoldKey,
          // The menu opens from the island, not by swiping over the map.
          // UI-04: the same dispatch and the real status as Home's menu.
          onDrawerChanged: (open) => _AcceptRideTrip(this)._menuChanged(open),
          drawer: ListenableBuilder(
            listenable:
                widget.sessionController ??
                const AlwaysStoppedAnimation<double>(0),
            builder: (_, __) => DriverSideMenu(
              isOnline: widget.sessionController?.availableAfterTrip ?? true,
              dispatchRepository: widget.dispatchRepository,
            ),
          ),
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
              final expanded = _AcceptRideSheet(this)._fitRideExpanded(
                math.min(
                  MoveraSheetMetrics.expandedHeight(viewport),
                  math.max(collapsed + 160, viewport - bannerReserve),
                ),
              );
              final snap = MoveraSheetMetrics.activeSnapPoint(
                collapsed: collapsed,
                middle: _AcceptRidePanel(this)._rideMiddleTotal(context),
                expanded: expanded,
              );
              _tripMotion.keep(rangePx: expanded - collapsed, snap: snap);

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
                    // The sheet's own pointer drag moves it (see TripSheetMotion).
                    isDraggable: false,
                    color: Colors.transparent,
                    boxShadow: const [],
                    backdropEnabled: false,
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    onPanelSlide: (pos) {
                      _ridePanelPosition.value = pos;
                      _cameraSheet.sheetMoved(
                        collapsed + pos * (expanded - collapsed),
                        maxInset:
                            viewport -
                            bannerReserve -
                            TripCameraSheetInset.minFreeMap,
                      );
                      if (!_ridePointerActive) {
                        _AcceptRidePanel(
                          this,
                        )._scheduleRideSheetPositionGuard();
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
                              onPointerDown: _AcceptRidePanel(
                                this,
                              )._onRideSheetPointerDown,
                              onPointerMove: _AcceptRidePanel(
                                this,
                              )._onRideSheetPointerMove,
                              onPointerUp: _AcceptRidePanel(
                                this,
                              )._onRideSheetPointerEnd,
                              onPointerCancel: _AcceptRidePanel(
                                this,
                              )._onRideSheetPointerEnd,
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
                              _camera.touching = _mapPointers > 0;
                              if (_mapPointers >= 2) {
                                _lastMapZoom = DateTime.now();
                              }
                            },
                            onPointerMove: (_) {
                              if (_mapPointers >= 2) {
                                _lastMapZoom = DateTime.now();
                              }
                            },
                            onPointerUp: (event) {
                              if (_mapZoomSettle.pointerEnded(event.pointer)) {
                                _finishBrowseSheetCollapse();
                              }
                              _mapPointers = _mapZoomSettle.activePointers;
                              _camera.touching = _mapPointers > 0;
                            },
                            onPointerCancel: (event) {
                              if (_mapZoomSettle.pointerEnded(event.pointer)) {
                                _finishBrowseSheetCollapse();
                              }
                              _mapPointers = _mapZoomSettle.activePointers;
                              _camera.touching = _mapPointers > 0;
                            },
                            onPointerSignal: (_) =>
                                _lastMapZoom = DateTime.now(),
                            child: _ThrottledVehicleMap(
                              key: const ValueKey<String>(
                                'active-ride-throttled-map',
                              ),
                              vehicle: _vehicle,
                              vehicleIcon: _driverVehicleIcon,
                              stage: _stage,
                              pickupPosition: _pickupPosition,
                              dropoffPosition: _dropoffPosition,
                              pickupAddress: _pickupAddress,
                              dropoffAddress: _dropoffAddress,
                              stopPositions: _stopPositions,
                              stopCursor: _stopCursor,
                              pinIcons: _pinIcons,
                              routeLines: _routeLines,
                              padding:
                                  MapOverlayInsets.forActiveRide(
                                    safeTop: safeTop,
                                    collapsedSheet: _cameraSheet.resolve(
                                      collapsed,
                                    ),
                                    // driver-77: browsing keeps the anchor; a flip moves the map.
                                  ).drivingInsets(
                                    MediaQuery.sizeOf(context).height,
                                    following:
                                        _camera.isGuidance &&
                                        _camera.mode !=
                                            DriverCameraMode.overview,
                                  ),
                              cameraAnchor:
                                  _camera.isGuidance &&
                                      _camera.mode == DriverCameraMode.following
                                  ? .75
                                  : .5,
                              blockGestures: _blockMapGestures,
                              initialTarget: _driverPosition,
                              onCameraMove: _onCameraMoveListener,
                              onCameraIdle: () {
                                _cameraPort?.onIdle();
                                _camera.browseSettled();
                              },
                              onUserGesture: () {
                                _rebuild(_camera.userGesture);
                                if (!MediaQuery.disableAnimationsOf(context)) {
                                  _browsePulse.repeat();
                                }
                                _navigation.pauseFollow();
                              },
                              onMapCreated: (controller) {
                                _cameraPort = GoogleDriverCameraPort(
                                  controller,
                                  onStatus: (status) {
                                    if (status != null &&
                                        mounted &&
                                        ModalRoute.of(context)?.isCurrent ==
                                            true) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(status),
                                          action: SnackBarAction(
                                            label: tr.retry,
                                            onPressed: _camera.recenter,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onFrame: (position) {
                                    if (_camera.mode ==
                                            DriverCameraMode.following &&
                                        _camera.isGuidance) {
                                      _vehicle.snapTo(
                                        position.target,
                                        _camera.vehicleCourse,
                                      );
                                    }
                                  },
                                  initialPosition: CameraPosition(
                                    target: _driverPosition,
                                    zoom: DriverCameraPolicy.guidanceStartZoom,
                                    tilt: DriverCameraPolicy.tiltForZoom(
                                      DriverCameraPolicy.guidanceStartZoom,
                                    ),
                                  ),
                                  reducedMotion: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                );
                                _camera.attach(_cameraPort!);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    unawaited(
                                      _AcceptRideTrip(this)._fitRoute(),
                                    );
                                  }
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
                              listenable: Listenable.merge([
                                _navigation,
                                _rideCheck,
                              ]),
                              // The Ride check card grows out of the island and covers it.
                              builder: (context, _) => IgnorePointer(
                                ignoring: _rideCheck.covering,
                                child: Opacity(
                                  opacity: _rideCheck.covering ? 0 : 1,
                                  child: AdaptiveTripIsland(
                                    banner:
                                        NavigationRouteStatus.bannerWithServerEta(
                                          _navigation.snapshot.banner,
                                          _freshServerEtaText,
                                        ),
                                    status:
                                        NavigationRouteStatus.shown(
                                          _navigation.snapshot.status,
                                          hasServerEta: _freshServerEta,
                                        ) ??
                                        _islandStatus,
                                    address: _showArrivalApproach
                                        ? _approachAddress
                                        : _nextStopAddress,
                                    detail: _nextStopDetail,
                                    eta: _routeEtaText,
                                    arrival: _showArrivalApproach
                                        ? _approachLabel
                                        : null,
                                    arrived: _arrivalApproachArrived,
                                    progress: _legFraction ?? 0,
                                    waitingSeconds: _countingWait
                                        ? _waitSeconds
                                        : null,
                                    paidSeconds: _countingWait
                                        ? _AcceptRideTrip(this)._paidWaitNow
                                        : null,
                                    waitingAtStop: _paidStopWait,
                                    navigationStatus:
                                        NavigationRouteStatus.shown(
                                          _navigation.locationLost
                                              ? _navigation.status
                                              : _locationStatus ??
                                                    _navigation.snapshot.status,
                                          hasServerEta: _freshServerEta,
                                        ),
                                    reroutes: _navigation.reroutes,
                                    waitingMessage: _tripBarStatus,
                                    paidWait:
                                        _paidStopWait ||
                                        (_countingWait && !_inIncludedWait),
                                    paidByCash: widget.paidByCash,
                                    lastTripLabel:
                                        _waybills.last?.fare ??
                                        DigitalIslandParts.noAmount,
                                    // driver-u79: a secured next trip cannot be turned off here.
                                    radarVisible:
                                        _stage == ActiveRideStage.onTrip &&
                                        _onTripRadarState !=
                                            _OnTripRadarState.secured,
                                    radarOn: _onTripRadarOn,
                                    onRadar: _AcceptRideTrip(
                                      this,
                                    )._toggleOnTripRadar,
                                    onMenu: () => _rideScaffoldKey.currentState
                                        ?.openDrawer(),
                                    onSearch: _openDestinationPicker,
                                    onHistory: () => pushSingle(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => rideHistoryScreen(),
                                      ),
                                    ),
                                    onRoute: _AcceptRideTripOptions(
                                      this,
                                    )._showTripOptions,
                                    onSafety: () => showSafetyToolKitSheet(
                                      context,
                                      duringTrip: true,
                                    ),
                                    onWait: _AcceptRidePanel(
                                      this,
                                    )._openWaitingTime,
                                    rideCheck: _rideCheck.active,
                                    onRideCheckDemo: driverDemoFeatures
                                        ? _AcceptRideTrip(
                                            this,
                                          )._openRideCheckDemo
                                        : null,
                                    pointKind: _approachKind,
                                    pointLabel: _approachLabel,
                                    bags: widget.bags,
                                    notice: _islandNotice,
                                    noticeKey: _islandNoticeKey,
                                    alert: _waitingAlert,
                                    alertKey: _waitingAlertKey,
                                    nextTripFare:
                                        _onTripRadarState ==
                                            _OnTripRadarState.secured
                                        ? _nextTripRadarOffer?.shownFare
                                        : null,
                                    sheetPosition: _ridePanelPosition,
                                    sheetRaisedAt: snap + 0.04,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The map buttons ride on top of the sheet and leave once
                        // it opens past the middle.
                        ValueListenableBuilder<double>(
                          valueListenable: _ridePanelPosition,
                          builder: (context, pos, controls) {
                            final lift =
                                math.min(pos, snap) * (expanded - collapsed);
                            final hidden = pos > snap + 0.04;
                            return Positioned(
                              key: const ValueKey<String>(
                                'active-ride-map-controls',
                              ),
                              right: 14,
                              bottom:
                                  math.max(
                                    sheetFloor,
                                    MediaQuery.paddingOf(context).bottom,
                                  ) +
                                  lift +
                                  16,
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
                          child: _AcceptRidePanel(this)._buildMapControls(),
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
                      child: _AcceptRidePanel(this)._mapOverlay(
                        child: _AcceptRideOfferCard(
                          this,
                        )._buildIncomingRideCard(),
                      ),
                    ),
                  _AcceptRideRouteChange(this)._buildRouteChangeLayer(context),
                  // Above the sheet and offers; nothing under it works until
                  // the driver answers.
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: _rideCheck,
                      builder: (context, _) => !_rideCheck.active
                          ? const SizedBox.shrink()
                          : _AcceptRidePanel(this)._mapOverlay(
                              child: RideCheckLayer(
                                key: const ValueKey<String>('ride-check-layer'),
                                controller: _rideCheck,
                                top: AdaptiveTripIsland.islandTop(context),
                                maxHeight:
                                    viewport -
                                    AdaptiveTripIsland.islandTop(context) -
                                    math.max(
                                      12.0,
                                      MediaQuery.paddingOf(context).bottom + 8,
                                    ),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _freshRadarLocation =>
      _hasLiveLocation &&
      _lastLocation?.isUsableAt(DateTime.now()) == true &&
      hasFreshLocation(
        GeoPointMaps.fromLatLng(_driverPosition),
        _lastGpsAppliedAt,
        DateTime.now(),
      );
}
