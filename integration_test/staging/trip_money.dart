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

  /// The amount the Exclusive offer card shows, from its fare key
  /// `exclusive-fare` (home_offer_sheet.dart: the big fare =
  /// offer.shownFare = driverEarnings + pickupPay, never the rider's
  /// fare). Null when it does not show (the radar card: its texts are
  /// used instead).
  (String, String)? _offerFareText() {
    for (final key in const ['exclusive-fare']) {
      final f = byKey(key);
      if (!shows(f)) continue;
      final w = f.evaluate().first.widget;
      final text = w is Text ? (w.data ?? w.textSpan?.toPlainText()) : null;
      if (text != null) return (key, text);
    }
    return null;
  }

  /// The offer id the app accepted: from its own recorded
  /// `POST /offers/{offerId}/accept` (api_dispatch_repository.dart).
  String? _acceptedOfferId() {
    final accept = RegExp(r'^/api/v1/offers/([^/]+)/accept$');
    for (final c in rec.calls.reversed) {
      if (c.method != 'POST') continue;
      final m = accept.firstMatch(c.path);
      if (m != null) return Uri.decodeComponent(m.group(1)!);
    }
    return null;
  }

  /// OFFER money (owner 2026-11-12 ~16:05 UTC): the card ([card], read
  /// while the offer was up; [fareText] = its fare key and text) shows
  /// what the driver gets = the server's offer driverEarnings (with its
  /// pickupPay added, the card's one total), and NOT the rider's fare
  /// (nor a cash to collect). The server offer is read after the accept,
  /// so the check never delays it: `GET /driver/offers/{offerId}`
  /// (OfferCheck {offer, trip?}) with the offerId of the app's own accept
  /// call; fallback `GET /driver/offers?status=claimed` (after the accept
  /// the server marks it claimed; there is no "accepted" status).
  /// Returns (ok, detail); a server field that is missing is not ok.
  Future<(bool, String)> _offerMoney(
    List<String>? card,
    (String, String)? fareText,
  ) async {
    final texts = card ?? const <String>[];
    bool hasIn(Iterable<String> list, Money m) => list.any(
      (t) => t.contains(m.formatted) || t.contains(TripRun.short(m)),
    );
    bool has(Money m) => hasIn(texts, m);
    Map? offer;
    final asked = <String>[];
    final offerId = _acceptedOfferId();
    if (offerId == null) {
      CheckLog.miss(
        'no recorded POST /api/v1/offers/{offerId}/accept (no offerId)',
      );
    } else {
      final (status, body) = await ask(
        '/api/v1/driver/offers/${Uri.encodeComponent(offerId)}',
      );
      asked.add('GET /driver/offers/{offerId} $status');
      final o = body is Map ? body['offer'] : null;
      if (o is Map) offer = o;
    }
    if (offer == null) {
      final (status, page) = await ask('/api/v1/driver/offers', {
        'status': 'claimed',
        'limit': '50',
      });
      asked.add('GET /driver/offers?status=claimed $status');
      final items = page is Map ? page['items'] : null;
      offer = items is List
          ? items
                .whereType<Map>()
                .where(
                  (o) =>
                      (offerId != null && o['offerId'] == offerId) ||
                      o['tripId'] == tripId,
                )
                .firstOrNull
          : null;
    }
    if (offer == null) {
      CheckLog.miss('server offer not found (${asked.join(', ')})');
    }
    if (card != null && fareText == null) {
      CheckLog.miss('"exclusive-fare" not on the card: card texts used');
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
        'server offer for the trip not found (${asked.join(', ')})',
      if (offer != null && offer['tripId'] != null && offer['tripId'] != tripId)
        'server offer ${offer['offerId']} is for another trip',
      if (offer != null && earnings == null)
        'server offer has no driverEarnings',
      if (fare == null) 'server sent no rider fare',
    ];
    final total = earnings == null
        ? null
        : pickupPay == null || pickupPay.isZero
        ? earnings
        : earnings + pickupPay;
    // The card's amount is its fare key; the other card texts only when
    // that key is not there (a radar card; noted as a miss above).
    final amountTexts = fareText == null ? texts : <String>[fareText.$2];
    final shown =
        total != null &&
        (hasIn(amountTexts, total) || hasIn(amountTexts, earnings!));
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
        '${problems.isEmpty ? '' : 'problems: ${problems.join('; ')}; '}'
        'card ${fareText?.$1 ?? 'fare key'}="${fareText?.$2}" driver amount='
        '${total?.formatted} (server driverEarnings=${earnings?.formatted} '
        'pickupPay=${pickupPay?.formatted}, via ${asked.join(', ')}) '
        'shown=$shown; rider fare ${fare?.formatted} shown=$fareShown'
        '${fare != null && (fare == total || fare == earnings) ? ' (same as the driver amount: not told apart)' : ''}';
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

  /// Opens the current trip's waybill during the trip, as a driver can:
  /// 1. the island's route cue (`island-route-cue` -> Route & options,
  ///    accept_ride.dart onRoute) then `current-trip-waybill-option`;
  /// 2. else the full sheet's trip card: `current-waybill-shortcut`, then
  ///    `current-trip-more` -> `current-trip-waybill-option`.
  /// Returns what it tried, for the FAIL line.
  Future<List<String>> _openWaybillDuring(Finder sheet) async {
    final tried = <String>[];
    final cue = byKey('island-route-cue');
    final option = byKey('current-trip-waybill-option');
    Future<bool> pickOption(String via) async {
      final open = await pumpUntil(
        tester,
        () => tester.any(option.hitTestable()),
        timeout: const Duration(seconds: 5),
      );
      if (!open) {
        CheckLog.miss('"current-trip-waybill-option" not shown after $via');
        return false;
      }
      return tapHit(tester, option, '"current-trip-waybill-option"');
    }

    Future<bool> opened() => pumpUntil(
      tester,
      () => shows(sheet),
      timeout: const Duration(seconds: 5),
    );
    // The island's route face comes back 2 s after a touch.
    await pumpUntil(
      tester,
      () => tester.any(cue.hitTestable()),
      timeout: const Duration(seconds: 4),
    );
    tried.add('island-route-cue');
    if (await tapHit(tester, cue, '"island-route-cue" (island route face)') &&
        await pickOption('island-route-cue') &&
        await opened()) {
      return tried;
    }
    if (_tripOptionsOpen()) await systemBack(tester);
    tried.add('current-waybill-shortcut (full face)');
    if (await tapTripControl(
          tester,
          'current-waybill-shortcut',
          face: 'full',
          timeout: const Duration(seconds: 8),
        ) &&
        await opened()) {
      return tried;
    }
    tried.add('current-trip-more (full face)');
    if (await tapTripControl(
          tester,
          'current-trip-more',
          face: 'full',
          timeout: const Duration(seconds: 8),
        ) &&
        await pickOption('current-trip-more')) {
      await opened();
    }
    return tried;
  }

  bool _tripOptionsOpen() => shows(byKey('trip-options-scroll'));

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
    final tried = <String>[];
    await watch.run(after ? 'waybill-after' : 'waybill-during', () async {
      if (after) {
        tried.add('ride-completed-waybill');
        final button = byKey('ride-completed-waybill');
        if (shows(button)) {
          await tester.ensureVisible(button.first);
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tapHit(tester, button, '"ride-completed-waybill"');
      } else {
        tried.addAll(await _openWaybillDuring(sheet));
      }
      await pumpUntil(
        tester,
        () => shows(sheet),
        timeout: const Duration(seconds: 10),
      );
    });
    if (!shows(sheet)) {
      log.fail(
        id,
        title,
        'the waybill "waybill-$tripId" did not open'
        '; tried: ${tried.join(' | ')}',
      );
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
