import 'package:movera/widgets/owned_route_exit.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:movera/widgets/route_mark_pins.dart';

/// Points the reservation passes through, in order: pickup, stops, drop-off.
List<GeoPoint> reservationWaypoints(ReservationRequestPreview request) => [
  request.pickup,
  for (final stop in request.stops) stop.point,
  request.dropoff,
];

/// Road route through every waypoint, one leg at a time. Falls back to
/// straight lines between the waypoints when routing is off or fails.
Future<List<GeoPoint>> loadReservationRoute(
  ReservationRequestPreview request,
  RouteRepository? routes,
) async {
  final waypoints = reservationWaypoints(request);
  if (routes == null || !DriverRuntimeConfig.current.externalRouting) {
    return waypoints;
  }
  try {
    final points = <GeoPoint>[];
    for (var i = 0; i < waypoints.length - 1; i++) {
      final leg = await routes.drivingRoute(
        origin: waypoints[i],
        destination: waypoints[i + 1],
      );
      if (leg.points.length < 2) {
        return waypoints;
      }
      points.addAll(i == 0 ? leg.points : leg.points.skip(1));
    }
    return points;
  } catch (_) {
    return waypoints;
  }
}

/// Opens the full route screen of [request] (the Home reservation popup
/// and the Reservation details screen share it). Without [route] the road
/// route loads here. Back returns to the screen that opened it.
void openReservationRoute(
  BuildContext context,
  ReservationRequestPreview request, {
  Future<List<GeoPoint>>? route,
  Widget Function(BuildContext context, List<GeoPoint> route)? mapBuilder,
}) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  var roadRoute = route;
  if (roadRoute == null) {
    final routes = DriverRuntimeConfig.current.externalRouting
        ? RoadRouteService()
        : null;
    roadRoute = loadReservationRoute(request, routes);
    if (routes != null) {
      unawaited(roadRoute.whenComplete(routes.dispose));
    }
  }
  final opened = roadRoute;
  pushSingle(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReservationRouteMapPage(
        request: request,
        route: opened,
        mapBuilder: mapBuilder,
      ),
    ),
  );
}

/// Live map of a reservation: route line and classic marks. With
/// [labelled], the marks carry bubbles: pickup time, stop number and
/// arrival time.
class ReservationRouteMap extends StatefulWidget {
  const ReservationRouteMap({
    super.key,
    required this.request,
    required this.route,
    this.labelled = false,
    this.padding = EdgeInsets.zero,
    this.fitPadding = 28,
    this.interactive = false,
    this.markerIcon,
    this.show3DNotice = true,
    this.tilt = 0,
    this.routeColor,
  });

  final ReservationRequestPreview request;
  final List<GeoPoint> route;
  final bool labelled;

  /// Area covered by other UI; the map keeps the route out of it.
  final EdgeInsets padding;

  /// Space between the route and the visible map edge.
  final double fitPadding;
  final bool interactive;
  final Future<BitmapDescriptor> Function(RouteMarkKind, String, String?)?
  markerIcon;

  /// The "2D map · 3D unavailable" note; off on the small popup map.
  final bool show3DNotice;

  /// Camera tilt in degrees after fitting the route; 0 keeps it flat.
  final double tilt;

  /// Route line colour; null keeps [DriverRouteStyle.color].
  final Color? routeColor;

  @override
  State<ReservationRouteMap> createState() => _ReservationRouteMapState();
}

class _ReservationRouteMapState extends State<ReservationRouteMap> {
  Set<Marker> _markers = const {};
  GoogleMapController? _controller;
  int _markerGeneration = 0;
  Timer? _fitTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_buildMarkers());
  }

  @override
  void didUpdateWidget(covariant ReservationRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request ||
        oldWidget.labelled != widget.labelled ||
        oldWidget.markerIcon != widget.markerIcon) {
      unawaited(_buildMarkers());
    }
    if (oldWidget.route != widget.route ||
        oldWidget.request != widget.request ||
        oldWidget.padding != widget.padding ||
        oldWidget.fitPadding != widget.fitPadding) {
      _fit();
    }
  }

  Future<void> _buildMarkers() async {
    final generation = ++_markerGeneration;
    final request = widget.request;
    final labelled = widget.labelled;
    final markerIcon = widget.markerIcon;
    final markers = <Marker>{};
    Future<bool> add(
      String id,
      GeoPoint point,
      RouteMarkKind kind,
      String title,
      String? time,
    ) async {
      BitmapDescriptor icon;
      try {
        icon = markerIcon != null
            ? await markerIcon(kind, title, time)
            : labelled
            ? await RouteMarkPins.labelled(kind, title, time)
            : await RouteMarkPins.mark(kind);
      } catch (_) {
        icon = BitmapDescriptor.defaultMarker;
      }
      if (!mounted || generation != _markerGeneration) return false;
      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: point.toLatLng(),
          icon: icon,
          anchor: labelled
              ? RouteMarkPins.labelledAnchor(title, time)
              : const Offset(0.5, 0.5),
          zIndexInt: kind == RouteMarkKind.stop ? 1 : 2,
        ),
      );
      return true;
    }

    if (!await add(
      'reservation-pickup',
      request.pickup,
      RouteMarkKind.pickup,
      'Pickup',
      request.pickupTime,
    )) {
      return;
    }
    for (var i = 0; i < request.stops.length; i++) {
      if (!await add(
        'reservation-stop-$i',
        request.stops[i].point,
        RouteMarkKind.stop,
        'Stop ${i + 1}',
        null,
      )) {
        return;
      }
    }
    if (!await add(
      'reservation-dropoff',
      request.dropoff,
      RouteMarkKind.dropoff,
      'Arrive',
      request.arrivalTime,
    )) {
      return;
    }
    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  LatLngBounds _bounds() {
    final points = [...widget.route, ...reservationWaypoints(widget.request)];
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _fit() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    // Let the map lay out before fitting; fitting a 0-size map throws.
    _fitTimer?.cancel();
    _fitTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }
      try {
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(_bounds(), widget.fitPadding),
        );
        if (widget.tilt > 0 && mounted) {
          final b = _bounds();
          final zoom = await controller.getZoomLevel();
          await controller.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(
                  (b.southwest.latitude + b.northeast.latitude) / 2,
                  (b.southwest.longitude + b.northeast.longitude) / 2,
                ),
                zoom: zoom,
                tilt: widget.tilt,
              ),
            ),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _markerGeneration++;
    _fitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bounds();
    return CustomGoogleMap(
      initialPosition: CameraPosition(
        target: LatLng(
          (b.southwest.latitude + b.northeast.latitude) / 2,
          (b.southwest.longitude + b.northeast.longitude) / 2,
        ),
        zoom: 12,
        tilt: widget.tilt,
      ),
      markers: _markers,
      polylines: {
        Polyline(
          polylineId: const PolylineId('reservation-route'),
          points: [for (final p in widget.route) p.toLatLng()],
          color: widget.routeColor ?? DriverRouteStyle.color,
          width: DriverRouteStyle.width,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      },
      padding: widget.padding,
      myLocationEnabled: false,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      webCameraControlEnabled: false,
      show3DNotice: widget.show3DNotice,
      onMapCreated: (controller) {
        _controller = controller;
        _fit();
      },
    );
  }
}

/// Full-screen route of a reservation request, opened from the popup's map.
class ReservationRouteMapPage extends StatelessWidget {
  const ReservationRouteMapPage({
    super.key,
    required this.request,
    required this.route,
    this.mapBuilder,
  });

  final ReservationRequestPreview request;
  final Future<List<GeoPoint>> route;

  /// Replaces the live map, for tests and previews.
  final Widget Function(BuildContext context, List<GeoPoint> route)? mapBuilder;

  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF5E6461);
  static const Color _line = Color(0xFFE4E6E5);

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE6EAED),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The details card covers roughly the lower third.
          final cardHeight = math.min(
            150.0 + request.stops.length * 44 + safe.bottom,
            constraints.maxHeight * .55,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<List<GeoPoint>>(
                  key: ValueKey(route),
                  future: route,
                  initialData: reservationWaypoints(request),
                  builder: (context, snapshot) {
                    final points =
                        snapshot.data ?? reservationWaypoints(request);
                    return mapBuilder?.call(context, points) ??
                        ReservationRouteMap(
                          request: request,
                          route: points,
                          labelled: true,
                          interactive: true,
                          fitPadding: 64,
                          padding: EdgeInsets.only(
                            top: safe.top + 64,
                            bottom: cardHeight,
                          ),
                        );
                  },
                ),
              ),
              Positioned(
                left: 16,
                top: safe.top + 12,
                child: MapControlButton(
                  key: const ValueKey<String>('reservation-map-close'),
                  tooltip: 'Back to request',
                  size: 48,
                  onTap: () => maybePopOwned(context),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _ink,
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: safe.bottom + 12,
                child: ConstrainedBox(
                  key: const ValueKey('reservation-route-details'),
                  constraints: BoxConstraints(maxHeight: cardHeight),
                  child: SingleChildScrollView(child: _details()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _details() {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0xFF172027).withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '${request.pickupDay} · ${request.category}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                Text(
                  '${request.tripMinutes} min · ${request.tripKm.toStringAsFixed(request.tripKm < 10 ? 1 : 0)} km',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(
              RouteMarkKind.pickup,
              'Pickup',
              request.pickupAddress,
              request.pickupTime,
            ),
            for (var i = 0; i < request.stops.length; i++) ...[
              _connector(),
              _row(
                RouteMarkKind.stop,
                'Stop ${i + 1}',
                request.stops[i].address,
                null,
              ),
            ],
            _connector(),
            _row(
              RouteMarkKind.dropoff,
              'Drop-off',
              request.dropoffAddress,
              request.arrivalTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _connector() => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(width: 2, height: 12, color: _line),
    ),
  );

  Widget _row(RouteMarkKind kind, String label, String address, String? time) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _MarkPainter(kind)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
              Text(
                address,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (time != null)
          Text(
            time,
            style: const TextStyle(
              color: _ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.kind);

  final RouteMarkKind kind;

  @override
  void paint(Canvas canvas, Size size) =>
      RouteMarkPins.paintMark(canvas, size.center(Offset.zero), kind);

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
