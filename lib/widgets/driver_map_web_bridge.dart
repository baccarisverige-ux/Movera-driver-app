import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('driverMapCamera')
external JSObject? get _adapter;

/// Maps JavaScript and web/driver_map_camera.js are installed. Before that
/// no map may be built and no adapter call made: either one throws, and a
/// throw while Home rebuilds drops its overlays (popup, offer cards) from
/// the frame while the map stays on screen.
bool get ready {
  final adapter = _adapter;
  if (adapter == null) return false;
  // An adapter without ready() only exists once installed.
  return !adapter.has('ready') ||
      adapter.callMethod<JSBoolean>('ready'.toJS).toDart;
}

@JS('driverMapCamera.anchor')
external void _anchor(JSNumber mapId);
@JS('driverMapCamera.claim')
external void _claim(JSNumber mapId);
@JS('driverMapCamera.vehicle')
external void _vehicle(JSNumber mapId, JSNumber heading);
@JS('driverMapCamera.configure')
external void _configure(
  JSNumber mapId,
  JSNumber top,
  JSNumber bottom,
  JSNumber anchor,
);
@JS('driverMapCamera.gestures')
external void _gestures(JSNumber mapId, JSBoolean enabled);
void gestures(int mapId, bool enabled) {
  if (ready) _gestures(mapId.toJS, enabled.toJS);
}

@JS('driverMapCamera.listen')
external JSFunction _listen(JSNumber mapId, JSFunction callback);
void applyAnchor(int mapId) {
  if (ready) _anchor(mapId.toJS);
}

/// The next programmatic pan is a follow frame: instant, then anchored once.
void claim(int mapId) {
  if (ready) _claim(mapId.toJS);
}

void vehicle(int mapId, double heading) {
  if (ready) _vehicle(mapId.toJS, heading.toJS);
}

void configure(int mapId, double top, double bottom, double anchor) {
  if (ready) _configure(mapId.toJS, top.toJS, bottom.toJS, anchor.toJS);
}

void Function() listen(int mapId, void Function() onGesture) {
  if (!ready) return () {};
  final remove = _listen(mapId.toJS, onGesture.toJS);
  return () => remove.callAsFunction();
}

@JS('driverMapCamera.supports3D')
external JSBoolean _supports3D(JSNumber mapId);
bool supports3D(int mapId) => ready && _supports3D(mapId.toJS).toDart;
@JS('driverMapCamera.listenRenderer')
external JSFunction _listenRenderer(JSNumber mapId, JSFunction callback);
void Function() listenRenderer(int mapId, void Function() onChanged) {
  if (!ready) return () {};
  final remove = _listenRenderer(mapId.toJS, onChanged.toJS);
  return () => remove.callAsFunction();
}
