import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/widgets/custom_google_map.dart';

/// BQ-V44 (plan §8, contract `DriverBonus.polygon`): the campaign's own
/// area on a small, still map in its card — the app's map
/// ([CustomGoogleMap]) with the server's outline, fitted to it. It is
/// only a picture: no gestures, taps go through to the list.
class CampaignAreaMap extends StatefulWidget {
  const CampaignAreaMap({super.key, required this.area, this.height = 120});

  /// The server's outline, 3 or more points.
  final List<GeoPoint> area;
  final double height;

  /// The same orange family as the app's surge zones, a little lighter.
  static const Color edge = Color(0xFFFF8A3D);

  @override
  State<CampaignAreaMap> createState() => _CampaignAreaMapState();
}

class _CampaignAreaMapState extends State<CampaignAreaMap> {
  GoogleMapController? _controller;
  Timer? _fitTimer;

  @override
  void dispose() {
    _fitTimer?.cancel();
    super.dispose();
  }

  LatLngBounds get _bounds {
    final first = widget.area.first;
    var south = first.latitude, north = south;
    var west = first.longitude, east = west;
    for (final p in widget.area) {
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
    if (controller == null) return;
    // Let the map lay out first: fitting a map of no size throws.
    _fitTimer?.cancel();
    _fitTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      try {
        await controller.moveCamera(CameraUpdate.newLatLngBounds(_bounds, 16));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: IgnorePointer(
          child: CustomGoogleMap(
            initialPosition: CameraPosition(
              target: LatLng(
                (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
                (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
              ),
              zoom: 11,
            ),
            polygons: {
              Polygon(
                polygonId: const PolygonId('campaign-area'),
                points: [for (final p in widget.area) p.toLatLng()],
                fillColor: CampaignAreaMap.edge.withValues(alpha: 0.25),
                strokeColor: CampaignAreaMap.edge,
                strokeWidth: 2,
                geodesic: false,
                consumeTapEvents: false,
              ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            webCameraControlEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              _fit();
            },
          ),
        ),
      ),
    );
  }
}
