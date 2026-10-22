import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/presentation/driver/home/components/route_fade.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';
import 'package:movera/widgets/offer_route_marks.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/web_map_bitmap.dart';

/// driver-u174: on web, google_maps_flutter_web 0.5.14+2 turns a
/// BytesMapBitmap icon into a new Blob URL on every marker update and never
/// revokes it (its URL cache is cleared after each batch), so the live car,
/// pushed on almost every frame while driving, leaked one Blob URL and one
/// image reload per push. On web the car's pictures are now one Blob URL
/// each, made once, sent as a URL icon the plugin passes through.
///
/// This models the plugin's conversion of the icon on each update and
/// counts the Blob URLs made, with the URL factory injected (tests do not
/// run in a browser).
void main() {
  final created = <String>[];
  final revoked = <String>[];
  var pluginBlobs = 0;

  setUp(() {
    WebMapBitmaps.debugCreateUrl = (Uint8List png) {
      final url = 'blob:test/${created.length}';
      created.add(url);
      return url;
    };
    WebMapBitmaps.debugRevokeUrl = revoked.add;
  });

  /// What google_maps_flutter_web does with the icon of one update batch.
  String pluginUrlFor(BitmapDescriptor icon) => switch (icon) {
    AssetMapBitmap(:final assetName) => assetName,
    BytesMapBitmap() => 'blob:plugin/${pluginBlobs++}',
    _ => throw UnsupportedError('$icon'),
  };

  test('600 live-car pushes make one Blob URL, not one each', () async {
    await MoveraVehicleMarker.createIcon();
    final urls = <String>{};
    for (var push = 0; push < 600; push++) {
      // The marker keeps the icon createIcon gave it (the arrow and its
      // ring, one picture).
      urls.add(pluginUrlFor(MoveraVehicleMarker.icon!));
    }
    expect(pluginBlobs, 0);
    expect(urls, hasLength(1));
    expect(created, hasLength(1), reason: 'one picture: the arrow and ring');
    final icon = MoveraVehicleMarker.icon! as AssetMapBitmap;
    expect(icon.assetName, urls.single);
    expect(icon.width, MoveraVehicleMarker.box);
    expect(icon.height, MoveraVehicleMarker.box);

    // Released, the URL is revoked once.
    WebMapBitmaps.release();
    expect(revoked, unorderedEquals(created));
    WebMapBitmaps.release();
    expect(revoked, hasLength(1));
  });

  // driver-r4-21: each offer-route fade step re-sends the pins with a new
  // alpha, so bytes icons leaked a Blob URL per pin per step.
  test('a route fade re-sends the offer pins with one URL each', () async {
    OfferRouteMarks.debugClearCache();
    final markers = await OfferRouteMarks.markers(
      pickup: const LatLng(59.33, 18.06),
      dropoff: const LatLng(59.36, 18.00),
      pickupValue: '3 min',
      dropoffValue: '12 min',
      stops: const [LatLng(59.34, 18.04)],
    );
    final ids = {for (final m in markers) m.markerId};
    final fade = RouteFade();
    final urls = <String>{};
    final before = pluginBlobs;
    for (var step = 1; step < RouteFade.steps; step++) {
      fade.value = step / RouteFade.steps;
      urls.addAll(fade.markers(markers, ids).map((m) => pluginUrlFor(m.icon)));
    }
    expect(pluginBlobs, before);
    expect(urls, hasLength(3), reason: 'pickup, drop-off and the stop');
    final pickup = markers
        .firstWhere((m) => m.markerId.value == 'radar_pickup')
        .icon as AssetMapBitmap;
    expect(pickup.width, RouteMarkPins.labelledSize('Pickup', '3 min').width);
  });

  test('off web (no URL factory) the icon stays bytes', () {
    WebMapBitmaps.debugCreateUrl = null;
    expect(WebMapBitmaps.enabled, isFalse);
    expect(
      WebMapBitmaps.of(Uint8List(4), width: 10, height: 10),
      isNull,
    );
  });
}
