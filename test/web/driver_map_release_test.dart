// Q3 (owner 2026-11-07, "Free each map, no reuse (Recommended)"): each
// driver web map gives its WebGL context and its DOM back when its screen
// closes. Finding C1 (plan/finders-2026-11-07/C.md): web/driver_map_camera.js
// only cleared its own JS state, so every trip left one vector map behind,
// and Safari keeps about 16 WebGL contexts per page.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  test('Q3: 6 map screens opened and closed leave no live WebGL context, '
      'no map DOM and no live map state behind', () async {
    final run = await Process.run('node', [
      'test/web/driver_map_release_harness.js',
      'web/driver_map_camera.js',
      '6',
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    final out = jsonDecode(run.stdout as String) as Map<String, dynamic>;
    expect(out['contexts'], 6, reason: 'one WebGL context per map');
    expect(out['liveContexts'], 0, reason: 'WEBGL_lose_context on each');
    expect(
      out['releasedUnmarked'],
      0,
      reason: 'restart_watch must not report a context given back on purpose',
    );
    expect(out['divsWithMapDom'], 0, reason: "Google's DOM is dropped");
    expect(out['listenersCleared'], 6, reason: 'clearInstanceListeners');
    expect(out['jsStatesLeft'], 0);
  }, skip: _hasNode() ? false : 'node is not installed');
}
