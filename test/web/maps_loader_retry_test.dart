import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/widgets/custom_google_map.dart';

/// Finder C3 (driver part, as rider PR #549): web/index.html set
/// moveraGoogleMapsRequested before adding the Maps script and had no
/// onerror, so one failed load (a network switch, a tunnel) left every map
/// "unavailable" until the page was reloaded. The script's onerror now
/// frees the loader and removes the failed script, and a waiting map asks
/// the page again every 5 s.
void main() {
  test('a failed Maps script load lets the next ask load it again', () async {
    final run = await Process.run('node', [
      'test/web/maps_loader_retry_harness.js',
      'web/index.html',
    ]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    final out = jsonDecode(run.stdout as String) as Map<String, dynamic>;
    expect(out['scripts'], 2, reason: 'one script, then one after the error');
    expect(out['firstRemoved'], isTrue);
  });

  testWidgets('a map waiting for Maps asks the page again every 5 s', (
    tester,
  ) async {
    final probe = CustomGoogleMap.mapsReadyProbe;
    final request = CustomGoogleMap.requestMaps;
    var asks = 0;
    CustomGoogleMap.mapsReadyProbe = () => false;
    CustomGoogleMap.requestMaps = () => asks++;
    addTearDown(() {
      CustomGoogleMap.mapsReadyProbe = probe;
      CustomGoogleMap.requestMaps = request;
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CustomGoogleMap())),
    );
    expect(asks, 1, reason: 'the first ask on open');
    await tester.pump(const Duration(milliseconds: 4900));
    expect(asks, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(asks, 2);
    await tester.pump(const Duration(seconds: 5));
    expect(asks, 3);
    await tester.pumpWidget(const SizedBox());
  });
}
