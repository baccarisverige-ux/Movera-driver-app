part of 'trip_run.dart';

/// L20 "one live connection" on a real phone (contract v0.18.122,
/// contract.json#driverOneStream; testlab_test `trip-one-stream`,
/// MOVERA_TL_SCENARIO=onestream).
///
/// No admin account exists for the test, so the zone's switch cannot be
/// turned on on staging. Instead the test's own HTTP client
/// ([RecordingClient.forceOneStream]) hands the app every
/// `GET /driver/config` answer with `realtime.oneStream: true`: the app
/// then picks its path exactly as for a real switch. Nothing in lib/ is
/// changed; the server serves `GET /driver/stream` whatever the switch says.
///
/// Checks:
/// * L20-OPEN: online -> `GET /driver/stream` open (200), no offer feed
///   (`/driver/offers/stream`) and no settings stream
///   (`/driver/config/stream`) open.
/// * L20-SETTINGS: the one stream is cut (as a network drop); the app
///   reconnects on it with its cursor; the test asks one config version
///   lower, so the server sends `config_published` on the one stream.
/// * BOOK / OFFER / ACCEPT as in the live trip, then L20-OFFER: the offer
///   came as an event on `/driver/stream` while no offer feed was open.
/// The trip is then closed by the usual clean-up.
extension _TripOneStream on TripRun {
  static const String _one = RecordingClient.oneStreamPath;
  static const String _offers = '/api/v1/driver/offers/stream';
  static const String _settings = '/api/v1/driver/config/stream';

  String _streams() =>
      'open: one=${rec.openCount(_one)} offers=${rec.openCount(_offers)} '
      'config=${rec.openCount(_settings)}';

  Future<void> _oneStreamScenario() async {
    await step('L20-OPEN', 'online opens only GET /driver/stream', () async {
      const title = 'online opens only GET /driver/stream';
      final config = rec.lastAnswer['/api/v1/driver/config'];
      final realtime = config is Map ? config['realtime'] : null;
      final switched = realtime is Map && realtime['oneStream'] == true;
      await pumpUntil(
        tester,
        () =>
            rec.openCount(_one) == 1 &&
            rec.openCount(_offers) == 0 &&
            rec.openCount(_settings) == 0,
        timeout: const Duration(seconds: 45),
      );
      final opens = calls(_one, method: 'GET').map((c) => c.status).toList();
      final ok =
          switched &&
          rec.openCount(_one) == 1 &&
          rec.openCount(_offers) == 0 &&
          rec.openCount(_settings) == 0;
      final detail =
          'config oneStream=$switched; ${_streams()}; '
          '/driver/stream answers=$opens';
      ok ? log.pass('L20-OPEN', title, detail) : log.fail('L20-OPEN', title, detail);
    });

    await step('L20-SETTINGS', 'settings event on the one stream', () async {
      const title = 'settings event (config_published) on the one stream';
      final before = rec.oneStreamKinds.length;
      final mark = rec.length;
      rec.lowerConfigCursorOnce = true;
      await rec.cutOneStream();
      bool came() => rec.oneStreamKinds
          .skip(before)
          .any((k) => k.$2 == 'config_published');
      await pumpUntil(tester, came, timeout: const Duration(seconds: 90));
      final reopened = calls(_one, method: 'GET', from: mark)
          .map((c) => c.status)
          .toList();
      final lowered = rec.loweredCursor != null;
      rec.lowerConfigCursorOnce = false;
      final ok =
          came() && lowered && rec.openCount(_settings) == 0;
      final detail =
          'reopened=$reopened cursor lowered=$lowered '
          'kinds=${rec.oneStreamKinds.skip(before).map((k) => k.$2).toList()}; '
          '${_streams()}';
      if (ok) {
        log.pass('L20-SETTINGS', title, detail);
      } else if (!lowered && reopened.isNotEmpty) {
        log.skip('L20-SETTINGS', title, 'NOT CHECKED: config version 0 '
            '(nothing lower to ask from); $detail');
      } else {
        log.fail('L20-SETTINGS', title, detail);
      }
    });

    final beforeBook = rec.oneStreamKinds.length;
    final offerFeedMark = rec.length;
    await step('BOOK', 'rider books a cash trip', () => _book('BOOK'));
    if (tripId == null) return;
    await step('OFFER', 'offer shows on the driver phone', _offerAndAccept);
    await step('L20-OFFER', 'the offer came on GET /driver/stream', () async {
      const title = 'the offer came on GET /driver/stream';
      final kinds = rec.oneStreamKinds
          .skip(beforeBook)
          .map((k) => k.$2)
          .toList();
      final offerFeed = calls(_offers, from: offerFeedMark).length;
      final ok = kinds.contains('offer_created') && offerFeed == 0;
      final detail =
          'kinds on one stream=$kinds; offer-feed opens since book=$offerFeed; '
          '${_streams()}';
      ok ? log.pass('L20-OFFER', title, detail) : log.fail('L20-OFFER', title, detail);
    });
  }
}
