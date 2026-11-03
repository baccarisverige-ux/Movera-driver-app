import 'dart:js_interop';

@JS('moveraAppReady')
external JSFunction? get _appReady;

/// Signals index.html that the first frame is up.
///
/// The boot screen is plain HTML, so it paints in milliseconds while the
/// app bundle is still downloading and compiling. Only Dart knows when there is
/// real UI behind it, which is why the page waits to be told rather than
/// guessing with a timer.
void webDismissSplash() {
  try {
    _appReady?.callAsFunction();
  } catch (_) {
    // A missing hook must never take the app down: the page's own fallback
    // timer clears the boot screen.
  }
}
