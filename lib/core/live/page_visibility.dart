import 'package:movera/core/live/page_visibility_io.dart'
    if (dart.library.js_interop) 'package:movera/core/live/page_visibility_web.dart'
    as impl;

/// Whether the app's page is on screen (`document.visibilityState` on the
/// web). A hidden tab gets throttled timers and a quiet geolocation watch,
/// so the location reporter must not keep passing its last fix off as new.
abstract class PageVisibility {
  /// True while the page is shown.
  bool get visible;

  /// The new [visible] value on each change.
  Stream<bool> get changes;

  /// The browser's page (web); null elsewhere (an app is always "visible":
  /// the phone's own background location mode keeps fixes coming).
  static PageVisibility? platform() => impl.platformPageVisibility();
}
