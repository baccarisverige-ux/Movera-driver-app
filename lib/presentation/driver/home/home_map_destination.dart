part of 'home.dart';

extension _HomeMapDestination on _DriverHomeState {
  Future<void> _activateDestinationMode(
    DriverDestinationResult result, {
    bool adopted = false,
  }) async {
    final destination = result.position;
    _mapPreviews.cancel(); // An old offer cannot reclaim the destination map.
    _destinationRoadRequests.cancel();
    _destinationRouteRefetch.reset();
    _cameraRoute = null;
    if (!adopted) {
      DestinationModeSession.instance.started(
        address: result.address,
        position: GeoPointMaps.fromLatLng(destination),
      );
    }
    _destinationLimitTimer?.cancel();
    _armDestinationLimit();
    _rebuild(() {
      _destinationModeActive = true;
      _destinationAddress = result.address;
      _destinationPosition = destination;
      _destinationTrip = result;
      _destinationRouteMarkers = {
        destinationModeMarker(destination, result.address),
      };
      _destinationRoutePolylines = <Polyline>{};
    });
    _nameDestination(result.address, destination);
    if (MoveraDestinationMarker.cachedPin == null) {
      unawaited(
        MoveraDestinationMarker.pin().then((_) {
          if (!mounted || _destinationPosition != destination) {
            return;
          }
          _rebuild(
            () => _destinationRouteMarkers = {
              destinationModeMarker(destination, result.address),
            },
          );
        }),
      );
    }

    // Only an offline driver is put online by the destination.
    final goOnline = !adopted && !_isOnline && !_isGoingOnline;
    await _refreshDestinationRoadRoute();
    await _fitDestinationRoute();
    // driver-66: the driver may have turned the destination off (or gone
    // offline, or left Home) while the road route was on its way.
    if (!mounted ||
        !_destinationModeActive ||
        _destinationPosition != destination) {
      return;
    }
    _seedDemoDestinationTrips();
    _HomeOfferRadar(this)._maybeShowSoonReservation();

    if (goOnline && !_isOnline && !_isGoingOnline) {
      _goOnline();
    }
  }

  /// R13-9: the admin's time limit ends the destination. One set later
  /// on a trip restarts the shared clock; Home then waits for that
  /// one's limit instead of ending it early (driver-u122).
  void _armDestinationLimit() {
    final session = DestinationModeSession.instance;
    final left = session.timeLeft();
    if (left == null) {
      return;
    }
    final since = session.activeSince;
    _destinationLimitTimer = Timer(left, () {
      if (!mounted || !_destinationModeActive) {
        return;
      }
      if (DestinationModeSession.instance.activeSince != since) {
        _armDestinationLimit();
        return;
      }
      _endDestinationMode();
      DestinationModeSession.instance.timedOut();
      IslandMessages.show(HomeIslandNotices.destinationEnded);
    });
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
      if (!mounted ||
          !_destinationModeActive ||
          _destinationPosition != destination ||
          !_destinationRoadRequests.owns(generation)) {
        return;
      }

      _cameraRoute = route;
      DestinationModeSession.instance.keepRoute(
        GeoPointMaps.fromLatLng(destination),
        route.points,
        meters: route.distanceMeters,
        seconds: route.durationSeconds,
      );
      unawaited(_animateToDriverLocation());

      _rebuild(() {
        _destinationRoutePolylines = DriverRouteStyle.polylines(
          id: 'destination_mode_road_route',
          points: route.latLngPoints,
        );
      });
    } catch (_) {
      if (!mounted ||
          !_destinationModeActive ||
          _destinationPosition != destination ||
          !_destinationRoadRequests.owns(generation)) {
        return;
      }
      _cameraRoute = null;
      _rebuild(() => _destinationRoutePolylines = <Polyline>{});
    }
  }

  /// The driver's position once a saved or live one is known; null
  /// while the map shows only the city-centre placeholder.
  LatLng? get _knownDriverPosition =>
      _startPositionKnown ? _driverPosition : null;
  Future<void> _fitDestinationRoute() async {
    final destination = _destinationPosition;
    if (destination == null || _mapController == null) {
      return;
    }
    final generation = _mapPreviews.begin();

    final routePoints = _destinationRoutePolylines.isEmpty
        ? <LatLng>[?_knownDriverPosition, destination]
        : _destinationRoutePolylines.first.points;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted ||
        !_destinationModeActive ||
        _destinationPosition != destination ||
        _mapController == null ||
        !_mapPreviews.owns(generation)) {
      return;
    }

    await _fitPoints(routePoints, padding: 74);
  }

  /// Live road route when GPS has one, else the confirmed figures.
  /// driver-r5-20: after a failed refresh or a lost fix, the last live
  /// figures for a few minutes, then none: once Home had live ones, the
  /// confirm-time figures are from far back and would read as live.
  (double, double)? get _destinationFigures {
    final route = _cameraRoute;
    if (route != null) {
      return (route.distanceMeters, route.durationSeconds);
    }
    final to = _destinationPosition, session = DestinationModeSession.instance;
    if (to != null && session.hadRouteTo(GeoPointMaps.fromLatLng(to))) {
      return session.figuresTo(GeoPointMaps.fromLatLng(to));
    }
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
      // driver-u123: when the mode really ends (the admin time limit),
      // not the arrival time.
      until: switch (DestinationModeSession.instance.endsAt()) {
        final end? => clockLabel(end),
        null => null,
      },
      onShowRoute: _fitDestinationRoute,
      // Decision 4: locked while a Match or Accept is with dispatch.
      onTurnOff: _HomeOfferRules(this)._claimInFlight
          ? null
          : _endDestinationMode,
    );
  }

  /// R13-9 demo: with real filtering the fixed demo trips rarely head the
  /// driver's way, so the demo adds trips along the route: an Exclusive
  /// near the destination and Radar trips on the way (plus two outside).
  void _seedDemoDestinationTrips() {
    final demo = _dispatch, destination = _destinationPosition;
    if (demo is! DemoDispatchRepository ||
        destination == null ||
        !_destinationModeActive) {
      return;
    }
    final rules = DestinationModeRules.current;
    final trips = DemoDestinationTrips.along(
      driver: GeoPointMaps.fromLatLng(_driverPosition),
      destination: GeoPointMaps.fromLatLng(destination),
      route: _cameraRoute?.points ?? const <GeoPoint>[],
      corridorKm: rules.corridorOn
          ? rules.corridorKm
          : DestinationFilter.defaultNearKm,
      destinationLabel: _destinationShortLabel,
    );
    final exclusive = trips.firstWhere(
      (t) => t.id == DemoDestinationTrips.exclusiveId,
    );
    _destinationDemoExclusive = _HomeDirectOffer.fromRide(
      exclusive,
      reason: ExclusiveReasons.nearby,
    );
    demo.showDestinationTrips([
      for (final t in trips)
        if (t != exclusive) t,
    ]);
    // Already online: the usual demo timers have run, so these come now.
    if (!_isOnline || _outsideRadarOffer != null) {
      return;
    }
    _directOfferTimer?.cancel();
    _directOfferTimer = Timer(const Duration(milliseconds: 1500), () {
      final offer = _destinationDemoExclusive;
      if (!mounted || !_isOnline || !_destinationModeActive || offer == null) {
        return;
      }
      unawaited(_HomeOfferRadar(this)._showOutsideRadarOffer(offer));
      // Radar trips on the way wait behind it.
      _HomeOfferRadar(this)._showDispatchOfferAt(0);
      _HomeOfferRadar(this)._showDispatchOfferAt(1);
    });
  }

  void _endDestinationMode() {
    if (!_destinationModeActive) {
      return;
    }
    _clearDemoDestinationTrips();
    _destinationLimitTimer?.cancel();
    DestinationModeSession.instance.ended();
    // driver-r4-38: an offer's route preview on screen keeps its road
    // and its framing; only the destination's own preview ends.
    final offerPreview = _HomeOfferRoute(this)._offerOnScreen;
    if (!offerPreview) {
      _mapPreviews.cancel();
    }
    _destinationRoadRequests.cancel();
    _destinationRoadRefresh.cancelPending();
    _cameraRoute = null;
    if (!offerPreview) {
      _camera.endPreview();
    }
    _rebuild(() {
      _destinationModeActive = false;
      _destinationAddress = null;
      _destinationPosition = null;
      _destinationRouteMarkers = {};
      _destinationRoutePolylines = {};
    });
  }

  /// Round 4 (live): the hold is the server's account state, not the demo
  /// hold with its "Skip demo".
  bool get _liveHold =>
      DriverRuntimeConfig.current.authRequired &&
      accountSessionOf(context) != null;

  bool get _liveAwaitsFleet =>
      accountSessionOf(context)?.account?.awaitsFleet ?? false;

  void _openHoldDocuments() {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => driverDocumentsScreen()),
    );
  }

  void _openHoldFleet() {
    final session = accountSessionOf(context);
    if (session == null) return;
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => MyFleetScreen(account: session)),
    );
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
}
