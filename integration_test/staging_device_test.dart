import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

import 'staging/check_log.dart';
import 'staging/driver_steps.dart';
import 'staging/session.dart';

/// Owner 2026-11-12 ("U need find problems! So whats the point of test"):
/// a real-phone run of the LIVE staging build (Firebase Test Lab,
/// `--type instrumentation`, .github/workflows/android-test-apk.yml), that
/// signs in with one test driver and checks what the Robo run could not:
///
/// * SIGN-IN  the test driver reaches Home through the real screens.
/// * ONLINE   Go online is taken by the server (`POST /driver/availability`).
/// * G24      position sends go out and the server takes them
///            (`POST /driver/location` 2xx with `accepted` >= 1, and the
///            server's own profile shows a fresh `lastFixAt`).
/// * G17      the safety screen's emergency numbers are the server's numbers
///            for the zone the phone is in, and the app asked the config
///            for that zone (`?zoneId=`).
/// * G27-ERR  Home -> menu pages -> Back, several times: no failed call.
/// * G27-RE   after each Back to Home, no resource is read again more than
///            once and at most [_maxReadsAfterBack] reads in total.
/// * OFFLINE  Go offline at the end is taken by the server.
///
/// The phone number and the code come ONLY at run time
/// (MainActivityTest copies the instrumentation arguments into this
/// process's environment); nothing is built into the APK
/// (test/widget/a12_no_test_numbers_test.dart). They are never printed,
/// and no screenshot is taken on a screen that shows the number.

/// G27 budget: reads Home may make in [_settleAfterBack] after one Back.
const int _maxReadsAfterBack = 3;
const Duration _settleAfterBack = Duration(seconds: 4);

/// G24: how long the phone stays online before the server is asked.
const Duration _onlineWindow = Duration(seconds: 35);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final phone = tlEnv('MOVERA_TL_PHONE');
  final code = tlEnv('MOVERA_TL_CODE');
  final live = DriverRuntimeConfig.current.authRequired;
  const name =
      'staging device checks (sign-in, online, G24, G17, G27, offline)';

  // Run 6 (2026-11-12): a test that times out (or hangs) is recorded
  // nowhere by the integration_test binding (JUnit "OK (0 tests)"). This
  // tear-down runs before the binding's own (last-in-first-out) and makes
  // it 1 test, 1 failure.
  var bodyDone = false;
  var bodyStarted = false;
  tearDownAll(() {
    if (bodyStarted && !bodyDone && binding.results[name] is! Failure) {
      binding.results[name] = Failure(
        name,
        'test body did not finish (timeout or hang)',
      );
    }
  });

  final String? skipReason = !live
      ? 'not a live build (MOVERA_AUTH_REQUIRED is off)'
      : phone == null || code == null
      ? 'no test number at run time (the workflow passes it from the '
            'MOVERA_TEST_NUMBERS secret; Test Lab --environment-variables)'
      : null;

  if (skipReason != null) {
    testWidgets('staging device checks SKIPPED: $skipReason', (tester) async {
      CheckLog.say('SKIP all checks: $skipReason');
    });
    return;
  }

  testWidgets(name, (tester) async {
    bodyStarted = true;
    final log = CheckLog(
      binding: binding,
      outDir: tlEnv('MOVERA_TL_OUT'),
      shots: tlEnv('MOVERA_TL_SHOTS') != '0',
    );
    final run = _Run(tester, log);
    try {
      await run.start();
      await run.all(phone: phone!, code: code!);
    } finally {
      await log.write(requestLog: [for (final c in run.rec.calls) '$c']);
      log.end();
    }
    final failed = log.failures;
    expect(
      failed,
      isEmpty,
      reason: [
        for (final f in failed) '${f.id} (${f.title}): ${f.detail}',
      ].join('\n'),
    );
    bodyDone = true;
  }, timeout: const Timeout(Duration(minutes: 8)));
}

class _Run extends StagingSession {
  _Run(super.tester, super.log);

  Future<void> all({required String phone, required String code}) async {
    log.step('sign in (server ${base.host})');
    final signInError = await guard(
      () => signIn(tester, phone: phone, code: code),
    );
    if (signInError != null) {
      log.fail('SIGN-IN', 'test driver reaches Home', signInError);
      for (final id in ['ONLINE', 'G24', 'G17', 'G27-ERR', 'G27-RE']) {
        log.skip(id, 'needs sign-in', 'not run: sign-in failed');
      }
      return;
    }
    log.pass('SIGN-IN', 'test driver reaches Home', 'Home is open');
    await wait(tester, const Duration(seconds: 3));
    await log.screenshot(tester, 'home-offline');

    try {
      await goOnline();
      if (online) {
        await _checkLocation();
      } else {
        log.skip('G24', 'position sends', 'not run: not online');
      }
      await _checkEmergencyNumbers();
      await _checkNavigation();
    } catch (error, stack) {
      log.fail('RUN', 'checks ran to the end', 'stopped by $error');
      CheckLog.say('STACK ${stack.toString().split('\n').take(6).join(' | ')}');
    } finally {
      await goOfflineAtEnd();
    }
  }

  Future<void> _checkLocation() async {
    log.step('stay online ${_onlineWindow.inSeconds} s (G24)');
    final mark = rec.length;
    await wait(tester, _onlineWindow);
    final sends = calls(
      '/api/v1/driver/location',
      method: 'POST',
      from: mark,
    ).toList();
    final ok = sends.where((c) => !c.failed && c.status != null).toList();
    final bad = sends.where((c) => c.failed).toList();
    var accepted = 0;
    DateTime? lastServerTime;
    var outside = false;
    for (final c in ok) {
      final a = c.answer;
      if (a is Map) {
        accepted += (a['accepted'] as num?)?.toInt() ?? 0;
        lastServerTime =
            DateTime.tryParse('${a['serverTime']}') ?? lastServerTime;
        if (a['outsideArea'] == true) outside = true;
      }
    }
    final (status, profile) = await ask('/api/v1/driver/profile');
    final lastFix = profile is Map
        ? DateTime.tryParse('${profile['lastFixAt']}')
        : null;
    final serverOnline = profile is Map ? profile['onlineStatus'] : null;
    final reference = lastServerTime ?? DateTime.now().toUtc();
    final fixAge = lastFix == null
        ? null
        : reference.difference(lastFix).inSeconds;
    final detail =
        'sends=${sends.length} ok=${ok.length} failed='
        '${bad.map((c) => c.status ?? c.error).toList()} accepted=$accepted '
        'profile=$status onlineStatus=$serverOnline '
        'lastFixAge=${fixAge ?? 'none'}s outsideArea=$outside';
    final good =
        ok.length >= 2 &&
        bad.isEmpty &&
        accepted >= 1 &&
        status == 200 &&
        serverOnline == 'online' &&
        fixAge != null &&
        fixAge <= 45;
    if (good) {
      log.pass('G24', 'position sends are taken by the server', detail);
    } else {
      log.fail(
        'G24',
        'position sends are taken by the server',
        '$detail (want >= 2 sends, all 2xx, accepted >= 1, server online '
            'with a fix <= 45 s old)',
      );
    }
  }

  /// The zone holding the phone's position, from the server's zone list
  /// the app read (smallest city zone that holds it).
  String? _zoneHere() {
    final zones = LiveDriverZones.parse(rec.lastAnswer['/api/v1/driver/zones']);
    if (zones == null) return null;
    final holding =
        zones.where((z) => !z.isAirport && z.contains(lat, lng)).toList()
          ..sort((a, b) => a.area.compareTo(b.area));
    return holding.isEmpty ? null : holding.first.id;
  }

  Future<void> _checkEmergencyNumbers() async {
    const title = 'SOS numbers = the server\'s numbers for this zone';
    log.step('safety screen (G17)');
    var zone = _zoneHere();
    if (zone == null) {
      final (_, z) = await ask('/api/v1/driver/zones');
      rec.lastAnswer['/api/v1/driver/zones'] = z;
      zone = _zoneHere();
    }
    if (zone == null) {
      log.fail('G17', title, 'no server zone holds the test position');
      return;
    }
    final (status, config) = await ask('/api/v1/driver/config', {
      'zoneId': zone,
    });
    final served = <String>[
      if (config is Map && config['emergencyNumbers'] is List)
        for (final row in config['emergencyNumbers'] as List)
          if (row is Map && row['number'] is String) row['number'] as String,
    ];
    final askedZones = calls(
      '/api/v1/driver/config',
      method: 'GET',
    ).map((c) => c.zoneId).toSet();

    final button = byKey('home-safety-button');
    if (!await pumpUntil(tester, () => shows(button))) {
      log.fail('G17', title, 'no safety button on Home');
      return;
    }
    final ink = find.descendant(of: button, matching: find.byType(InkWell));
    if (shows(ink)) {
      tester.widget<InkWell>(ink.first).onTap?.call();
    } else {
      await tester.tap(button, warnIfMissed: false);
    }
    final opened = await pumpUntil(
      tester,
      () => shows(find.byType(SafetyToolKits)),
      timeout: const Duration(seconds: 10),
    );
    if (!opened) {
      log.fail('G17', title, 'the safety screen did not open');
      return;
    }
    await wait(tester, const Duration(seconds: 2));
    final shown = <String>[
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'safety-call-',
                    ),
              )
              .evaluate())
        (e.widget.key! as ValueKey<String>).value.substring(
          'safety-call-'.length,
        ),
    ];
    await log.screenshot(tester, 'safety');
    // Ordered compare: the contract orders the emergency numbers, so the
    // app must show them in the server's order. The detail says whether a
    // difference is only the order or the numbers themselves.
    final sameOrder = listEquals(shown, served);
    final sameSet =
        shown.length == served.length &&
        shown.toSet().containsAll(served) &&
        served.toSet().containsAll(shown);
    final diff = sameOrder
        ? 'same numbers, same order'
        : sameSet
        ? 'same numbers, DIFFERENT ORDER'
        : 'missing=${served.where((n) => !shown.contains(n)).toList()} '
              'extra=${shown.where((n) => !served.contains(n)).toList()}';
    final detail =
        'zone=$zone config=$status server=$served shown=$shown ($diff) '
        'app asked config for zones=$askedZones';
    final good =
        status == 200 &&
        served.isNotEmpty &&
        sameOrder &&
        askedZones.contains(zone);
    if (good) {
      log.pass('G17', title, detail);
    } else {
      log.fail('G17', title, detail);
    }
    await backToHome(tester);
    await wait(tester, const Duration(seconds: 1));
  }

  Future<void> _checkNavigation() async {
    log.step('Home -> pages -> Back (G27)');
    final pages = <(String, Future<bool> Function())>[
      for (final item in <String>[
        tr.profile,
        tr.wallet,
        tr.rideHistory,
        tr.notifications,
        tr.settings,
      ])
        ('menu "$item"', () => _openFromMenu(item)),
      ('dock "${tr.inbox}"', () => _openTooltip(tr.inbox)),
      ('dock "${tr.wallet}"', () => _openTooltip(tr.wallet)),
      ('menu "${tr.profile}" again', () => _openFromMenu(tr.profile)),
    ];
    final start = rec.length;
    final overBudget = <String>[];
    final notOpened = <String>[];
    final notBack = <String>[];
    for (final (name, open) in pages) {
      await backToHome(tester);
      if (!await open()) {
        notOpened.add(name);
        continue;
      }
      await wait(tester, const Duration(seconds: 3));
      await systemBack(tester);
      // The drawer stays under a page opened from it: Back once more.
      if (shows(byKey('driver-side-menu'))) await systemBack(tester);
      final mark = rec.length;
      await wait(tester, _settleAfterBack);
      if (!onHomeOnly(tester)) notBack.add(name);
      final reads = rec
          .since(mark)
          .where((c) => !c.isBackground && c.method == 'GET')
          .toList();
      final perLabel = <String, int>{};
      for (final c in reads) {
        perLabel[c.path] = (perLabel[c.path] ?? 0) + 1;
      }
      CheckLog.say('STEP back from $name: ${reads.length} reads $perLabel');
      if (reads.length > _maxReadsAfterBack ||
          perLabel.values.any((n) => n > 1)) {
        overBudget.add('$name: ${reads.length} reads $perLabel');
      }
    }
    final calls = rec.since(start).where((c) => !c.isBackground).toList();
    final failed = calls.where((c) => c.failed).map((c) => '$c').toList();
    final where =
        'pages=${pages.length} calls=${calls.length} '
        'not opened=$notOpened not back on Home=$notBack';
    if (failed.isEmpty && notOpened.isEmpty && notBack.isEmpty) {
      log.pass(
        'G27-ERR',
        'pages open, Back returns Home, no failed call',
        where,
      );
    } else {
      log.fail(
        'G27-ERR',
        'pages open, Back returns Home, no failed call',
        '$where failed=$failed',
      );
    }
    const reTitle =
        'Back to Home re-reads at most $_maxReadsAfterBack, none twice';
    if (overBudget.isEmpty) {
      log.pass('G27-RE', reTitle, 'every Back within budget');
    } else {
      log.fail('G27-RE', reTitle, overBudget.join(' ; '));
    }
  }

  Future<bool> _openFromMenu(String title) async {
    if (!await _openTooltip(tr.menu)) return false;
    final drawer = byKey('driver-side-menu');
    if (!await pumpUntil(
      tester,
      () => shows(drawer),
      timeout: const Duration(seconds: 5),
    )) {
      return false;
    }
    await tester.pump(const Duration(milliseconds: 400));
    final item = find.descendant(of: drawer, matching: find.text(title));
    if (!shows(item)) return false;
    await tester.ensureVisible(item.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(item.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    return !shows(drawer) || !onHomeOnly(tester);
  }

  Future<bool> _openTooltip(String message) async {
    final target = find.byTooltip(message);
    if (!await pumpUntil(
      tester,
      () => shows(target),
      timeout: const Duration(seconds: 5),
    )) {
      return false;
    }
    await tester.tap(target.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    return true;
  }
}
