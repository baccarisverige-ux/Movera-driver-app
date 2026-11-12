part of 'trip_run.dart';

/// The money checks (owner rule 2026-11-12 ~16:05 UTC): the OFFER shows
/// only what the driver gets; the WAYBILL shows all of it (rider fare,
/// Movera's commission, what the driver gets, payment method); the cash
/// screen shows what to collect; the trip history keeps the driver's own
/// money only. A server field that is missing is a FAIL, never a pass.
extension _TripMoney on TripRun {
  /// The texts of the offer card(s) on Home right now; null = no card.
  List<String>? _offerCardTexts() {
    final cards = <Finder>[
      find.byType(ExclusiveRequestSheet),
      find.byType(RadarOfferCard),
    ].where(shows).toList();
    return cards.isEmpty ? null : [for (final c in cards) ...textsUnder(c)];
  }

  /// OFFER money (owner 2026-11-12 ~16:05 UTC): the card ([card], read
  /// while the offer was up) shows what the driver gets = the server's
  /// offer driverEarnings (with its pickupPay added, the card's one
  /// total), and NOT the rider's fare (nor a cash to collect). The server
  /// offer is read after the accept, so the check never delays it.
  /// Returns (ok, detail); a server field that is missing is not ok.
  Future<(bool, String)> _offerMoney(List<String>? card) async {
    final texts = card ?? const <String>[];
    bool has(Money m) => texts.any(
      (t) => t.contains(m.formatted) || t.contains(TripRun.short(m)),
    );
    // GET /driver/offers lists one status (open by default): the accepted
    // offer first, else (accept not taken) the still open one.
    Map? offer;
    final statuses = <String>[];
    for (final want in const ['accepted', 'open']) {
      final (status, page) = await ask('/api/v1/driver/offers', {
        'status': want,
        'limit': '50',
      });
      statuses.add('$want $status');
      final items = page is Map ? page['items'] : null;
      offer = items is List
          ? items
                .whereType<Map>()
                .where((o) => o['tripId'] == tripId)
                .firstOrNull
          : null;
      if (offer != null) break;
    }
    Money? money(Object? json) =>
        json is Map ? Money.fromJson(Map<String, dynamic>.from(json)) : null;
    final earnings = money(offer?['driverEarnings']);
    final pickupPay = money(offer?['pickupPay']);
    final fare = money(offer?['fare'] ?? lastRiderView?['fare']);
    final cash = money(offer?['cashToCollect']);
    final problems = <String>[
      if (card == null) 'no offer card on screen',
      if (offer == null)
        'server offer for the trip not found (offers ${statuses.join(', ')})',
      if (offer != null && earnings == null)
        'server offer has no driverEarnings',
      if (fare == null) 'server sent no rider fare',
    ];
    final total = earnings == null
        ? null
        : pickupPay == null || pickupPay.isZero
        ? earnings
        : earnings + pickupPay;
    final shown = total != null && (has(total) || has(earnings!));
    if (total != null && !shown) {
      problems.add('driver amount ${total.formatted} not on the card');
    }
    // The rider's fare (and a cash to collect) must not show, unless it is
    // the same amount as the driver's (then it cannot be told apart).
    final fareShown =
        fare != null && fare != total && fare != earnings && has(fare);
    if (fareShown) {
      problems.add(
        'rider fare ${fare.formatted} IS on the card (owner rule: '
        'the offer shows only what the driver gets)',
      );
    }
    final cashShown =
        cash != null &&
        cash != fare &&
        cash != total &&
        cash != earnings &&
        has(cash);
    if (cashShown) {
      problems.add('to-collect ${cash.formatted} IS on the card');
    }
    final detail =
        'card driver amount=${total?.formatted} (server driverEarnings='
        '${earnings?.formatted} pickupPay=${pickupPay?.formatted}) shown=$shown; '
        'rider fare ${fare?.formatted} shown=$fareShown'
        '${fare != null && (fare == total || fare == earnings) ? ' (same as the driver amount: not told apart)' : ''}'
        '${problems.isEmpty ? '' : '; problems: ${problems.join('; ')}'}';
    return (problems.isEmpty, detail);
  }

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
    final wantCash = TripRun.short(p.cashDue);
    final share = p.yourShare;
    final balance = textsUnder(byKey('cash-collect-balance'));
    final shareShown = share == null
        ? null
        : balance.contains(TripRun.short(share));
    await log.screenshot(tester, 'cash-collect');
    var status = serverStatus;
    await watch.run('end', () async {
      await tester.tap(byKey('cash-complete-ride').first, warnIfMissed: false);
      final end = DateTime.now().add(const Duration(seconds: 45));
      while (DateTime.now().isBefore(end) &&
          !rideCompletedShown() &&
          !stopped) {
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
        '${share == null ? 'not sent by the server' : '${TripRun.short(share)} shown=$shareShown'}; '
        'server status=$status fare=$fare preview total=$total '
        'earlyEnd=${p.earlyEnd}; finished screen=${rideCompletedShown()}';
    good ? log.pass('PAY', title, detail) : log.fail('PAY', title, detail);
    if (rideCompletedShown()) await log.screenshot(tester, 'ride-completed');
  }

  /// The waybill: trip id, pickup, drop-off, driver name; after the trip
  /// all the money (owner 2026-11-12 ~16:05 UTC): the rider's fare,
  /// Movera's commission, what the driver gets and the payment method,
  /// each equal to the server's trip (a field the server did not send is
  /// a FAIL too).
  Future<void> _waybill({required bool after}) async {
    final id = after ? 'WAYBILL-AFTER' : 'WAYBILL-DURING';
    final title = after
        ? 'waybill after the trip = server'
        : 'waybill during the trip = server';
    if (late) return log.skip(id, title, 'not run: time limit near');
    final sheet = byKey('waybill-$tripId');
    await watch.run(after ? 'waybill-after' : 'waybill-during', () async {
      if (after) {
        if (shows(byKey('ride-completed-waybill'))) {
          await tester.ensureVisible(byKey('ride-completed-waybill').first);
          await tester.tap(
            byKey('ride-completed-waybill').first,
            warnIfMissed: false,
          );
        }
      } else if (shows(byKey('current-waybill-shortcut'))) {
        await tapTripControl(tester, 'current-waybill-shortcut');
      } else if (await tapTripControl(tester, 'current-trip-more')) {
        await pumpUntil(
          tester,
          () => shows(byKey('current-trip-waybill-option')),
          timeout: const Duration(seconds: 5),
        );
        if (shows(byKey('current-trip-waybill-option'))) {
          await tester.tap(
            byKey('current-trip-waybill-option').first,
            warnIfMissed: false,
          );
        }
      }
      await pumpUntil(
        tester,
        () => shows(sheet),
        timeout: const Duration(seconds: 10),
      );
    });
    if (!shows(sheet)) {
      log.fail(id, title, 'the waybill did not open');
      return;
    }
    final texts = textsUnder(sheet);
    bool has(String s) => texts.any((t) => t.contains(s));
    final profile = rec.lastAnswer['/api/v1/driver/profile'];
    final first = profile is Map ? profile['firstName'] as String? : null;
    final missing = <String>[
      if (!has(tripId!)) 'trip id',
      if (!has(TripRun.pickupName)) 'pickup',
      if (!has(TripRun.dropoffName)) 'drop-off',
      if (first != null && !has(first)) 'driver name',
    ];
    if (after) {
      final server = (await driverApi.trip(tripId!)).map;
      for (final (name, money) in [
        ('rider fare', server?['fare'] ?? completedView?['fare']),
        ('Movera commission', server?['commission']),
        ('what he gets (driverTotal)', server?['driverTotal']),
      ]) {
        if (money is! Map) {
          missing.add('$name (server sent none)');
          continue;
        }
        final m = Money.fromJson(Map<String, dynamic>.from(money));
        if (!has(m.formatted) && !has(TripRun.short(m))) {
          missing.add('$name ${m.formatted}');
        }
      }
      final method =
          server?['paymentMethod'] ?? completedView?['paymentMethod'];
      if (method is! String) {
        missing.add('payment method (server sent none)');
      } else {
        final want = method == 'cash' ? tr.cash : tr.inApp;
        if (!texts.contains(want)) missing.add('payment method "$want"');
      }
    }
    await systemBack(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final detail =
        'checked trip id, pickup, drop-off, driver name'
        '${after ? ', rider fare, commission, what he gets, payment method' : ''}; '
        'missing=$missing; '
        'times and vehicle: shown, not compared (no server field in the '
        'same format)';
    missing.isEmpty ? log.pass(id, title, detail) : log.fail(id, title, detail);
  }

  /// Driver history (menu): the server's net for today (G28) shows, the
  /// trip is listed and its detail shows the driver's own money = the
  /// server's driverTotal. Not the rider's fare or Movera's commission:
  /// the history keeps "the driver's own money only" (owner 2026-10-26,
  /// kept 2026-11-12 ~16:05 UTC; the waybill has the rest).
  Future<void> _history() async {
    const title = 'history: G28 net, the trip, his own money';
    if (late) return log.skip('HISTORY', title, 'not run: time limit near');
    await backToHome(tester);
    final mark = rec.length;
    var opened = false;
    await watch.run('history-open', () async {
      final menu = find.byTooltip(tr.menu);
      if (!await pumpUntil(
        tester,
        () => shows(menu),
        timeout: const Duration(seconds: 5),
      )) {
        return;
      }
      await tester.tap(menu.first, warnIfMissed: false);
      await pumpUntil(
        tester,
        () => shows(byKey('driver-side-menu')),
        timeout: const Duration(seconds: 5),
      );
      final entry = find.descendant(
        of: byKey('driver-side-menu'),
        matching: find.text(tr.rideHistory),
      );
      if (!shows(entry)) return;
      await tester.ensureVisible(entry.first);
      await tester.tap(entry.first, warnIfMissed: false);
      opened = await pumpUntil(
        tester,
        () => shows(find.byType(DriverRideHistory)),
        timeout: const Duration(seconds: 10),
      );
      await pumpUntil(
        tester,
        () => calls(
          '/api/v1/driver/earnings',
          method: 'GET',
          from: mark,
        ).any((c) => c.status != null),
        timeout: const Duration(seconds: 20),
      );
      await wait(tester, const Duration(seconds: 2));
    });
    final report = rec.lastAnswer['/api/v1/driver/earnings'];
    EarningsTotals? totals;
    try {
      if (report is Map) {
        totals = EarningsTotals.of(Map<String, dynamic>.from(report));
      }
    } on FormatException {
      totals = null;
    }
    final page = find.byType(DriverRideHistory);
    final netShown =
        totals != null &&
        textsUnder(page).any((t) => t.contains(totals!.net.formatted));
    final row = find.byKey(ValueKey<String>(tripId!));
    if (!shows(row)) {
      for (final key in const [
        'history-view-all-rides',
        'history-all-rides-button',
      ]) {
        if (shows(byKey(key))) {
          await tester.tap(byKey(key).first, warnIfMissed: false);
          await wait(tester, const Duration(seconds: 2));
          break;
        }
      }
    }
    final listed = shows(row);
    final missing = <String>[];
    if (listed) {
      await watch.run('history-detail', () async {
        await tester.ensureVisible(row.first);
        await tester.tap(row.first, warnIfMissed: false);
        await pumpUntil(
          tester,
          () => shows(find.byType(DriverRideHistoryDetail)),
          timeout: const Duration(seconds: 10),
        );
      });
      final texts = textsUnder(find.byType(DriverRideHistoryDetail));
      final driverView = await driverApi.trip(tripId!);
      final own = driverView.map?['driverTotal'];
      if (own is! Map) {
        // A missing server field is a FAIL, never a pass.
        missing.add('his own money (server sent no driverTotal)');
      } else {
        final m = Money.fromJson(Map<String, dynamic>.from(own));
        if (!texts.any(
          (t) => t.contains(m.formatted) || t.contains(TripRun.short(m)),
        )) {
          missing.add('his own money ${m.formatted}');
        }
      }
    }
    await backToHome(tester, tries: 4);
    final detail =
        'page=$opened server net today=${totals?.net.formatted} shown=$netShown '
        'trips=${totals?.tripCount}; trip listed=$listed; detail missing=$missing '
        '(rider fare / commission not required here: waybill)';
    opened && netShown && listed && missing.isEmpty
        ? log.pass('HISTORY', title, detail)
        : log.fail('HISTORY', title, detail);
  }
}
