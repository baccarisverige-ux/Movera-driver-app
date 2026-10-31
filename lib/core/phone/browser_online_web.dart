import 'package:web/web.dart' as web;

/// The browser's `navigator.onLine`: false means surely no network.
bool? browserOnline() {
  try {
    return web.window.navigator.onLine;
  } catch (_) {
    return null;
  }
}
