import 'package:movera/core/web/web_splash_io.dart'
    if (dart.library.js_interop) 'package:movera/core/web/web_splash_web.dart';

/// Tells the page that Flutter has painted, so the HTML boot screen can go.
void dismissWebSplash() => webDismissSplash();
