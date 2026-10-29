part of 'home.dart';

// The driver's account on Home (Round 3):
// - the admin's driving limit, 12 h of work then 6 h of rest (Q25): island
//   warnings at 30 and 10 min left; at the limit Radar goes offline and
//   going online waits for "Rest until 04:30";
// - Important reminders (contract v0.17.0, owner group 2 items 1, 2, 3
//   and 9): the server's list on the Home sheet; a red line (a missing or
//   expired document, no approved car, no car picked, the account not
//   active) keeps the driver offline and the island says why;
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
  VoidCallback? remindersListener;
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
    if (remindersListener case final listener?) {
      DriverRemindersStore.instance.removeListener(listener);
    }
    if (categoriesListener case final listener?) {
      DriverCategoryChoice.off.removeListener(listener);
    }
  }
}

/// The Home states whose badges were requested once (extensions carry no fields).
final Set<int> _badgesRequested = <int>{};

extension _HomeAccount on _DriverHomeState {
  DrivingTimeClock get _drivingClock => DrivingTimeClock.instance;
  DriverNotificationFeed get _feed => DriverNotificationFeed.instance;

  /// From initState: admin texts, listeners, the demo arrivals.
  void _startAccount() {
    DriverAppTexts.overrides = _adminHomeConfig.appTexts;
    final account = _account;
    final onFeed = account.feedListener = _showNoticePopups;
    _feed.changes.addListener(onFeed);
    final onReminders = account.remindersListener = _onRemindersChanged;
    DriverRemindersStore.instance.addListener(onReminders);
    final onCategories = account.categoriesListener = _HomeOfferRules(
      this,
    )._onCategoriesChanged;
    DriverCategoryChoice.off.addListener(onCategories);
    _syncDrivingLimit();
    for (final (after, make) in _feed.takeArrivals()) {
      account.arrivalTimers.add(
        Timer(after, () {
          if (mounted) {
            _feed.add(make(_feed.now));
          }
        }),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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
    if (!rule.on) {
      return;
    }
    if (clock.running) {
      final left = clock.left;
      for (final minutes in rule.warnMinutesLeft) {
        final at = left - Duration(minutes: minutes);
        if (at > Duration.zero) {
          // Ahead again after a rest.
          account.warned.remove(minutes);
          account.drivingTimers.add(Timer(at, () => _drivingWarning(minutes)));
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
    if (!mounted || !_account.warned.add(minutes)) {
      return;
    }
    IslandMessages.show(HomeIslandNotices.drivingLeft(minutes));
  }

  /// At the limit: "Rest until 04:30", and Radar goes offline. On a
  /// trip, the driver finishes it first and is offline after it.
  void _drivingLimitReached() {
    if (!mounted || !_drivingClock.running) {
      return;
    }
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
    if (!mounted || account.restEnding == null) {
      return;
    }
    account.restEnding = null;
    account.warned.clear();
    _feed.add(DriverNotices.restOver(_feed.now));
    _rebuild(() {});
  }

  // Important reminders (contract v0.17.0).

  void _onRemindersChanged() {
    if (!mounted) {
      return;
    }
    _rebuild(() {});
  }

  /// The words of the first red line, for the island and the orb.
  String? _blockingReminderText() {
    final first = DriverRemindersStore.instance.firstBlocking;
    if (first == null) {
      return null;
    }
    return reminderWords(
      first,
      nameOf: (type) =>
          OnboardingSettingsStore.instance.nameOf(type, tr.localeName),
      owner: accountSessionOf(context)?.account?.fleet?.isOwner ?? false,
    ).title;
  }

  /// Opens the Home sheet on the reminders.
  void _showReminders() {
    if (!mounted || !_panelController.isAttached) {
      return;
    }
    unawaited(_springPanelTo(1));
  }

  /// A tap on a reminder line: the upload guide, "How to book", My fleet
  /// or the car list (`ReminderFix.target`).
  Future<void> _fixReminder(DriverReminder reminder) async {
    final session = accountSessionOf(context);
    final fix = reminder.fix;
    if (!mounted || session == null || fix == null) {
      return;
    }
    final me = session.account;
    final Widget page = switch (fix.target) {
      ReminderFixTarget.document => UploadGuideScreen(
        account: session,
        type: fix.documentType ?? reminder.documentType ?? '',
        ownerId: fix.vehicleId ?? me?.driverId ?? '',
        isCar: fix.vehicleId != null,
        country: me?.country ?? DriverAccountRules.current.country,
        status: reminder.status,
        expiresAt: reminder.expiresAt,
      ),
      ReminderFixTarget.infoSession => InfoSessionScreen(
        status: reminder.status ?? 'waiting_for_movera',
      ),
      ReminderFixTarget.fleetVehicles => MyFleetScreen(account: session),
      ReminderFixTarget.pickVehicle => LiveVehiclesScreen(account: session),
    };
    await pushSingle(context, MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) {
      _refreshLiveBadges();
    }
  }

  /// The Home sheet box (live builds; nothing in the demo).
  Widget _remindersBox() {
    final session = accountSessionOf(context);
    if (session == null) {
      return const SizedBox.shrink();
    }
    return ImportantRemindersBox(
      store: DriverRemindersStore.instance,
      owner: session.account?.fleet?.isOwner ?? false,
      onFix: (reminder) => unawaited(_fixReminder(reminder)),
    );
  }

  // Going online.

  /// True when the driver can't go online now; the island says why.
  bool _blocksGoingOnline() {
    final rest = _drivingClock.restUntil;
    if (rest != null) {
      IslandMessages.show(HomeIslandNotices.restUntil(clockLabel(rest)));
      return true;
    }
    // Owner items 1, 3 and 9: a red reminder keeps the driver offline
    // (the server refuses too); the island says why, the sheet shows all.
    final reason = _blockingReminderText();
    if (reason != null) {
      IslandMessages.show(
        HomeIslandNotices.holdReminder(
          tr.remCantGoOnline(reason),
          _showReminders,
        ),
      );
      _showReminders();
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
    final reason = _blockingReminderText();
    if (reason != null) {
      return (status: tr.statusHold, subtitle: reason);
    }
    return null;
  }

  /// R10-7: offline and on hold, the island keeps the reason until it is
  /// fixed; a tap opens the matching sheet. Same order as [_goOnline].
  IslandMessage? _islandHold() {
    if (_isOnline || _driverSession.activeTripId != null) {
      return null;
    }
    if (_driverSession.isSuspended) {
      return HomeIslandNotices.holdSuspended(
        () => unawaited(showDriverSuspendedSheet(context)),
      );
    }
    if (!isAccountActivated) {
      return HomeIslandNotices.holdNotActive(_goOnline);
    }
    final rest = _drivingClock.restUntil;
    if (rest != null) {
      return HomeIslandNotices.holdRest(
        clockLabel(rest),
        _HomeMapSheet(this)._openDrivingTime,
      );
    }
    final reason = _blockingReminderText();
    if (reason != null) {
      return HomeIslandNotices.holdReminder(reason, _showReminders);
    }
    return null;
  }

  // Notifications (Q31).

  /// New notifications show on the island, online or not. A tap opens
  /// what they are about.
  void _showNoticePopups() {
    if (!mounted) {
      return;
    }
    for (final notice in _feed.takePopups()) {
      IslandMessages.show(
        HomeIslandNotices.notice(
          notice.island!,
          tone: switch (notice.kind) {
            DriverNoticeKind.documentExpiring ||
            DriverNoticeKind.scheduledPaused => IslandTone.warning,
            DriverNoticeKind.restOver ||
            DriverNoticeKind.documentApproved => IslandTone.success,
            _ => IslandTone.info,
          },
          onTap: switch (notice.action) {
            DriverNoticeAction.uploadDocument => _openDocuments,
            DriverNoticeAction.viewScheduledRides => _openScheduledRides,
            null =>
              notice.group == DriverNoticeGroup.demand
                  ? _openNotifications
                  : null,
          },
        ),
      );
    }
  }

  void _openNotifications() {
    if (!mounted) {
      return;
    }
    pushSingle(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DriverNotificationsScreen(dispatchRepository: _dispatch),
      ),
    );
  }

  // Round 4b (live): the server's notifications and the invitation badge.

  /// The bell on the map: the unread count from `GET /notifications`.
  Widget _buildNotificationsBell() {
    final session = accountSessionOf(context);
    if (session == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: session.unreadNotifications,
      builder: (context, unread, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          MapControlButton(
            key: const ValueKey<String>('home-notifications-bell'),
            tooltip: unread > 0
                ? '${tr.notifications} · $unread'
                : tr.notifications,
            size: _homeMapButtonSize,
            onTap: () => _openServerNotifications(session),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF172027),
              size: 24,
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey<String>('home-notifications-count'),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD03A2B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openServerNotifications(DriverAccountSession session) async {
    if (!mounted) {
      return;
    }
    await pushSingle(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServerNotificationsScreen(account: session),
      ),
    );
    _refreshLiveBadges();
  }

  /// Home's first dependencies pass only (didChangeDependencies may run again).
  void _refreshLiveBadgesOnce() {
    if (_badgesRequested.add(hashCode)) {
      _refreshLiveBadges();
    }
  }

  /// The profile (the invitation count) and the unread count, when Home
  /// opens, comes back on top or the app returns; nothing in the demo.
  void _refreshLiveBadges() {
    if (!mounted || !DriverRuntimeConfig.current.authRequired) {
      return;
    }
    final session = accountSessionOf(context);
    if (session == null) {
      return;
    }
    unawaited(
      session.refreshBadges().then((_) {
        if (mounted) {
          _rebuild(() {});
        }
      }),
    );
    // Contract v0.17.0: the reminders and the country's settings (names of
    // the admin's own document types).
    unawaited(refreshReminders(session));
    unawaited(refreshOnboardingSettings(session).then((_) {}, onError: (_) {}));
  }

  void _openDocuments() {
    if (!mounted) {
      return;
    }
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const DriverDocuments()),
    );
  }
}
