part of 'home.dart';

// R11-7: a Radar or Exclusive offer on Home shows its whole route, pickup
// to drop-off (no drive to the pickup), fitted between the top island and
// the top of the offer card or deck. The fit follows the card's height.
// A reservation request shows its route the same way, above its sheet,
// with clock times on the pins; so does the Exclusive offer, above the
// same sheet, with minutes on the pins.

/// What the offer route needs to re-fit: the card heights and the points.
class _OfferRouteFrame {
  /// Measured heights of the Radar deck and the Exclusive sheet (its orb
  /// included).
  double? deckHeight;
  double? exclusiveHeight;

  /// Measured height of the reservation sheet, its orb included.
  double? reservationHeight;

  /// Pickup, drop-off, the stops and the road between them.
  List<LatLng> framing = const <LatLng>[];
  Timer? refit;

  /// The pins' chip texts, so the fit leaves room for the chips.
  String? pickupLabel;
  String? dropoffLabel;

  /// The camera this offer's route was last fitted to; null until the
  /// first fit of a new offer (which takes the map over).
  RouteCameraFit? fitted;

  /// R14-2: the road the line animation runs along, and its clock.
  List<GeoPoint> road = const <GeoPoint>[];
  Timer? line;
  final Stopwatch lineClock = Stopwatch();
  OfferLinePhase? linePhase;

  /// The white part of the animated line; only the map listens to it.
  final ValueNotifier<Set<Polyline>> lightLine =
      ValueNotifier<Set<Polyline>>(const <Polyline>{});

  /// Stops the animation (offer gone, app hidden); the line stays black.
  void stopLine() {
    line?.cancel();
    line = null;
    lineClock
      ..stop()
      ..reset();
    linePhase = null;
    if (lightLine.value.isNotEmpty) { lightLine.value = const <Polyline>{}; }
  }

  void dispose() {
    refit?.cancel();
    line?.cancel();
    lightLine.dispose();
  }
}

/// The animation's beat: ~30 a second at most (light on web).
const Duration _lineTick = Duration(milliseconds: 33);

extension _HomeOfferRoute on _DriverHomeState {
  /// R14-1: the pins with their minutes, pickup = the drive there,
  /// drop-off = the trip's own length, and a circle on each stop.
  Future<Set<Marker>> _offerRouteMarkers(_HomeDirectOffer offer) =>
      _routePins(
        offer.pickupPosition,
        offer.dropoffPosition,
        OfferRouteMarks.minutes(offer.pickupMinutes),
        OfferRouteMarks.minutes(offer.tripMinutes),
        stops: [for (final stop in offer.stops) stop.point.toLatLng()],
      );

  /// "Pickup" and "Drop-off" pins with [pickupValue] and [dropoffValue]
  /// (clock times or minutes) and a small circle on each of [stops].
  Future<Set<Marker>> _routePins(
    LatLng pickup,
    LatLng dropoff,
    String pickupValue,
    String dropoffValue, {
    List<LatLng> stops = const <LatLng>[],
  }) => OfferRouteMarks.markers(
    pickup: pickup,
    dropoff: dropoff,
    pickupValue: pickupValue,
    dropoffValue: dropoffValue,
    stops: stops,
  );

  /// The road pickup → each stop → drop-off, one leg per stop, so the
  /// line passes the stops' circles.
  Future<List<LatLng>> _offerRoad(
    LatLng pickup,
    List<LatLng> stops,
    LatLng dropoff,
  ) async {
    final via = [pickup, ...stops, dropoff];
    final legs = await Future.wait([
      for (var i = 1; i < via.length; i++)
        _roadRouteService.drivingRoute(
          origin: GeoPointMaps.fromLatLng(via[i - 1]),
          destination: GeoPointMaps.fromLatLng(via[i]),
        ),
    ]);
    final road = <LatLng>[];
    for (final leg in legs) {
      final points = leg.latLngPoints;
      road.addAll(
        road.isNotEmpty && points.isNotEmpty && points.first == road.last
            ? points.skip(1)
            : points,
      );
    }
    return _offerRoutePoints(pickup, dropoff, road);
  }

  /// The trip's road, pinned to the exact pickup and drop-off.
  List<LatLng> _offerRoutePoints(
    LatLng pickup,
    LatLng dropoff,
    List<LatLng> road,
  ) {
    if (road.isEmpty) { return const <LatLng>[]; }
    return <LatLng>[
      if (road.first != pickup) pickup,
      ...road,
      if (road.last != dropoff) dropoff,
    ];
  }

  /// How much of the map's bottom the offer card or deck covers; null
  /// before it has been measured.
  double? _offerCardObscured() {
    if (_reservation.routeId != null) {
      return _offerRouteFrame.reservationHeight ??
          MediaQuery.sizeOf(context).height * 0.4 +
              HomeReservationSheet.orbSize / 2;
    }
    if (_outsideRadarOffer != null) {
      return _offerRouteFrame.exclusiveHeight ??
          MediaQuery.sizeOf(context).height * 0.4 +
              HomeOfferSheet.orbSize / 2;
    }
    final deck = _offerRouteFrame.deckHeight;
    if (deck == null || _radarHomeOffers.isEmpty) { return null; }
    // The deck sits above the map buttons (see the deck's slot).
    return 138 + _homeMapButtonSize + 12 + deck;
  }

  /// Insets for the Home map; with an offer up the top clears the island.
  MapOverlayInsets _homeMapInsets(BuildContext context) =>
      MapOverlayInsets.forHome(
        safeTop: MediaQuery.paddingOf(context).top,
        obscuredBottom: _HomeMapSheet(this)._homeMapObscuredBottom(context),
        hasTopBanner: _isDirectOfferRoutePreview ||
            _radarHomeOffers.isNotEmpty ||
            _outsideRadarOffer != null,
      );

  /// An offer whose route belongs on the map is on screen right now.
  bool get _offerOnScreen =>
      _isDirectOfferRoutePreview &&
      (_outsideRadarOffer != null ||
          _radarHomeOffers.isNotEmpty ||
          _reservation.routeId != null);

  /// The map between the island and the top of the card, sheet or orb.
  Rect _offerFreeArea(Size size, MapOverlayInsets insets) => Rect.fromLTRB(
        16,
        insets.top + 12,
        size.width - 16,
        size.height - insets.bottom - 6,
      );

  /// Everything of the route the camera must show: the road, the stops'
  /// circles and both pins with their bubbles.
  List<RouteFitPoint> _offerFitPoints() {
    final frame = _offerRouteFrame;
    final points = frame.framing;
    RouteFitPoint pin(LatLng at, RouteMarkKind kind, String? label) {
      final point = GeoPointMaps.fromLatLng(at);
      if (label == null) {
        return RouteFitPoint(point, left: 17, right: 17, up: 17, down: 17);
      }
      final size = OfferRouteMarks.pinSize(kind, label);
      final anchor = OfferRouteMarks.pinAnchor(kind, label);
      return RouteFitPoint(
        point,
        left: size.width * anchor.dx,
        right: size.width * (1 - anchor.dx),
        up: size.height * anchor.dy,
        down: size.height * (1 - anchor.dy),
      );
    }

    return [
      for (var i = 0; i < points.length; i++)
        i == 0
            ? pin(points[0], RouteMarkKind.pickup, frame.pickupLabel)
            : i == 1
            ? pin(points[1], RouteMarkKind.dropoff, frame.dropoffLabel)
            : RouteFitPoint(
                GeoPointMaps.fromLatLng(points[i]),
                left: 12,
                right: 12,
                up: 12,
                down: 12,
              ),
    ];
  }

  /// Fits the whole route (road, stops, pins and chips) into the free map
  /// above the sheet and its orb. The first fit of an offer takes the map
  /// over; later ones (road loaded, sheet measured) only correct it, and
  /// never once the driver moved the map.
  Future<void> _fitOfferRoute() async {
    final frame = _offerRouteFrame;
    if (!mounted || !_isDirectOfferRoutePreview || frame.framing.isEmpty) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final insets = _homeMapInsets(context);
    final fit = fitRouteCamera(
      points: _offerFitPoints(),
      free: _offerFreeArea(size, insets),
      // Web maps ignore padding: the target is the view's middle.
      targetAt: kIsWeb
          ? size.center(Offset.zero)
          : insets.edgeInsets.deflateRect(Offset.zero & size).center,
    );
    if (fit == null) { return; }
    final last = frame.fitted;
    if (last != null &&
        (fit.closeTo(last) || _camera.mode == DriverCameraMode.browsing)) {
      return;
    }
    frame.fitted = fit;
    await _camera.previewFit(
      fit,
      points: frame.framing.map(GeoPointMaps.fromLatLng).toList(),
      padding: insets.boundsPadding,
      takeOver: last == null,
    );
  }

  /// R14-2: the black-and-white line animation along [road] (see
  /// [OfferRouteLine]), again and again while the offer is up. None with
  /// reduced motion or while Home is hidden: the line stays black.
  void _startRouteLine(List<LatLng> road) {
    final frame = _offerRouteFrame..stopLine();
    if (road.length >= 2) {
      frame.road = road.map(GeoPointMaps.fromLatLng).toList();
    }
    _resumeRouteLine();
  }

  /// Runs the line animation again (Home shown again) when an offer's
  /// road is on the map.
  void _resumeRouteLine() {
    final frame = _offerRouteFrame;
    if (!mounted ||
        frame.line != null ||
        frame.road.length < 2 ||
        !_liveVisible ||
        !_offerOnScreen ||
        _directOfferRoutePolylines.isEmpty ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    frame.lineClock.start();
    void tick() {
      if (!mounted ||
          !_offerOnScreen ||
          !_liveVisible ||
          _directOfferRoutePolylines.isEmpty ||
          MediaQuery.disableAnimationsOf(context)) {
        frame.stopLine();
        return;
      }
      final phase = OfferRouteLine.phaseAt(frame.lineClock.elapsed);
      final last = frame.linePhase;
      // Resting black (or unchanged): nothing to send to the map.
      if (last != null && (phase == last || (phase.dark && last.dark))) {
        return;
      }
      frame
        ..linePhase = phase
        ..lightLine.value = OfferRouteLine.light(
          frame.road,
          phase,
          zoom: _routeZoomStep,
        );
    }

    frame.line = Timer.periodic(_lineTick, (_) => tick());
    tick();
  }

  /// The deck, the Exclusive card or the reservation sheet changed
  /// height: re-fit the route to the new free space once it settles.
  void _offerCardMeasured({
    double? deck,
    double? exclusive,
    double? reservation,
  }) {
    if (!mounted) { return; }
    final frame = _offerRouteFrame;
    final old = deck != null
        ? frame.deckHeight
        : exclusive != null
        ? frame.exclusiveHeight
        : frame.reservationHeight;
    final next = deck ?? exclusive ?? reservation!;
    // No real change, or a request sheet is down (nothing laid out).
    if ((old != null && (old - next).abs() < 2) ||
        (deck == null && next <= 0)) { return; }
    if (deck != null) {
      frame.deckHeight = deck;
    } else if (exclusive != null) {
      frame.exclusiveHeight = exclusive;
    } else {
      frame.reservationHeight = reservation;
    }
    if (!_isDirectOfferRoutePreview) { return; }
    frame.refit?.cancel();
    frame.refit = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_isDirectOfferRoutePreview) { return; }
      // The map's padding follows the new height first.
      _rebuild(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_fitOfferRoute());
      });
    });
  }

  /// Reports [child]'s height after layout to [onHeight].
  Widget _measureOfferCard(Widget child, ValueChanged<double> onHeight) =>
      _OfferCardSize(onHeight: onHeight, child: child);
}

class _OfferCardSize extends SingleChildRenderObjectWidget {
  const _OfferCardSize({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOfferCardSize(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOfferCardSize renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderOfferCardSize extends RenderProxyBox {
  _RenderOfferCardSize(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) { return; }
    _reported = height;
    final report = onHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) => report(height));
  }
}
