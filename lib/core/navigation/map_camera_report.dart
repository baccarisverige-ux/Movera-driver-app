import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show CameraPosition;

/// Which camera reports are camera frames (owner N6, live test 2026-10-26).
///
/// google_maps_flutter_web (0.5.14+2, `convert.dart`
/// `_gmViewportToCameraPosition`) builds every `onCameraMove` report from
/// Maps JavaScript's getters and puts **0** where Maps has no value yet:
/// zoom 0 when `getZoom()` is undefined, the centre (0, 0) when
/// `getCenter()` is. A driver map never shows zoom 0 (the web gestures
/// keep it in 3–21, the follow in the policy's zooms) nor the Gulf of
/// Guinea, so such a report is a gap, not a frame. Taken for one it
/// would set the route line to its thinnest step (`stepZoom(0)` = 10),
/// make the camera's logical pose zoom 0 (the next recenter then flies
/// in from a world view) and count as a hand zoom for the zoom detector.
abstract final class MapCameraReport {
  /// True when [position] carries a zoom and a centre.
  static bool isFrame(CameraPosition position) {
    if (!position.zoom.isFinite || position.zoom <= 0) return false;
    final target = position.target;
    if (!target.latitude.isFinite || !target.longitude.isFinite) return false;
    return target.latitude != 0 || target.longitude != 0;
  }
}
