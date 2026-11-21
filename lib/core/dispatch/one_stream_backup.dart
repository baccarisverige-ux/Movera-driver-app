part of 'api_dispatch_repository.dart';

/// L20 stream backup (contract v0.18.150, contract.json#driverOneStreamFallback;
/// owner 2026-11-21 "Switch to old two (Rec.)": "when first down we can use
/// second as backup"). Own file (Rule 25: api_dispatch_repository.dart size).
///
/// - [_countOneTry]: failed tries of `GET /driver/stream` in a row (D2: a
///   200 alone is not connected). At `failuresInARow` the two old streams
///   open at once and stay for `retryOneAfterMinutes`.
/// - Way back ([_startReturn]): when that time is up the one stream is
///   opened NEXT TO the working old streams (offers keep coming on the old
///   feed). Only once it counts as connected (a real event, or
///   [streamConnectedAfter] up) is it adopted and the old two closed
///   ([_adopt]); one failed return try means another backup period
///   ([_returnFailed]).
/// - Kept in memory only: an app restart asks the one stream first again.

/// Who a feed's lines belong to: the main feed, or the return try. Its
/// [isCurrent] and [lost] change when a return try is adopted.
class _FeedOwner {
  _FeedOwner(this.isCurrent, this.lost);
  bool Function() isCurrent;
  void Function() lost;

  /// Set on a return try: runs once on its first real event.
  void Function()? connected;
  Timer? idle;
  Timer? upFor;
  StreamSubscription<String>? sub;
  DateTime? openedAt;
}

extension _OneStreamBackup on ApiDispatchRepository {
  OneStreamFallback get _rule =>
      oneStream?.fallback() ?? const OneStreamFallback();

  /// Whether this connect uses the two old streams as the backup. With no
  /// timer and no return try running (after a disconnect) the time left is
  /// read from the clock and the timer armed again for it.
  bool _stillOnBackup() {
    final until = _backupUntil;
    if (until == null) return false;
    if (_backupEnd != null || _probe != null) return true;
    final left = until.difference(_now());
    if (left <= Duration.zero) {
      _clearBackup();
      DriverLog.info(
        'offer_feed.one_stream_backup_end: backup time over; asking GET /driver/stream again',
      );
      return false;
    }
    _armBackupEnd(left);
    return true;
  }

  void _armBackupEnd(Duration after) {
    _backupEnd?.cancel();
    _backupEnd = _backupTimer(after, () {
      // The end-of-backup step runs here, whatever the wall clock says.
      _backupEnd = null;
      _startReturn();
    });
  }

  /// Stops the timer and any return try (offline, dispose); [_backupUntil]
  /// stays, so the next connect knows the time left.
  void _pauseBackup() {
    _backupEnd?.cancel();
    _backupEnd = null;
    _dropProbe();
  }

  /// Forgets the backup (another driver, or its time is over).
  void _clearBackup() {
    _pauseBackup();
    _backupUntil = null;
    _oneFailures = 0;
  }

  void _dropProbe() {
    final probe = _probe;
    _probe = null;
    if (probe == null) return;
    probe.idle?.cancel();
    probe.upFor?.cancel();
    unawaited(probe.sub?.cancel());
  }

  /// Counts the one-stream try that just ended; true when it starts the
  /// backup (the caller then opens the two old streams at once).
  bool _countOneTry({required bool counts}) {
    final opened = _openedAt;
    final connected =
        _oneConnected ||
        (opened != null && _now().difference(opened) >= streamConnectedAfter);
    if (connected) {
      _oneFailures = 0;
      return false;
    }
    if (!counts) return false;
    final rule = _rule;
    if (++_oneFailures < rule.failuresInARow) return false;
    _oneFailures = 0;
    _oneMode = false;
    _backupUntil = _now().add(rule.retryOneAfter);
    _armBackupEnd(rule.retryOneAfter);
    DriverLog.info(
      'offer_feed.one_stream_backup: ${rule.failuresInARow} failed tries of '
      'GET /driver/stream in a row; the two old streams for '
      '${rule.retryOneAfterMinutes} min',
    );
    oneStream?.attached(false);
    return true;
  }

  /// The backup time is up: try the one stream next to the old two.
  void _startReturn() {
    final link = oneStream;
    if (!_feedOpen ||
        !_wanted ||
        _disposed ||
        link == null ||
        _oneStreamRefused ||
        _oneMode ||
        !link.wanted()) {
      // Nothing to protect (offline, switch off): the next connect decides.
      _clearBackup();
      return;
    }
    late final _FeedOwner owner;
    owner = _FeedOwner(
      () => identical(_probe, owner),
      () => _returnFailed(owner),
    );
    _probe = owner;
    unawaited(_openReturn(owner, link));
  }

  Future<void> _openReturn(_FeedOwner owner, OneStreamLink link) async {
    final http.StreamedResponse response;
    try {
      final headers = await _headers();
      if (!identical(_probe, owner)) return;
      final zone = link.zoneId();
      final cursor = '$_lastSequence.${link.configVersion()}';
      final request =
          http.Request(
              'GET',
              _uri('/driver/stream', {
                if (zone != null) 'zoneId': zone,
                if (_hasCursor) 'after': cursor,
              }),
            )
            ..headers.addAll({
              ...headers,
              'Accept': 'text/event-stream',
              if (_hasCursor) 'Last-Event-ID': cursor,
            });
      response = await _client
          .send(request)
          .timeout(ApiDispatchRepository.requestTimeout);
    } catch (_) {
      _returnFailed(owner);
      return;
    }
    if (!identical(_probe, owner)) {
      ApiDispatchRepository._discard(response);
      return;
    }
    if (response.statusCode != 200) {
      var refused = false;
      try {
        final body = await response.stream.bytesToString().timeout(
          ApiDispatchRepository.requestTimeout,
        );
        if (response.statusCode == 404) {
          final decoded = jsonDecode(body);
          refused = !(decoded is Map && decoded['reason'] == 'zone_not_found');
        }
      } catch (_) {
        refused = response.statusCode == 404;
      }
      if (!identical(_probe, owner)) return;
      if (refused) {
        // An older server: the two streams until the app restarts.
        _oneStreamRefused = true;
        _clearBackup();
        return;
      }
      if (response.statusCode == 401) {
        try {
          await renewSession?.call();
        } catch (_) {
          // The next return try asks again.
        }
      }
      _returnFailed(owner);
      return;
    }
    owner.openedAt = _now();
    owner.connected = () => _adopt(owner, link);
    owner.upFor = Timer(streamConnectedAfter, () => _adopt(owner, link));
    owner.sub = _listenFeed(response, owner, link);
  }

  /// The return try failed: the old two stay, for another backup period.
  void _returnFailed(_FeedOwner owner) {
    if (!identical(_probe, owner)) return;
    _dropProbe();
    if (_disposed) return;
    final rule = _rule;
    _backupUntil = _now().add(rule.retryOneAfter);
    _armBackupEnd(rule.retryOneAfter);
    DriverLog.info(
      'offer_feed.one_stream_backup: the return try failed; the two old '
      'streams for ${rule.retryOneAfterMinutes} min more',
    );
  }

  /// The return try counts as connected: it becomes the feed, and the two
  /// old streams close (the settings close their own).
  void _adopt(_FeedOwner owner, OneStreamLink link) {
    if (!identical(_probe, owner)) return;
    _probe = null;
    owner.upFor?.cancel();
    owner.connected = null;
    _backupUntil = null;
    _backupEnd?.cancel();
    _backupEnd = null;
    final generation = ++_generation;
    _reconnect?.cancel();
    _reconnect = null;
    _stopIdle();
    final old = _feed;
    owner
      ..isCurrent = (() => generation == _generation)
      ..lost = _feedLost;
    _main = owner;
    _feed = owner.sub;
    _openedAt = owner.openedAt;
    _lastLine = _now();
    _oneMode = true;
    _oneConnected = true;
    _oneFailures = 0;
    _reconnects = 0;
    unawaited(old?.cancel());
    link.attached(true);
    link.opened();
    _setLive(true);
    DriverLog.info(
      'offer_feed.one_stream_backup_end: GET /driver/stream connected; '
      'the two old streams closed',
    );
  }
}
