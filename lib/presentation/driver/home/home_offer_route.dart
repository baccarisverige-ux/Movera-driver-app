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

  /// Pickup, drop-off and the road between them.
  List<LatLng> framing = const <LatLng>[];
  Timer? refit;
}

extension _HomeOfferRoute on _DriverHomeState {
  /// The pins with their time chips: pickup = minutes to drive there,
  /// drop-off = the trip's own length.
  Future<Set<Marker>> _offerRouteMarkers(_HomeDirectOffer offer) =>
      _routePins(
        offer.pickupPosition,
        offer.dropoffPosition,
        OfferRoutePins.minutes(offer.pickupMinutes),
        OfferRoutePins.minutes(offer.tripMinutes),
      );

  /// Pickup and drop-off pins with their chips: [pickupLabel] left of the
  /// green dot, [dropoffLabel] right of the black square.
  Future<Set<Marker>> _routePins(
    LatLng pickup,
    LatLng dropoff,
    String pickupLabel,
    String dropoffLabel,
  ) async {
    final icons = await Future.wait([
      OfferRoutePins.icon(OfferRoutePinKind.pickup, pickupLabel),
      OfferRoutePins.icon(OfferRoutePinKind.dropoff, dropoffLabel),
    ]);
    return {
      Marker(
        markerId: const MarkerId('radar_pickup'),
        position: pickup,
        infoWindow: InfoWindow(title: pickupLabel),
        icon: icons[0],
        anchor: OfferRoutePins.anchor(OfferRoutePinKind.pickup, pickupLabel),
        consumeTapEvents: true,
        zIndexInt: 14,
      ),
      Marker(
        markerId: const MarkerId('radar_dropoff'),
        position: dropoff,
        infoWindow: InfoWindow(title: dropoffLabel),
        icon: icons[1],
        anchor: OfferRoutePins.anchor(OfferRoutePinKind.dropoff, dropoffLabel),
        consumeTapEvents: true,
        zIndexInt: 14,
      ),
    };
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

  Future<void> _fitOfferRoute() async {
    final points = _offerRouteFrame.framing;
    if (!mounted || !_isDirectOfferRoutePreview || points.isEmpty) { return; }
    await _HomeMapSheet(this)._fitPoints(
      points,
      padding: _homeMapInsets(context).boundsPadding,
    );
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
