import 'package:movera/core/web/web_reload_io.dart'
    if (dart.library.js_interop) 'package:movera/core/web/web_reload_web.dart';

/// Reloads the page so it picks up the newest published app, at most once
/// per [webReloadGuard]. Returns true when the reload has started (the page
/// is going away); false on phones, when offline, or when a reload already
/// ran in the last [webReloadGuard] (no reload loop).
bool reloadPageForNewVersion() => webReloadPageOnce();

/// Reloads the page now (the person pressed Retry). Returns false on phones
/// and when offline, where reloading would only show the browser's own
/// error page.
bool reloadPageNow() => webReloadPageNow();

/// The shortest time between two automatic reloads.
const Duration webReloadGuard = Duration(minutes: 5);

/// The longest wait for the fresh app shell before the page reloads anyway.
const Duration webReloadRefreshTimeout = Duration(seconds: 4);

/// The app bundles. GitHub Pages serves them under fixed names with
/// `max-age=600`, so a plain reload can run the old ones from the browser
/// cache (rider reload proof 2026-11-11). The live build is `--wasm`:
/// browsers with WasmGC run main.dart.mjs + main.dart.wasm, the others
/// main.dart.js.
const List<String> webAppBundleFiles = [
  'main.dart.js',
  'main.dart.mjs',
  'main.dart.wasm',
];

/// The app shell files to download fresh, resolved against the page's base
/// href: flutter_bootstrap.js (it picks the bundle) and the bundles this page
/// ran ([loaded]: the page's resource URLs). When none is recorded, every
/// bundle, so the reload never runs a stale one.
List<Uri> webAppShellUrls(Uri base, {Iterable<String> loaded = const []}) {
  final loadedPaths = {for (final url in loaded) Uri.tryParse(url)?.path};
  final bundles = [for (final file in webAppBundleFiles) base.resolve(file)];
  final ran = bundles.where((u) => loadedPaths.contains(u.path)).toList();
  return [
    base.resolve('flutter_bootstrap.js'),
    ...(ran.isEmpty ? bundles : ran),
  ];
}

/// Waits for [refresh] (the fresh download of the app shell into the browser
/// cache), at most [timeout], then calls [reload]. A failed or slow refresh
/// still reloads: the page is no worse off than a plain reload.
Future<void> refreshThenReload({
  required Future<void> Function() refresh,
  required void Function() reload,
  Duration timeout = webReloadRefreshTimeout,
}) async {
  try {
    await refresh().timeout(timeout);
  } catch (_) {
    // Offline, blocked or slow: reload with what the cache has.
  }
  reload();
}
