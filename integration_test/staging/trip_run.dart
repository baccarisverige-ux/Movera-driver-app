import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/safety/emergency_numbers.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

import 'check_log.dart';
import 'driver_steps.dart';
import 'mock_position.dart';
import 'movera_api.dart';
import 'session.dart';
import 'transition_watch.dart';
import 'trip_steps.dart';

part 'trip_extras.dart';
part 'trip_cleanup.dart';
part 'trip_scheduled.dart';

/// Owner 2026-11-12 ("U can't make all trip lifecycle test on firebase?"):
/// one full trip on a real Test Lab phone. The DRIVER is the real app on
/// the phone; the RIDER is played over HTTP by this test (one big-test
/// rider from the MOVERA_TEST_NUMBERS secret, handed over at run time).
///
/// Every step is one `MOVERA-TL CHECK` line; every step has a time limit
/// and a clear FAIL detail, and the run always reaches the clean-up
/// (open trip cancelled, driver offline).
class TripRun extends StagingSession {
  TripRun(super.tester, super.log, {this.scheduled = false}) {
    rider = RiderApi(
      Uri(scheme: base.scheme, host: base.host, port: base.port),
    );
    watch = TransitionWatch(tester, log, rec);
    mock = MockPosition(lat, lng);
  }

  late final RiderApi rider;

  /// The `trip-scheduled` scenario: a booked-for-later ride (and its
  /// cancel case) instead of a live one.
  final bool scheduled;

  /// Trip ids this run booked (the clean-up closes every one).
  final List<String> booked = <String>[];
  late final TransitionWatch watch;
  late final MockPosition mock;

  /// Pickup ~300 m north of the driver, drop-off ~700 m east of the pickup
  /// (inside zone Z001 for the default point).
  late final (double, double) pickup = MockPosition.offset(
    lat,
    lng,
    north: 300,
  );
  late final (double, double) dropoff = MockPosition.offset(
    pickup.$1,
    pickup.$2,
    east: 700,
  );

  static const String pickupName = 'Movera TL pickup (test)';
  static const String dropoffName = 'Movera TL drop-off (test)';

  final DateTime startedAt = DateTime.now();

  /// Optional checks are skipped past this point, so the clean-up always
  /// has time inside the test's own limit.
  late final DateTime softDeadline = startedAt.add(const Duration(minutes: 14));

  bool get late => DateTime.now().isAfter(softDeadline);

  String? tripId;
  Map<String, dynamic>? lastRiderView;
  CompletePreview? preview;
  Map<String, dynamic>? completedView;
  bool accepted = false;
  bool started = false;
  bool completed = false;
  DateTime? onBoardAt;
  DateTime? rideCheckSeenAt;
  String? rideCheckId;

  /// Runs one step: an exception is that step's FAIL, never the end of
  /// the run.
  Future<void> step(
    String id,
    String title,
    Future<void> Function() body,
  ) async {
    log.step(id);
    try {
      await body();
    } catch (error, stack) {
      log.fail(id, title, 'stopped by ${error.runtimeType}: $error');
      CheckLog.say('STACK ${stack.toString().split('\n').take(5).join(' | ')}');
    }
  }

  Future<Map<String, dynamic>?> riderView() async {
    final id = tripId;
    if (id == null) return null;
    final answer = await rider.trip(id);
    if (answer.ok) lastRiderView = answer.map;
    return answer.ok ? answer.map : null;
  }

  String? get serverStatus => lastRiderView?['status'] as String?;

  /// Polls the rider's view every 2 s until a status in [want] (or a
  /// terminal one) or [timeout]; answers the ride check card meanwhile.
  Future<String?> waitStatus(Set<String> want, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      await rideCheckGate();
      final view = await riderView();
      final status = view?['status'] as String?;
      if (status != null &&
          (want.contains(status) || terminalStatuses.contains(status))) {
        return status;
      }
      if (DateTime.now().isAfter(end)) return status;
      await wait(tester, const Duration(seconds: 2));
    }
  }

  /// The server's ride check card on the trip screen: noted and answered
  /// "OK" the way a driver would, whichever step is running.
  Future<void> rideCheckGate() async {
    final card = byKey('ride-check-card');
    if (!shows(card)) return;
    rideCheckSeenAt ??= DateTime.now();
    CheckLog.say('STEP ride check card shown: answered OK');
    final ok = byKey('ride-check-ok');
    if (shows(ok)) {
      await tester.tap(ok.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> all({
    required String phone,
    required String code,
    required String riderPhone,
  }) async {
    log.step('sign in (server ${base.host})');
    final signInError = await guard(
      () => signIn(tester, phone: phone, code: code),
    );
    if (signInError != null) {
      log.fail('SIGN-IN', 'test driver reaches Home', signInError);
      log.skip('TRIP', 'trip lifecycle', 'not run: sign-in failed');
      return;
    }
    log.pass('SIGN-IN', 'test driver reaches Home', 'Home is open');
    await wait(tester, const Duration(seconds: 3));
    watch.baseline();
    try {
      await goOnline();
      if (!online) {
        log.skip('TRIP', 'trip lifecycle', 'not run: driver not online');
        return;
      }
      await step('RIDER-SIGN-IN', 'rider signs in over HTTP', () async {
        final error = await rider.signIn(
          phone: riderPhone,
          code: code,
          app: 'rider',
        );
        error == null
            ? log.pass('RIDER-SIGN-IN', 'rider signs in over HTTP', 'signed in')
            : log.fail('RIDER-SIGN-IN', 'rider signs in over HTTP', error);
      });
      if (!rider.signedIn) return;
      if (scheduled) {
        await _scheduledScenario();
      } else {
        await step('BOOK', 'rider books a cash trip', () => _book('BOOK'));
        if (tripId == null) return;
        await step('OFFER', 'offer shows on the driver phone', _offerAndAccept);
        if (!accepted) return;
        await _tripSteps(extras: true);
      }
    } catch (error, stack) {
      log.fail('RUN', 'checks ran to the end', 'stopped by $error');
      CheckLog.say('STACK ${stack.toString().split('\n').take(6).join(' | ')}');
    } finally {
      await _cleanup();
      await goOfflineAtEnd();
      rider.close();
    }
  }

  /// The trip from "on the way to the pickup" to the end, the same for a
  /// live and a booked ride. [extras]: chat, call, SOS, ride check.
  Future<void> _tripSteps({required bool extras}) async {
    await step(
      'SWITCH-1',
      'menu/back/background keep the trip',
      () => _switches('1'),
    );
    await step(
      'WAYBILL-DURING',
      'waybill during the trip',
      () => _waybill(after: false),
    );
    await step('ARRIVE', 'driver taps Arrived', _arrive);
    await step('START', 'driver starts the trip', _start);
    if (!started) return;
    if (extras) {
      // At the pickup with the rider on board: the server's long-stop ride
      // check clock runs while these stationary checks go on.
      await step('CHAT', 'chat both ways', _chat);
      await step('CALL', 'call rider: ring, answer, end', _call);
      await step(
        'SWITCH-2',
        'menu/back/background keep the trip',
        () => _switches('2'),
      );
      await step('SOS', 'SOS visible during the trip', _sos);
      await step(
        'RIDE-CHECK',
        'server ride check reaches the driver',
        _rideCheck,
      );
    }
    await step('DROPOFF', 'drive to the drop-off', _dropoff);
    await step('PAY', 'cash screen shows the server amounts', _collect);
    if (!completed) return;
    await step('RATE', 'driver rates the rider', _rate);
    await step('RIDER', 'rider sees the trip completed + receipt', _riderSide);
    await step('HISTORY', 'history and earnings show the trip', _history);
  }

  // ---- booking, offer, accept -------------------------------------------

  /// Books one cash trip as the rider; [at] = a booked ride for then.
  /// Sets [tripId] (null when booking failed: the step says why).
  Future<void> _book(String id, {DateTime? at}) async {
    final title = at == null
        ? 'rider books a cash trip'
        : 'rider books a cash ride for later';
    tripId = null;
    final active = await rider.activeTrip();
    if (active.status == 200 && active.map?['tripId'] is String) {
      final old = active.map!;
      final cancel = await rider.cancel(
        old['tripId'] as String,
        (old['version'] as num).toInt(),
        'plans_changed',
      );
      CheckLog.say(
        'STEP rider had an open trip (${old['status']}): cancel ${cancel.short}',
      );
    }
    final q = await rider.quote(
      pickup: {'lat': pickup.$1, 'lng': pickup.$2, 'address': pickupName},
      dropoff: {'lat': dropoff.$1, 'lng': dropoff.$2, 'address': dropoffName},
      scheduledAt: at,
    );
    final quotes = <Map<String, dynamic>>[
      if (q.map?['quotes'] is List)
        for (final x in q.map!['quotes'] as List)
          if (x is Map) Map<String, dynamic>.from(x),
    ];
    if (!q.ok || quotes.isEmpty) {
      log.fail(id, title, 'quote ${q.short} quotes=${quotes.length}');
      return;
    }
    // A category the test driver drives (his profile), else the first.
    final profile = rec.lastAnswer['/api/v1/driver/profile'];
    final mine = profile is Map && profile['categoryIds'] is List
        ? (profile['categoryIds'] as List).whereType<String>().toSet()
        : <String>{};
    final chosen = quotes.firstWhere(
      (x) => mine.contains(x['categoryId']),
      orElse: () => quotes.first,
    );
    final booked = await rider.book(chosen, scheduledAt: at);
    final made = booked.map?['tripId'];
    if (!booked.ok || made is! String) {
      log.fail(id, title, 'quote ${q.short}; book ${booked.short}');
      return;
    }
    tripId = made;
    this.booked.add(made);
    lastRiderView = booked.map;
    log.pass(
      id,
      title,
      'trip $made ${booked.map?['status']} category=${chosen['categoryId']} '
      '${at == null ? '' : 'pickup in ${at.difference(DateTime.now()).inMinutes} min '}'
      'fare=${moneyOf(booked.map?['fare'])} pickup ~300 m from the driver, '
      'drop-off ~700 m (cash, wallet off)',
    );
  }

  Future<void> _offerAndAccept() async {
    const title = 'offer shows on the driver phone';
    final sent = DateTime.now();
    String? control;
    await watch.run('home->offer', () async {
      await pumpUntil(
        tester,
        () => (control = offerControl()) != null,
        timeout: const Duration(seconds: 90),
      );
    });
    final view = await riderView();
    if (control == null) {
      log.fail(
        'OFFER',
        title,
        'no offer control on Home in 90 s; server trip ${view?['status']} '
            'driver=${view?['driver'] is Map ? 'someone' : 'none'}',
      );
      log.skip('ACCEPT', 'driver accepts', 'not run: no offer');
      return;
    }
    log.pass(
      'OFFER',
      title,
      '$control after ${DateTime.now().difference(sent).inSeconds} s; '
          'server trip ${view?['status']}',
    );
    const accept = 'driver accepts in the app';
    final shown = await watch.run(
      'offer->trip',
      () => acceptOffer(tester, control!),
    );
    final status = await waitStatus({
      'accepted',
      'driver_to_pickup',
    }, const Duration(seconds: 30));
    final screen = tripScreen();
    final sameTrip = screen?.tripId == tripId;
    accepted =
        shown &&
        sameTrip &&
        (status == 'accepted' || status == 'driver_to_pickup');
    final detail =
        'trip screen=$shown same trip=$sameTrip server=$status '
        'cash=${screen?.paidByCash}';
    if (accepted) {
      log.pass('ACCEPT', accept, detail);
      await log.screenshot(tester, 'trip-accepted');
    } else {
      log.fail('ACCEPT', accept, '$detail (want accepted/driver_to_pickup)');
    }
  }

  // ---- arrive, start, drop-off, pay, rate --------------------------------

  Future<void> _arrive() async {
    const title = 'at the pickup, Arrived is taken';
    final drove = await mock.driveTo(tester, pickup.$1, pickup.$2);
    if (!drove) {
      log.fail(
        'ARRIVE',
        title,
        'mock position cannot move (no MOVERA_TL_MOCK_FILE)',
      );
      return;
    }
    String? status;
    final tapped = await watch.run('arrived', () async {
      await rideCheckGate();
      if (!await tapTripControl(tester, 'active-ride-arrived-button')) {
        return false;
      }
      status = await waitStatus({'arrived'}, const Duration(seconds: 40));
      return true;
    });
    final detail = 'button=$tapped server=$status';
    status == 'arrived'
        ? log.pass('ARRIVE', title, detail)
        : log.fail(
            'ARRIVE',
            title,
            '$detail (want arrived; the app needs a '
                'fix within 100 m of the pickup)',
          );
  }

  Future<void> _start() async {
    const title = 'Start trip is taken (rider on board)';
    final view = await riderView();
    final pin = view?['pickupPin'] as String?;
    String? status;
    final slid = await watch.run('start', () async {
      await rideCheckGate();
      if (!await slidePrimary(tester)) return false;
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (DateTime.now().isBefore(end)) {
        await answerStepSheets(tester, pin: pin);
        status = await waitStatus(onBoardStatuses, const Duration(seconds: 1));
        if (onBoardStatuses.contains(status)) break;
      }
      return true;
    });
    started = onBoardStatuses.contains(status);
    if (started) onBoardAt = DateTime.now();
    final detail =
        'slide=$slid server=$status pinRequired=${view?['pinRequired']}';
    started
        ? log.pass('START', title, detail)
        : log.fail('START', title, '$detail (want rider_onboard/in_trip)');
  }

  Future<void> _dropoff() async {
    const title = 'drive to the drop-off, trip still running';
    final drove = await mock.driveTo(
      tester,
      dropoff.$1,
      dropoff.$2,
      metersPerSecond: 12,
    );
    await rideCheckGate();
    final status = await waitStatus(
      onBoardStatuses,
      const Duration(seconds: 5),
    );
    final collect = await pumpUntil(
      tester,
      () => shows(byKey('active-ride-collect-cash')),
      timeout: const Duration(seconds: 20),
    );
    final detail =
        'moved=$drove server=$status collect button=$collect '
        'screen on top=${onTripTop()}';
    drove && onBoardStatuses.contains(status) && collect
        ? log.pass('DROPOFF', title, detail)
        : log.fail('DROPOFF', title, detail);
  }

  static String short(Money m) =>
      Money.parseLabel(m.formatted)?.formattedShort ?? m.formatted;

  Future<void> _collect() async {
    const title = 'to collect / you get = server, trip completed';
    final opened = await watch.run('collect', () async {
      await rideCheckGate();
      if (!await tapTripControl(tester, 'active-ride-collect-cash')) {
        return false;
      }
      return pumpUntil(
        tester,
        () => shows(byKey('cash-collect-sheet')),
        timeout: const Duration(seconds: 30),
      );
    });
    final raw = rec.lastAnswer['/api/v1/driver/trips/$tripId/complete-preview'];
    preview = raw is Map
        ? CompletePreview.tryParse(Map<String, dynamic>.from(raw))
        : null;
    final p = preview;
    if (!opened || p == null) {
      log.fail('PAY', title, 'cash sheet=$opened server preview=${p != null}');
      return;
    }
    final amount = byKey('cash-collect-amount');
    final shownCash = shows(amount)
        ? tester.widget<Text>(amount.first).data
        : null;
    final wantCash = short(p.cashDue);
    final share = p.yourShare;
    final balance = textsUnder(byKey('cash-collect-balance'));
    final shareShown = share == null ? null : balance.contains(short(share));
    await log.screenshot(tester, 'cash-collect');
    var status = serverStatus;
    await watch.run('end', () async {
      await tester.tap(byKey('cash-complete-ride').first, warnIfMissed: false);
      final end = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(end) && !rideCompletedShown()) {
        await answerStepSheets(tester);
        await wait(tester, const Duration(milliseconds: 750));
      }
      status = await waitStatus({'completed'}, const Duration(seconds: 15));
    });
    completed = status == 'completed';
    completedView = lastRiderView;
    final fare = moneyOf(completedView?['fare']);
    final total = (p.total.minorUnits, p.total.currency);
    final good =
        shownCash == wantCash &&
        shareShown != false &&
        completed &&
        fare == total &&
        rideCompletedShown();
    final detail =
        'to collect shown=$shownCash server=$wantCash; you get '
        '${share == null ? 'not sent by the server' : '${short(share)} shown=$shareShown'}; '
        'server status=$status fare=$fare preview total=$total '
        'earlyEnd=${p.earlyEnd}; finished screen=${rideCompletedShown()}';
    good ? log.pass('PAY', title, detail) : log.fail('PAY', title, detail);
    if (rideCompletedShown()) await log.screenshot(tester, 'ride-completed');
  }

  Future<void> _rate() async {
    const title = 'stars + Done send the rating, Home shows';
    final star = byKey('rider-rating-star-5');
    var tapped = false;
    await watch.run('rate', () async {
      if (await pumpUntil(
        tester,
        () => shows(star),
        timeout: const Duration(seconds: 10),
      )) {
        await tester.ensureVisible(star.first);
        await tester.tap(star.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
        tapped = true;
      }
    });
    if (!late) {
      await step(
        'WAYBILL-AFTER',
        'waybill after the trip',
        () => _waybill(after: true),
      );
    }
    final mark = rec.length;
    await watch.run('done->home', () async {
      final done = byKey('ride-completed-done');
      if (shows(done)) {
        await tester.ensureVisible(done.first);
        await tester.tap(done.first, warnIfMissed: false);
      }
      await pumpUntil(
        tester,
        () => onHomeOnly(tester),
        timeout: const Duration(seconds: 30),
      );
    });
    final posts = calls(
      '/api/v1/trips/$tripId/rating',
      method: 'POST',
      from: mark,
    ).toList();
    final sent = posts.any((c) => !c.failed && c.status != null);
    final home = shows(find.byType(DriverHome)) && onHomeOnly(tester);
    final detail =
        'star tapped=$tapped rating POST=${posts.map((c) => c.status ?? c.error).toList()} '
        'Home=$home';
    tapped && sent && home
        ? log.pass('RATE', title, detail)
        : log.fail('RATE', title, detail);
  }

  static String randomTag() => math.Random().nextInt(1 << 20).toRadixString(36);
}
