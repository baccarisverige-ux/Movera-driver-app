import 'dart:typed_data';

bool get ready => true;
String? createBlobUrl(Uint8List bytes) => null;
void revokeBlobUrl(String url) {}
void applyAnchor(int mapId) {}
void claim(int mapId, {bool anchored = true, double? lead}) {}
void gestures(int mapId, bool enabled) {}
void tiltFollowsZoom(int mapId, bool enabled) {}
void vehicle(int mapId, double heading, double? accuracyMeters) {}
void configure(int mapId, double top, double bottom, double anchor) {}
void Function() listen(int mapId, void Function() onGesture) => () {};

bool supports3D(int mapId) => true;
void Function() listenRenderer(int mapId, void Function() onChanged) => () {};
