part of 'home.dart';

// The driver's account on Home (Round 3):
// - the admin's driving limit, 12 h of work then 6 h of rest (Q25): island
//   warnings at 30 and 10 min left; at the limit Radar goes offline and
//   going online waits for "Rest until 04:30";
// - documents that run out (Q26): island and notification warnings on the
//   admin's days before; on the expiry day going online waits for admin to
//   approve the new one;
// - notifications (Q31): popups on the island, also while offline;
// - driver app texts from admin (Q30).

class _HomeAccountState {
  /// Driving-limit warnings, the limit and the end of the rest.
  final List<Timer> drivingTimers = <Timer>[];

  /// Minutes-left warnings already given in this stretch of work.
  final Set<int> warned = <int>{};

  /// Demo notifications that arrive while Home is open.
  final List<Timer> arrivalTimers = <Timer>[];

  VoidCallback? feedListener;
  VoidCallback? documentsListener;
  VoidCallback? categoriesListener;

  /// The rest that ended, so "Rest over" comes once.
  DateTime? restEnding;

  void cancelDriving() {
    for (final timer in drivingTimers) {
      timer.cancel();
    }
    drivingTimers.clear();
  }

  void dispose() {
    cancelDriving();
    for (final timer in arrivalTimers) {
      timer.cancel();
    }
    arrivalTimers.clear();
    if (feedListener case final listener?) {
      DriverNotificationFeed.instance.changes.removeListener(listener);
    }
    if (documentsListener case final listener?) {
      DocumentExpiryStore.instance.changes.removeListener(listener);
    }
    if (categoriesListener case final listener?) {
      DriverCategoryChoice.off.removeListener(listener);
    }
  }
}

extension _HomeAccount on _DriverHomeState {
    DrivingTimeClock get _drivingClock => DrivingTimeClock.instance;
    DriverNotificationFeed get _feed => DriverNotificationFeed.instance;

    /// From initState: admin texts, listeners, the demo arrivals.
    void _startAccount() {
      DriverAppTexts.overrides = _adminHomeConfig.appTexts;
      final account = _account;
      final onFeed = account.feedListener = _showNoticePopups;
      _feed.changes.addListener(onFeed);
      final onDocuments = account.documentsListener = _onDocumentsChanged;
      DocumentExpiryStore.instance.changes.addListener(onDocuments);
      final onCategories =
          account.categoriesListener = _HomeOfferRules(this)._onCategoriesChanged;
      DriverCategoryChoice.off.addListener(onCategories);
      _syncDrivingLimit();
      for (final (after, make) in _feed.takeArrivals()) {
        account.arrivalTimers.add(Timer(after, () {
          if (mounted) { _feed.add(make(_feed.now)); }
        }));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        _warnDocuments();
        _showNoticePopups();
      });
    }

    void _stopAccount() => _account.dispose();

    // Driving limit (Q25).

    /// Plans the warnings, the limit and the end of the rest for the
    /// driver's state now. Runs on every availability change.
    void _syncDrivingLimit() {
      final account = _account..cancelDriving();
      final clock = _drivingClock;
      final rule = clock.rule;
      if (!rule.on) { return; }
      if (clock.running) {
        final left = clock.left;
        for (final minutes in rule.warnMinutesLeft) {
          final at = left - Duration(minutes: minutes);
          if (at > Duration.zero) {
            // Ahead again after a rest.
            account.warned.remove(minutes);
            account.drivingTimers.add(
              Timer(at, () => _drivingWarning(minutes)),
            );
          }
        }
        if (rule.blockAtLimit) {
          account.drivingTimers.add(Timer(left, _drivingLimitReached));
        }
        return;
      }
      final until = clock.restUntil;
      if (until != null) {
        account.restEnding = until;
        account.drivingTimers.add(
          Timer(until.difference(ScheduledClock.realNow()), _restOver),
        );
      }
    }

    void _drivingWarning(int minutes) {
      if (!mounted || !_account.warned.add(minutes)) { return; }
      IslandMessages.show(HomeIslandNotices.drivingLeft(minutes));
    }

    /// At the limit: "Rest until 04:30", and Radar goes offline. On a
    /// trip, the driver finishes it first and is offline after it.
    void _drivingLimitReached() {
      if (!mounted || !_drivingClock.running) { return; }
      final until = _drivingClock.restUntil;
      if (until != null) {
        IslandMessages.show(HomeIslandNotices.restUntil(clockLabel(until)));
      }
      if (_driverSession.activeTripId != null) {
        _driverSession.setOnline(false);
        return;
      }
      // A claim with dispatch is answered first (Decision 3).
      _HomeOfferRules(this)._forcedOffline();
    }

    void _restOver() {
      final account = _account;
      if (!mounted || account.restEnding == null) { return; }
      account.restEnding = null;
      account.warned.clear();
      _feed.add(DriverNotices.restOver(_feed.now));
      _rebuild(() {});
    }

    // Documents (Q26).

    /// Warnings on the admin's days before expiry, each once.
    void _warnDocuments() {
      for (final warning in DocumentExpiryStore.instance.takeWarnings()) {
        final document = warning.document;
        _feed.add(DriverNotices.documentExpiring(
          _feed.now,
          documentId: document.id,
          title: () => document.title,
          shortTitle: () => document.shortTitle,
          when: () => expiresInLabel(warning.daysLeft),
        ));
      }
    }

    void _onDocumentsChanged() {
      if (!mounted) { return; }
      _warnDocuments();
      _rebuild(() {});
    }

    // Going online.

    /// True when the driver can't go online now; the island says why.
    bool _blocksGoingOnline() {
      final rest = _drivingClock.restUntil;
      if (rest != null) {
        IslandMessages.show(HomeIslandNotices.restUntil(clockLabel(rest)));
        return true;
      }
      final document = DocumentExpiryStore.instance.blocking;
      if (document != null) {
        IslandMessages.show(document.inReview
            ? HomeIslandNotices.documentInReview
            : HomeIslandNotices.documentExpired(document.shortTitle));
        unawaited(showDocumentBlockedSheet(context, document));
        return true;
      }
      return false;
    }

    /// What the radar orb says while going online waits: "REST · Until
    /// 04:30" or "HOLD · Document expired".
    ({String status, String subtitle})? _onlineHold() {
      final rest = _drivingClock.restUntil;
      if (rest != null) {
        return (status: tr.statusRest, subtitle: tr.untilTime(clockLabel(rest)));
      }
      if (DocumentExpiryStore.instance.blocking != null) {
        return (status: tr.statusHold, subtitle: tr.documentExpired);
      }
      return null;
    }

    /// R10-7: offline and on hold, the island keeps the reason until it is
    /// fixed; a tap opens the matching sheet. Same order as [_goOnline].
    IslandMessage? _islandHold() {
      if (_isOnline || _driverSession.activeTripId != null) { return null; }
      if (_driverSession.isSuspended) {
        return HomeIslandNotices.holdSuspended(
            () => unawaited(showDriverSuspendedSheet(context)));
      }
      if (!isAccountActivated) {
        return HomeIslandNotices.holdNotActive(_goOnline);
      }
      final rest = _drivingClock.restUntil;
      if (rest != null) {
        return HomeIslandNotices.holdRest(
            clockLabel(rest), _HomeMapSheet(this)._openDrivingTime);
      }
      final document = DocumentExpiryStore.instance.blocking;
      if (document != null) {
        return HomeIslandNotices.holdDocument(
          document.shortTitle,
          inReview: document.inReview,
          onTap: () => unawaited(showDocumentBlockedSheet(context, document)),
        );
      }
      return null;
    }

    // Notifications (Q31).

    /// New notifications show on the island, online or not. A tap opens
    /// what they are about.
    void _showNoticePopups() {
      if (!mounted) { return; }
      for (final notice in _feed.takePopups()) {
        IslandMessages.show(HomeIslandNotices.notice(
          notice.island!,
          tone: switch (notice.kind) {
            DriverNoticeKind.documentExpiring ||
            DriverNoticeKind.scheduledPaused =>
              IslandTone.warning,
            DriverNoticeKind.restOver ||
            DriverNoticeKind.documentApproved =>
              IslandTone.success,
            _ => IslandTone.info,
          },
          onTap: switch (notice.action) {
            DriverNoticeAction.uploadDocument => _openDocuments,
            DriverNoticeAction.viewScheduledRides => _openScheduledRides,
            null => notice.group == DriverNoticeGroup.demand
                ? _openNotifications
                : null,
          },
        ));
      }
    }

    void _openNotifications() {
      pushSingle(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DriverNotificationsScreen(dispatchRepository: _dispatch),
        ),
      );
    }

    void _openDocuments() {
      pushSingle(
        context,
        MaterialPageRoute<void>(builder: (_) => const DriverDocuments()),
      );
    }
}
