import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// What the server said to the rider's PIN (contract v0.18.8
/// `arrivedWaiting.pin.check`, owner G6 decision 2).
enum PickupPinResult { ok, wrong, locked, blocked, notNow, required, failed }

/// One answer to a PIN try, with the plain words the driver reads.
class PickupPinOutcome {
  const PickupPinOutcome(
    this.result, {
    this.attemptsLeft,
    this.lockedFor,
    this.message,
  });

  const PickupPinOutcome.ok() : this(PickupPinResult.ok);

  /// The refusal in [error]: `400 pin_wrong` (`details: attemptsLeft=N`),
  /// `429 pin_locked` (`retryAfterSeconds`), `429 pin_blocked` (no wait:
  /// call support), `409 pin_not_now` (not arrived), `409 pin_required`; anything
  /// else is [PickupPinResult.failed] with [fallback] as its words.
  factory PickupPinOutcome.fromError(Object? error, {String? fallback}) {
    if (error is ApiError) {
      switch (error.detail) {
        case 'pin_wrong':
          return PickupPinOutcome(
            PickupPinResult.wrong,
            attemptsLeft: attemptsLeftOf(error.details),
          );
        case 'pin_locked':
          return PickupPinOutcome(
            PickupPinResult.locked,
            lockedFor: error.retryAfter ?? const Duration(minutes: 5),
          );
        case 'pin_blocked':
          return const PickupPinOutcome(PickupPinResult.blocked);
        case 'pin_not_now':
          return const PickupPinOutcome(PickupPinResult.notNow);
        case 'pin_required':
          return const PickupPinOutcome(PickupPinResult.required);
      }
    }
    return PickupPinOutcome(PickupPinResult.failed, message: fallback);
  }

  final PickupPinResult result;

  /// `pin_wrong`: tries left before the lock; null when not sent.
  final int? attemptsLeft;

  /// `pin_locked`: how long until the next try.
  final Duration? lockedFor;

  /// Words of a refusal that is not about the PIN.
  final String? message;

  bool get ok => result == PickupPinResult.ok;

  /// True when this refusal is about the PIN (the PIN step handles it).
  bool get aboutPin =>
      result == PickupPinResult.wrong ||
      result == PickupPinResult.locked ||
      result == PickupPinResult.blocked ||
      result == PickupPinResult.required;

  /// Whole minutes of the lock, rounded up, at least 1.
  int get lockedMinutes {
    final seconds = lockedFor?.inSeconds ?? 300;
    return seconds <= 0 ? 1 : (seconds + 59) ~/ 60;
  }

  /// The driver's words (`pin.texts.driverWrong` / `driverLocked` /
  /// `driverAsk`), sv / fr / en.
  String get text => switch (result) {
    PickupPinResult.ok => '',
    PickupPinResult.wrong => tr.g6PinWrong(attemptsLeft ?? 0),
    PickupPinResult.locked => tr.g6PinLocked(lockedMinutes),
    PickupPinResult.blocked => tr.g6PinBlocked,
    PickupPinResult.notNow => tr.g6PinNotNow,
    PickupPinResult.required => tr.g6PinAsk,
    PickupPinResult.failed => message ?? '',
  };

  /// `attemptsLeft=N` of a `pin_wrong` answer's `details`.
  static int? attemptsLeftOf(List<String> details) {
    for (final item in details) {
      final match = RegExp(r'^attemptsLeft=(\d+)$').firstMatch(item.trim());
      if (match != null) return int.parse(match.group(1)!);
    }
    return null;
  }

  /// A PIN is exactly 4 digits.
  static bool valid(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
}
