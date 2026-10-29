import 'package:movera/core/contracts/trip_status.dart';

/// Pure transition engine for `contracts/contract.json#transitions` (v0.7.2).
///
/// The table below is a hand copy of the contract. `test/contract/` checks it
/// row by row against `contracts/contract.json` and replays
/// `contracts/fixtures/scenarios.json`, so a drift fails the build.
///
/// Anything not in the table is `invalid_transition`: the status does not
/// change. Guards (for example "waited >= noShowAfterMin") are checked by the
/// caller, not here.

/// Who sends a command (`contract.json#actors`).
enum TripActor {
  rider,
  driver,
  admin,
  system;

  String get wireName => name;

  static TripActor? tryParse(String? value) {
    for (final actor in TripActor.values) {
      if (actor.name == value) return actor;
    }
    return null;
  }
}

/// Live trip or scheduled reservation. Some rows apply to one kind only.
enum TripKind {
  live,
  scheduled;

  String get wireName => name;

  static TripKind? tryParse(String? value) {
    for (final kind in TripKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}

/// Trip commands. [wireName] is the contract's snake_case `command`.
enum TripCommand {
  quote('quote'),
  request('request'),
  startSearch('start_search'),
  raisePrice('raise_price'),
  sendOffer('send_offer'),
  offerLapsed('offer_lapsed'),
  accept('accept'),
  assign('assign'),
  headToPickup('head_to_pickup'),
  arrive('arrive'),
  board('board'),
  startTrip('start_trip'),
  nearDropoff('near_dropoff'),
  complete('complete'),
  cancel('cancel'),
  endEarly('end_early'),
  noShow('no_show'),
  reassign('reassign'),
  expire('expire'),
  systemCancel('system_cancel'),
  fail('fail');

  const TripCommand(this.wireName);
  final String wireName;

  static TripCommand? tryParse(String? value) {
    for (final command in TripCommand.values) {
      if (command.wireName == value) return command;
    }
    return null;
  }
}

/// One row of the transition table.
class TripTransition {
  const TripTransition(
    this.command,
    this.actor,
    this.from,
    this.to, {
    this.when,
  });

  final TripCommand command;
  final TripActor actor;
  final List<TripStatus> from;
  final TripStatus to;

  /// Null: the row applies to live and scheduled trips.
  final TripKind? when;

  bool matches(
    TripStatus status,
    TripCommand command,
    TripActor actor,
    TripKind kind,
  ) =>
      this.command == command &&
      this.actor == actor &&
      from.contains(status) &&
      (when == null || when == kind);
}

/// Thrown by [TripTransitions.apply] for a command the contract rejects.
class InvalidTripTransition implements Exception {
  const InvalidTripTransition(this.from, this.command, this.actor, this.kind);
  final TripStatus from;
  final TripCommand command;
  final TripActor actor;
  final TripKind kind;

  /// Matches the contract error code.
  String get code => 'invalid_transition';

  @override
  String toString() =>
      'invalid_transition: ${command.wireName} by ${actor.wireName} '
      'from ${from.wireName} (${kind.wireName})';
}

abstract final class TripTransitions {
  static const String contractVersion = '0.17.3';

  static const List<TripTransition> table = [
    TripTransition(TripCommand.quote, TripActor.system, [
      TripStatus.draft,
    ], TripStatus.quoted),
    TripTransition(TripCommand.request, TripActor.rider, [
      TripStatus.quoted,
    ], TripStatus.requested),
    TripTransition(TripCommand.startSearch, TripActor.system, [
      TripStatus.requested,
    ], TripStatus.searching),
    // v0.5.5 §3.6: the rider raises their offer; a new search starts.
    TripTransition(TripCommand.raisePrice, TripActor.rider, [
      TripStatus.searching,
      TripStatus.offered,
    ], TripStatus.searching),
    TripTransition(TripCommand.sendOffer, TripActor.system, [
      TripStatus.searching,
    ], TripStatus.offered),
    TripTransition(TripCommand.offerLapsed, TripActor.system, [
      TripStatus.offered,
    ], TripStatus.searching),
    TripTransition(TripCommand.accept, TripActor.driver, [
      TripStatus.offered,
    ], TripStatus.accepted),
    // v0.5.1: a live trip is accepted only from an offer; a scheduled one
    // straight from its request.
    TripTransition(
      TripCommand.accept,
      TripActor.driver,
      [TripStatus.requested],
      TripStatus.accepted,
      when: TripKind.scheduled,
    ),
    TripTransition(TripCommand.assign, TripActor.admin, [
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
    ], TripStatus.offered),
    TripTransition(TripCommand.headToPickup, TripActor.driver, [
      TripStatus.accepted,
    ], TripStatus.driverToPickup),
    TripTransition(TripCommand.arrive, TripActor.driver, [
      TripStatus.driverToPickup,
    ], TripStatus.arrived),
    TripTransition(TripCommand.board, TripActor.driver, [
      TripStatus.arrived,
    ], TripStatus.riderOnboard),
    TripTransition(TripCommand.startTrip, TripActor.driver, [
      TripStatus.riderOnboard,
    ], TripStatus.inTrip),
    TripTransition(TripCommand.nearDropoff, TripActor.system, [
      TripStatus.inTrip,
    ], TripStatus.approachingDropoff),
    TripTransition(TripCommand.complete, TripActor.driver, [
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.completed),
    TripTransition(TripCommand.complete, TripActor.admin, [
      TripStatus.riderOnboard,
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.completed),
    TripTransition(TripCommand.cancel, TripActor.rider, [
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
      TripStatus.accepted,
      TripStatus.driverToPickup,
      TripStatus.arrived,
    ], TripStatus.cancelledByRider),
    TripTransition(TripCommand.endEarly, TripActor.rider, [
      TripStatus.riderOnboard,
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.cancelledByRider),
    TripTransition(
      TripCommand.cancel,
      TripActor.driver,
      [TripStatus.accepted, TripStatus.driverToPickup, TripStatus.arrived],
      TripStatus.searching,
      when: TripKind.live,
    ),
    TripTransition(
      TripCommand.cancel,
      TripActor.driver,
      [TripStatus.accepted],
      TripStatus.requested,
      when: TripKind.scheduled,
    ),
    TripTransition(
      TripCommand.cancel,
      TripActor.driver,
      [TripStatus.driverToPickup, TripStatus.arrived],
      TripStatus.searching,
      when: TripKind.scheduled,
    ),
    TripTransition(TripCommand.cancel, TripActor.driver, [
      TripStatus.riderOnboard,
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.cancelledByDriver),
    TripTransition(TripCommand.noShow, TripActor.driver, [
      TripStatus.arrived,
    ], TripStatus.noShow),
    TripTransition(TripCommand.noShow, TripActor.admin, [
      TripStatus.arrived,
      TripStatus.accepted,
      TripStatus.driverToPickup,
    ], TripStatus.noShow),
    TripTransition(TripCommand.reassign, TripActor.admin, [
      TripStatus.offered,
      TripStatus.accepted,
      TripStatus.driverToPickup,
      TripStatus.arrived,
    ], TripStatus.searching),
    TripTransition(TripCommand.cancel, TripActor.admin, [
      TripStatus.draft,
      TripStatus.quoted,
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
      TripStatus.accepted,
      TripStatus.driverToPickup,
      TripStatus.arrived,
      TripStatus.riderOnboard,
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.cancelledByAdmin),
    TripTransition(TripCommand.expire, TripActor.system, [
      TripStatus.quoted,
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
    ], TripStatus.expired),
    TripTransition(TripCommand.systemCancel, TripActor.system, [
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
      TripStatus.accepted,
    ], TripStatus.cancelledBySystem),
    TripTransition(TripCommand.fail, TripActor.system, [
      TripStatus.requested,
      TripStatus.searching,
      TripStatus.offered,
      TripStatus.accepted,
      TripStatus.driverToPickup,
      TripStatus.arrived,
      TripStatus.riderOnboard,
      TripStatus.inTrip,
      TripStatus.approachingDropoff,
    ], TripStatus.failed),
  ];

  /// The status after [command] by [actor] from [from], or null when the
  /// contract rejects it (`invalid_transition`). First matching row wins,
  /// like the reference engine.
  static TripStatus? target(
    TripStatus from,
    TripCommand command,
    TripActor actor, {
    TripKind kind = TripKind.live,
  }) {
    for (final row in table) {
      if (row.matches(from, command, actor, kind)) return row.to;
    }
    return null;
  }

  static bool allows(
    TripStatus from,
    TripCommand command,
    TripActor actor, {
    TripKind kind = TripKind.live,
  }) => target(from, command, actor, kind: kind) != null;

  /// Like [target], but throws [InvalidTripTransition].
  static TripStatus apply(
    TripStatus from,
    TripCommand command,
    TripActor actor, {
    TripKind kind = TripKind.live,
  }) =>
      target(from, command, actor, kind: kind) ??
      (throw InvalidTripTransition(from, command, actor, kind));
}

/// One row of `contract.json#ratingAllowed.rules`: [rater] may rate a trip
/// that ended in [status], through [command] when it is set.
class TripRatingRule {
  const TripRatingRule(this.rater, this.status, {this.command});
  final TripActor rater;
  final TripStatus status;
  final TripCommand? command;
}

/// Who may rate a finished trip (`contract.json#ratingAllowed`, v0.3.1).
/// The driver rates the rider after `completed` only; the rider also rates
/// a trip they ended early. Anything else is `invalid_transition`.
abstract final class TripRatingRules {
  static const List<TripRatingRule> rules = [
    TripRatingRule(TripActor.rider, TripStatus.completed),
    TripRatingRule(TripActor.driver, TripStatus.completed),
    TripRatingRule(
      TripActor.rider,
      TripStatus.cancelledByRider,
      command: TripCommand.endEarly,
    ),
  ];

  /// Whether [rater] may rate a trip in [status] that [endedBy] (the
  /// command that ended it, when known) brought there.
  static bool allows(
    TripActor rater,
    TripStatus status, {
    TripCommand? endedBy,
  }) => rules.any(
    (rule) =>
        rule.rater == rater &&
        rule.status == status &&
        (rule.command == null || rule.command == endedBy),
  );
}

/// How a trip leaves this driver's phone.
///
/// A driver cancel before the rider is on board does not end the trip: the
/// contract sends it back to dispatch (`searching`, or `requested` for a
/// reservation). For this driver the trip is over all the same, so local
/// records (journal, history, terminal markers) store that contract status
/// with the driver cancel. Only these two non-terminal statuses are valid
/// there.
extension DriverTripRelease on TripStatus {
  /// True for `searching` / `requested` reached by a driver cancel.
  bool get isReleasedToDispatch =>
      this == TripStatus.searching || this == TripStatus.requested;

  /// A status that ends this driver's part of the trip: terminal, or
  /// released back to dispatch.
  bool get endsDriverTrip => isTerminal || isReleasedToDispatch;
}
