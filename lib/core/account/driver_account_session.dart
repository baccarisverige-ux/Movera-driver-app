import 'package:flutter/foundation.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/legal/driver_legal.dart';

/// The live account (`GET /driver/profile`) for the life of the session:
/// read at the gate, after the details screen and whenever a screen
/// changes it (join, leave, pick a car). Screens listen for the hold state
/// and the fleet. Demo builds never load it ([account] stays null).
class DriverAccountSession extends ChangeNotifier {
  DriverAccountSession({required DriverAccountRepository repository})
    : _repository = repository;

  final DriverAccountRepository _repository;
  DriverAccount? _account;
  Future<DriverAccount>? _loading;

  /// Round 4b: unread server notifications (the bell on Home). Read with
  /// [refreshUnread]; a failed read keeps the last count.
  final ValueNotifier<int> unreadNotifications = ValueNotifier<int>(0);

  DriverAccountRepository get repository => _repository;

  /// The last profile the server sent, or null before the first read.
  DriverAccount? get account => _account;

  /// Home's hold: the account is not active yet (or not read yet).
  bool get onHold => !(_account?.isActive ?? false);

  /// `GET /driver/profile`; one request at a time.
  Future<DriverAccount> refresh() {
    final active = _loading;
    if (active != null) return active;
    final pending = _repository.profile().then(replace);
    _loading = pending;
    // The caller handles the error; this bookkeeping must not become a
    // second, unhandled failure.
    pending.whenComplete(() {
      if (identical(_loading, pending)) _loading = null;
    }).ignore();
    return pending;
  }

  /// Round 4b: `GET /notifications?unreadOnly=true`, counted; quiet on
  /// failure (the bell keeps its last count).
  Future<int> refreshUnread() async {
    try {
      final unread = await _repository.notifications(unreadOnly: true);
      unreadNotifications.value = unread.length;
    } catch (_) {
      // Offline or a server fault: the count stays.
    }
    return unreadNotifications.value;
  }

  /// Round 4b: the profile (the invitation badge) and the unread count,
  /// when a screen opens or the app comes back; failures are quiet.
  Future<void> refreshBadges() async {
    try {
      await refresh();
    } catch (_) {
      // The screen shows what it has.
    }
    await refreshUnread();
  }

  /// Takes the account a command answered with.
  DriverAccount replace(DriverAccount account) {
    _account = account;
    // G3-D2: the driver's real numbers (Home, side menu, Analytics).
    if (account.performance case final performance?) {
      DriverPerformanceConfig.live.value = performance;
    }
    // Contract v0.18.2 `auth.firstLanguage`: an account's language wins
    // over the phone's when nothing was picked on this phone.
    DriverLanguage.useAccount(account.language);
    // Contract v0.18.5 `legal.apps`: the account's country's terms.
    DriverLegal.instance.useAccount(
      driverId: account.driverId,
      country: account.country,
    );
    notifyListeners();
    return account;
  }

  /// Forgets the account (sign-out).
  void clear() {
    _account = null;
    unreadNotifications.value = 0;
    DriverPerformanceConfig.live.value = null;
    notifyListeners();
  }
}
