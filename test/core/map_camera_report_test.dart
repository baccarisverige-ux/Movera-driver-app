import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/navigation/map_camera_report.dart';
import 'package:movera/widgets/driver_route_style.dart';

/// Owner N6 (live test 2026-10-26): the web plugin's "no value yet"
/// report (zoom 0, centre 0,0) is not a camera frame.
void main() {
  const stockholm = LatLng(59.3326, 18.0649);

  test('a report with a zoom and a centre is a frame', () {
    expect(MapCameraReport.isFrame(const CameraPosition(target: stockholm, zoom: 16.4)), isTrue);
    expect(MapCameraReport.isFrame(const CameraPosition(target: stockholm, zoom: 3)), isTrue);
    expect(MapCameraReport.isFrame(const CameraPosition(target: LatLng(-33.9, 151.2), zoom: 12, bearing: 90, tilt: 45)), isTrue);
  });

  test('the plugin\'s zoom 0 and (0, 0) stand-ins are not', () {
    expect(MapCameraReport.isFrame(const CameraPosition(target: stockholm, zoom: 0)), isFalse);
    expect(MapCameraReport.isFrame(const CameraPosition(target: LatLng(0, 0), zoom: 16)), isFalse);
    expect(MapCameraReport.isFrame(const CameraPosition(target: stockholm, zoom: double.nan)), isFalse);
  });

  test('taken for a frame, zoom 0 would draw the thinnest route line', () {
    // The step the line width follows: what the gap would have done.
    expect(DriverRouteStyle.stepZoom(0), 10);
    expect(DriverRouteStyle.widthAt(0), 4);
    expect(DriverRouteStyle.widthAt(16.4), 10);
  });
}
