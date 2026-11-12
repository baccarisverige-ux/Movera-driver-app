part of 'trip_run.dart';

/// Owner 2026-11-12 ("SCHEDULED (booked-for-later) rides too"): the
/// `trip-scheduled` scenario. The rider (HTTP) books for the shortest lead
/// staging allows (rider config booking.minAheadMin, contract default 15,
/// + 2 min). Inside DriverAppConfig.reservations.soonBeforeMin (30) the
/// server sends such a ride like a live one at once, so the offer shows on
/// Home; the accepted ride is listed in Scheduled rides; "Leave now"
/// (W3 startable from the server's mustBeOnlineAt) opens the trip, which
/// then runs the same steps as a live trip.
///
/// Cancel case first: ride A is booked, accepted, then cancelled by the
/// rider; the driver must lose it and see the notice (with the booked-ride
/// late-cancel fee when the server charges one). Then ride B runs.
extension _TripScheduled on TripRun {
  Future<void> _scheduledScenario() async {
    final config = await rider.config();
    final booking = config.map?['booking'];
    final minAhead = booking is Map && booking['minAheadMin'] is num
        ? (booking['minAheadMin'] as num).toInt()
        : 15;
    final lead = Duration(minutes: minAhead + 2);
    CheckLog.say(
      'STEP booked rides at +${lead.inMinutes} min (minAheadMin=$minAhead)',
    );

    // ---- A: book, accept, rider cancels --------------------------------
    await step(
      'SCHED-CANCEL-BOOK',
      'rider books ride A for later',
      () => _book('SCHED-CANCEL-BOOK', at: DateTime.now().add(lead)),
    );
    if (tripId != null) {
      await step(
        'SCHED-CANCEL',
        'rider cancels a held booked ride',
        _cancelCase,
      );
    }

    // ---- B: the full booked ride -----------------------------------------
    if (late) {
      return log.skip(
        'SCHED-BOOK',
        'booked ride B',
        'not run: time limit near',
      );
    }
    final at = DateTime.now().add(lead);
    await step(
      'SCHED-BOOK',
      'rider books ride B for later',
      () => _book('SCHED-BOOK', at: at),
    );
    if (tripId == null) return;
    await step(
      'SCHED-OFFER',
      'booked ride offered and accepted',
      () => _acceptBooked('SCHED-OFFER'),
    );
    if (!accepted) return;
    await step(
      'SCHED-LIST',
      'Scheduled rides shows it right',
      () => _scheduledList(at),
    );
    await step(
      'SCHED-REMINDER',
      'pickup reminder notice',
      () => _reminder(lead),
    );
    await step('SCHED-LEAVE', 'Leave now opens the trip', _leaveNow);
    if (tripScreen()?.tripId != tripId) return;
    await _tripSteps(extras: false);
  }

  /// Offer control on Home -> accept; ok when the server says accepted
  /// (a booked ride stays "accepted" until the driver leaves) or the trip
  /// opened at once.
  Future<void> _acceptBooked(String id) async {
    accepted = false;
    const title = 'booked ride offered and accepted';
    String? control;
    await watch.run('$id:home->offer', () async {
      await pumpUntil(
        tester,
        () => (control = offerControl()) != null,
        timeout: const Duration(seconds: 90),
      );
    });
    if (control == null) {
      final view = await riderView();
      log.fail(
        id,
        title,
        'no offer control on Home in 90 s; server ${view?['status']} '
        '(a booked ride further than soonBeforeMin goes to the Scheduled '
        'rides list instead)',
      );
      return;
    }
    await watch.run('$id:accept', () async {
      await tester.tap(byKey(control!).first, warnIfMissed: false);
      await wait(tester, const Duration(seconds: 3));
    });
    final status = await waitStatus({
      'accepted',
      'driver_to_pickup',
    }, const Duration(seconds: 30));
    accepted = status == 'accepted' || status == 'driver_to_pickup';
    final detail =
        '$control; server=$status; trip screen open=${tripScreen()?.tripId == tripId}';
    accepted ? log.pass(id, title, detail) : log.fail(id, title, detail);
  }

  Future<void> _cancelCase() async {
    const title = 'rider cancel: driver loses it, sees the notice';
    await _acceptBooked('SCHED-CANCEL-OFFER');
    if (!accepted) {
      log.skip('SCHED-CANCEL', title, 'not run: ride A was not accepted');
      return;
    }
    final id = tripId!;
    final view = await riderView();
    final cancel = await rider.cancel(
      id,
      (view!['version'] as num).toInt(),
      'plans_changed',
    );
    final c = cancel.map?['cancellation'];
    final fee = c is Map && c['fee'] is Map
        ? Money.fromJson(Map<String, dynamic>.from(c['fee'] as Map))
        : null;
    final notice = <String>[];
    await watch.run('sched-cancelled', () async {
      await pumpUntil(tester, () {
        final texts = textsUnder(find.byType(DriverHome));
        if (fee != null && !fee.isZero) {
          notice
            ..clear()
            ..addAll(
              texts.where(
                (t) =>
                    t.contains(fee.formatted) || t.contains(TripRun.short(fee)),
              ),
            );
        }
        return tripScreen() == null &&
            (fee == null || fee.isZero || notice.isNotEmpty);
      }, timeout: const Duration(seconds: 30));
    });
    await backToHome(tester);
    final listed = await _inScheduledList();
    final good =
        cancel.ok &&
        tripScreen() == null &&
        listed == false &&
        (fee == null || fee.isZero || notice.isNotEmpty);
    final detail =
        'rider cancel ${cancel.short} feeKind=${c is Map ? c['feeKind'] : null} '
        'fee=${fee?.formatted ?? 'none'}; driver trip screen gone=${tripScreen() == null}; '
        'in Scheduled rides=$listed; fee in a Home notice=${notice.isNotEmpty}';
    good
        ? log.pass('SCHED-CANCEL', title, detail)
        : log.fail('SCHED-CANCEL', title, detail);
    tripId = null;
  }

  /// Opens Scheduled rides from the menu; true/false = the test pickup's
  /// card is there or not, null = the page did not open. Leaves the page
  /// open when [stay].
  Future<bool?> _inScheduledList({bool stay = false}) async {
    await backToHome(tester);
    final menu = find.byTooltip(tr.menu);
    if (!await pumpUntil(
      tester,
      () => shows(menu),
      timeout: const Duration(seconds: 5),
    )) {
      return null;
    }
    await tester.tap(menu.first, warnIfMissed: false);
    await pumpUntil(
      tester,
      () => shows(byKey('driver-side-menu')),
      timeout: const Duration(seconds: 5),
    );
    final entry = find.descendant(
      of: byKey('driver-side-menu'),
      matching: find.text(tr.scheduledRides),
    );
    if (!shows(entry)) {
      await backToHome(tester);
      return null;
    }
    await tester.ensureVisible(entry.first);
    await tester.tap(entry.first, warnIfMissed: false);
    final card = byKey('scheduled-booked-${TripRun.pickupName}');
    final found = await pumpUntil(
      tester,
      () => shows(card),
      timeout: const Duration(seconds: 10),
    );
    if (!stay) await backToHome(tester, tries: 4);
    return found;
  }

  Future<void> _scheduledList(DateTime at) async {
    const title = 'Scheduled rides: time, pickup, price = server';
    bool? found;
    await watch.run(
      'sched-list',
      () async => found = await _inScheduledList(stay: true),
    );
    final card = byKey('scheduled-booked-${TripRun.pickupName}');
    final view = await riderView();
    final fareJson = view?['fare'];
    final fare = fareJson is Map
        ? Money.fromJson(Map<String, dynamic>.from(fareJson))
        : null;
    final local = at.toLocal();
    final hhmm =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final scope = find.ancestor(of: card, matching: find.byType(InkWell));
    final texts = shows(scope) ? textsUnder(scope.first) : <String>[];
    final timeShown =
        texts.any((t) => t.contains(hhmm)) ||
        textsUnder(card).any((t) => t.contains(hhmm));
    final priceShown =
        fare != null &&
        texts.any(
          (t) => t.contains(fare.formatted) || t.contains(TripRun.short(fare)),
        );
    final detail =
        'page=${found != null} card=$found time $hhmm shown=$timeShown '
        'price ${fare?.formatted} shown=$priceShown (driver price may differ: '
        'reported) server=${view?['status']}';
    found == true && timeShown
        ? log.pass('SCHED-LIST', title, detail)
        : log.fail('SCHED-LIST', title, detail);
  }

  Future<void> _reminder(Duration lead) async {
    const title = 'pickup reminder notice';
    if (shows(byKey('scheduled-reminder'))) {
      return log.pass(
        'SCHED-REMINDER',
        title,
        'reminder note shows on Scheduled rides',
      );
    }
    final config = rec.lastAnswer['/api/v1/driver/config'];
    final res = config is Map ? config['reservations'] : null;
    log.skip(
      'SCHED-REMINDER',
      title,
      'NOT CHECKED: the reminders come reminderMin before the pickup '
          '(contract bookLater, owner M6: [120]; zone document '
          '${res is Map ? 'has reservations' : 'not read'}), the shortest '
          'booking staging allows is ${lead.inMinutes} min ahead',
    );
  }

  /// Opens the card's details and taps "Leave now" (startable from the
  /// server's mustBeOnlineAt); the trip screen must open on this trip.
  Future<void> _leaveNow() async {
    const title = 'Leave now opens the booked trip';
    final card = byKey('scheduled-booked-${TripRun.pickupName}');
    if (!shows(card)) await _inScheduledList(stay: true);
    await watch.run('sched-leave', () async {
      if (shows(card)) {
        await tester.tap(card.first, warnIfMissed: false);
        await pumpUntil(
          tester,
          () => shows(byKey('scheduled-leave-start')),
          timeout: const Duration(seconds: 15),
        );
      }
      if (shows(byKey('scheduled-leave-start'))) {
        await tester.ensureVisible(byKey('scheduled-leave-start').first);
        await tester.tap(
          byKey('scheduled-leave-start').first,
          warnIfMissed: false,
        );
      }
      await pumpUntil(
        tester,
        () => tripScreen()?.tripId == tripId,
        timeout: const Duration(seconds: 40),
      );
    });
    final status = await waitStatus({
      'driver_to_pickup',
    }, const Duration(seconds: 20));
    final detail =
        'leave-now control=${shows(byKey('scheduled-leave-countdown')) || tripScreen() != null} '
        'trip screen=${tripScreen()?.tripId == tripId} server=$status';
    tripScreen()?.tripId == tripId && status == 'driver_to_pickup'
        ? log.pass('SCHED-LEAVE', title, detail)
        : log.fail('SCHED-LEAVE', title, detail);
  }
}
