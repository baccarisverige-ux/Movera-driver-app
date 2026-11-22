part of 'home.dart';

/// A saved trip Home could not simply resume, and the timers a resumed
/// app arms again.
extension _HomeRecovery on _DriverHomeState {
  /// The app is back. Home's one-shot timers for wall-clock moments
  /// count monotonic time, which stops while the phone sleeps, so they
  /// would fire late by the time asleep: they are worked out again from
  /// the wall clock, and what is due runs now.
  void _rearmWallClockTimers() {
    if (!mounted) {
      return;
    }
    // The driving limit, its warnings and the end of a rest
    // (driver-r5-6).
    _HomeAccount(this)._syncDrivingLimit();
    // Scheduled rides: reminders, "Be online", "Leave now", the backup
    // and the request refreshes (driver-r5-7).
    _HomeScheduled(this)._planScheduled(catchUp: true);
  }

  /// "Close trip" on a stale or endpoint-less saved trip. Its secured
  /// next trip is handed off through the completion journal, as every
  /// other exit from the trip does, and Home then asks about it: it is
  /// never dropped with the snapshot (driver-r5-36).
  Future<void> _closeSavedTrip(
    ActiveRideRepository repo,
    PersistedActiveRide snapshot,
  ) async {
    final status =
        TripTransitions.target(
          snapshot.stage.tripStatus,
          TripCommand.cancel,
          TripActor.driver,
        ) ??
        TripStatus.cancelledByDriver;
    final next = snapshot.next;
    try {
      if (next != null) {
        await CompletionJournal(active: repo).finish(
          _waybillFromSnapshot(snapshot),
          status: status,
          cancellationActor: 'driver',
          next: _queuedAsActive(next),
          // As old as the trip it came with: Home still asks first.
          endedAt: snapshot.savedAt,
        );
        _didAttemptActiveRideRestore = false;
        if (mounted) {
          await _restoreActiveRideIfNeeded();
        }
        return;
      }
      if (repo is TerminalRideRepository) {
        await (repo as TerminalRideRepository).markTerminal(
          snapshot.tripId,
          status,
        );
      }
      if (repo is TerminalRideRepository) {
        await (repo as TerminalRideRepository).clearForTrip(snapshot.tripId);
      } else {
        await repo.clear();
      }
      if (mounted) {
        _rebuild(() => _recoveryResolved = true);
        // v0.18.154 P16c: the saved trip is closed; the server was not
        // asked, so only the demo (no live server) counts it as "no trip".
        MinAppVersion.answerTripCheck(
          askedServer: false,
          serverReadFailed: false,
          liveServer: LiveDriverServices.instance != null,
        );
      }
    } catch (_) {
      _didAttemptActiveRideRestore = false;
      if (mounted) {
        _HomeMapSheet(this)._tripProblem(
          HomeIslandNotices.savedTripNotClosed,
          tr.savedTripCouldNotBeClosed,
        );
      }
    }
  }

  /// [next] as the trip it becomes, heading to its pickup, with the
  /// terms its secured offer had (driver-12): on live the server's saved
  /// driverTotal, bonus and pickup pay, never a sum worked out on the
  /// phone (BQ-F1c, [PersistedQueuedTrip.asHeadingToPickup]).
  PersistedActiveRide _queuedAsActive(PersistedQueuedTrip next) =>
      next.asHeadingToPickup(matchedVia: WaybillRecord.exclusiveOfferSource);
}
