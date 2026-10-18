import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One route-line look for every driver map (Home destination, direct offer
/// preview, trip to pickup/drop-off, reservation popup and full-screen map):
/// thick and black like Uber, a dark casing under a slightly lighter core.
abstract final class DriverRouteStyle {
  static const Color casingColor = Color(0xFF2A2D31);
  static const Color color = Color(0xFF45494F);

  /// Visible line width (the casing); the core sits inside it.
  static const int width = 20;
  static const int coreWidth = 14;

  /// The casing and core polylines for one route. The core keeps [id], so
  /// lookups by polyline id still find the route; the casing is `$id-casing`.
  static Set<Polyline> polylines({
    required String id,
    required List<LatLng> points,
    bool geodesic = false,
  }) => {
    Polyline(
      polylineId: PolylineId('$id-casing'),
      points: points,
      color: casingColor,
      width: width,
      geodesic: geodesic,
      zIndex: 1,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
    Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: coreWidth,
      geodesic: geodesic,
      zIndex: 2,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
  };
}
