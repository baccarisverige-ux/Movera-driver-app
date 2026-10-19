part of 'home.dart';

// Map, location, and sheet presentation for DriverHome.
// Timers and fields stay on the state. Geometry and map controls are unchanged.

/// One size for the floating controls on Home: recenter, safety and the
/// top island.
const double _homeMapButtonSize = 48;

/// Faces of the top island's screen, in tap order.
enum _IslandFace { hidden, lastTrip, today, history }

const Duration _islandIdleTimeout = Duration(seconds: 5);

/// The whole island, its content included, is drawn at 80 % of its design
/// size.
const double _islandScale = 0.8;

/// Set once the first-launch hint has been shown.
const String _islandHintSeenKey = 'home_island_hint_seen';

/// How long a just-finished trip's money counts as still updating. The
/// demo has no earnings service; a real one would confirm the amount.
const Duration _lastTripSettleTime = Duration(seconds: 4);


extension _HomeMapSheet on _DriverHomeState {
    Future<void> _startDriverLocation({bool moveCamera = false}) async {
      final epoch = ++_locationEpoch;
      if (!_liveVisible) { return; }
      try {
        final position = await _driverLocationService.getCurrentPosition();
        if (!mounted) { return; }
        if (!_liveVisible || epoch != _locationEpoch) { return; }
        final validInitial = position.isDisplayableAt(DateTime.now()) &&
            position.isUsableAt(DateTime.now());
        _applyDriverLocation(position);
        _listenToDriverLocation();
        if (validInitial && (moveCamera || !_didCenterOnLiveLocation)) {
          _didCenterOnLiveLocation = true;
          await _animateToDriverLocation();
        }
      } catch (_) {
        if (!mounted || !_liveVisible || epoch != _locationEpoch) { return; }
        _rebuild(() { _hasLiveDriverLocation = false; _startLocationFailed = true; });
        // A transient one-shot GPS failure must not leave Home without a
        // location subscription until the next app resume or recenter tap.
        // Continuous updates can recover when permissions/provider return.
        _listenToDriverLocation();
      }
    }
    void _listenToDriverLocation() {
      final epoch = _locationEpoch;
      _driverLocationSubscription?.cancel();
      _driverLocationSubscription = _driverLocationService
          .watchPosition(distanceFilterMeters: 8)
          .listen(
        (location) {
          if (!mounted || !_liveVisible || epoch != _locationEpoch) { return; }
          final usable = location.isDisplayableAt(DateTime.now()) &&
              location.isUsableAt(DateTime.now());
          _applyDriverLocation(location);
          if (usable && !_didCenterOnLiveLocation) {
            _didCenterOnLiveLocation = true;
            unawaited(_animateToDriverLocation());
          }
        },
        onError: (_) {
          if (!mounted || !_liveVisible || epoch != _locationEpoch) { return; }
          _rebuild(() { _hasLiveDriverLocation = false; _startLocationFailed = true; });
        },
      );
    }
    void _applyDriverLocation(DriverLocation location) {
      if (!mounted || !_liveVisible) { return; }
      if (!location.isDisplayableAt(DateTime.now())) {
        _rebuild(() => _hasLiveDriverLocation = false);
        return;
      }

      final next = location.point.toLatLng();
      _cameraLocation = location;
      final heading = location.courseOr(_driverHeading);
      _rebuild(() {
        _driverPosition = next;
        _driverHeading = heading;
        _hasLiveDriverLocation = location.isUsableAt(DateTime.now());
        _startPositionKnown = true;
        _markers = _HomeStartPosition(this)._driverMarkers();
      });
      if (_hasLiveDriverLocation) { unawaited(DriverStartPosition.save(location.point)); }

      // Only leaving the route or a slow refresh asks for a new one.
      if (_destinationModeActive && (!_hasLiveDriverLocation ||
          _destinationRouteRefetch.due(position: location.point,
              route: _cameraRoute, now: DateTime.now()))) {
        _refreshDestinationRoadRoute();
      }
      unawaited(_animateToDriverLocation());
    }
    Future<void> _prepareDriverVehicleMarker() async {
      final icon = await MoveraVehicleMarker.createIcon();
      if (!mounted) { return; }
      _rebuild(() {
        _driverVehicleIcon = icon;
        // No car until the driver's position is known (no city fallback).
        if (_startPositionKnown) { _markers = _HomeStartPosition(this)._driverMarkers(); }
      });
    }
    Future<void> _animateToDriverLocation() async {
      final location = _cameraLocation;
      if (location == null || !_liveVisible) { return; }
      _camera.update(location: location,
        route: _destinationModeActive ? _cameraRoute : null,
        navigating: false);
    }
    Future<void> _zoomToDriverLocation() async {
      _camera.recenter();
      await _startDriverLocation();
      if (mounted) { await _animateToDriverLocation(); }
    }
    Widget _buildDriverLocationButton() {
      return PointerInterceptor(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            MapControlButton(
              key: const ValueKey<String>('driver-location-zoom'),
              tooltip: 'Recenter',
              size: _homeMapButtonSize,
              fill: MapControlButton.recenterBlue,
              onTap: _zoomToDriverLocation,
              child: SvgPicture.asset(AppAssets.mapRecenter, width: 22, height: 22),
            ),
            // Live GPS indicator.
            Positioned(
              right: 2,
              top: 2,
              child: IgnorePointer(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _hasLiveDriverLocation
                        ? const Color(0xFF2FBE7B)
                        : const Color(0xFFAAB2B6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    double _homeMapObscuredBottom(BuildContext context) {
      // R11-7: the measured top of the offer card or deck, once known.
      final measured = _HomeOfferRoute(this)._offerCardObscured();
      if (measured != null) { return measured; }
      if (_outsideRadarOffer != null) {
        // The Exclusive sheet, its orb's upper half over the map.
        return MediaQuery.sizeOf(context).height * 0.4 +
            HomeOfferSheet.orbSize / 2;
      }
      if (_isDirectOfferRoutePreview || _radarHomeOffers.isNotEmpty) {
        return 188;
      }
      return MoveraSheetMetrics.collapsedHeight;
    }
    /// R11-7: the offer's whole trip, pickup → drop-off only (no drive to
    /// the pickup), with minute pins, fitted above the card or deck.
    Future<void> _previewDirectOfferRoute(_HomeDirectOffer offer) =>
        _previewTripRoute(
          offer.pickupPosition,
          offer.dropoffPosition,
          () => _HomeOfferRoute(this)._offerRouteMarkers(offer),
          labels: (
            OfferRouteMarks.minutes(offer.pickupMinutes),
            OfferRouteMarks.minutes(offer.tripMinutes),
          ),
          stops: [for (final stop in offer.stops) stop.point.toLatLng()],
        );
    /// A trip's route on the Home map, pickup → drop-off with [pins],
    /// fitted into the free space above the card or sheet: at once on the
    /// pins and [stops], again once the road is in.
    Future<void> _previewTripRoute(
      LatLng pickup,
      LatLng dropoff,
      Future<Set<Marker>> Function() pins, {
      required (String, String) labels,
      List<LatLng> stops = const <LatLng>[],
    }) async {
      if (!mounted) { return; }
      final generation = _mapPreviews.begin();
      bool isCurrent() => mounted && _mapPreviews.owns(generation) &&
          _isDirectOfferRoutePreview;

      final frame = _offerRouteFrame..stopLine();
      frame
        ..road = const <GeoPoint>[]
        ..framing = <LatLng>[pickup, dropoff, ...stops]
        ..pickupLabel = labels.$1
        ..dropoffLabel = labels.$2
        ..fitted = null;
      _rebuild(() {
        _isDirectOfferRoutePreview = true;
        _directOfferRouteMarkers = {};
        _directOfferRoutePolylines = <Polyline>{};
      });
      unawaited(_HomeOfferRoute(this)._fitOfferRoute());

      final markers = await pins();
      if (!isCurrent()) return;
      _rebuild(() => _directOfferRouteMarkers = markers);

      var roadPoints = const <LatLng>[];
      try {
        roadPoints =
            await _HomeOfferRoute(this)._offerRoad(pickup, stops, dropoff);
        if (!isCurrent()) return;
      } catch (_) {
        if (!isCurrent()) return;
      }

      // The route request crossed an async gap: prove context is still mounted.
      if (!mounted || !isCurrent()) return;

      if (roadPoints.length >= 2) {
        _rebuild(() {
          _directOfferRoutePolylines = OfferRouteLine.polylines(roadPoints);
        });
        _HomeOfferRoute(this)._startRouteLine(roadPoints);
      }

      frame.framing = [
        ...MapPreviewGeneration.framingPoints(pickup, dropoff, roadPoints),
        ...stops,
      ];
      await _HomeOfferRoute(this)._fitOfferRoute();
    }
    /// The whole route between the island and the sheet (web maps ignore
    /// padding), zoomed by its length, like an offer's route. The driver
    /// asked for it, so it takes the map even after a pan.
    Future<void> _fitPoints(List<LatLng> points, {double padding = 80}) async {
      final geo = points.map(GeoPointMaps.fromLatLng).toList();
      final size = MediaQuery.sizeOf(context);
      final insets = _HomeOfferRoute(this)._homeMapInsets(context);
      final fit = fitRouteCamera(
        points: [
          for (var i = 0; i < geo.length; i++)
            // The destination pin stands above its point.
            RouteFitPoint(geo[i], left: 20, right: 20, down: 20,
                up: i == geo.length - 1 ? 56 : 20),
        ],
        free: _HomeOfferRoute(this)._offerFreeArea(size, insets),
        targetAt: kIsWeb
            ? size.center(Offset.zero)
            : insets.edgeInsets.deflateRect(Offset.zero & size).center,
      );
      if (fit == null) { return _camera.preview(geo, padding: padding); }
      await _camera.previewFit(fit, points: geo, padding: padding, takeOver: true);
    }
    void _openDestinationModePicker() {
      // R13-9: admin can switch the mode off per zone and limit it per day.
      final refusal = DestinationModeSession.instance.refusal();
      if (refusal != null) {
        IslandMessages.show(refusal == DestinationRefusal.off
            ? HomeIslandNotices.destinationOff
            : HomeIslandNotices.destinationsUsed);
        return;
      }
      _closeHomeFloatingPopupsForSheet();
      if (_mainPanelPosition > 0.001 || isPanelOpen) {
        _panelController.close();
      }
      if (!mounted) { return; }

      // UI-07: one picker per tap burst, so one pick uses one daily use.
      pushSingle<DriverDestinationResult>(
            context,
            MaterialPageRoute(
              builder: (_) => DriverDestinationPicker(
                origin: _driverPosition,
                routeRepository: _roadRouteService,
              ),
            ),
          )
          .then((result) {
            if (!mounted || result == null) { return; }
            _activateDestinationMode(result);
          });
    }
    Future<void> _activateDestinationMode(
      DriverDestinationResult result,
    ) async {
      final destination = result.position;
      _mapPreviews.cancel(); // An old offer cannot reclaim the destination map.
      _destinationRoadRequests.cancel();
      _destinationRouteRefetch.reset();
      _cameraRoute = null;
      final session = DestinationModeSession.instance..started();
      _destinationLimitTimer?.cancel();
      final left = session.timeLeft();
      if (left != null) {
        _destinationLimitTimer = Timer(left, () {
          if (!mounted || !_destinationModeActive) { return; }
          _endDestinationMode();
          DestinationModeSession.instance.timedOut();
          IslandMessages.show(HomeIslandNotices.destinationEnded);
        });
      }
      _rebuild(() {
        _destinationModeActive = true;
        _destinationAddress = result.address;
        _destinationPosition = destination;
        _destinationTrip = result;
        _destinationUntil = result.durationSeconds == null ? null
            : DateTime.now().add(Duration(seconds: result.durationSeconds!.round()));
        _destinationRouteMarkers = {
          destinationModeMarker(destination, result.address),
        };
        _destinationRoutePolylines = <Polyline>{};
      });
      if (MoveraDestinationMarker.cachedPin == null) {
        unawaited(MoveraDestinationMarker.pin().then((_) {
          if (!mounted || _destinationPosition != destination) { return; }
          _rebuild(() => _destinationRouteMarkers = {
            destinationModeMarker(destination, result.address),
          });
        }));
      }

      await _refreshDestinationRoadRoute();
      await _fitDestinationRoute();
      _seedDemoDestinationTrips();
      _HomeOfferRadar(this)._maybeShowSoonReservation();

      if (!_isOnline && !_isGoingOnline) {
        _goOnline();
      }
    }
    Future<void> _refreshDestinationRoadRoute() =>
        _destinationRoadRefresh.request(_fetchLatestDestinationRoadRoute);

    Future<void> _fetchLatestDestinationRoadRoute() async {
      final generation = _destinationRoadRequests.begin();
      final destination = _destinationPosition;
      if (destination == null || !_hasLiveDriverLocation) {
        if (mounted && _destinationRoadRequests.owns(generation)) {
          _cameraRoute = null;
          _rebuild(() => _destinationRoutePolylines = <Polyline>{});
        }
        return;
      }

      try {
        final origin = GeoPointMaps.fromLatLng(_driverPosition);
        _destinationRouteRefetch.asked(origin, DateTime.now());
        final route = await _roadRouteService.drivingRoute(
          origin: origin,
          destination: GeoPointMaps.fromLatLng(destination),
        );
        if (!mounted || !_destinationModeActive ||
            _destinationPosition != destination ||
            !_destinationRoadRequests.owns(generation)) { return; }

        _cameraRoute = route;
        DestinationModeSession.instance.keepRoute(
            GeoPointMaps.fromLatLng(destination), route.points);
        unawaited(_animateToDriverLocation());

        _rebuild(() {
          _destinationRoutePolylines = DriverRouteStyle.polylines(
            id: 'destination_mode_road_route',
            points: route.latLngPoints,
          );
        });
      } catch (_) {
        if (!mounted || !_destinationModeActive ||
            _destinationPosition != destination ||
            !_destinationRoadRequests.owns(generation)) { return; }
        _cameraRoute = null;
        _rebuild(() => _destinationRoutePolylines = <Polyline>{});
      }
    }
    Future<void> _fitDestinationRoute() async {
      final destination = _destinationPosition;
      if (destination == null || _mapController == null) { return; }
      final generation = _mapPreviews.begin();

      final routePoints = _destinationRoutePolylines.isEmpty
          ? <LatLng>[_driverPosition, destination]
          : _destinationRoutePolylines.first.points;

      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || !_destinationModeActive ||
          _destinationPosition != destination || _mapController == null ||
          !_mapPreviews.owns(generation)) { return; }

      await _fitPoints(routePoints, padding: 74);
    }
    /// Live road route when GPS has one, else the confirmed figures.
    (double, double)? get _destinationFigures {
      final route = _cameraRoute;
      if (route != null) { return (route.distanceMeters, route.durationSeconds); }
      final trip = _destinationTrip;
      final m = trip?.distanceMeters, sec = trip?.durationSeconds;
      return m == null || sec == null ? null : (m, sec);
    }
    String? get _destinationSummary {
      final f = _destinationFigures;
      return f == null ? null : destinationTimeDistanceLabel(f.$1, f.$2);
    }
    String? get _destinationEta {
      final f = _destinationFigures;
      return f == null ? null : '${(f.$2 / 60).round().clamp(1, 9999)} min';
    }
    void _openDestinationDetails() {
      showDestinationDetailsSheet(
        context,
        place: _destinationShortLabel,
        address: _destinationAddress ?? '',
        summary: _destinationSummary,
        until: _destinationUntil == null ? null : clockLabel(_destinationUntil!),
        onShowRoute: _fitDestinationRoute,
        onTurnOff: _endDestinationMode,
      );
    }
    /// R13-9 demo: with real filtering the fixed demo trips rarely head the
    /// driver's way, so the demo adds trips along the route: an Exclusive
    /// near the destination and Radar trips on the way (plus two outside).
    void _seedDemoDestinationTrips() {
      final demo = _dispatch, destination = _destinationPosition;
      if (demo is! DemoDispatchRepository || destination == null ||
          !_destinationModeActive) { return; }
      final rules = DestinationModeRules.current;
      final trips = DemoDestinationTrips.along(
        driver: GeoPointMaps.fromLatLng(_driverPosition),
        destination: GeoPointMaps.fromLatLng(destination),
        route: _cameraRoute?.points ?? const <GeoPoint>[],
        corridorKm: rules.corridorOn ? rules.corridorKm : DestinationFilter.defaultNearKm,
        destinationLabel: _destinationShortLabel,
      );
      final exclusive = trips.firstWhere((t) => t.id == DemoDestinationTrips.exclusiveId);
      _destinationDemoExclusive = _HomeDirectOffer.fromRide(exclusive,
          reason: ExclusiveReasons.nearby);
      demo.showDestinationTrips([for (final t in trips) if (t != exclusive) t]);
      // Already online: the usual demo timers have run, so these come now.
      if (!_isOnline || _outsideRadarOffer != null) { return; }
      _directOfferTimer?.cancel();
      _directOfferTimer = Timer(const Duration(milliseconds: 1500), () {
        final offer = _destinationDemoExclusive;
        if (!mounted || !_isOnline || !_destinationModeActive || offer == null) { return; }
        unawaited(_HomeOfferRadar(this)._showOutsideRadarOffer(offer));
        // Radar trips on the way wait behind it.
        _HomeOfferRadar(this)._showDispatchOfferAt(0);
        _HomeOfferRadar(this)._showDispatchOfferAt(1);
      });
    }
    void _clearDemoDestinationTrips() {
      _destinationDemoExclusive = null;
      final demo = _dispatch;
      if (demo is DemoDispatchRepository) { demo.clearDestinationTrips(); }
    }
    void _endDestinationMode() {
      if (!_destinationModeActive) { return; }
      _clearDemoDestinationTrips();
      _destinationLimitTimer?.cancel();
      DestinationModeSession.instance.ended();
      _mapPreviews.cancel();
      _destinationRoadRequests.cancel();
      _destinationRoadRefresh.cancelPending();
      _cameraRoute = null;
      _camera.endPreview();
      _rebuild(() {
        _destinationModeActive = false;
        _destinationAddress = null;
        _destinationPosition = null;
        _destinationRouteMarkers = {};
        _destinationRoutePolylines = {};
      });
    }
    Widget _inactiveSheetFace() {
      return PhysicalShape(
        clipper: const RadarSheetClipper(
          notchWidth: 126,
          notchDepth: 58,
          cornerRadius: 24,
        ),
        color: MoveraRadarOrb.holdSheet,
        elevation: 8,
        shadowColor: const Color(0x3311181C),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            // Starts below the red dock, which stays on top of the sheet's
            // first [collapsedHeight] and takes its taps (UI-02).
            padding: const EdgeInsets.fromLTRB(
              16, MoveraSheetMetrics.collapsedHeight + 4, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _openActivationSupport,
                  child: const Text('Contact support',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: _skipActivationDemo,
                  child: const Text(
                    'Skip demo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    void openDestinationPanel() {
      if (!mounted) { return; }
      _destinationOpenTimer?.cancel();
      _rebuild(() => hideMainPanel = true);
      _destinationOpenTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted) { return; }
        if (!_driverSession.isOnline || !_destinationPanelController.isAttached) {
          _rebuild(() => hideMainPanel = false);
          return;
        }
        _destinationPanelController.open();
      });
    }
    void _setMapGesturesBlocked(bool value) {
      if (!mounted || _blockMapGestures == value) { return; }
      _rebuild(() {
        _blockMapGestures = value;
      });
    }
    void _onSheetPointerDown(PointerDownEvent event) {
      _sheetTrace.down();
      _sheetPointerActive = true;
      _sheetPointerLastY = event.position.dy;
      _sheetPointerLastMs = DateTime.now().millisecondsSinceEpoch;
      _sheetPointerVelocity = 0;
      _sheetPointerTravel = 0;
      _sheetPointerStartPos =
          _panelController.isAttached ? _panelController.panelPosition : 0;
      _homeSheetPositionGuardTimer?.cancel();
      _snapSheet.stopSpring();
      _setMapGesturesBlocked(true);
    }
    void _onSheetPointerMove(PointerEvent event) {
      _trackSheetPointer(event);
    }
    void _onSheetPointerEnd(PointerEvent event) {
      _sheetTrace.up(_sheetPointerVelocity);
      _trackSheetPointer(event);
      _sheetPointerActive = false;
      // Resting at middle or fully open cannot suppress gestures on the
      // *exposed* area above the sheet. Its own overlay handles touch blocking.
      _setMapGesturesBlocked(false);
      if (!_panelController.isAttached) { return; }
      // A drag settles at once toward where the finger went, with the same
      // spring as a tap; no late correction afterwards.
      // An Exclusive card on top holds the sheet closed.
      if (_sheetPointerTravel > 6 && _outsideRadarOffer == null) {
        unawaited(_snapHomeSheet(velocity: _sheetPointerVelocity));
      }
    }
    /// Safety net only: if something outside a drag leaves the sheet
    /// between stages (e.g. a cancelled animation), settle it.
    void _scheduleHomeSheetPositionGuard({
      Duration delay = const Duration(milliseconds: 180),
    }) {
      _homeSheetPositionGuardTimer?.cancel();
      _homeSheetPositionGuardTimer = Timer(delay, () {
        if (!mounted ||
            _outsideRadarOffer != null ||
            _sheetPointerActive ||
            _snapSheet.isSpringing ||
            !_panelController.isAttached) {
          return;
        }

        final position = _panelController.panelPosition.clamp(0.0, 1.0);
        var nearestDistance = math.min(position.abs(), (1 - position).abs());
        if (_homeSheetInactive) {
          nearestDistance = math.min(
            nearestDistance,
            (position - _inactiveSheetStop).abs(),
          );
        }

        if (nearestDistance <= 0.025) { return; }
        unawaited(_snapHomeSheet(velocity: 0));
      });
    }
    Future<void> _closeDriverSheet() async {
      await _springPanelTo(0);
    }
    /// Account on hold: the red sheet still rests a little open to show
    /// its buttons. Every other Home sheet is closed or open, nothing else.
    bool get _homeSheetInactive => _activationHold && !isAccountActivated;
    static const double _inactiveSheetStop = 0.28;
    /// Open, the sheet fills the screen up to the status bar.
    double _homeExpandedHeight(BuildContext context) {
      return MediaQuery.sizeOf(context).height -
          MediaQuery.paddingOf(context).top;
    }
    void _trackSheetPointer(PointerEvent event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_sheetPointerLastMs != 0) {
        final dt = math.max(1, now - _sheetPointerLastMs);
        _sheetPointerVelocity = (event.position.dy - _sheetPointerLastY) / dt * 1000;
      }
      _sheetPointerTravel += (event.position.dy - _sheetPointerLastY).abs();
      _sheetPointerLastY = event.position.dy;
      _sheetPointerLastMs = now;
    }
    Future<void> _snapHomeSheet({double? velocity}) async {
      if (!_panelController.isAttached) { return; }
      _snapSheet.rangePx =
          _homeExpandedHeight(context) - MoveraSheetMetrics.collapsedHeight;
      final position = _panelController.panelPosition.clamp(0.0, 1.0);
      final v = velocity ?? _sheetPointerVelocity;
      final target = _homeSheetInactive
          ? MoveraSheetMetrics.directionalTarget(
              start: _sheetPointerStartPos,
              position: position,
              velocityPxPerSec: v,
              snap: _inactiveSheetStop,
            )
          : MoveraSheetMetrics.twoStopTarget(
              start: _sheetPointerStartPos,
              position: position,
              velocityPxPerSec: v,
            );
      if ((target - _lastSnapHapticAt).abs() > 0.04) {
        unawaited(HapticFeedback.lightImpact());
        _lastSnapHapticAt = target;
      }
      await _snapSheet.springTo(
        target,
        velocityPxPerSec: velocity ?? _sheetPointerVelocity,
      );
    }
    void _settleHomeSheet({double? velocity}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        unawaited(_snapHomeSheet(velocity: velocity));
      });
    }
    Future<void> _springPanelTo(
      double target, {
      double velocityPxPerSec = 0,
    }) {
      _snapSheet.rangePx =
          _homeExpandedHeight(context) - MoveraSheetMetrics.collapsedHeight;
      return _snapSheet.springTo(target, velocityPxPerSec: velocityPxPerSec);
    }
    Widget _buildRadarMapBackdrop() {
      return SizedBox.expand(
        child: !_HomeStartPosition(this)._mapReady ? _HomeStartPosition(this)._locating() : CustomGoogleMap(
          initialPosition: _initialPosition,
          markers: _markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          webCameraControlEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          // Idle overview: Google's traffic layer paints free-flow roads
          // green and hides the Waze road palette. Traffic stays on the
          // active-ride map only.
          trafficEnabled: false,
          buildingsEnabled: true,
          indoorViewEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          onUserGesture: _camera.userGesture,
          onCameraIdle: () { _cameraPort?.onIdle(); _camera.browseSettled(); },
          onCameraMove: (position) => _cameraPort?.onMove(position),
          mapType: MapType.normal,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _cameraPort = GoogleDriverCameraPort(controller,
                        onStatus: (status) {
                          if (status != null && mounted && ModalRoute.of(context)?.isCurrent == true) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status),
                              action: SnackBarAction(label: 'Retry', onPressed: _camera.recenter)));
                          }
                        },
              initialPosition: _initialPosition,
              reducedMotion: MediaQuery.disableAnimationsOf(context));
            _camera.attach(_cameraPort!);
          },
          onTap: (LatLng position) {},
        ),
      );
    }
    Widget body({bool isDestinationPanel = false}) {
      final viewport = MediaQuery.sizeOf(context);
      final viewportWidth = viewport.width;
      final offerOnScreen = _HomeOfferRoute(this)._offerOnScreen;
      // The line's animated white part, once the route has faded fully in.
      final lightShown = offerOnScreen &&
          _exclusive.fade.value >= 1 &&
          _reservation.fade.value >= 1;
      ({Set<Marker> markers, Set<Polyline> polylines}) layersWith(
        Set<Polyline> light,
      ) => homeMapLayers(
        car: _markers,
        destinationMode: _destinationModeActive,
        destinationMarkers: _destinationRouteMarkers,
        destinationPolylines: _destinationRoutePolylines,
        offerMarkers: _directOfferRouteMarkers,
        offerPolylines: lightShown && light.isNotEmpty
            ? {..._directOfferRoutePolylines, ...light}
            : _directOfferRoutePolylines,
        offerOnScreen: offerOnScreen,
      );

      return SizedBox(
        height: viewport.height,
        width: viewportWidth,
        child: Stack(
          children: [
            if (!_HomeStartPosition(this)._mapReady) _HomeStartPosition(this)._locating() else ValueListenableBuilder<Set<Polyline>>(
              // Only the map redraws for each step of the line animation.
              valueListenable: _offerRouteFrame.lightLine,
              builder: (context, light, _) {
              final layers = layersWith(light);
              return CustomGoogleMap(
              initialPosition: _initialPosition,
              markers: _HomeExclusive(this)._exclusiveFadedPins(
                  _HomeReservation(this)._fadedPins(layers.markers)),
              polylines: _HomeExclusive(this)._exclusiveFadedLines(
                  _HomeReservation(this)._fadedLines(
                OfferRouteLine.sized(DriverRouteStyle.sized(
                    layers.polylines, _routeZoomStep), _routeZoomStep))),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
          webCameraControlEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              // See _buildRadarMapBackdrop: no traffic layer on home.
              trafficEnabled: false,
              onUserGesture: _camera.userGesture,
              onCameraIdle: () { _cameraPort?.onIdle(); _camera.browseSettled(); },
              onCameraMove: (position) {
                _cameraPort?.onMove(position);
                final step = DriverRouteStyle.stepZoom(position.zoom);
                if (step != _routeZoomStep) _rebuild(() => _routeZoomStep = step);
              },
              buildingsEnabled: true,
              indoorViewEnabled: false,
              mapType: MapType.normal,
              padding: _HomeOfferRoute(this)._homeMapInsets(context).edgeInsets,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _cameraPort = GoogleDriverCameraPort(controller,
                        onStatus: (status) {
                          if (status != null && mounted && ModalRoute.of(context)?.isCurrent == true) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status),
                              action: SnackBarAction(label: 'Retry', onPressed: _camera.recenter)));
                          }
                        },
                  initialPosition: _initialPosition,
                  reducedMotion: MediaQuery.disableAnimationsOf(context));
                _camera.attach(_cameraPort!);
                if (_hasLiveDriverLocation) {
                  unawaited(_animateToDriverLocation());
                }
              },
              onTap: (LatLng position) {},
            );
              },
            ),
            isDestinationPanel
                ? Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      AppAssets.destinationSelected,
                      height: ResSize.h * 241,
                    ),
                  )
                : SizedBox(),
            isDestinationPanel
                ? Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 140, right: 30),
                      child: InkWell(
                        onTap: () {
                          showSafetyToolKitSheet(context);
                        },
                        child: Image.asset(
                          AppAssets.direction,
                          height: ResSize.h * 90,
                        ),
                      ),
                    ),
                  )
                : SizedBox(),

            Visibility(
              visible: true,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: ResSize.h * 55,
                  horizontal: screenHorizPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The top island is drawn above the scrim, further down.
                    const SizedBox(height: _homeMapButtonSize),
                    // Destination mode shows on the island (R10-9).
                    if (isDestinationPanel)
                      Padding(
                        padding: EdgeInsets.only(top: ResSize.h * 12),
                        child: InAirportQueue(),
                      ),
                  ],
                ),
              ),
            ),

            if (!isDestinationPanel)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: 138,
                child: _buildDriverLocationButton(),
              ),
            if (!isDestinationPanel)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: 16,
                bottom: 138,
                child: MapControlButton(
                  key: const ValueKey<String>('home-safety-button'),
                  tooltip: 'Safety toolkit',
                  size: _homeMapButtonSize,
                  onTap: () => showSafetyToolKitSheet(context),
                  child: SvgPicture.asset(AppAssets.mapSafety, width: 24, height: 24),
                ),
              ),
            if (!isDestinationPanel &&
                _mainPanelPosition <= 0.04 &&
                _outsideRadarOffer == null &&
                _radarHomeOffers.isNotEmpty)
              Positioned(
                // Keyed so the deck keeps its order when siblings come and go.
                key: const ValueKey<String>('radar-home-deck-slot'),
                left: 14,
                width: math.max(0, viewportWidth - 28),
                // Clears the safety and recenter buttons below it.
                bottom: 138 + _homeMapButtonSize + 12,
                // R10-12: the deck keeps its drags and flings, gaps and
                // peeking cards included; the map moves only outside it.
                // On web the interceptor keeps pointers off the map view.
                child: PointerInterceptor(
                  child: GestureDetector(
                    key: const ValueKey<String>('radar-home-deck-guard'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (_) {},
                    child: _HomeOfferRoute(this)._measureOfferCard(
                      _HomeOfferRadar(this)._buildRadarOffersTray(),
                      (height) => _HomeOfferRoute(this)
                          ._offerCardMeasured(deck: height),
                    ),
                  ),
                ),
              ),
            if (!isDestinationPanel) ...[
              // As high as the phone allows: tucked just under the clock
              // and notch (the safe area keeps a few spare pixels below).
              Positioned(
                left: 0,
                right: 0,
                top: math.max(MediaQuery.paddingOf(context).top - 4, 10.0),
                // Opening the sheet pushes the island off the top; it comes
                // back as the sheet goes down.
                child: ValueListenableBuilder<double>(
                  valueListenable: _panelSlidePosition,
                  child: Transform.scale(
                    scale: _islandScale,
                    alignment: Alignment.topCenter,
                    child: _buildTopIsland(viewportWidth / _islandScale),
                  ),
                  builder: (context, panelPosition, island) {
                    final push = Curves.easeIn.transform(
                      ((panelPosition - 0.12) / 0.6).clamp(0.0, 1.0),
                    );
                    final lift = MediaQuery.paddingOf(context).top +
                        DigitalIslandParts.height + 24;
                    return IgnorePointer(
                      key: const ValueKey<String>('home-island-push'),
                      ignoring: push > 0.5,
                      child: Opacity(
                        opacity: 1 - push,
                        child: Transform.translate(
                          offset: Offset(0, -lift * push),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: island,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

          ],
        ),
      );
    }
    /// White island at the top of Home: menu, today's earnings and
    /// destination search. The earnings are hidden until tapped; a second
    /// tap grows the island into the full Today details.
    /// Black island drawn like a small live screen: the blue arrow opens
    /// Destination, the middle cycles through the money faces, the menu
    /// sits on the right.
    Widget _buildTopIsland(double viewportWidth) {
      const height = DigitalIslandParts.height;
      // At launch the island is small (menu and arrow), then grows; a
      // message widens it and moves the menu and arrow aside.
      // R10-7: with no message passing, a hold keeps its reason on the
      // island, red, with the menu and search still beside it.
      final hold = _islandMessage == null && _islandWake >= 2
          ? _HomeAccount(this)._islandHold()
          : null;
      final message = _islandMessage ?? hold;
      final maxWidth = viewportWidth - 32;
      // A reservation request up: calendar and "Today 06:35 · Reservation".
      final reservation = message == null &&
              _HomeReservation(this)._reservationOnDock
          ? DigitalReservationFace.whenOf(
              _reservation.request!, ScheduledClock.instance.now())
          : null;
      // An Exclusive offer up: check and "Exclusive · Pickup 4 min".
      final exclusive = message == null && reservation == null &&
              _HomeExclusive(this)._exclusiveOnIsland
          ? _exclusive.shown!.pickupMinutes
          : null;
      // Destination mode: pin and "Centralplan 15 · 35 min", menu kept.
      final destination = message == null && reservation == null &&
          exclusive == null && _destinationModeActive;
      // R13-1: online on Home with no offer and no trip, the island says
      // "Finding trips" and now and then a short message. A message passing
      // (e.g. "Radar online") goes first.
      final waitingShown = _islandWaiting.sync(_waitingForTrips);
      final waitingTip = _islandWaiting.tip;
      final waiting = waitingShown && message == null && reservation == null &&
          exclusive == null && !destination;
      final waitingTitle = waitingTip?.title ?? DigitalWaitingFace.findingTitle;
      // A message sizes the island to its words (never taller): the normal
      // size for short words, a little longer for longer ones. 14 + 14 for the
      // tucked sides, 2 for the border and some air on both ends.
      final width = hold != null
          ? (DigitalMessageFace.widthFor(context, hold.title, tappable: true) +
                    54 + 54 + 2 + 8)
                .clamp(math.min(244.0, maxWidth), maxWidth)
                .toDouble()
          : message != null
          ? (DigitalMessageFace.widthFor(context, message.title) +
                    14 + 14 + 2 + 36)
                .clamp(math.min(244.0, maxWidth), math.min(244.0 * 1.15, maxWidth))
                .toDouble()
          : reservation != null
              ? (DigitalReservationFace.widthFor(context, reservation) +
                        14 + 14 + 2 + 36)
                    .clamp(math.min(200.0, maxWidth), maxWidth)
                    .toDouble()
          : exclusive != null
              ? (DigitalExclusiveFace.widthFor(context, exclusive) +
                        14 + 14 + 2 + 36)
                    .clamp(math.min(200.0, maxWidth), maxWidth)
                    .toDouble()
          : waiting
              ? (DigitalWaitingFace.widthFor(context, waitingTitle, dots: waitingTip == null) +
                        14 + 14 + 2 + 36)
                    .clamp(math.min(200.0, maxWidth), maxWidth)
                    .toDouble()
          : destination
              ? (DigitalDestinationFace.widthFor(context, _destinationShortLabel, _destinationEta) +
                        54 + 14 + 2 + 28)
                    .clamp(math.min(200.0, maxWidth), maxWidth)
                    .toDouble()
          : _islandWake >= 1
              ? math.min(maxWidth, 244.0)
              : 112.0;
      final tucked = _islandMessage != null || reservation != null ||
          exclusive != null || waiting;
      Widget side(Widget button, {bool tuck = false}) => AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: tucked || tuck ? 14 : 54,
            child: ClipRect(
              child: OverflowBox(
                minWidth: 54,
                maxWidth: 54,
                child: IgnorePointer(
                  ignoring: tucked || tuck,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: tucked || tuck ? 0 : 1,
                    child: button,
                  ),
                ),
              ),
            ),
          );
      return PointerInterceptor(
        child: Listener(
          // Any touch on the island: normal behaviour at once (R13-1).
          onPointerDown: (_) => _islandWaiting.touch(),
          child: DigitalIslandShell(
            width: width,
            height: height,
            // Online, the driver is on the road: no light passing over it.
            calm: _isOnline,
            // Every size change, out and back, glides with a soft spring.
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeOutCubic,
            // Radar offers ring it green, like the radar.
            offers: _isOnline &&
                (_hasRideOffers || _radarHomeOffers.isNotEmpty),
          child: Row(
            children: [
              side(Builder(
                builder: (context) => Tooltip(
                  message: 'Menu',
                  child: InkWell(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: SizedBox(
                      width: 54,
                      height: height,
                      child: DigitalIslandParts.menuIcon(),
                    ),
                  ),
                ),
              )),
              Expanded(
                // Asleep, the middle is a few pixels wide and shows
                // nothing: no unlabelled target for a screen reader (UI-12).
                child: ExcludeSemantics(
                  excluding: message == null && reservation == null &&
                      exclusive == null && !waiting && !destination &&
                      _islandWake < 2,
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    if (_islandFace == _IslandFace.history &&
                        (details.primaryVelocity ?? 0).abs() > 80) {
                      _openRideHistoryFromIsland();
                    }
                  },
                  child: InkWell(
                    key: const ValueKey<String>('last-trip-launcher'),
                    onTap: hold != null
                        ? hold.onTap
                        : message != null
                        ? () => _onIslandMessageTap(message)
                        : reservation != null || exclusive != null
                        ? null
                        : destination
                        ? _openDestinationDetails
                        : _onIslandEarningsTap,
                    // Holding the middle goes straight to Ride history.
                    onLongPress: message != null || destination ||
                            reservation != null || exclusive != null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _openRideHistoryFromIsland();
                          },
                    child: SizedBox(
                      height: height,
                      child: DigitalFaceSwitcher(
                        child: hold != null
                            ? _islandMessageView(hold, hold: true)
                            : message != null
                            ? _islandMessageView(message)
                            : reservation != null
                            ? DigitalReservationFace(
                                key: const ValueKey<String>(
                                  'island-reservation-face',
                                ),
                                when: reservation,
                              )
                            : exclusive != null
                            ? DigitalExclusiveFace(
                                key: const ValueKey<String>(
                                  'island-exclusive-face',
                                ),
                                pickupMinutes: exclusive,
                              )
                            : waiting
                            ? (waitingTip == null
                                ? const DigitalWaitingFace.finding(
                                    key: ValueKey<String>('island-finding'),
                                  )
                                : DigitalWaitingFace(
                                    key: ValueKey<String>('island-tip-${waitingTip.id}'),
                                    title: waitingTip.title,
                                    color: islandTipColor(waitingTip.look),
                                  ))
                            : destination
                            ? DigitalDestinationFace(
                                key: const ValueKey<String>('island-destination-face'),
                                place: _destinationShortLabel,
                                eta: _destinationEta,
                              )
                            : _islandWake >= 2
                                ? _islandFaceView()
                                : const SizedBox(
                                    key: ValueKey<String>('island-asleep'),
                                  ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
              side(Tooltip(
                message: 'Search destination',
                child: InkWell(
                  key: const ValueKey<String>('destination-mode-open'),
                  onTap: _openDestinationModePicker,
                  child: const SizedBox(
                    width: 54,
                    height: height,
                    child: DigitalIslandParts.searchIcon,
                  ),
                ),
              ), tuck: destination),
            ],
          ),
        ),
        ),
      );
    }
    /// Online on Home with no offer, no trip and no request up.
    bool get _waitingForTrips =>
        _isOnline && _islandWake >= 2 &&
        _driverSession.activeTripId == null &&
        !_hasRideOffers && _radarHomeOffers.isEmpty &&
        _outsideRadarOffer == null &&
        !_HomeExclusive(this)._exclusiveLive &&
        !_HomeReservation(this)._reservationOnDock;
    /// The short messages the app has facts for; in the demo, all of them.
    List<IslandWaitingTip> _waitingTips() {
      final dispatch = _dispatch;
      final signals = _ownsDispatch && dispatch is DemoDispatchRepository
          ? IslandWaitingSignals.demo(_adminHomeConfig)
          : IslandWaitingSignals.fromHome(_adminHomeConfig,
              now: ScheduledClock.instance.now());
      return signals.tips();
    }
    Widget _islandFaceView() {
      switch (_islandFace) {
        case _IslandFace.hidden:
          return DigitalIslandParts.hiddenFace();
        case _IslandFace.lastTrip:
          if (_lastTripSettling) {
            return const DigitalUpdatingFace(
              key: ValueKey<String>('island-updating'),
            );
          }
          return DigitalIslandParts.amountFace(
              'island-last-trip', 'LAST TRIP', _lastTripFareLabel);
        case _IslandFace.today:
          return DigitalIslandParts.amountFace(
              'island-today', 'TODAY', DigitalIslandParts.sampleToday);
        case _IslandFace.history:
          return DigitalIslandParts.historyFace();
      }
    }
    Widget _islandMessageView(IslandMessage message, {bool hold = false}) {
      final (color, toneIcon) = DigitalIslandParts.toneLook(message.tone);
      return DigitalMessageFace(
        key: ValueKey<String>(hold
            ? 'island-hold-${message.title}'
            : 'island-message-$_islandMessageSeq'),
        title: message.title,
        color: color,
        icon: message.icon ?? toneIcon,
        pulse: message.live,
        tappable: hold,
      );
    }
    /// A posted message: show it now if the screen is free, or replace an
    /// outdated one of the same group.
    void _onIslandMessagesChanged() {
      if (!mounted) { return; }
      final current = _islandMessage;
      final next = IslandMessages.peek();
      if (current != null &&
          next != null &&
          current.group != null &&
          current.group == next.group) {
        _islandMessageTimer?.cancel();
        _islandMessage = null;
      }
      _showNextIslandMessage();
    }
    void _showNextIslandMessage() {
      if (!mounted || _islandMessage != null) { return; }
      final next = IslandMessages.take();
      if (next == null) { return; }
      _islandWakeTimer?.cancel();
      _rebuild(() {
        _islandWake = 2;
        _islandMessage = next;
        _islandMessageSeq++;
      });
      _islandMessageTimer?.cancel();
      _islandMessageTimer = Timer(next.priority.duration, _endIslandMessage);
    }
    void _endIslandMessage() {
      _islandMessageTimer?.cancel();
      if (!mounted) { return; }
      _rebuild(() => _islandMessage = null);
      _showNextIslandMessage();
    }
    /// A saved-trip problem: a heads-up on the island and a sheet that
    /// stays until the driver acts, since a tap only closes the island.
    void _tripProblem(IslandMessage notice, String message,
        {String action = 'Retry'}) {
      IslandMessages.show(notice);
      unawaited(showTripProblemSheet(
        context,
        title: notice.title,
        message: message,
        actionLabel: action,
        onAction: () => unawaited(_restoreActiveRideIfNeeded()),
      ));
    }
    /// Tapping a message closes it; the first-launch hint and notification
    /// popups also open what they are about.
    void _onIslandMessageTap(IslandMessage message) {
      _endIslandMessage();
      message.onTap?.call();
    }
    /// Hidden total → last trip → today's total → Ride history → hidden.
    /// Left untouched for 5 s, the island goes back to the hidden total.
    void _onIslandEarningsTap() {
      // The touch only closed "Finding trips" or a waiting message.
      if (_islandWaiting.takeSwallowedTap()) { return; }
      if (_islandWake < 2) {
        // A tap during the launch animation just finishes it.
        _islandWakeTimer?.cancel();
        _rebuild(() => _islandWake = 2);
        return;
      }
      HapticFeedback.selectionClick();
      _rebuild(() {
        _islandFace = _IslandFace
            .values[(_islandFace.index + 1) % _IslandFace.values.length];
      });
      _restartIslandIdle();
    }
    void _restartIslandIdle() {
      _islandIdleTimer?.cancel();
      if (_islandFace == _IslandFace.hidden) { return; }
      _islandIdleTimer = Timer(_islandIdleTimeout, () {
        if (!mounted || _islandFace == _IslandFace.hidden) { return; }
        _rebuild(() => _islandFace = _IslandFace.hidden);
      });
    }
    /// Launch: small island, it grows after a beat, then its screen turns on.
    void _startIslandWake() {
      _islandWakeTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) { return; }
        _rebuild(() => _islandWake = 1);
        _islandWakeTimer = Timer(const Duration(milliseconds: 560), () {
          if (!mounted) { return; }
          _rebuild(() => _islandWake = 2);
          unawaited(_showIslandHintOnce());
        });
      });
      _scheduleLastTripSettle();
    }
    /// First launch only: tell the driver the middle shows the earnings.
    Future<void> _showIslandHintOnce() async {
      if (!DriverRuntimeConfig.current.islandHint) { return; }
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || (prefs.getBool(_islandHintSeenKey) ?? false)) { return; }
      await prefs.setBool(_islandHintSeenKey, true);
      IslandMessages.show(HomeIslandNotices.earningsHint(_onIslandEarningsTap));
    }
    /// A trip that just ended still has its money updating.
    bool get _lastTripSettling {
      final pending = _lastTripPendingId;
      return pending != null && pending == _waybills.last?.tripId;
    }
    String get _lastTripFareLabel {
      final fare = _waybills.last?.fare;
      if (fare == null || !fare.contains(RegExp(r'\d'))) { return DigitalIslandParts.sampleLastTrip; }
      return fare;
    }
    void _onLastTripChanged() {
      if (!mounted) { return; }
      _rebuild(() {});
      _scheduleLastTripSettle();
    }
    void _scheduleLastTripSettle() {
      _lastTripSettleTimer?.cancel();
      final last = _waybills.last;
      final left = last == null
          ? Duration.zero
          : _lastTripSettleTime - DateTime.now().difference(last.issuedAt);
      if (left <= Duration.zero) {
        _lastTripPendingId = null;
        return;
      }
      _lastTripPendingId = last!.tripId;
      _lastTripSettleTimer = Timer(left, () {
        if (!mounted) { return; }
        // The money is in: show it, and give the driver 5 s to read it.
        _rebuild(() => _lastTripPendingId = null);
        if (_islandFace == _IslandFace.lastTrip) { _restartIslandIdle(); }
      });
    }
    void _openRideHistoryFromIsland() {
      _islandIdleTimer?.cancel();
      _rebuild(() => _islandFace = _IslandFace.hidden);
      pushSingle(
        context,
        MaterialPageRoute<void>(builder: (_) => const DriverRideHistory()),
      );
    }
    void _onRadarSheetDragStart(DragStartDetails details) {
      _sheetPointerStartPos =
          _panelController.isAttached ? _panelController.panelPosition : 0;
    }
    void _onRadarSheetDragUpdate(DragUpdateDetails details) {
      if (!_panelController.isAttached || _outsideRadarOffer != null) { return; }
      _snapSheet.stopSpring();
      final range = _homeExpandedHeight(context) - MoveraSheetMetrics.collapsedHeight;
      if (range <= 0) { return; }
      final next = (_panelController.panelPosition - details.delta.dy / range)
          .clamp(0.0, 1.0);
      _panelController.panelPosition = next;
    }
    void _onRadarSheetDragEnd(DragEndDetails details) {
      _settleHomeSheet(velocity: details.primaryVelocity ?? 0);
    }
    Widget _radarDragToSheet({required Widget child}) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onRadarSheetDragStart,
        onVerticalDragUpdate: _onRadarSheetDragUpdate,
        onVerticalDragEnd: _onRadarSheetDragEnd,
        child: child,
      );
    }
    void _closeHomeFloatingPopupsForSheet() {
      if (!showRideRequests &&
          !_isDirectOfferRoutePreview) {
        return;
      }

      _mapPreviews.cancel();
      _camera.endPreview();
      _rebuild(() {
        showRideRequests = false;
        _isDirectOfferRoutePreview = false;
        _directOfferRouteMarkers = {};
        _directOfferRoutePolylines = {};
      });
    }
    bool _isVersionNewer(String candidate, String current) {
      List<int> parse(String value) {
        return value
            .split('.')
            .map((part) => int.tryParse(part) ?? 0)
            .toList(growable: true);
      }

      final a = parse(candidate);
      final b = parse(current);
      final length = math.max(a.length, b.length);

      while (a.length < length) {
        a.add(0);
      }
      while (b.length < length) {
        b.add(0);
      }

      for (var index = 0; index < length; index++) {
        if (a[index] > b[index]) { return true; }
        if (a[index] < b[index]) { return false; }
      }

      return false;
    }
    Future<void> _maybeShowAppUpdatePrompt() async {
      if (_updatePromptShown || !mounted || ModalRoute.of(context)?.isCurrent != true) { return; }

      final update = _adminHomeConfig.update;
      if (!update.enabled ||
          !_isVersionNewer(update.latestVersion, _DriverHomeState._currentAppVersion)) {
        return;
      }

      _updatePromptShown = true;

      await showModalBottomSheet<void>(
        context: context,
        isDismissible: !update.mandatory,
        enableDrag: !update.mandatory,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return AppUpdateSheet(update: update);
        },
      );
    }
    /// One quiet row of the Home sheet list: line icon, label, and a value
    /// or a chevron when the row opens something.
    Widget _todayRow({
      Key? key,
      required MoveraMark mark,
      required String label,
      String? value,
      Color valueColor = const Color(0xFF111614),
      bool dot = false,
      VoidCallback? onTap,
      bool last = false,
    }) {
      const ink = Color(0xFF111614);
      return InkWell(
        key: key,
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFEDEFF0))),
          ),
          child: Row(
            children: [
              MoveraLineIcon(mark: mark, size: 20, color: ink),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (dot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: valueColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB4BBB8),
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    Widget _todayGroup(List<Widget Function(bool last)> rows) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E9EA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) rows[i](i == rows.length - 1),
          ],
        ),
      );
    }
    /// How far the open sheet has covered the dock's notch: 0 closed,
    /// 1 once the sheet has risen a little. The notch flattens over it.
    static double _notchCover(double position) =>
        (position / 0.10).clamp(0.0, 1.0);

    Widget _sheetPointer(Widget child) {
      return PointerInterceptor(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onSheetPointerDown,
          onPointerMove: _onSheetPointerMove,
          onPointerUp: _onSheetPointerEnd,
          onPointerCancel: _onSheetPointerEnd,
          child: child,
        ),
      );
    }

    /// The four dock icons, fixed at the bottom of the sheet from closed to
    /// open. Closed, it carries the notch for the radar; as the sheet opens
    /// over it the notch flattens into plain white.
    Widget? _homeDockFooter() {
      if (_homeSheetInactive) { return null; }
      return _sheetPointer(SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: MoveraSheetMetrics.collapsedHeight,
        child: AnimatedBuilder(
          animation: _panelSlidePosition,
          builder: (context, _) {
            final position = _panelSlidePosition.value;
            final cover = _notchCover(position);
            return DriverSheetNav.collapsedDock(
              context: context,
              scaffoldKey: _scaffoldKey,
              isOnline: _isOnline,
              hasRideOffers: _hasRideOffers || _radarHomeOffers.isNotEmpty,
              hasScheduledRideOffers: _hasScheduledRideOffers,
              goOnlinePulseController: _goOnlinePulseController,
              onOpenScheduledRides: _openScheduledRides,
              notchDepth: 58 * (1 - cover),
              elevation: 8 * (1 - cover),
              edgeOpacity: 1 - cover,
              topRuleOpacity: cover,
            );
          },
        ),
      ));
    }

    /// The map darkens a little as the sheet rises over it.
    Widget _homeMapDim() {
      return IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: _panelSlidePosition,
          builder: (context, position, _) => position <= 0.001
              ? const SizedBox.shrink()
              : ColoredBox(
                  key: const ValueKey<String>('home-map-dim'),
                  color: const Color(0xFF0A0E10)
                      .withValues(alpha: 0.22 * position.clamp(0.0, 1.0)),
                ),
        ),
      );
    }

    /// The radar never moves: it sits in the dock, closed or open. With the
    /// sheet open and Radar on, the same radar reads "Hold · OFF" and a
    /// one-second hold goes offline.
    Widget _homeRadarLayer() {
      if (_homeSheetInactive) {
        // Account on hold: the radar rides the red sheet's notch.
        return ValueListenableBuilder<double>(
          valueListenable: _panelSlidePosition,
          builder: (context, position, child) => Positioned(
            left: 0,
            right: 0,
            bottom: MoveraSheetMetrics.collapsedHeight - 50 +
                (_homeExpandedHeight(context) -
                        MoveraSheetMetrics.collapsedHeight) *
                    position,
            child: child!,
          ),
          child: Center(child: _radarDragToSheet(child: _buildGoOnlineButton())),
        );
      }
      return Positioned(
        left: 0,
        right: 0,
        bottom: MoveraSheetMetrics.collapsedHeight - 50,
        child: Center(
          child: _radarDragToSheet(
            child: ValueListenableBuilder<double>(
              valueListenable: _panelSlidePosition,
              builder: (context, position, _) {
                final holdOff = _isOnline && position >= 0.5;
                // A reservation request or an Exclusive offer brings its
                // own Accept orb on its sheet, over this one. Offers on the deck: the radar takes
                // the front trip.
                final front = !holdOff && _isOnline &&
                        _outsideRadarOffer == null
                    ? _HomeOfferRadar(this)._radarFrontOffer()
                    : null;
                final face = _isOnline
                    ? (holdOff
                        ? 'radar-hold-off'
                        : front != null
                        ? 'radar-accept'
                        : 'radar-online')
                    : _isGoingOnline
                    ? 'radar-connecting'
                    : 'radar-offline';
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  reverseDuration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.97, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<String>(face),
                    child: _isOnline
                        ? (holdOff
                            ? _holdOffRadar()
                            : front != null
                            ? _acceptRadar(front)
                            : _buildTripRadarButton())
                        : _isGoingOnline
                        ? _buildGoingOnlineButton()
                        : _buildGoOnlineButton(),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    /// The online radar with the sheet open: same look, "Hold · OFF ·
    /// Go offline"; a one-second hold vibrates and goes offline.
    Widget _holdOffRadar() {
      return RadarHoldOff(
        onConfirmed: () => unawaited(_goOffline()),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _goOnlinePulseController,
            _radarSweepController,
          ]),
          builder: (context, child) => _buildRadarOrb(
            title: "Hold",
            status: "OFF",
            subtitle: "Go offline",
            active: true,
            offer: _hasRideOffers ||
                _radarHomeOffers.isNotEmpty ||
                _pendingRadarHomeOffers.isNotEmpty,
            pulse: _goOnlinePulseController.value,
            sweep: _radarSweepController.value,
          ),
        ),
      );
    }

    /// While offers show, the radar reads "Accept · MATCH" and tapping it
    /// matches the deck's front trip, same as its Match button.
    Widget _acceptRadar(_HomeDirectOffer front) {
      final busy = _homeRadarMatchingOfferId != null;
      return KeyedSubtree(
        key: const ValueKey<String>('home-radar-accept'),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _goOnlinePulseController,
            _radarSweepController,
            _radarMotionController,
          ]),
          builder: (context, child) => _buildRadarOrb(
            title: busy ? "Matching" : "Accept",
            status: "MATCH",
            subtitle: busy ? "Please wait" : "Tap to accept",
            active: true,
            offer: true,
            pulse: _goOnlinePulseController.value,
            sweep: _radarSweepController.value,
            wedge: _radarWedge(found: true),
            statusPulse: _matchPulse,
            onTap: busy
                ? null
                : () => _HomeOfferRadar(this)._startHomeRadarMatch(front),
          ),
        ),
      );
    }

    /// Account on hold: the red dock, faded out as the red sheet opens.
    Widget? _inactiveDock() {
      if (!_homeSheetInactive) { return null; }
      return _sheetPointer(
        DriverSheetNav.collapsedDock(
          context: context,
          scaffoldKey: _scaffoldKey,
          isOnline: _isOnline,
          hasRideOffers: _hasRideOffers || _radarHomeOffers.isNotEmpty,
          hasScheduledRideOffers: _hasScheduledRideOffers,
          goOnlinePulseController: _goOnlinePulseController,
          onOpenScheduledRides: _openScheduledRides,
          inactive: true,
        ),
      );
    }

    static const Color _sheetInk = Color(0xFF121619);
    static const Color _sheetText = Color(0xFF3A4247);
    static const Color _sheetSub = Color(0xFF80888E);
    static const Color _sheetLine = Color(0xFFEEF0F2);

    Widget _sheetRow({
      required Key key,
      required Widget icon,
      required String label,
      Widget? trailing,
      VoidCallback? onTap,
    }) {
      return InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SizedBox(width: 32, child: Center(child: icon)),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _sheetText,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      );
    }

    Widget _solarIcon(String asset) => SvgPicture.asset(
          asset,
          width: 26,
          height: 26,
          colorFilter: const ColorFilter.mode(_sheetInk, BlendMode.srcIn),
        );

    /// Home sheet, open: "Today", then one card with driving time,
    /// Performance and the latest waybill. Each row opens its details.
    List<Widget> _todayList() {
      final performance = _adminHomeConfig.performance;
      final showPerformance = performance.showRating ||
          performance.showAcceptanceRate ||
          performance.showCancellationRate;
      return [
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text(
            'Right now',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sheetSub,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _sheetLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0811181C),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              DrivingTimeRow(
                clock: DrivingTimeClock.instance,
                running: _isOnline,
                onTap: _openDrivingTime,
              ),
              // Q23: cash rides on or off. Off: no cash offers. One node,
              // so the switch is read with its label (UI-12).
              MergeSemantics(child: _sheetRow(
                key: const ValueKey<String>('home-sheet-cash'),
                icon: _solarIcon(AppAssets.solarWadOfMoney),
                label: 'Cash rides',
                trailing: Switch.adaptive(
                  key: const ValueKey<String>('home-sheet-cash-switch'),
                  value: DriverOfferPreferences.acceptsCash.value,
                  activeTrackColor: const Color(0xFF1C6B45),
                  onChanged: _HomeOfferRules(this)._setAcceptsCash,
                ),
                onTap: () => _HomeOfferRules(this)._setAcceptsCash(
                  !DriverOfferPreferences.acceptsCash.value,
                ),
              )),
              if (showPerformance)
                _sheetRow(
                  key: const ValueKey<String>('home-sheet-performance'),
                  icon: _solarIcon(AppAssets.solarMedalRibbonStar),
                  label: 'Performance',
                  onTap: _openPerformance,
                ),
              ValueListenableBuilder<WaybillRecord?>(
                valueListenable: _waybills.lastListenable,
                builder: (context, lastWaybill, _) => _sheetRow(
                  key: const ValueKey<String>('home-sheet-last-waybill'),
                  icon: _solarIcon(AppAssets.solarBillList),
                  label: 'Latest waybill',
                  trailing: lastWaybill == null
                      ? const Text(
                          'None yet',
                          style: TextStyle(
                            color: _sheetSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: lastWaybill == null
                      ? null
                      : () => showMoveraWaybillSheet(
                            context,
                            lastWaybill,
                            title: 'Latest waybill',
                          ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    Future<void> _openDetailsSheet({
      required String title,
      required List<Widget Function(bool last)> rows,
      String? note,
    }) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _sheetInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _todayGroup(rows),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _sheetSub,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    void _openPerformance() {
      final performance = _adminHomeConfig.performance;
      unawaited(_openDetailsSheet(
        title: 'Performance',
        rows: [
          if (performance.showRating)
            (last) => _todayRow(
                  mark: MoveraMark.star,
                  label: 'Rating',
                  value: performance.ratingLabel,
                  last: last,
                ),
          if (performance.showAcceptanceRate)
            (last) => _todayRow(
                  mark: MoveraMark.check,
                  label: 'Acceptance',
                  value: performance.acceptanceLabel,
                  last: last,
                ),
          if (performance.showCancellationRate)
            (last) => _todayRow(
                  mark: MoveraMark.close,
                  label: 'Cancellation',
                  value: performance.cancellationLabel,
                  last: last,
                ),
        ],
      ));
    }

    void _openDrivingTime() {
      final clock = DrivingTimeClock.instance;
      unawaited(_openDetailsSheet(
        title: 'Driving time',
        rows: [
          (last) => _todayRow(
                mark: MoveraMark.timer,
                label: 'Worked',
                value: DrivingTimeClock.hoursMinutes(clock.worked),
                last: last,
              ),
          (last) => _todayRow(
                mark: MoveraMark.route,
                label: switch (clock.restUntil) {
                  null => 'Left before rest',
                  _ => 'Rest until',
                },
                value: switch (clock.restUntil) {
                  final until? => clockLabel(until),
                  null => DrivingTimeClock.hoursMinutes(clock.left),
                },
                last: last,
              ),
          (last) => _todayRow(
                mark: MoveraMark.calendar,
                label: 'Work limit',
                value: '${clock.rule.workHours} h',
                last: last,
              ),
          (last) => _todayRow(
                mark: MoveraMark.timer,
                label: 'Rest after it',
                value: '${clock.rule.restHours} h',
                last: last,
              ),
        ],
        // Q25: the admin's rule for the country.
        note: 'Counts while Radar is on. After ${clock.rule.workHours} h you '
            'rest ${clock.rule.restHours} h before going online again. A '
            '${clock.rule.restHours} h break starts it from zero.',
      ));
    }

    Widget panelColumn(ScrollController sc) {
      final content = Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFDADEE1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _sheetLine)),
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey<String>('home-sheet-close'),
                    tooltip: 'Close sheet',
                    onPressed: () => unawaited(_closeDriverSheet()),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _sheetInk,
                      size: 28,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Today',
                      key: ValueKey<String>('home-sheet-today'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _sheetInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const PageStorageKey<String>('driver-overview-list'),
                controller: sc,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  12,
                  20,
                  12,
                  MoveraSheetMetrics.collapsedHeight + 70,
                ),
                children: _todayList(),
              ),
            ),
          ],
        ),
      );
      // One white shape from closed to open: the top notch the radar sits
      // in closed flattens as soon as the sheet rises.
      return ValueListenableBuilder<double>(
        valueListenable: _panelSlidePosition,
        child: content,
        builder: (context, position, child) => PhysicalShape(
          clipper: RadarSheetClipper(
            notchWidth: 126,
            notchDepth: 58 * (1 - _notchCover(position)),
            // The top corners flatten as the sheet reaches the top.
            cornerRadius: 24 * (1 - ((position - 0.9) / 0.1).clamp(0.0, 1.0)),
          ),
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x3311181C),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
    }
}
