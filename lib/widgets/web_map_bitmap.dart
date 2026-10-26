import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'driver_map_web_bridge_stub.dart'
    if (dart.library.js_interop) 'driver_map_web_bridge.dart'
    as web;

/// Web: map icons drawn at run time, as one stable URL per picture.
///
/// google_maps_flutter_web turns a [BytesMapBitmap] into a new Blob URL on
/// every marker update and never revokes it (driver-u174). The live car is
/// updated on almost every frame while driving, so each push leaked a Blob
/// holding the PNG and made the page load the image again. Here each
/// picture gets one Blob URL, made once, and the icon is an
/// [AssetMapBitmap] with that URL, which the plugin uses as it is.
///
/// The URLs are shared by every map on the page (Home and the trip show the
/// same car at once), so no map revokes them when it goes; there is one per
/// picture for the page's lifetime. [release] revokes them all.
abstract final class WebMapBitmaps {
  /// Tests: makes the URL for a picture instead of the browser.
  @visibleForTesting
  static String? Function(Uint8List png)? debugCreateUrl;

  /// Tests: revokes a URL instead of the browser.
  @visibleForTesting
  static void Function(String url)? debugRevokeUrl;

  static final Map<Uint8List, String> _urls =
      LinkedHashMap<Uint8List, String>.identity();

  /// True where icons go to the map as URLs (web).
  static bool get enabled => debugCreateUrl != null || kIsWeb;

  /// [png] as a [width] x [height] icon with its one URL; null off web (or
  /// when no URL could be made), where the caller sends the bytes.
  static BitmapDescriptor? of(
    Uint8List png, {
    required double width,
    required double height,
  }) {
    if (!enabled) return null;
    final url = _urls[png] ??= (debugCreateUrl ?? web.createBlobUrl)(png) ?? '';
    if (url.isEmpty) {
      _urls.remove(png);
      return null;
    }
    return AssetMapBitmap(url, width: width, height: height);
  }

  /// Revokes every URL made here. Icons built from them stop loading.
  static void release() {
    final revoke = debugRevokeUrl ?? web.revokeBlobUrl;
    for (final url in _urls.values) {
      revoke(url);
    }
    _urls.clear();
  }
}
