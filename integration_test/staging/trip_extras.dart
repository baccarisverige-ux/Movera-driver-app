part of 'trip_run.dart';

/// The checks around the trip's main steps (owner 2026-11-12: screen
/// switches, waybill, chat, call, SOS, ride check, both sides' history).
extension _TripExtras on TripRun {
  /// Menu page + Back, and the app to the background and back, while the
  /// trip runs: the trip screen, its trip and the server status stay.
  Future<void> _switches(String n) async {
    final id = 'SWITCH-$n';
    const title = 'menu/back/background keep the trip';
    if (late) return log.skip(id, title, 'not run: time limit near');
    final before = (await riderView())?['status'];
    final menu = await watch.run(
      'menu-back-$n',
      () => menuPageAndBack(tester, tr.rideHistory),
    );
    await watch.run('background-resume-$n', () async {
      // Run 6 (2026-11-12): `hidden` and `paused` turn frames off
      // (SchedulerBinding.framesEnabled = false), and the live binding's
      // `tester.pump` then waits for a frame that never comes: the test
      // hung for 17 min. So: NEVER pump (nor [wait]) while the fake
      // lifecycle is hidden/paused; only plain time passes then.
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 300));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      CheckLog.say('STEP background (frames off, no pump) 3 s');
      await Future<void>.delayed(const Duration(seconds: 3));
      // `inactive` turns frames back on and schedules one; only then pump.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      CheckLog.say('STEP resumed (frames on)');
      await tester.pump(const Duration(milliseconds: 300));
      await wait(tester, const Duration(seconds: 3));
    });
    await rideCheckGate();
    final after = (await riderView())?['status'];
    final same = tripScreen()?.tripId == tripId;
    final detail =
        'menu page=${menu ?? 'ok'} trip screen on top=${onTripTop()} '
        'same trip=$same server before=$before after=$after';
    menu == null && onTripTop() && same && before == after
        ? log.pass(id, title, detail)
        : log.fail(id, title, detail);
  }

  /// Rider -> driver (unread badge, the text in the chat), driver ->
  /// rider (typed in the app, read over HTTP); chat open/close watched.
  Future<void> _chat() async {
    const title = 'chat both ways, unread badge';
    if (late) return log.skip('CHAT', title, 'not run: time limit near');
    final id = tripId!;
    final riderText = 'TL rider ping ${TripRun.randomTag()}';
    final sent = await rider.sendMessage(id, riderText);
    var unread = 0;
    await pumpUntil(
      tester,
      () => (unread = chatUnread(tester)) > 0 || shows(find.text(riderText)),
      timeout: const Duration(seconds: 25),
    );
    final opened = await watch.run('chat-open', () async {
      await tapTripControl(tester, 'active-ride-message-rider');
      return pumpUntil(tester, chatOpen, timeout: const Duration(seconds: 10));
    });
    final seen = await pumpUntil(
      tester,
      () => shows(find.text(riderText)),
      timeout: const Duration(seconds: 15),
    );
    final replyText = 'TL driver reply ${TripRun.randomTag()}';
    final mark = rec.length;
    var typed = false;
    if (opened && shows(chatField())) {
      await tester.enterText(chatField().first, replyText);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      typed = true;
      await pumpUntil(
        tester,
        () => calls(
          '/api/v1/trips/$id/messages',
          method: 'POST',
          from: mark,
        ).any((c) => c.status != null || c.error != null),
        timeout: const Duration(seconds: 20),
      );
    }
    final posted = calls(
      '/api/v1/trips/$id/messages',
      method: 'POST',
      from: mark,
    ).map((c) => c.status ?? c.error).toList();
    await watch.run('chat-close', () async {
      await backToTrip(tester);
    });
    final read = await rider.messages(id);
    final items = read.map?['items'];
    final riderSees =
        items is List &&
        items.any(
          (m) => m is Map && m['from'] == 'driver' && m['text'] == replyText,
        );
    final unreadAfter = chatUnread(tester);
    final detail =
        'rider send ${sent.short}; driver badge=$unread; chat opened=$opened '
        'rider text shown=$seen; reply typed=$typed POST=$posted; rider reads '
        'reply=$riderSees (${read.short}); unread after close=$unreadAfter; '
        'back on trip=${onTripTop()}';
    sent.ok &&
            unread > 0 &&
            opened &&
            seen &&
            riderSees &&
            unreadAfter == 0 &&
            onTripTop()
        ? log.pass('CHAT', title, detail)
        : log.fail('CHAT', title, detail);
  }

  /// Driver calls from the trip screen; the rider (HTTP) answers, then
  /// hangs up. Only states: Test Lab has no audio peer, so "Call failed"
  /// after the answer is the expected way for media and counts as the
  /// state flow working (reported).
  Future<void> _call() async {
    const title = 'call: ringing, answered, ended, back to the trip';
    if (late) return log.skip('CALL', title, 'not run: time limit near');
    final id = tripId!;
    final mark = rec.length;
    String? callId;
    ApiAnswer? answered, ended;
    final lines = <String>{};
    await watch.run('call', () async {
      await tapTripControl(tester, 'active-ride-call-rider');
      await pumpUntil(tester, callOpen, timeout: const Duration(seconds: 10));
      await pumpUntil(
        tester,
        () => calls(
          '/api/v1/trips/$id/call',
          method: 'POST',
          from: mark,
        ).any((c) => c.status != null || c.error != null),
        timeout: const Duration(seconds: 20),
      );
      final ans = rec.lastAnswer['/api/v1/trips/$id/call'];
      callId = ans is Map ? ans['callId'] as String? : null;
      if (callId == null) {
        // The rider's own call attempt names the live call (call_busy).
        final busy = await rider.call(id);
        final details = busy.map?['details'];
        if (details is List && details.isNotEmpty) callId = '${details.first}';
      }
      if (callStateLine(tester) case final l?) lines.add(l);
      if (callId != null) {
        answered = await rider.answerCall(callId!);
        await wait(tester, const Duration(seconds: 5));
        if (callStateLine(tester) case final l?) lines.add(l);
        ended = await rider.endCall(callId!, 'hangup');
        await pumpUntil(tester, () {
          if (callStateLine(tester) case final l?) lines.add(l);
          return !callOpen() ||
              lines.contains(tr.callEnded) ||
              lines.contains(tr.callFailed);
        }, timeout: const Duration(seconds: 25));
      }
      if (callOpen() && shows(byKey('call-close'))) {
        await tester.tap(byKey('call-close').first, warnIfMissed: false);
      }
      await pumpUntil(
        tester,
        () => !callOpen(),
        timeout: const Duration(seconds: 10),
      );
      await backToTrip(tester);
    });
    final post = calls(
      '/api/v1/trips/$id/call',
      method: 'POST',
      from: mark,
    ).map((c) => c.status ?? c.error).toList();
    final state = answered?.map?['state'];
    final endState = ended?.map?['state'];
    final endedShown = lines.contains(tr.callEnded);
    final failedShown = lines.contains(tr.callFailed);
    final detail =
        'driver call POST=$post callId=${callId != null}; rider answer '
        '${answered?.short} state=$state; rider end ${ended?.short} '
        'state=$endState; driver screen lines=${lines.toList()} '
        '${failedShown ? '(Call failed: no audio peer on Test Lab, state flow only)' : ''}; '
        'back on trip=${onTripTop()}';
    final good =
        post.contains(200) &&
        state == 'answered' &&
        endState == 'ended' &&
        (endedShown || failedShown) &&
        onTripTop();
    good ? log.pass('CALL', title, detail) : log.fail('CALL', title, detail);
  }

  /// SOS on the trip's safety sheet (never pressed); the numbers the app
  /// holds are the server's for the trip's zone (G17). By design the
  /// sheet lists the zone's numbers only after an SOS is sent (v0.18.57
  /// §79), so the held list is compared, not the screen.
  Future<void> _sos() async {
    const title = 'SOS shows; the app holds the zone numbers (G17)';
    if (late) return log.skip('SOS', title, 'not run: time limit near');
    final zone = lastRiderView?['zoneId'] as String?;
    final (status, config) = zone == null
        ? (0, null)
        : await ask('/api/v1/driver/config', {'zoneId': zone});
    final served = <String>[
      if (config is Map && config['emergencyNumbers'] is List)
        for (final row in config['emergencyNumbers'] as List)
          if (row is Map && row['number'] is String) row['number'] as String,
    ];
    await watch.run('sos-open', () async {
      await tapTripControl(tester, 'active-ride-safety-button');
      await pumpUntil(
        tester,
        () => shows(find.byType(SafetyToolKits)),
        timeout: const Duration(seconds: 10),
      );
    });
    final sosShown = shows(find.byKey(const ValueKey('safety-sos')));
    final held = [for (final n in EmergencyNumbers.current) n.number];
    await log.screenshot(tester, 'trip-safety');
    await watch.run('sos-close', () => backToTrip(tester));
    final detail =
        'SOS button=$sosShown (not pressed); zone=$zone config=$status '
        'server=$served app holds=$held received=${EmergencyNumbers.received}';
    sosShown &&
            served.isNotEmpty &&
            held.join(',') == served.join(',') &&
            onTripTop()
        ? log.pass('SOS', title, detail)
        : log.fail('SOS', title, detail);
  }

  /// The server's long-stop ride check (DriverAppConfig.rideCheck:
  /// stopMinutes still within 50 m while on board, not near the drop-off):
  /// the phone stays at the pickup, the card must show and the driver's
  /// OK must reach the server. The rider's side is answered OK over HTTP.
  Future<void> _rideCheck() async {
    const title = 'server ride check card, answered OK';
    final config = rec.lastAnswer['/api/v1/driver/config'];
    final rc = config is Map ? config['rideCheck'] : null;
    final on = rc is Map ? rc['on'] != false : true;
    final stopMin = rc is Map && rc['stopMinutes'] is num
        ? (rc['stopMinutes'] as num).toDouble()
        : 2.0;
    if (!on) {
      return log.skip(
        'RIDE-CHECK',
        title,
        'NOT CHECKED: rideCheck.on is false for this zone on staging',
      );
    }
    final since = onBoardAt ?? DateTime.now();
    final until = since.add(Duration(seconds: (stopMin * 60).round() + 90));
    if (until.isAfter(softDeadline)) {
      return log.skip(
        'RIDE-CHECK',
        title,
        'NOT CHECKED: waiting $stopMin min still would pass the time limit',
      );
    }
    final mark = rec.length;
    while (rideCheckSeenAt == null &&
        DateTime.now().isBefore(until) &&
        !stopped) {
      await rideCheckGate();
      await wait(tester, const Duration(seconds: 2));
    }
    await wait(tester, const Duration(seconds: 3));
    final view = await riderView();
    final check = view?['rideCheck'];
    String? riderAnswer;
    if (check is Map && check['checkId'] is String) {
      final answer = await rider
          .post('/api/v1/rider/trips/$tripId/ride-check', {
            'checkId': check['checkId'],
            'trigger': check['trigger'],
            'at': DateTime.now().toUtc().toIso8601String(),
            'answer': 'ok',
          });
      riderAnswer = answer.short;
    }
    final posts = calls(
      '/api/v1/driver/trips/$tripId/ride-check',
      method: 'POST',
      from: mark,
    ).map((c) => c.status ?? c.error).toList();
    final answers = check is Map ? check['answers'] : null;
    final driverOk = answers is Map && answers['driver'] != null;
    final detail =
        'card seen=${rideCheckSeenAt != null} after '
        '${rideCheckSeenAt?.difference(since).inSeconds ?? '-'} s on board '
        '(stopMinutes=$stopMin); driver POST=$posts; server rideCheck '
        'trigger=${check is Map ? check['trigger'] : null} driver answer='
        '${answers is Map ? answers['driver'] : null}; rider answered $riderAnswer';
    rideCheckSeenAt != null && driverOk
        ? log.pass('RIDE-CHECK', title, detail)
        : log.fail('RIDE-CHECK', title, detail);
  }

  /// The rider (HTTP): trip completed, receipt = the trip's fare, cash
  /// paid = the cash the driver collected, the trip in the rider history.
  Future<void> _riderSide() async {
    const title = 'rider: completed, receipt, history = server';
    final id = tripId!;
    final view = await riderView();
    ApiAnswer receipt = await rider.receipt(id);
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (receipt.status == 409 && DateTime.now().isBefore(end) && !stopped) {
      await wait(tester, const Duration(seconds: 3));
      receipt = await rider.receipt(id);
    }
    final fare = moneyOf(view?['fare']);
    final total = moneyOf(receipt.map?['total']);
    final cashPaid = moneyOf(receipt.map?['cashPaid']);
    final due = preview == null
        ? null
        : (preview!.cashDue.minorUnits, preview!.cashDue.currency);
    final history = await rider.history();
    final items = history.map?['items'];
    final row = items is List
        ? items.whereType<Map>().where((t) => t['tripId'] == id).firstOrNull
        : null;
    final detail =
        'status=${view?['status']} fare=$fare receipt ${receipt.short} '
        'total=$total cashPaid=$cashPaid (collected $due); history '
        '${history.short} has trip=${row != null} fare=${moneyOf(row?['fare'])}';
    view?['status'] == 'completed' &&
            receipt.ok &&
            total == fare &&
            (cashPaid == null || cashPaid == due) &&
            row != null &&
            moneyOf(row['fare']) == fare
        ? log.pass('RIDER', title, detail)
        : log.fail('RIDER', title, detail);
  }
}
