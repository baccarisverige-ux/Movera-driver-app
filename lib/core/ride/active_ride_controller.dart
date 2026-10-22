import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

export 'package:movera/core/ride/active_ride_repository.dart'
    show ActiveRideStage;
export 'package:movera/core/contracts/trip_transitions.dart'
    show TripCommand, TripKind;

/// Single source of truth for the lifecycle stage of one active ride.
///
/// Terminal outcomes are tracked separately so presentation switches only need
/// to render the three live stages. Persistence attaches here so screens do
/// not own ride recovery.
class ActiveRideController extends ChangeNotifier {
  ActiveRideController({
    this.tripId,
    ActiveRideRepository? repository,
    ActiveRideStage initialStage = ActiveRideStage.headingToPickup,
    this.snapshotBuilder,
    this.kind = TripKind.live,
  }) : _repository = repository ?? MemoryActiveRideRepository(),
       _stage = initialStage;

  final String? tripId;

  /// Live trip or reservation; picks the contract's driver-cancel row.
  final TripKind kind;
  final ActiveRideRepository _repository;
  PersistedActiveRide Function(ActiveRideStage stage)? snapshotBuilder;
  ActiveRideStage _stage;

  /// The contract status at which the trip left this driver: a terminal
  /// status, or `searching` / `requested` after a driver cancel before the
  /// rider was on board (the trip goes back to dispatch).
  TripStatus? _terminalStatus;

  ActiveRideStage get stage => _stage;
  TripStatus? get terminalStatus => _terminalStatus;
  bool get completed => _terminalStatus == TripStatus.completed;
  bool get cancelled =>
      _terminalStatus == TripStatus.cancelledByRider ||
      _terminalStatus == TripStatus.cancelledByDriver ||
      _terminalStatus == TripStatus.cancelledByAdmin ||
      _terminalStatus == TripStatus.cancelledBySystem ||
      (_terminalStatus?.isReleasedToDispatch ?? false);

  /// True once the trip is no longer this driver's (terminal or released).
  bool get terminal => _terminalStatus != null;

  /// True when a driver cancel handed the trip back to dispatch.
  bool get releasedToDispatch => _terminalStatus?.isReleasedToDispatch ?? false;

  /// Canonical status derived from the live stage and terminal outcome.
  /// Does not replace [ActiveRideStage] in UI.
  TripStatus get tripStatus => _terminalStatus ?? _stage.tripStatus;

  /// Where a driver [command] would take the trip from the current stage
  /// (`contract.json#transitions`), or null when the contract rejects it.
  TripStatus? driverTarget(TripCommand command) => terminal
      ? null
      : TripTransitions.target(
          tripStatus,
          command,
          TripActor.driver,
          kind: kind,
        );

  Future<bool> transitionTo(ActiveRideStage next) async {
    if (_backgroundSave != null) {
      await _afterBackgroundSave();
    }
    if (_disposed || terminal || saving) {
      return false;
    }
    if (next == _stage) {
      return true;
    }

    // The driver app folds `board` + `start_trip` into one slide: both rows
    // must allow it. Pickup → Waiting is `arrive`.
    final allowed = switch ((_stage, next)) {
      (ActiveRideStage.headingToPickup, ActiveRideStage.waitingForRider) =>
        driverTarget(TripCommand.arrive) == TripStatus.arrived,
      (ActiveRideStage.waitingForRider, ActiveRideStage.onTrip) =>
        driverTarget(TripCommand.board) == TripStatus.riderOnboard &&
            TripTransitions.target(
                  TripStatus.riderOnboard,
                  TripCommand.startTrip,
                  TripActor.driver,
                  kind: kind,
                ) ==
                next.tripStatus,
      _ => false,
    };

    if (!allowed) {
      return false;
    }

    return _write(
      () => _repository.save(_snapshot(next)),
      commit: () => _stage = next,
    );
  }

  /// Apply an authoritative projection, including skipped live stages.
  Future<bool> applyProjection(TripStatus status) async {
    // Duplicate terminal deliveries must not rerun persistence. A different
    // authoritative terminal status may correct an earlier tentative outcome;
    // the completion journal supports such authoritative corrections.
    if (saving ||
        _disposed ||
        (terminal && (!status.isTerminal || _terminalStatus == status))) {
      return false;
    }
    if (status.isTerminal) {
      return _write(
        () => _finish(status),
        commit: () => _terminalStatus = status,
      );
    } else if (status.isReleasedToDispatch) {
      // Admin reassign or a released reservation (`searching` /
      // `requested`): the trip went back to dispatch at whatever stage,
      // so it is over for this driver. Echoes of the driver's own cancel
      // were dropped above (already terminal).
      return _write(
        () => _finish(status),
        commit: () => _terminalStatus = status,
      );
    } else {
      if (terminal) {
        return false;
      }
      final next = switch (status) {
        TripStatus.accepted ||
        TripStatus.driverToPickup => ActiveRideStage.headingToPickup,
        TripStatus.arrived => ActiveRideStage.waitingForRider,
        TripStatus.riderOnboard ||
        TripStatus.inTrip ||
        TripStatus.approachingDropoff => ActiveRideStage.onTrip,
        _ => null,
      };
      if (next == null || next.index < _stage.index) {
        return false;
      }
      // Realtime may repeat the same stage each poll: avoid disk writes and
      // rebuild notifications when nothing in the lifecycle changed.
      if (next == _stage) {
        return true;
      }
      return _write(
        () => _repository.save(_snapshot(next)),
        commit: () => _stage = next,
      );
    }
  }

  Future<bool> complete({bool clearSnapshot = true}) async {
    if (_backgroundSave != null) {
      await _afterBackgroundSave();
    }
    if (_disposed ||
        terminal ||
        saving ||
        driverTarget(TripCommand.complete) != TripStatus.completed) {
      return false;
    }
    return _end(TripStatus.completed, clearSnapshot: clearSnapshot);
  }

  /// Ends the trip for this driver with a cancel.
  ///
  /// Without [status] this is the driver's own cancel: the contract decides
  /// the outcome from the stage (`searching`/`requested` before the rider is
  /// on board, `cancelled_by_driver` after). An explicit [status] (another
  /// actor's cancel) must be reachable from the current status by some
  /// contract row, or it is rejected.
  Future<bool> cancel({TripStatus? status, bool clearSnapshot = true}) async {
    if (_backgroundSave != null) {
      await _afterBackgroundSave();
    }
    if (_disposed || terminal || saving) {
      return false;
    }
    final to = status ?? driverTarget(TripCommand.cancel);
    if (to == null ||
        to == TripStatus.completed ||
        !to.endsDriverTrip ||
        !_reachable(to)) {
      return false;
    }
    return _end(to, clearSnapshot: clearSnapshot);
  }

  /// Driver no-show at pickup (`no_show`, from `arrived` only). The waiting
  /// guard (`noShowAfterMin`) is the caller's.
  Future<bool> noShow({bool clearSnapshot = true}) async {
    if (_backgroundSave != null) {
      await _afterBackgroundSave();
    }
    if (_disposed ||
        terminal ||
        saving ||
        driverTarget(TripCommand.noShow) != TripStatus.noShow) {
      return false;
    }
    return _end(TripStatus.noShow, clearSnapshot: clearSnapshot);
  }

  bool _reachable(TripStatus to) => TripTransitions.table.any(
    (row) =>
        row.to == to &&
        row.from.contains(tripStatus) &&
        (row.when == null || row.when == kind),
  );

  Future<bool> _end(TripStatus status, {required bool clearSnapshot}) async {
    if (clearSnapshot) {
      return _write(
        () => _finish(status),
        commit: () => _terminalStatus = status,
      );
    }
    _terminalStatus = status;
    if (!_disposed) {
      notifyListeners();
    }
    return true;
  }

  Future<void> _finish(TripStatus status) async {
    final repository = _repository;
    if (repository is TerminalRideRepository && tripId != null) {
      await (repository as TerminalRideRepository).markTerminal(
        tripId!,
        status,
      );
      await (repository as TerminalRideRepository).clearForTrip(tripId!);
    } else {
      await repository.clear();
    }
  }

  bool recoveryRequired = false;
  bool _disposed = false;
  bool _writing = false;

  /// Set while the write in flight is a background [persistNow] (GPS
  /// snapshot, lifecycle save) rather than a driver command.
  Completer<void>? _backgroundSave;
  int _revision = 0;
  Object? persistenceError;
  bool get saving => _writing;
  PersistedActiveRide _snapshot(ActiveRideStage stage) =>
      snapshotBuilder?.call(stage) ??
      PersistedActiveRide(tripId: tripId ?? 'demo', stage: stage);
  /// D-09: a driver command (Arrive, Start, Finish, cancel) that lands
  /// while a background save is in flight waits for it and then runs,
  /// instead of being dropped. A command in flight still rejects a
  /// second one (double tap).
  Future<void> _afterBackgroundSave() async {
    while (_writing && _backgroundSave != null && !_disposed) {
      await _backgroundSave!.future;
    }
  }

  Future<bool> _write(
    Future<void> Function() operation, {
    VoidCallback? commit,
    bool background = false,
  }) async {
    if (_disposed || _writing) {
      return false;
    }
    _writing = true;
    if (!background) {
      _lastSaved = null;
    }
    final done = _writeDone = Completer<void>();
    final backgroundSave = background ? Completer<void>() : null;
    _backgroundSave = backgroundSave;
    _revision++;
    persistenceError = null;
    if (!_disposed) {
      notifyListeners();
    }
    try {
      await operation();
      if (_disposed) return false;
      // Commit lifecycle state while the write lock is still held. The final
      // notification may synchronously trigger another command or snapshot.
      commit?.call();
      return true;
    } catch (error) {
      persistenceError = error;
      return false;
    } finally {
      _writing = false;
      if (identical(_backgroundSave, backgroundSave)) {
        _backgroundSave = null;
      }
      if (!_disposed) {
        notifyListeners();
      }
      backgroundSave?.complete();
      done.complete();
    }
  }

  /// Completes when the write in flight (any kind) ends.
  Completer<void>? _writeDone;

  /// The one save queued behind the write in flight (driver-u33).
  Future<bool>? _queuedSave;

  /// The snapshot the last background save wrote; null after any other
  /// write. A queued save with nothing new is skipped, so it does not hold
  /// the write lock for nothing.
  String? _lastSaved;

  /// Errors are observable; fire-and-forget lifecycle saves never throw.
  Future<bool> persistNow() async {
    if (_disposed) {
      return false;
    }
    if (terminal || tripId == null) {
      return true;
    }
    if (_writing) {
      // driver-u33: a change made while another save is in flight (a stop
      // reached or left, a next trip secured or cancelled) was dropped
      // until the next GPS snapshot. Save once more after it, with the
      // state as it is then; later asks join that one save.
      return _queuedSave ??= () async {
        while (_writing && !_disposed) {
          await _writeDone!.future;
        }
        _queuedSave = null;
        if (!_disposed && !_writing && !terminal && _lastSaved != null &&
            jsonEncode(_snapshot(_stage).toJson()) == _lastSaved) {
          return true;
        }
        return persistNow();
      }();
    }
    _lastSaved = null;
    return _write(() async {
      final snapshot = _snapshot(_stage);
      await _repository.save(snapshot);
      _lastSaved = jsonEncode(snapshot.toJson());
    }, background: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }

  Future<void> restore() async {
    if (_disposed || terminal || saving) {
      return;
    }
    final revision = ++_revision;
    PersistedActiveRide? stored;
    try {
      stored = await _repository.read();
    } catch (error) {
      if (_disposed || terminal || saving || revision != _revision) {
        return;
      }
      persistenceError = error;
      notifyListeners();
      return;
    }
    if (_disposed || terminal || saving || revision != _revision) {
      return;
    }
    if (stored == null) {
      return;
    }
    if (tripId != null && stored.tripId != tripId) {
      return;
    }
    recoveryRequired = !stored.isFresh;
    persistenceError = null;
    if (recoveryRequired) {
      if (!_disposed) {
        notifyListeners();
      }
      return;
    }
    _stage = stored.stage;
    if (!_disposed) {
      notifyListeners();
    }
  }
}
