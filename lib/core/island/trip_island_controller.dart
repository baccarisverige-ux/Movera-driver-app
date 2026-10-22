import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/routing/route_instruction.dart';

enum TripIslandKind { guidance, arrival, waitingTimer, waitingMessage, status }

class TripIslandInput {
  const TripIslandInput({
    required this.status,
    required this.address,
    required this.waitingMessage,
    this.banner,
    this.arrival,
    this.arrived = false,
    this.waitingSeconds,
    this.paidWait = false,
    this.paidSeconds,
    this.waitingAtStop = false,
    this.navigationStatus,
    this.reroutes = 0,
  });
  final NavigationBanner? banner;
  final String status, address, waitingMessage;
  final String? arrival, navigationStatus;
  final bool arrived, paidWait, waitingAtStop;
  final int? waitingSeconds, paidSeconds;

  /// Routes replaced after the driver left the route; each new one says
  /// "Route updated". A first route, a retry or a silent refresh does not.
  final int reroutes;
}

class TripIslandFace {
  const TripIslandFace(this.kind, this.title, this.subtitle, this.identity);
  final TripIslandKind kind;
  final String title, subtitle, identity;
}

/// Chooses a single truthful message. Never changes trip or camera state.
/// Clock ticks and GPS updates do not restart presentation timers.
class TripIslandController extends ChangeNotifier {
  TripIslandController(TripIslandInput input) : _input = input {
    _cycle();
  }
  TripIslandInput _input;
  Timer? _idle, _waitingCycle, _noticeTimer;
  TripIslandFace? _notice;
  bool _defaultFace = false;
  bool waitingMessageFace = false;
  String? get _fault => _input.navigationStatus ?? _input.banner?.status;
  bool get defaultFace => _defaultFace && !(_fault?.isNotEmpty ?? false);
  int _pointers = 0;
  int _touchEpoch = 0;
  bool _disposed = false;

  void update(TripIslandInput input) {
    if (_disposed) return;
    final wasWaiting = _input.waitingSeconds != null;
    final changedWait =
        wasWaiting != (input.waitingSeconds != null) ||
        _input.waitingAtStop != input.waitingAtStop;
    final previous = _input;
    final previousFault = previous.navigationStatus ?? previous.banner?.status;
    final fault = input.navigationStatus ?? input.banner?.status;
    _input = input;
    if (fault?.isNotEmpty ?? false) {
      _defaultFace = false;
      _idle?.cancel();
    }
    if (wasWaiting && input.waitingSeconds == null) {
      _showNotice(previous.waitingAtStop ? input.status : tr.tripStarted);
    } else if (input.reroutes > previous.reroutes) {
      // Only after a real reroute. It never hides a maneuver (see [face]).
      _showNotice(tr.routeUpdated);
    } else if (previousFault != null &&
        fault == null &&
        _isLocationFault(previousFault)) {
      _showNotice(tr.gpsRestored);
    } else if (wasWaiting &&
        input.waitingSeconds != null &&
        previous.waitingAtStop == input.waitingAtStop &&
        previous.waitingMessage != input.waitingMessage) {
      _showNotice(input.waitingMessage);
    }
    if (changedWait) {
      waitingMessageFace = false;
      _cycle();
    }
    notifyListeners();
  }

  /// The GPS warning, in whatever language it was shown: "GPS restored"
  /// follows it, never a route fault.
  static bool _isLocationFault(String fault) =>
      fault == tr.locationUpdatingEllipsis || fault.contains('Location');

  void _showNotice(String title) {
    _noticeTimer?.cancel();
    _notice = TripIslandFace(TripIslandKind.status, title, '', 'notice-$title');
    _noticeTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      _notice = null;
      notifyListeners();
    });
  }

  void hold() {
    if (_disposed) return;
    _pointers++;
    _touchEpoch++;
    _idle?.cancel();
  }

  void release() {
    if (_disposed || _pointers == 0) return;
    _pointers--;
    if (_pointers != 0) return;
    final epoch = ++_touchEpoch;
    scheduleMicrotask(() {
      if (_disposed || _pointers != 0 || _touchEpoch != epoch) return;
      if (_fault?.isNotEmpty ?? false) return;
      _defaultFace = true;
      notifyListeners();
      _idle?.cancel();
      _idle = Timer(const Duration(seconds: 2), () {
        if (_disposed || _pointers != 0 || _touchEpoch != epoch) return;
        _defaultFace = false;
        notifyListeners();
      });
    });
  }

  void _cycle() {
    _waitingCycle?.cancel();
    if (_input.waitingSeconds == null) return;
    _waitingCycle = Timer(Duration(seconds: waitingMessageFace ? 2 : 8), () {
      if (_disposed) return;
      waitingMessageFace = !waitingMessageFace;
      notifyListeners();
      _cycle();
    });
  }

  TripIslandFace get face {
    final i = _input;
    // Persistent location/reroute faults must not be hidden by an old banner.
    final fault = i.navigationStatus ?? i.banner?.status;
    if (fault != null && fault.isNotEmpty) {
      return TripIslandFace(TripIslandKind.status, fault, '', 'status-$fault');
    }
    final b = i.banner;
    final maneuver = b != null && b.symbol.isManeuver;
    if (_notice != null && (i.waitingSeconds != null || !maneuver)) {
      return _notice!;
    }
    if (i.waitingSeconds != null) {
      if (waitingMessageFace) {
        return TripIslandFace(
          TripIslandKind.waitingMessage,
          i.waitingMessage,
          '',
          'waiting-message-${i.waitingAtStop}',
        );
      }
      final seconds = i.paidWait
          ? (i.paidSeconds ?? i.waitingSeconds!)
          : i.waitingSeconds!;
      return TripIslandFace(
        TripIslandKind.waitingTimer,
        clock(seconds),
        i.waitingAtStop
            ? tr.waitingAtStop
            : i.paidWait
            ? tr.paidWaiting
            : tr.waitingTime,
        'waiting-timer-${i.waitingAtStop}-${i.paidWait}',
      );
    }
    // A real maneuver beats proximity copy until the final arrival instruction.
    if (i.arrival != null && !maneuver) {
      return TripIslandFace(
        TripIslandKind.arrival,
        i.arrived ? tr.nearValue(i.arrival!.toLowerCase()) : tr.arrivingSoon,
        i.address,
        'arrival-${i.arrival}',
      );
    }
    return TripIslandFace(
      TripIslandKind.guidance,
      b?.primary ?? i.status,
      [
        if (b != null &&
            b.distanceLabel.isNotEmpty &&
            !b.primary.contains(b.distanceLabel))
          b.distanceLabel,
        if (b?.roadName?.isNotEmpty ?? false) b!.roadName!,
      ].join(' · '),
      'guidance-${b?.symbol.name}-${b?.roadName}-${b?.exitNumber}',
    );
  }

  static String clock(int value) {
    final s = value < 0 ? 0 : value;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _disposed = true;
    _touchEpoch++;
    _idle?.cancel();
    _waitingCycle?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}

/// Which point the trip is heading to.
enum TripLeg { pickup, stop, dropoff }

enum TripStripKind { eta, lanes, message }

/// What the island's lighter bottom strip may say right now.
class TripStripInput {
  const TripStripInput({
    this.leg,
    this.stopLabel,
    this.etaMinutes,
    this.bags = 0,
    this.nextTripFare,
    this.pickupSide,
    this.toll = false,
    this.laneKey,
  });

  final TripLeg? leg;

  /// "Stop 1" while heading to that stop.
  final String? stopLabel;
  final int? etaMinutes;

  /// Bags the rider said they bring (from the booking).
  final int bags;

  /// Fare of a just-secured next trip ("132 kr").
  final String? nextTripFare;

  /// 'left' / 'right' when the route knows the pickup's side of the street.
  final String? pickupSide;

  /// The road after the next maneuver has a toll.
  final bool toll;

  /// Identity of the next maneuver's lanes when they matter.
  final String? laneKey;
}

class TripStripItem {
  const TripStripItem(this.kind, [this.text = '']);
  final TripStripKind kind;
  final String text;

  static const eta = TripStripItem(TripStripKind.eta);

  @override
  bool operator ==(Object other) =>
      other is TripStripItem && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);
}

/// Rotates the strip: ETA + progress by default, lane guidance while the
/// lanes matter (~6 s), short messages (4 s) only at the moment they are
/// true, then back to the ETA. Nothing plays while the strip is tucked.
class TripStripController extends ChangeNotifier {
  TripStripController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const messageTime = Duration(seconds: 4);
  static const laneTime = Duration(seconds: 6);

  /// "Arriving in N min" once per drop-off leg, inside this window.
  static const arrivingMinutes = 10;

  final DateTime Function() _clock;
  TripStripInput? _last;
  final _queue = <TripStripItem>[];
  TripStripItem _current = TripStripItem.eta;
  Timer? _timer;
  bool _hidden = false, _disposed = false, _arrivingSaid = false;
  int? _bestEta;

  TripStripItem get current => _current;

  void update(TripStripInput next, {bool hidden = false}) {
    if (_disposed) return;
    final last = _last;
    _last = next;
    // Stop to stop stays TripLeg.stop: the stop label tells the legs apart.
    final newLeg =
        last == null ||
        last.leg != next.leg ||
        last.stopLabel != next.stopLabel;
    if (newLeg) {
      _arrivingSaid = false;
      _bestEta = null;
    }
    if (hidden != _hidden) {
      _hidden = hidden;
      if (hidden) {
        // Tucked under the island: drop what was planned, it is stale.
        _queue.clear();
        _timer?.cancel();
        _show(TripStripItem.eta);
      }
    }
    if (_hidden) return;

    if (newLeg && next.leg == TripLeg.pickup && next.bags > 0) {
      _say(tr.riderBags(next.bags));
    }
    if (newLeg && next.leg == TripLeg.stop && next.stopLabel != null) {
      _say(tr.stopNext(next.stopLabel!));
    }
    final eta = next.etaMinutes;
    if (eta != null) {
      final best = _bestEta;
      if (best != null && eta - best >= 2) {
        _say(tr.trafficAheadValueMin(eta - best));
        _bestEta = eta;
      } else if (best == null || eta < best) {
        _bestEta = eta;
      }
      if (next.leg == TripLeg.dropoff &&
          !_arrivingSaid &&
          eta <= arrivingMinutes &&
          eta >= 3) {
        _arrivingSaid = true;
        final at = _clock().add(Duration(minutes: eta));
        String two(int v) => v.toString().padLeft(2, '0');
        _say(tr.arrivingInEtaMinTimeTime2(eta, two(at.hour), two(at.minute)));
      }
    }
    if (last != null &&
        last.nextTripFare == null &&
        next.nextTripFare != null) {
      _say(tr.nextTripSecuredNextTripFare(next.nextTripFare!));
    }
    if (next.leg == TripLeg.pickup &&
        next.pickupSide != null &&
        last?.pickupSide != next.pickupSide) {
      // The side is data ('left' / 'right'); the words are the driver's.
      _say(next.pickupSide == 'left'
          ? tr.pickupOnLeftSide
          : tr.pickupOnRightSide);
    }
    if (next.toll && !(last?.toll ?? false)) _say(tr.tollAhead);

    final lanes = next.laneKey;
    if (lanes != null && lanes != last?.laneKey) {
      // Lanes are time-critical: they go first and cut a message short.
      _queue.removeWhere((i) => i.kind == TripStripKind.lanes);
      _queue.insert(0, TripStripItem(TripStripKind.lanes, lanes));
      if (_current.kind != TripStripKind.lanes) _advance();
    } else if (lanes == null && _current.kind == TripStripKind.lanes) {
      _advance();
    }
  }

  void _say(String text) {
    final item = TripStripItem(TripStripKind.message, text);
    if (_current == item || _queue.contains(item)) return;
    _queue.add(item);
    if (_current.kind == TripStripKind.eta) _advance();
  }

  void _advance() {
    _timer?.cancel();
    if (_queue.isEmpty) {
      _show(TripStripItem.eta);
      return;
    }
    final item = _queue.removeAt(0);
    _show(item);
    _timer = Timer(
      item.kind == TripStripKind.lanes ? laneTime : messageTime,
      () {
        if (!_disposed) _advance();
      },
    );
  }

  void _show(TripStripItem item) {
    if (_current == item) return;
    _current = item;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
