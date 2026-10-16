bool get ready => true;
void applyAnchor(int mapId) {}
void claim(int mapId) {}
void gestures(int mapId, bool enabled) {}
void vehicle(int mapId, double heading) {}
void configure(int mapId, double top, double bottom, double anchor) {}
void Function() listen(int mapId, void Function() onGesture) => () {};

bool supports3D(int mapId) => true;
void Function() listenRenderer(int mapId, void Function() onChanged) => () {};
