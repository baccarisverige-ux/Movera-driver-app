import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/movera_destination_marker.dart';

const String destinationModeMarkerId = 'destination_mode_target';

/// The one Destination-mode pin: Movera blue with a white square, painted
/// (not Google's default pin, which the web build shows red).
Marker destinationModeMarker(LatLng position, String address) => Marker(
  markerId: const MarkerId(destinationModeMarkerId),
  position: position,
  infoWindow: InfoWindow(title: address),
  icon: MoveraDestinationMarker.cachedPin ??
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
  anchor: MoveraDestinationMarker.pinAnchor,
  zIndexInt: 6,
);

/// What the Home map draws. An offer's pins and route are drawn only
/// while that offer is on screen ([offerOnScreen]), in every mode: a
/// preview left over from an offer that is gone is never drawn (R13-3).
/// With Destination mode on, the map shows only the car, the one
/// destination pin and the direct road route — unless an offer is up:
/// then that offer's preview replaces the destination layer, so
/// pickup/drop-off pins and their route never mix with the destination
/// route (which made it look like a loop through extra stops).
({Set<Marker> markers, Set<Polyline> polylines}) homeMapLayers({
  required Set<Marker> car,
  required bool destinationMode,
  required Set<Marker> destinationMarkers,
  required Set<Polyline> destinationPolylines,
  required Set<Marker> offerMarkers,
  required Set<Polyline> offerPolylines,
  required bool offerOnScreen,
}) {
  if (!offerOnScreen) {
    return (
      markers: {...car, ...destinationMarkers},
      polylines: destinationPolylines,
    );
  }
  if (destinationMode) {
    return (markers: {...car, ...offerMarkers}, polylines: offerPolylines);
  }
  return (
    markers: {...car, ...destinationMarkers, ...offerMarkers},
    polylines: {...destinationPolylines, ...offerPolylines},
  );
}
