import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/home.dart';

import 'check_log.dart';
import 'driver_steps.dart';
import 'recording_client.dart';

/// Owner 2026-11-12 ("can you check if screens change smoothly without any
/// bug and reload or any problem?"): every screen change of the trip is
/// watched and gets three checks:
///
/// * `TRANSITION:<name>:SMOOTH`  frame timings (engine FrameTiming) while
///   it runs: FAIL when one frame takes > [freezeMs] ms (build or raster: a
///   visible freeze) or, with at least [minFramesForRatio] frames, more
///   than [missedLimit] of the frames miss the 16.7 ms budget.
/// * `TRANSITION:<name>:RELOAD`  the app's GET reads are counted (shown
///   only); FAIL when a map the screen keeps is created again (a new
///   GoogleMap State object for the same screen; Home's map is compared
///   with the one Home had at the start), or when a full-screen loader
///   (a spinner centred in >= 60 % of the screen, not inside a button) or
///   a blank frame (no Scaffold at all) is seen.
/// * `TRANSITION:<name>:ERRORS`  FAIL on any 4xx/5xx or failed call the
///   app made, or a Flutter exception, while it ran.
///
/// The phone runs a DEBUG build (Flutter's JUnit runner tests the debug
/// variant), so the frame numbers are indicative: debug frames are slower
/// than release ones. Rows go to `transitions.json` and the job summary.
class TransitionWatch {
  TransitionWatch(this.tester, this.log, this.rec);

  static const int freezeMs = 200;
  static const double missedLimit = 0.20;
  static const int minFramesForRatio = 10;
  static const Duration _budget = Duration(microseconds: 16667);

  final WidgetTester tester;
  final CheckLog log;
  final RecordingClient rec;

  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];

  /// Home's map State ids when the watch started (the reload baseline).
  Set<int>? _homeBaseline;

  static String get buildMode => kDebugMode
      ? 'debug build, indicative'
      : kProfileMode
      ? 'profile build'
      : 'release build';

  /// GoogleMap State ids per screen ('home', 'trip', 'other'), offstage
  /// routes included (a covered Home keeps its map).
  Map<String, Set<int>> mapStates() {
    final out = <String, Set<int>>{};
    for (final e in find.byType(GoogleMap, skipOffstage: false).evaluate()) {
      if (e is! StatefulElement) continue;
      final owner = e.findAncestorWidgetOfExactType<AcceptRide>() != null
          ? 'trip'
          : e.findAncestorWidgetOfExactType<DriverHome>() != null
          ? 'home'
          : 'other';
      (out[owner] ??= <int>{}).add(identityHashCode(e.state));
    }
    return out;
  }

  /// Call once Home shows, before the first transition.
  void baseline() => _homeBaseline = mapStates()['home'];

  /// Runs [body] as the transition [name] and logs its three checks.
  /// [body]'s own result is returned; an exception in it is rethrown after
  /// the checks are logged.
  Future<T> run<T>(String name, Future<T> Function() body) async {
    final frames = <FrameTiming>[];
    void onTimings(List<FrameTiming> t) => frames.addAll(t);
    final mark = rec.length;
    final before = mapStates();
    var blank = 0, loader = 0;
    final previousProbe = pumpProbe;
    pumpProbe = () {
      previousProbe?.call();
      if (!shows(find.byType(Scaffold))) blank++;
      if (_fullScreenLoader()) loader++;
    };
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    try {
      return await body();
    } finally {
      // The engine hands timings over in batches: let the last ones come.
      await wait(tester, const Duration(milliseconds: 1200));
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      pumpProbe = previousProbe;
      final exceptions = <String>[];
      for (var i = 0; i < 5; i++) {
        final e = tester.takeException();
        if (e == null) break;
        exceptions.add(e.runtimeType.toString());
      }
      _report(
        name,
        frames,
        mark,
        before,
        mapStates(),
        blank,
        loader,
        exceptions,
      );
    }
  }

  bool _fullScreenLoader() {
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final area = screen.width * screen.height;
    for (final e in find.byType(CircularProgressIndicator).evaluate()) {
      var inButton = false;
      Size? box;
      e.visitAncestorElements((a) {
        final w = a.widget;
        if (w is ButtonStyleButton || w is InkWell || w is IconButton) {
          inButton = true;
          return false;
        }
        if (w is Center || w is Align) {
          final r = a.renderObject;
          if (r is RenderBox && r.hasSize) box = r.size;
          return false;
        }
        return true;
      });
      final b = box;
      if (!inButton && b != null && b.width * b.height >= 0.6 * area) {
        return true;
      }
    }
    return false;
  }

  void _report(
    String name,
    List<FrameTiming> frames,
    int mark,
    Map<String, Set<int>> before,
    Map<String, Set<int>> after,
    int blank,
    int loader,
    List<String> exceptions,
  ) {
    double ms(Duration d) => d.inMicroseconds / 1000.0;
    var missed = 0;
    var worst = 0.0;
    for (final f in frames) {
      final build = f.buildDuration, raster = f.rasterDuration;
      if (build > _budget || raster > _budget) missed++;
      final w = ms(build) > ms(raster) ? ms(build) : ms(raster);
      if (w > worst) worst = w;
    }
    final ratio = frames.isEmpty ? 0.0 : missed / frames.length;
    final smooth =
        worst <= freezeMs &&
        (frames.length < minFramesForRatio || ratio <= missedLimit);

    final calls = rec.since(mark);
    final gets = calls.where((c) => c.method == 'GET' && !c.isBackground);
    final perPath = <String, int>{};
    for (final c in gets) {
      perPath[c.path] = (perPath[c.path] ?? 0) + 1;
    }
    final recreated = <String>[
      for (final owner in before.keys)
        if (after.containsKey(owner) &&
            after[owner]!.intersection(before[owner]!).isEmpty)
          owner,
      if (_homeBaseline case final home?)
        if (after['home'] case final now?)
          if (now.intersection(home).isEmpty && !before.containsKey('home'))
            'home (Home came back with a new map)',
    ];
    final failed = <String>[
      for (final c in calls)
        if (c.failed) '$c',
    ];

    final smoothDetail =
        'frames=${frames.length} missed=$missed '
        '(${(ratio * 100).toStringAsFixed(0)}%) worst=${worst.toStringAsFixed(1)} ms '
        '[FAIL above $freezeMs ms or ${(missedLimit * 100).round()}% missed '
        'with >= $minFramesForRatio frames; $buildMode]';
    final reloadDetail =
        'GET reads=${gets.length} $perPath; maps before=${_ids(before)} '
        'after=${_ids(after)} recreated=$recreated; full-screen loader '
        'samples=$loader blank samples=$blank';
    final errorDetail =
        'calls=${calls.length} failed=$failed exceptions=$exceptions';
    final reloadOk = recreated.isEmpty && loader == 0 && blank == 0;
    final errorsOk = failed.isEmpty && exceptions.isEmpty;

    void check(String kind, bool ok, String title, String detail) {
      final id = 'TRANSITION:$name:$kind';
      ok ? log.pass(id, title, detail) : log.fail(id, title, detail);
    }

    check('SMOOTH', smooth, 'screen change has no freeze', smoothDetail);
    check('RELOAD', reloadOk, 'screen change does not reload', reloadDetail);
    check('ERRORS', errorsOk, 'screen change has no error', errorDetail);
    rows.add(<String, Object?>{
      'name': name,
      'frames': frames.length,
      'missed': missed,
      'worstMs': double.parse(worst.toStringAsFixed(1)),
      'gets': gets.length,
      'recreatedMaps': recreated,
      'loaderSamples': loader,
      'blankSamples': blank,
      'failedCalls': failed,
      'exceptions': exceptions,
      'smooth': smooth,
      'reload': !reloadOk,
      'errors': !errorsOk,
      'build': buildMode,
    });
  }

  static Map<String, int> _ids(Map<String, Set<int>> maps) => {
    for (final MapEntry(:key, :value) in maps.entries) key: value.length,
  };
}
