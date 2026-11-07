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
// UI-12: room around the island, before the scale, that makes each side
// button's touch area 48 x 48 on screen (the buttons draw 54 x 50.4).
const double _islandSideSlopX = IslandSideHitSlop.minTarget / _islandScale - 54;
const double _islandSideSlopBottom =
    IslandSideHitSlop.minTarget / _islandScale - DigitalIslandParts.height;

/// Set once the first-launch hint has been shown.
const String _islandHintSeenKey = 'home_island_hint_seen';

/// How long a just-finished trip's money counts as still updating. The
/// demo has no earnings service; a real one would confirm the amount.
const Duration _lastTripSettleTime = Duration(seconds: 4);

extension _HomeMapSheet on _DriverHomeState {
  Future<void> _startDriverLocation({bool moveCamera = false}) async {
    final epoch = ++_locationEpoch;
    if (!_liveVisible) {
      return;
    }
    // driver-u119: a stream already running keeps delivering under the
    // new epoch while the one-shot fix is awaited.
    if (_driverLocationSubscription != null) {
      _listenToDriverLocation();
    }
    try {
      final position = await _driverLocationService.getCurrentPosition();
      if (!mounted) {
        return;
      }
      if (!_liveVisible || epoch != _locationEpoch) {
        return;
      }
      final validInitial =
          position.isDisplayableAt(DateTime.now()) &&
          position.isUsableAt(DateTime.now());
      _applyDriverLocation(position);
      if (_driverLocationSubscription == null) {
        _listenToDriverLocation();
      }
      if (validInitial && (moveCamera || !_didCenterOnLiveLocation)) {
        _didCenterOnLiveLocation = true;
        await _animateToDriverLocation();
      }
    } catch (error) {
      if (!mounted || !_liveVisible || epoch != _locationEpoch) {
        return;
      }
      _rebuild(() {
        _hasLiveDriverLocation = false;
        _startLocationFailed = true;
      });
      // driver-u24, driver-r5-51, decision 2: approximate only, not
      // allowed or location off. The reason card says so above the radar
      // (driver group 3: a snackbar covered Go online).
      _HomeOnlineGate(this)._locationFailed(error);
      // A transient one-shot GPS failure must not leave Home without a
      // location subscription until the next app resume or recenter tap.
      // Continuous updates can recover when permissions/provider return.
      if (_driverLocationSubscription == null) {
        _listenToDriverLocation();
      }
    }
  }

  void _listenToDriverLocation() {
    final epoch = _locationEpoch;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = _driverLocationService
        .watchPosition(distanceFilterMeters: 8)
        .listen(
          (location) {
            if (!mounted || !_liveVisible || epoch != _locationEpoch) {
              return;
            }
            final usable =
                location.isDisplayableAt(DateTime.now()) &&
                location.isUsableAt(DateTime.now());
            _applyDriverLocation(location);
            if (usable && !_didCenterOnLiveLocation) {
              _didCenterOnLiveLocation = true;
              unawaited(_animateToDriverLocation());
            }
          },
          onError: (Object error) {
            if (!mounted || !_liveVisible || epoch != _locationEpoch) {
              return;
            }
            _rebuild(() {
              _hasLiveDriverLocation = false;
              _startLocationFailed = true;
            });
            _HomeOnlineGate(this)._locationFailed(error);
          },
        );
  }

  void _applyDriverLocation(DriverLocation location) {
    if (!mounted || !_liveVisible) {
      return;
    }
    _HomeOnlineGate(this)._locationWorks();
    if (!location.isDisplayableAt(DateTime.now())) {
      // Driver group 3 (live test: the map stayed on a zoomed-out
      // Stockholm): a fresh fix too rough for the car (a laptop's Wi-Fi
      // position) still opens the map where the driver is.
      if (!_didCenterOnLiveLocation && location.isStartHintAt(DateTime.now())) {
        _didCenterOnLiveLocation = true;
        _cameraLocation = location;
        _rebuild(() {
          _driverPosition = location.point.toLatLng();
          _hasLiveDriverLocation = false;
          _startPositionKnown = true;
          _markers = _HomeStartPosition(this)._driverMarkers();
        });
        unawaited(_animateToDriverLocation());
        return;
      }
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
    if (_hasLiveDriverLocation) {
      unawaited(DriverStartPosition.save(location.point));
    }

    // Only leaving the route or a slow refresh asks for a new one.
    if (_destinationModeActive &&
        (!_hasLiveDriverLocation ||
            _destinationRouteRefetch.due(
              position: location.point,
              route: _cameraRoute,
              now: DateTime.now(),
            ))) {
      _refreshDestinationRoadRoute();
    }
    unawaited(_animateToDriverLocation());
  }

  /// Driver group 3: a destination picked as a bare point ("59.33,
  /// 18.06") gets its street address from the server's reverse geocode.
  void _nameDestination(String address, LatLng destination) {
    final places = LiveDriverServices.instance?.places;
    if (places == null || !LiveAddressLookup.unnamed(address)) {
      return;
    }
    unawaited(
      places.reverseGeocode(destination.latitude, destination.longitude).then((
        found,
      ) {
        if (found == null ||
            !mounted ||
            !_destinationModeActive ||
            _destinationPosition != destination) {
          return;
        }
        _rebuild(() => _destinationAddress = found);
      }),
    );
  }

  Future<void> _prepareDriverVehicleMarker() async {
    final icon = await MoveraVehicleMarker.createIcon();
    if (!mounted) {
      return;
    }
    _rebuild(() {
      _driverVehicleIcon = icon;
      // No car until the driver's position is known (no city fallback).
      if (_startPositionKnown) {
        _markers = _HomeStartPosition(this)._driverMarkers();
      }
    });
  }

  Future<void> _animateToDriverLocation() async {
    final location = _cameraLocation;
    if (location == null || !_liveVisible) {
      return;
    }
    _camera.update(
      location: location,
      route: _destinationModeActive ? _cameraRoute : null,
      navigating: false,
    );
  }

  Future<void> _zoomToDriverLocation() async {
    // Locate: back to the car at the street view (zoom 15, tilted).
    _camera.locate();
    await _startDriverLocation();
    if (mounted) {
      await _animateToDriverLocation();
    }
  }

  Widget _buildDriverLocationButton() {
    return PointerInterceptor(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MapControlButton(
            key: const ValueKey<String>('driver-location-zoom'),
            tooltip: tr.recenter,
            size: _homeMapButtonSize,
            fill: MapControlButton.recenterBlue,
            onTap: _zoomToDriverLocation,
            child: SvgPicture.asset(
              AppAssets.mapRecenter,
              width: 22,
              height: 22,
            ),
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
    if (measured != null) {
      return measured;
    }
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
    if (!mounted) {
      return;
    }
    final generation = _mapPreviews.begin();
    bool isCurrent() =>
        mounted && _mapPreviews.owns(generation) && _isDirectOfferRoutePreview;

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
      roadPoints = await _HomeOfferRoute(
        this,
      )._offerRoad(pickup, stops, dropoff);
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
          RouteFitPoint(
            geo[i],
            left: 20,
            right: 20,
            down: 20,
            up: i == geo.length - 1 ? 56 : 20,
          ),
      ],
      free: _HomeOfferRoute(this)._offerFreeArea(size, insets),
      targetAt: kIsWeb
          ? size.center(Offset.zero)
          : insets.edgeInsets.deflateRect(Offset.zero & size).center,
    );
    if (fit == null) {
      return _camera.preview(geo, padding: padding);
    }
    await _camera.previewFit(
      fit,
      points: geo,
      padding: padding,
      takeOver: true,
    );
  }

  void _openDestinationModePicker() {
    // Decision 4: not while a Match or Accept is with dispatch.
    if (_HomeOfferRules(this)._claimInFlight) {
      return;
    }
    // R13-9: admin can switch the mode off per zone and limit it per day.
    final refusal = DestinationModeSession.instance.refusal();
    if (refusal != null) {
      IslandMessages.show(
        refusal == DestinationRefusal.off
            ? HomeIslandNotices.destinationOff
            : HomeIslandNotices.destinationsUsed,
      );
      return;
    }
    _closeHomeFloatingPopupsForSheet();
    if (_mainPanelPosition > 0.001 || isPanelOpen) {
      _panelController.close();
    }
    if (!mounted) {
      return;
    }

    // UI-07: one picker per tap burst, so one pick uses one daily use.
    pushSingle<DriverDestinationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDestinationPicker(
          // driver-u121: no origin without a real position, so the
          // picker skips its confirm step and invents no figures.
          origin: _knownDriverPosition,
          routeRepository: _roadRouteService,
        ),
      ),
    ).then((result) {
      if (!mounted || result == null) {
        return;
      }
      _activateDestinationMode(result);
    });
  }

  /// driver-u65: a destination set on the trip screen is the driver's
  /// destination here too once Home is visible again. It already counted
  /// for today, so taking it over is not a new use.
  void _adoptSessionDestination() {
    final session = DestinationModeSession.instance;
    final position = session.activePosition;
    if (position == null || session.expired()) {
      return;
    }
    final destination = position.toLatLng();
    if (_destinationModeActive && _destinationPosition == destination) {
      return;
    }
    unawaited(
      _activateDestinationMode(
        DriverDestinationResult(
          position: destination,
          address: session.activeAddress ?? '',
        ),
        adopted: true,
      ),
    );
  }

  /// driver-r5-9: Home is back on screen. The limit's Timer counts on the
  /// monotonic clock, which stops while the phone sleeps, but the limit is
  /// wall-clock time: re-armed from it, a destination whose time passed
  /// meanwhile ends now instead of filtering offers late.
  void _recheckDestinationLimit() {
    if (!_destinationModeActive) {
      return;
    }
    _destinationLimitTimer?.cancel();
    _armDestinationLimit();
  }

  void _clearDemoDestinationTrips() {
    _destinationDemoExclusive = null;
    final demo = _dispatch;
    if (demo is DemoDispatchRepository) {
      demo.clearDestinationTrips();
    }
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
            16,
            MoveraSheetMetrics.collapsedHeight + 4,
            16,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Round 4 (live): the account is on hold with Movera; the
              // driver uploads documents and sees the fleet meanwhile.
              if (_liveHold) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    _HomeAccount(this)._holdHeadline(),
                    key: const ValueKey('hold-being-checked'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Owner group 2 item 3 (and group 1): why the account
                // cannot go online yet, each with its fix.
                _HomeAccount(this)._remindersBox(),
                if (_liveAwaitsFleet)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      tr.holdWaitingFleetVehicle,
                      key: const ValueKey('hold-awaiting-fleet'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF2D9D4),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextButton(
                  key: const ValueKey('hold-documents'),
                  onPressed: _openHoldDocuments,
                  child: Text(
                    tr.documents,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('hold-fleet'),
                  onPressed: _openHoldFleet,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr.myFleet,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      // Round 4b: invitations waiting for an answer.
                      if ((accountSessionOf(
                                context,
                              )?.account?.pendingFleetInvitations ??
                              0) >
                          0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InvitationBadge(
                            accountSessionOf(
                              context,
                            )!.account!.pendingFleetInvitations,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              TextButton(
                onPressed: _openActivationSupport,
                child: Text(
                  tr.contactSupport,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!_liveHold)
                TextButton(
                  onPressed: _skipActivationDemo,
                  child: Text(
                    tr.skipDemo,
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
    if (!mounted) {
      return;
    }
    _destinationOpenTimer?.cancel();
    _rebuild(() => hideMainPanel = true);
    _destinationOpenTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      if (!_driverSession.isOnline || !_destinationPanelController.isAttached) {
        _rebuild(() => hideMainPanel = false);
        return;
      }
      _destinationPanelController.open();
    });
  }

  void _setMapGesturesBlocked(bool value) {
    if (!mounted || _blockMapGestures == value) {
      return;
    }
    _rebuild(() {
      _blockMapGestures = value;
    });
  }

  void _onSheetPointerDown(PointerDownEvent event) {
    _sheetTrace.down();
    _sheetPointerActive = true;
    _sheetPointerLastY = event.position.dy;
    _sheetVelocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _sheetPointerVelocity = 0;
    _sheetPointerTravel = 0;
    _sheetPointerStartPos = _panelController.isAttached
        ? _panelController.panelPosition
        : 0;
    _homeSheetPositionGuardTimer?.cancel();
    _snapSheet.stopSpring();
    _setMapGesturesBlocked(true);
  }

  void _onSheetPointerMove(PointerEvent event) {
    _trackSheetPointer(event);
  }

  void _onSheetPointerEnd(PointerEvent event) {
    _trackSheetPointer(event);
    // driver-r4-37: the finger's speed over its last moves, by the
    // events' own time stamps. The up event repeats the last position,
    // so measured against it alone a flick read 0.
    _sheetPointerVelocity = event is PointerCancelEvent
        ? 0
        : _sheetVelocity.getVelocity().pixelsPerSecond.dy;
    _sheetTrace.up(_sheetPointerVelocity);
    _sheetPointerActive = false;
    // Resting at middle or fully open cannot suppress gestures on the
    // *exposed* area above the sheet. Its own overlay handles touch blocking.
    _setMapGesturesBlocked(false);
    if (!_panelController.isAttached) {
      return;
    }
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

      if (nearestDistance <= 0.025) {
        return;
      }
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
    _sheetVelocity.addPosition(event.timeStamp, event.position);
    _sheetPointerTravel += (event.position.dy - _sheetPointerLastY).abs();
    _sheetPointerLastY = event.position.dy;
  }

  Future<void> _snapHomeSheet({double? velocity}) async {
    if (!_panelController.isAttached) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      unawaited(_snapHomeSheet(velocity: velocity));
    });
  }

  Future<void> _springPanelTo(double target, {double velocityPxPerSec = 0}) {
    _snapSheet.rangePx =
        _homeExpandedHeight(context) - MoveraSheetMetrics.collapsedHeight;
    return _snapSheet.springTo(target, velocityPxPerSec: velocityPxPerSec);
  }

  Widget _buildRadarMapBackdrop() {
    return SizedBox.expand(
      child: !_HomeStartPosition(this)._mapReady
          ? _HomeStartPosition(this)._locating()
          : CustomGoogleMap(
              key: _homeMapKey,
              initialPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              webCameraControlEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              buildingsEnabled: true,
              indoorViewEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              onUserGesture: _camera.userGesture,
              onTouching: (down) => _camera.touching = down,
              onCameraIdle: () {
                _cameraPort?.onIdle();
                _camera.browseSettled();
              },
              onCameraMove: (position) => _cameraPort?.onMove(position),
              mapType: MapType.normal,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _cameraPort = GoogleDriverCameraPort(
                  controller,
                  onStatus: (status) {
                    if (status != null &&
                        mounted &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
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
                  initialPosition: _initialPosition,
                  reducedMotion: MediaQuery.disableAnimationsOf(context),
                );
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
    final lightShown =
        offerOnScreen &&
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
          if (!_HomeStartPosition(this)._mapReady)
            _HomeStartPosition(this)._locating()
          else
            ListenableBuilder(
              // G4-F6: the admin's events, and their icon once painted.
              listenable: Listenable.merge([
                _offerRouteFrame.flowLine,
                DriverEvents.instance,
                MoveraEventMarker.icon,
              ]),
              builder: (context, _) {
                final layers = layersWith(_offerRouteFrame.flowLine.value);
                unawaited(MoveraEventMarker.paintIcon());
                return CustomGoogleMap(
                  key: _homeMapKey,
                  initialPosition: _initialPosition,
                  markers: withEventMarkers(
                    _HomeExclusive(this)._exclusiveFadedPins(
                      _HomeReservation(this)._fadedPins(layers.markers),
                    ),
                    DriverEvents.instance,
                    onTap: (event) =>
                        unawaited(showEventDetails(context, event)),
                  ),
                  polylines: _HomeExclusive(this)._exclusiveFadedLines(
                    _HomeReservation(this)._fadedLines(
                      OfferRouteLine.sized(
                        DriverRouteStyle.sized(
                          layers.polylines,
                          _routeZoomStep,
                        ),
                        _routeZoomStep,
                      ),
                    ),
                  ),
                  // Contract v0.7.2 §17: surge zones as colour only.
                  polygons: _isOnline ? _surgePolygons : const {},
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  webCameraControlEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onUserGesture: _camera.userGesture,
                  onTouching: (down) => _camera.touching = down,
                  onCameraIdle: () {
                    _cameraPort?.onIdle();
                    _camera.browseSettled();
                  },
                  onCameraMove: (position) {
                    _cameraPort?.onMove(position);
                    final step = DriverRouteStyle.stepZoom(position.zoom);
                    if (step != _routeZoomStep) {
                      _rebuild(() => _routeZoomStep = step);
                    }
                  },
                  buildingsEnabled: true,
                  indoorViewEnabled: false,
                  mapType: MapType.normal,
                  padding: _HomeOfferRoute(
                    this,
                  )._homeMapInsets(context).edgeInsets,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _cameraPort = GoogleDriverCameraPort(
                      controller,
                      onStatus: (status) {
                        if (status != null &&
                            mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                      initialPosition: _initialPosition,
                      reducedMotion: MediaQuery.disableAnimationsOf(context),
                    );
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
                  // Audit B3: the airport queue is a sample until the real
                  // queue is built (G15 Q5); demo builds only.
                  if (isDestinationPanel && driverDemoFeatures)
                    Padding(
                      padding: EdgeInsets.only(top: ResSize.h * 12),
                      child: InAirportQueue(),
                    ),
                  // Fix job 9 (§60): the real airport queue place (live
                  // builds); shown only while he is in a queue.
                  if (!driverDemoFeatures && LiveDriverServices.active)
                    Padding(
                      padding: EdgeInsets.only(top: ResSize.h * 12),
                      child: const AirportQueueCard(),
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
          // Round 4b (live): the server's notifications, with the unread
          // count; above the safety button, under the Radar deck.
          if (!isDestinationPanel && _liveHold && _radarHomeOffers.isEmpty)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: 16,
              bottom: HomeMapButtonLayout.bellBottom,
              child: _HomeAccount(this)._buildNotificationsBell(),
            ),
          if (!isDestinationPanel)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: 16,
              bottom: 138,
              child: MapControlButton(
                key: const ValueKey<String>('home-safety-button'),
                tooltip: tr.safetyToolkit,
                size: _homeMapButtonSize,
                onTap: () => showSafetyToolKitSheet(context),
                child: SvgPicture.asset(
                  AppAssets.mapSafety,
                  width: 24,
                  height: 24,
                ),
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
                    (height) =>
                        _HomeOfferRoute(this)._offerCardMeasured(deck: height),
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
                  final lift =
                      MediaQuery.paddingOf(context).top +
                      DigitalIslandParts.height +
                      24;
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

  /// A posted message: show it now if the screen is free, or replace an
  /// outdated one of the same group.
  void _onIslandMessagesChanged() {
    if (!mounted) {
      return;
    }
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

  /// D3.2 (driver-u110/u126): while a screen covers Home (a trip, a
  /// menu screen) or the app is away, messages wait in the queue; Home
  /// shows them once it is back on top.
  void _showNextIslandMessage() {
    if (!mounted || !_liveVisible || _islandMessage != null) {
      return;
    }
    final next = IslandMessages.take();
    if (next == null) {
      return;
    }
    _islandWakeTimer?.cancel();
    _rebuild(() {
      _islandWake = 2;
      _islandMessage = next;
      _islandMessageSeq++;
    });
    _islandMessageTimer?.cancel();
    _islandMessageTimer = Timer(next.priority.duration, _endIslandMessage);
  }

  /// A saved-trip problem: a heads-up on the island and a sheet that
  /// stays until the driver acts, since a tap only closes the island.
  void _tripProblem(IslandMessage notice, String message, {String? action}) {
    IslandMessages.show(notice);
    unawaited(
      showTripProblemSheet(
        context,
        title: notice.title,
        message: message,
        actionLabel: action ?? tr.retry,
        onAction: () => unawaited(_restoreActiveRideIfNeeded()),
      ),
    );
  }

  /// Launch: small island, it grows after a beat, then its screen turns on.
  void _startIslandWake() {
    _islandWakeTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      _rebuild(() => _islandWake = 1);
      _islandWakeTimer = Timer(const Duration(milliseconds: 560), () {
        if (!mounted) {
          return;
        }
        _rebuild(() => _islandWake = 2);
        unawaited(_showIslandHintOnce());
      });
    });
    _scheduleLastTripSettle();
    _HomeMapIsland(this)._refreshLastTripTip(auto: true);
  }

  void _onLastTripChanged() {
    if (!mounted) {
      return;
    }
    _rebuild(() {});
    _scheduleLastTripSettle();
  }

  void _closeHomeFloatingPopupsForSheet() {
    if (!showRideRequests && !_isDirectOfferRoutePreview) {
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

  Future<void> _maybeShowAppUpdatePrompt() async {
    if (_updatePromptShown ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final update = _adminHomeConfig.update;
    if (!update.enabled ||
        !_isVersionNewer(
          update.latestVersion,
          _DriverHomeState._currentAppVersion,
        )) {
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

  /// How far the open sheet has covered the dock's notch: 0 closed,
  /// 1 once the sheet has risen a little. The notch flattens over it.
  static double _notchCover(double position) =>
      (position / 0.10).clamp(0.0, 1.0);

  /// The four dock icons, fixed at the bottom of the sheet from closed to
  /// open. Closed, it carries the notch for the radar; as the sheet opens
  /// over it the notch flattens into plain white.
  Widget? _homeDockFooter() {
    if (_homeSheetInactive) {
      return null;
    }
    return _sheetPointer(
      SizedBox(
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
      ),
    );
  }

  static const Color _sheetInk = Color(0xFF121619);
  static const Color _sheetText = Color(0xFF3A4247);
  static const Color _sheetSub = Color(0xFF80888E);
  static const Color _sheetLine = Color(0xFFEEF0F2);

  void _openDrivingTime() {
    final clock = DrivingTimeClock.instance;
    unawaited(
      _openDetailsSheet(
        title: tr.drivingTime,
        rows: [
          (last) => _todayRow(
            mark: MoveraMark.timer,
            label: tr.worked,
            value: DrivingTimeClock.hoursMinutes(clock.worked),
            last: last,
          ),
          (last) => _todayRow(
            mark: MoveraMark.route,
            label: switch (clock.restUntil) {
              null => tr.leftBeforeRest,
              _ => tr.restUntil,
            },
            value: switch (clock.restUntil) {
              final until? => clockLabel(until),
              null => DrivingTimeClock.hoursMinutes(clock.left),
            },
            last: last,
          ),
          (last) => _todayRow(
            mark: MoveraMark.calendar,
            label: tr.workLimit,
            value: '${clock.rule.workHours} h',
            last: last,
          ),
          (last) => _todayRow(
            mark: MoveraMark.timer,
            label: tr.restAfterIt,
            value: '${clock.rule.restHours} h',
            last: last,
          ),
        ],
        // Q25: the admin's rule for the country.
        note: tr.countsWhileRadarIsOnAfter(
          clock.rule.workHours,
          clock.rule.restHours,
        ),
      ),
    );
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
                  tooltip: tr.closeSheet,
                  onPressed: () => unawaited(_closeDriverSheet()),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _sheetInk,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Text(
                    tr.today,
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
            child: ListenableBuilder(
              listenable: DriverContentStore.instance,
              builder: (context, _) => ListView(
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
