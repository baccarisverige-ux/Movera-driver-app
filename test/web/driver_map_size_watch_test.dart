// Grey band (port of rider PR #559): Maps JS 3.66 measures its element only
// when its hidden size frame fires 'load' or its window fires 'resize'
// (trigger(map, 'resize') does nothing). When an iPhone misses those after
// the map's box grows, Google keeps drawing the old height and a flat grey
// band shows below the tiles. web/driver_map_camera.js watches each map's
// element and runs Google's own measuring once its size changes. Owner
// decision 1 (no flying camera): the watch never moves the camera.
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
  final skip = _hasNode() ? false : 'node is not installed';

  Future<Map<String, dynamic>> runHarness() async {
    final run = await Process.run('node', [
      'test/web/driver_map_size_watch_harness.js',
      'web/driver_map_camera.js',
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    return jsonDecode(run.stdout as String) as Map<String, dynamic>;
  }

  test('driver map: a map element that grows is measured again by Google '
      'without a zoom (no grey band)', () async {
    final out = await runHarness();
    expect(out['watched'], isTrue, reason: "each map's element is watched");
    expect(out['firstSize'], 555);
    expect(
      out['grownSize'],
      844,
      reason: 'Google must draw the grown element, not its old 555 px',
    );
  }, skip: skip);

  test('driver map size watch: one measure per frame, none at 0 x 0, and the '
      'camera is never moved (no flight)', () async {
    final out = await runHarness();
    expect(out['measuredSync'], 0, reason: 'waits for the next frame');
    expect(out['measuresForGrow'], 1, reason: 'three reports, one measure');
    expect(out['measuresWhenHidden'], 0);
    expect(out['cameraCalls'], {
      'moves': 0,
      'pans': 0,
      'centers': 0,
      'zooms': 0,
    });
    expect(out['cameraKept'], isTrue);
  }, skip: skip);

  test('driver map size watch: a new frame window whose load never fired is '
      'still measured, and the watch is disconnected on dispose', () async {
    final out = await runHarness();
    expect(out['newWindowSize'], 621);
    expect(out['disposedWatchDisconnected'], isTrue);
  }, skip: skip);
}
