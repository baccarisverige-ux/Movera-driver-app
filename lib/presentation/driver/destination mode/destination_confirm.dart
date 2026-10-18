import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// "38.1 km · 34 min" (confirm sheet).
String destinationDistanceTimeLabel(double meters, double seconds) =>
    '${(meters / 1000).toStringAsFixed(1)} km · ${_minutes(seconds)} min';

/// "35 min · 35 km" (Home bar once Destination mode is on).
String destinationTimeDistanceLabel(double meters, double seconds) =>
    '${_minutes(seconds)} min · ${(meters / 1000).round()} km';

int _minutes(double seconds) => math.max(1, (seconds / 60).round());

/// Choose-destination step: a black arc draws from the car to the
/// destination over a faint straight line, the place chip sits on the pin,
/// and one option card ends in "Confirm destination". Pops the destination
/// with its distance and time, or null on close.
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
  GoogleMapController? _map;
  Offset? _carPx;
  Offset? _pinPx;
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
    _draw.dispose();
    super.dispose();
  }

  LatLngBounds get _bounds {
    final a = widget.origin;
    final b = widget.destination.position;
    return LatLngBounds(
      southwest: LatLng(math.min(a.latitude, b.latitude),
          math.min(a.longitude, b.longitude)),
      northeast: LatLng(math.max(a.latitude, b.latitude),
          math.max(a.longitude, b.longitude)),
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _map = controller;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) { return; }
    try {
      await controller.moveCamera(CameraUpdate.newLatLngBounds(_bounds, 90));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _measure();
  }

  /// Screen points of the car and the pin, for the overlay arc. The map
  /// takes no gestures here, so they stay put once measured.
  Future<void> _measure() async {
    final map = _map;
    if (map == null || !mounted) { return; }
    try {
      final car = await map.getScreenCoordinate(widget.origin);
      final pin = await map.getScreenCoordinate(widget.destination.position);
      if (!mounted) { return; }
      // Android answers in physical pixels; iOS and web in logical ones.
      final scale = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? MediaQuery.devicePixelRatioOf(context)
          : 1.0;
      final carPx = Offset(car.x / scale, car.y / scale);
      final pinPx = Offset(pin.x / scale, pin.y / scale);
      if (carPx == _carPx && pinPx == _pinPx) { return; }
      final first = _carPx == null;
      setState(() {
        _carPx = carPx;
        _pinPx = pinPx;
      });
      if (first) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _draw.value = 1;
        } else {
          unawaited(_draw.forward(from: 0));
        }
      }
    } catch (_) {}
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
            child: Stack(
              children: [
                CustomGoogleMap(
                  initialPosition: CameraPosition(
                    target: LatLng(
                      (widget.origin.latitude +
                              widget.destination.position.latitude) / 2,
                      (widget.origin.longitude +
                              widget.destination.position.longitude) / 2,
                    ),
                    zoom: 10,
                  ),
                  myLocationEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  show3DNotice: false,
                  onMapCreated: _onMapCreated,
                  onCameraIdle: () => unawaited(_measure()),
                ),
                if (_carPx != null && _pinPx != null) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _draw,
                        builder: (context, _) => CustomPaint(
                          key: const ValueKey<String>('destination-arc'),
                          painter: DestinationArcPainter(
                            from: _carPx!,
                            to: _pinPx!,
                            progress: Curves.easeInOutCubic
                                .transform(_draw.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _pinPx!.dx,
                    top: _pinPx!.dy - 46,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -1),
                      child: IgnorePointer(child: _chip()),
                    ),
                  ),
                ],
              ],
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

  Widget _chip() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _place,
              key: const ValueKey<String>('destination-confirm-chip'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
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

/// Faint straight line, the black arc drawn to [progress], the car ring at
/// [from] and the square destination pin with its stem at [to].
class DestinationArcPainter extends CustomPainter {
  DestinationArcPainter({
    required this.from,
    required this.to,
    required this.progress,
  });

  final Offset from;
  final Offset to;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0x55888E94)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Bulge sideways by a third of the distance, on the upper side.
    final delta = to - from;
    var normal = Offset(-delta.dy, delta.dx);
    if (normal.dy > 0) { normal = -normal; }
    final length = normal.distance;
    final control = Offset.lerp(from, to, 0.5)! +
        (length == 0 ? Offset.zero : normal / length * delta.distance * 0.32);
    final arc = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    if (progress > 0) {
      final metric = arc.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = const Color(0xFF111315)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Pin: stem up to the chip, small white square with a black edge.
    final ink = Paint()..color = const Color(0xFF111315);
    canvas.drawLine(to, to.translate(0, -46), ink..strokeWidth = 2.5);
    canvas.drawRect(Rect.fromCenter(center: to, width: 13, height: 13), ink);
    canvas.drawRect(Rect.fromCenter(center: to, width: 7, height: 7),
        Paint()..color = Colors.white);

    // Car: white disc, black ring, arrow.
    canvas.drawCircle(from, 16, Paint()..color = Colors.white);
    canvas.drawCircle(
      from,
      16,
      Paint()
        ..color = const Color(0xFF111315)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    final arrow = Path()
      ..moveTo(from.dx + 6, from.dy - 7)
      ..lineTo(from.dx - 6, from.dy + 7)
      ..lineTo(from.dx - 0.5, from.dy + 1.5)
      ..lineTo(from.dx + 1, from.dy + 7)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF111315));
  }

  @override
  bool shouldRepaint(DestinationArcPainter old) =>
      old.progress != progress || old.from != from || old.to != to;
}
