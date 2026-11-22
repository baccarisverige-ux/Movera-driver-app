import 'dart:async';

import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';

/// R6 (owner 2026-10-30, "Update + notice (Recommended)"): an open Home
/// or Documents screen reads the documents and reminders again this
/// often, besides when it comes back on top or the app returns.
const Duration onboardingRefreshEvery = Duration(seconds: 60);

/// The clock Home's badge gate reads (a test sets a fake one).
DateTime Function() badgesClock = DateTime.now;

/// D12-5: whether a return to the app reads Home's badges again (profile,
/// unread count, reminders, onboarding settings): not when they were read
/// less than [onboardingRefreshEvery] ago, so a short trip out of the app
/// sends no burst; the 60 s refresh goes on as before.
bool badgesDueOnResume(DateTime? lastRead, DateTime now) =>
    lastRead == null || now.difference(lastRead) >= onboardingRefreshEvery;

/// The admin's onboarding settings of the driver's country (contract
/// v0.17.0), read into [OnboardingSettingsStore.instance].
Future<OnboardingSettings> refreshOnboardingSettings(
  DriverAccountSession session,
) {
  final store = OnboardingSettingsStore.instance;
  store.country = session.account?.country ?? store.country;
  return store.refresh(() => session.repository.onboardingSettings());
}

/// The Home sheet's reminders, read into [DriverRemindersStore.instance];
/// quiet on failure (the last list stays).
Future<void> refreshReminders(DriverAccountSession session) async {
  try {
    await DriverRemindersStore.instance.refresh(() async {
      return _forViewer(session, await session.repository.reminders());
    });
  } catch (_) {
    // Offline or a server fault: the sheet keeps what it showed.
  }
}

DriverReminderList _forViewer(
  DriverAccountSession session,
  DriverReminderList list,
) {
  final me = session.account;
  return list.forViewer(
    owner: me == null || me.isFleetAccount || (me.fleet?.isOwner ?? false),
  );
}

/// Contract v0.18.145 (`contract.json#loadCut.homeBadges`): set once an
/// older server answered `GET /driver/home-badges` with 404; the app then
/// sends the four reads until it restarts.
bool homeBadgesMissing = false;

/// Contract v0.18.145: Home's badges (profile, unread count, reminders,
/// onboarding settings) in ONE request, `GET /driver/home-badges`, instead
/// of four. On 404 (an older server) the four reads as before. Quiet on
/// failure: every badge keeps its last value. [afterProfile] runs once the
/// profile was read (or its read failed), as after
/// [DriverAccountSession.refreshBadges].
///
/// One request at a time per session (as G27 for the profile and the
/// bell): a second caller while one is out shares its answer.
Future<void> refreshHomeBadges(
  DriverAccountSession session, {
  void Function()? afterProfile,
}) {
  final active = _homeBadgesLoading[session];
  if (active != null) return active.then((_) => afterProfile?.call());
  final pending = _readHomeBadges(session, afterProfile: afterProfile);
  _homeBadgesLoading[session] = pending;
  pending.whenComplete(() {
    if (identical(_homeBadgesLoading[session], pending)) {
      _homeBadgesLoading[session] = null;
    }
  }).ignore();
  return pending;
}

final _homeBadgesLoading = Expando<Future<void>>('homeBadges');

Future<void> _readHomeBadges(
  DriverAccountSession session, {
  void Function()? afterProfile,
}) async {
  if (!homeBadgesMissing) {
    try {
      // The profile read shares the session's one-at-a-time guard; an older
      // answer never overwrites a newer account.
      final badges = await session.readProfileWith(
        session.repository.homeBadges,
        (b) => b.profile,
      );
      session.unreadNotifications.value = badges.unread.length;
      afterProfile?.call();
      await _quiet(
        DriverRemindersStore.instance.refresh(
          () async => _forViewer(session, badges.reminders),
        ),
      );
      final settings = badges.onboardingSettings;
      if (settings != null) {
        final store = OnboardingSettingsStore.instance;
        store.country = session.account?.country ?? store.country;
        await _quiet(store.refresh(() async => settings));
      }
      return;
    } on ApiError catch (error) {
      if (error.statusCode != 404) {
        afterProfile?.call();
        return;
      }
      homeBadgesMissing = true;
    } catch (_) {
      // Offline or a server fault: the badges keep what they showed.
      afterProfile?.call();
      return;
    }
  }
  final profile = session.refreshBadges().then((_) => afterProfile?.call());
  await Future.wait([
    profile,
    refreshReminders(session),
    _quiet(refreshOnboardingSettings(session)),
  ]);
}

Future<void> _quiet(Future<Object?> work) => work.then((_) {}, onError: (_) {});
