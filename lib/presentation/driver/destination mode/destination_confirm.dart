import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/movera_destination_marker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// "38.1 km · 34 min" (confirm sheet).
String destinationDistanceTimeLabel(double meters, double seconds) =>
    '${(meters / 1000).toStringAsFixed(1)} km · ${_minutes(seconds)} min';

/// "35 min · 35 km" (Home bar once Destination mode is on).
String destinationTimeDistanceLabel(double meters, double seconds) =>
    '${_minutes(seconds)} min · ${(meters / 1000).round()} km';

int _minutes(double seconds) => math.max(1, (seconds / 60).round());

/// Choose-destination step: a black arc draws from the car (the driver's
/// real position, [DestinationConfirmScreen.origin]) to the destination over
/// a faint straight line, the place chip stands on the blue pin, and one
/// option card ends in "Confirm destination". Arc, car, pin and chip are map
/// objects, so they stay on their places when the map is dragged. Pops the
/// destination with its distance and time, or null on close.
class DestinationConfirmScreen extends StatefulWidget {
  const DestinationConfirmScreen({
    super.key,
    required this.origin,
    required this.destination,
    this.routeRepository,
    this.now,
  });

  final LatLng origin;
  final DriverDestinationResult destination;
  final RouteRepository? routeRepository;
  final DateTime Function()? now;

  @override
  State<DestinationConfirmScreen> createState() =>
      _DestinationConfirmScreenState();
}

class _DestinationConfirmScreenState extends State<DestinationConfirmScreen>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(0xFF111315);
  static const Color _muted = Color(0xFF5D646C);
  static const double _sheetOverlap = 300;

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final List<LatLng> _arc =
      destinationArcPoints(widget.origin, widget.destination.position);
  int _arcShown = 0; // Points of [_arc] drawn so far.
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pinIcon = MoveraDestinationMarker.cachedPin;
  BitmapDescriptor? _chipIcon;
  Timer? _drawStart;
  late double _meters;
  late double _seconds;
  bool _done = false;

  String get _place =>
      widget.destination.name ?? widget.destination.address.split(',').first;

  @override
  void initState() {
    super.initState();
    // Until the road route answers: straight line x1.3 at ~40 km/h.
    final straight = GeoPointMaps.fromLatLng(widget.origin)
        .distanceMetersTo(GeoPointMaps.fromLatLng(widget.destination.position));
    _meters = straight * 1.3;
    _seconds = _meters / (40 / 3.6);
    unawaited(_loadRoute());
    unawaited(_loadIcons());
    _draw.addListener(_grow);
    // Draw once the map is up, or shortly anyway.
    _drawStart = Timer(const Duration(milliseconds: 700), _startDraw);
  }

  Future<void> _loadIcons() async {
    try {
      final icons = await Future.wait([
        MoveraDestinationMarker.car(),
        MoveraDestinationMarker.pin(),
        MoveraDestinationMarker.chip(_place),
      ]);
      if (!mounted) { return; }
      setState(() {
        _carIcon = icons[0];
        _pinIcon = icons[1];
        _chipIcon = icons[2];
      });
    } catch (_) {}
  }

  void _startDraw() {
    _drawStart?.cancel();
    if (!mounted || _draw.isAnimating || _draw.value > 0) { return; }
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else {
      unawaited(_draw.forward(from: 0));
    }
  }

  void _grow() {
    final t = Curves.easeInOutCubic.transform(_draw.value);
    final shown = (t * _arc.length).ceil().clamp(0, _arc.length);
    if (shown != _arcShown) { setState(() => _arcShown = shown); }
  }

  Future<void> _loadRoute() async {
    final repo = widget.routeRepository;
    if (repo == null) { return; }
    try {
      final route = await repo
          .drivingRoute(
            origin: GeoPointMaps.fromLatLng(widget.origin),
            destination: GeoPointMaps.fromLatLng(widget.destination.position),
          )
          .timeout(const Duration(seconds: 6));
      if (!mounted || route.distanceMeters <= 0) { return; }
      setState(() {
        _meters = route.distanceMeters;
        _seconds = route.durationSeconds;
      });
    } catch (_) {
      // Keep the estimate.
    }
  }

  @override
  void dispose() {
    _drawStart?.cancel();
    _draw.dispose();
    super.dispose();
  }

  /// The arc and both ends, so the bulge and the chip fit too.
  LatLngBounds get _bounds {
    final lats = _arc.map((p) => p.latitude);
    final lngs = _arc.map((p) => p.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      northeast: LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) { return; }
    try {
      await controller.moveCamera(CameraUpdate.newLatLngBounds(_bounds, 80));
    } catch (_) {}
    if (mounted) { _startDraw(); }
  }

  /// Faint straight line under the black arc, grown to [_arcShown] points.
  @visibleForTesting
  Set<Polyline> get polylines => {
    Polyline(
      polylineId: const PolylineId('destination-straight'),
      points: [widget.origin, widget.destination.position],
      color: const Color(0x55888E94),
      width: 3,
      zIndex: 1,
    ),
    if (_arcShown >= 2)
      Polyline(
        polylineId: const PolylineId('destination-arc'),
        points: _arc.sublist(0, _arcShown),
        color: _ink,
        width: 6,
        zIndex: 2,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
  };

  /// The car on the driver's position, the blue pin and its name chip on
  /// the destination.
  @visibleForTesting
  Set<Marker> get markers {
    final to = widget.destination.position;
    final fallback = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure);
    return {
      Marker(
        markerId: const MarkerId('destination-confirm-car'),
        position: widget.origin,
        icon: _carIcon ?? fallback,
        anchor: MoveraDestinationMarker.carAnchor,
        zIndexInt: 3,
        consumeTapEvents: true,
      ),
      if (_chipIcon != null)
        Marker(
          markerId: const MarkerId('destination-confirm-chip'),
          position: to,
          icon: _chipIcon!,
          anchor: MoveraDestinationMarker.chipAnchor,
          zIndexInt: 4,
          consumeTapEvents: true,
        ),
      Marker(
        markerId: const MarkerId('destination-confirm-pin'),
        position: to,
        icon: _pinIcon ?? fallback,
        anchor: MoveraDestinationMarker.pinAnchor,
        zIndexInt: 5,
        consumeTapEvents: true,
      ),
    };
  }

  void _confirm() {
    if (_done || ModalRoute.of(context)?.isCurrent != true) { return; }
    _done = true;
    final d = widget.destination;
    Navigator.of(context).pop(DriverDestinationResult(
      position: d.position,
      address: d.address,
      name: d.name,
      distanceMeters: _meters,
      durationSeconds: _seconds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.now ?? DateTime.now)();
    final arrive = clockLabel(now.add(Duration(seconds: _seconds.round())));
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: _sheetOverlap,
            child: CustomGoogleMap(
              initialPosition: CameraPosition(
                target: LatLng(
                  (widget.origin.latitude +
                          widget.destination.position.latitude) / 2,
                  (widget.origin.longitude +
                          widget.destination.position.longitude) / 2,
                ),
                zoom: 10,
              ),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              show3DNotice: false,
              onMapCreated: _onMapCreated,
            ),
          ),
          Positioned(
            left: 16,
            top: top + 12,
            child: PointerInterceptor(
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: Colors.black26,
                child: InkWell(
                  key: const ValueKey<String>('destination-confirm-close'),
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: SvgPicture.asset(AppAssets.solarClose,
                        width: 22, height: 22),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: PointerInterceptor(child: _sheet(arrive)),
          ),
        ],
      ),
    );
  }

  Widget _sheet(String arrive) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 22, 20, 16 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x2211181C), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            destinationDistanceTimeLabel(_meters, _seconds),
            key: const ValueKey<String>('destination-confirm-summary'),
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey<String>('destination-confirm-option'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SvgPicture.asset(AppAssets.solarClockCircle,
                          width: 20, height: 20,
                          colorFilter: const ColorFilter.mode(
                              _ink, BlendMode.srcIn)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Fastest route to your destination',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "You'll only get trips heading your way, so every ride "
                  'takes you closer to $_place.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Arrive by $arrive',
                  key: const ValueKey<String>('destination-confirm-arrive'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const ValueKey<String>('destination-confirm'),
              onPressed: _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Confirm destination',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
