import 'package:flutter/foundation.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';

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
    _loading = pending.whenComplete(() => _loading = null);
    return pending;
  }

  /// Takes the account a command answered with.
  DriverAccount replace(DriverAccount account) {
    _account = account;
    notifyListeners();
    return account;
  }

  /// Forgets the account (sign-out).
  void clear() {
    _account = null;
    notifyListeners();
  }
}
