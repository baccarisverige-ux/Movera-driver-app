import 'package:flutter/foundation.dart';
import 'package:movera/core/session/driver_session_repository.dart';

/// Canonical driver availability (P1 / D10).
enum DriverOnlineStatus { offline, goingOnline, online, onTrip, suspended }

/// Single source of truth for driver availability during one app/session flow.
///
/// The composition root owns this controller and injects it into screens that
/// need driver availability. A backend synchronization adapter can attach here
/// later without giving individual screens their own online flags.
class DriverSessionController extends ChangeNotifier {
  DriverSessionController({
    bool initialOnline = false,
    DriverSessionRepository? repository,
  }) : _status = initialOnline
           ? DriverOnlineStatus.online
           : DriverOnlineStatus.offline,
       _repository = repository ?? MemoryDriverSessionRepository();

  final DriverSessionRepository _repository;
  DriverOnlineStatus _status;
  bool _resumeHomeAfterTrip = false;
  String? _activeTripId;
  // Availability to return to when the active trip ends. A trip never turns a
  // suspended or deliberately offline driver back into an available one.
  DriverOnlineStatus _statusBeforeTrip = DriverOnlineStatus.online;
  bool _suspendAfterTrip = false;
  bool _offlineAfterTrip = false;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();
  Object? persistenceError;
  bool get availableForOffers => _status == DriverOnlineStatus.online;
  String? get activeTripId => _activeTripId;

  void _save(Future<void> Function() operation) {
    _writes = _writes
        .then((_) async {
          await operation();
          // A later successful write resolves any visible persistence failure.
          if (!_disposed && persistenceError != null) {
            persistenceError = null;
            notifyListeners();
          }
        })
        .catchError((Object error) {
          persistenceError = error;
          if (!_disposed) {
            notifyListeners();
          }
        });
  }

  void beginTrip(String tripId) {
    // A duplicate widget mount or a stale navigation action must not replace
    // the active trip or reset its return-to-online intent.
    if (_disposed ||
        tripId.trim().isEmpty ||
        (_activeTripId != null && _activeTripId != tripId)) {
      return;
    }
    if (_activeTripId == tripId) return;
    // A return-to-Home hint from the previous ride must never be consumed
    // while a new ride is occupying this session.
    _resumeHomeAfterTrip = false;
    _revision++;
    if (_activeTripId == null) {
      _statusBeforeTrip = _status == DriverOnlineStatus.onTrip
          ? DriverOnlineStatus.online
          : _status;
    }
    if (_status == DriverOnlineStatus.suspended) {
      _suspendAfterTrip = true;
    }
    _activeTripId = tripId;
    _status = DriverOnlineStatus.onTrip;
    notifyListeners();
    _save(() => _repository.saveOnline(false));
  }

  DriverOnlineStatus get status => _status;

  bool get isOnline =>
      _status == DriverOnlineStatus.online ||
      _status == DriverOnlineStatus.onTrip;

  /// During a trip: true unless the driver goes offline or on hold when
  /// it ends (missed offers, "go offline", suspension). Otherwise the same
  /// as [availableForOffers].
  bool get availableAfterTrip => _activeTripId == null
      ? availableForOffers
      : !_offlineAfterTrip &&
          !_suspendAfterTrip &&
          _status != DriverOnlineStatus.suspended &&
          _statusBeforeTrip == DriverOnlineStatus.online;

  bool get isGoingOnline => _status == DriverOnlineStatus.goingOnline;

  bool get isSuspended => _status == DriverOnlineStatus.suspended;

  /// Bool availability command. During a trip it records what should happen
  /// when the trip ends instead of interrupting the trip.
  void setOnline(bool value) {
    if (_disposed) {
      return;
    }
    if (_activeTripId != null) {
      if (_offlineAfterTrip == !value) return;
      _offlineAfterTrip = !value;
      notifyListeners(); // [availableAfterTrip] changed.
      return;
    }
    if (isSuspended && value) {
      return;
    }
    _revision++;
    final next = value ? DriverOnlineStatus.online : DriverOnlineStatus.offline;
    if (_status == next) {
      return;
    }
    _status = next;
    notifyListeners();
    _save(() => _repository.saveOnline(value));
  }

  /// Home connecting animation. Driver is not available for offers yet.
  void beginGoingOnline() {
    if (_disposed || _activeTripId != null || isSuspended) {
      return;
    }
    _revision++;
    if (_status == DriverOnlineStatus.goingOnline) {
      return;
    }
    _status = DriverOnlineStatus.goingOnline;
    notifyListeners();
    _save(() => _repository.saveOnline(false));
  }

  void completeGoingOnline() {
    if (_disposed || _status != DriverOnlineStatus.goingOnline) {
      return;
    }
    _revision++;
    _status = DriverOnlineStatus.online;
    notifyListeners();
    _save(() => _repository.saveOnline(true));
  }

  void suspend() {
    if (_disposed) {
      return;
    }
    if (_activeTripId != null) {
      // Suspension takes effect after the active ride, not mid-journey.
      _suspendAfterTrip = true;
      return;
    }
    if (_status == DriverOnlineStatus.suspended) {
      return;
    }
    _revision++;
    _status = DriverOnlineStatus.suspended;
    notifyListeners();
    _save(() => _repository.saveOnline(false));
  }

  /// D11: crash / cold start is always offline. Going online is explicit.
  Future<void> restore() async {
    if (_disposed || _activeTripId != null) {
      return;
    }
    final revision = ++_revision;
    try {
      final stored = await _repository.readOnline();
      if (_disposed || revision != _revision) {
        return;
      }
      if (stored == true) {
        _save(() => _repository.saveOnline(false));
        await _writes;
      }
      if (_disposed || revision != _revision) {
        return;
      }
      if (_status == DriverOnlineStatus.offline) {
        return;
      }
      _status = DriverOnlineStatus.offline;
      notifyListeners();
    } catch (error) {
      if (_disposed || revision != _revision) {
        return;
      }
      persistenceError = error;
      // Failed recovery must not leave an initial-online session available.
      if (_activeTripId == null) {
        _status = DriverOnlineStatus.offline;
      }
      notifyListeners();
    }
  }

  /// Ends trip occupancy and returns to the availability the driver had
  /// before the trip, unless the driver was suspended or asked to go offline
  /// meanwhile. Only an available driver becomes available again.
  void endTrip() {
    if (_disposed) {
      return;
    }
    if (_activeTripId == null) {
      // Late/duplicate terminal callbacks cannot turn an offline, suspended,
      // or still-connecting driver into an available one. Preserve the legacy
      // Home return hint if this was already an online session.
      if (_status == DriverOnlineStatus.online) {
        _resumeHomeAfterTrip = true;
      }
      return;
    }
    _revision++;
    final DriverOnlineStatus next;
    if (_suspendAfterTrip || _status == DriverOnlineStatus.suspended) {
      next = DriverOnlineStatus.suspended;
    } else if (_offlineAfterTrip ||
        _statusBeforeTrip != DriverOnlineStatus.online) {
      next = DriverOnlineStatus.offline;
    } else {
      next = DriverOnlineStatus.online;
    }
    _activeTripId = null;
    _suspendAfterTrip = false;
    _offlineAfterTrip = false;
    _statusBeforeTrip = DriverOnlineStatus.online;
    _status = next;
    _resumeHomeAfterTrip = true;
    _save(() => _repository.saveOnline(next == DriverOnlineStatus.online));
    notifyListeners();
  }

  /// Kept for existing call sites. Same as [endTrip]: it no longer forces a
  /// suspended or offline driver back online.
  void stayOnlineAfterTrip() => endTrip();

  bool consumeResumeHomeAfterTrip() {
    if (!_resumeHomeAfterTrip) {
      return false;
    }
    _resumeHomeAfterTrip = false;
    return true;
  }

  void reset() {
    if (_disposed) {
      return;
    }
    _revision++;
    _activeTripId = null;
    _suspendAfterTrip = false;
    _offlineAfterTrip = false;
    _statusBeforeTrip = DriverOnlineStatus.online;
    if (_status == DriverOnlineStatus.offline && !_resumeHomeAfterTrip) {
      _save(_repository.clear);
      return;
    }
    _status = DriverOnlineStatus.offline;
    _resumeHomeAfterTrip = false;
    notifyListeners();
    _save(_repository.clear);
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
