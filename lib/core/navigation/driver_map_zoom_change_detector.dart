/// Tracks actual SDK zoom changes without mistaking camera panning for zoom.
///
/// Capture every map frame (including GPS following), then report a change
/// only when the viewport already belongs to the driver. Native Google Maps
/// +/- controls do not generate a pinch or mouse-wheel event in Flutter.
class DriverMapZoomChangeDetector {
  DriverMapZoomChangeDetector({double? initialZoom}) : _lastZoom = initialZoom;

  // Baseline of the last *significant* manual zoom, not the last SDK frame.
  // Maps can emit many tiny zoom steps (<0.075) during a slow pinch; replacing
  // the baseline on every frame previously meant none were ever recognized.
  double? _lastZoom;

  bool observe(double zoom, {required bool browsing}) {
    if (!zoom.isFinite) return false;
    if (!browsing || _lastZoom == null) {
      // Programmatic GPS framing updates the baseline but never turns into
      // a manual zoom. The next physical gesture starts from that frame.
      _lastZoom = zoom;
      return false;
    }
    if ((zoom - _lastZoom!).abs() < 0.075) return false;
    _lastZoom = zoom;
    return true;
  }
}
