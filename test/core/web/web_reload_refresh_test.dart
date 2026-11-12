import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/web/web_reload.dart';

/// 2026-11-11 (owner "Yes, fix it", rider reload proof): GitHub Pages lets
/// the browser keep the app bundle for ten minutes, so a plain reload ran
/// the old bundle again and rejected the new screen part a second time. The
/// reload first downloads the app shell fresh into the browser cache.
void main() {
  final base = Uri.parse('https://example.org/Movera-driver-app/live/');
  String at(String file) => base.resolve(file).toString();

  test('the cache refresh finishes before the page reloads', () async {
    final calls = <String>[];
    final refreshDone = Completer<void>();
    final run = refreshThenReload(
      refresh: () {
        calls.add('refresh started');
        return refreshDone.future.then((_) => calls.add('refresh done'));
      },
      reload: () => calls.add('reload'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['refresh started'], reason: 'no reload before the refresh');
    refreshDone.complete();
    await run;
    expect(calls, ['refresh started', 'refresh done', 'reload']);
  });

  test('a slow refresh still reloads after the timeout', () async {
    var reloads = 0;
    final run = refreshThenReload(
      refresh: () => Completer<void>().future,
      reload: () => reloads += 1,
      timeout: const Duration(milliseconds: 50),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reloads, 0);
    await run;
    expect(reloads, 1);
    expect(webReloadRefreshTimeout, const Duration(seconds: 4));
  });

  test('a failed refresh (offline, blocked) still reloads', () async {
    var reloads = 0;
    await refreshThenReload(
      refresh: () => Future<void>.error(StateError('network')),
      reload: () => reloads += 1,
    );
    expect(reloads, 1);
  });

  test('wasm page: refreshes the bootstrap and the wasm bundle it ran', () {
    expect(
      webAppShellUrls(
        base,
        loaded: [
          at('flutter_bootstrap.js'),
          at('main.dart.mjs'),
          at('main.dart.wasm'),
          at('canvaskit/skwasm.wasm'),
        ],
      ).map((u) => u.toString()),
      [at('flutter_bootstrap.js'), at('main.dart.mjs'), at('main.dart.wasm')],
    );
  });

  test('JavaScript page: refreshes main.dart.js only', () {
    expect(
      webAppShellUrls(
        base,
        loaded: [at('flutter_bootstrap.js'), '${at('main.dart.js')}?v=1'],
      ).map((u) => u.toString()),
      [at('flutter_bootstrap.js'), at('main.dart.js')],
    );
  });

  test('nothing recorded: refreshes every bundle', () {
    expect(webAppShellUrls(base).map((u) => u.toString()), [
      at('flutter_bootstrap.js'),
      at('main.dart.js'),
      at('main.dart.mjs'),
      at('main.dart.wasm'),
    ]);
  });
}
