import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

/// D4 (fix plan 2026-11-13, owner 12:22 UTC "Show \"No connection\""):
/// whether Home's island says "No connection" because the offer feed has
/// been down for more than [downAfter] while the driver is online.
///
/// An offer made while the feed is down can run out before the driver
/// sees it (sup4-driver D4), so the island stops looking like "Finding
/// trips" then. The feed back up takes the line away at once. A dispatch
/// with no feed (the demo) never shows it.
class OfferFeedDownWatch extends ChangeNotifier {
  OfferFeedDownWatch(
    OfferFeedHealth? feed, {
    this.downAfter = const Duration(seconds: 10),
  }) : _feed = feed {
    _live = feed?.feedLive ?? true;
    _changes = feed?.watchFeedLive().listen((live) {
      _live = live;
      if (_update()) notifyListeners();
    });
  }

  /// Home's watch (D4) of [dispatch]'s offer feed, calling [onChange]
  /// when the line comes or goes; a dispatch without a feed (the demo)
  /// never says "No connection".
  factory OfferFeedDownWatch.of(
    DispatchRepository dispatch,
    VoidCallback onChange,
  ) => OfferFeedDownWatch(switch (dispatch) {
    final OfferFeedHealth feed => feed,
    _ => null,
  })..addListener(onChange);

  /// Owner: "more than 10 s".
  final Duration downAfter;

  final OfferFeedHealth? _feed;
  StreamSubscription<bool>? _changes;
  Timer? _timer;
  bool _online = false;
  bool _live = true;
  bool _down = false;

  /// The island says "No connection" now.
  bool get down => _down;

  /// Called on every build of the island with whether the driver is
  /// online on Home with no trip. Starts or stops the wait without
  /// notifying: the caller is building with the new value already.
  bool sync(bool online) {
    _online = online;
    _update();
    return _down;
  }

  /// True when [down] changed.
  bool _update() {
    if (_feed == null) return false;
    if (!_online || _live) {
      _timer?.cancel();
      _timer = null;
      if (!_down) return false;
      _down = false;
      return true;
    }
    if (!_down && _timer == null) {
      _timer = Timer(downAfter, () {
        _timer = null;
        if (!_online || _live || _down) return;
        _down = true;
        notifyListeners();
      });
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
