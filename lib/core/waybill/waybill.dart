import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/money/money.dart';

class WaybillRecord {
  const WaybillRecord({
    required this.tripId,
    required this.statusLabel,
    required this.issuedAt,
    required this.fare,
    required this.service,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.source,
    required this.driverName,
    required this.vehicle,
    required this.licensePlate,
    required this.passengerCapacity,
    this.waitingFee,
    this.driverBonus,
  });

  final String tripId;
  final String statusLabel;
  final DateTime issuedAt;
  final String fare;
  final String service;
  final String riderName;
  final String pickup;
  final String dropoff;
  final String source;
  final String driverName;
  final String vehicle;
  final String licensePlate;
  final int passengerCapacity;

  /// The driver's waiting fee in [fare] (Q42/Q43), e.g. "3,68 kr"; null
  /// when the trip had none.
  final String? waitingFee;

  /// Movera's bonus in [fare] (Q16/Q18), e.g. "40 kr"; null without one.
  final String? driverBonus;

  /// Stored values of [statusLabel] and [source]. They stay in English in
  /// storage; the screens show them in the driver's language.
  static const String currentTrip = 'Current trip';
  static const String nextTripSecured = 'Next trip secured';
  static const String completed = 'Completed';
  static const String exclusiveOfferSource = 'Exclusive offer';
  static const String localDemoSource = 'Local demo';
  static const String demoRadarSource = 'Demo Radar';

  /// [statusLabel] in the driver's language ("Course en cours").
  String get statusText => switch (statusLabel) {
    currentTrip => tr.currentTrip,
    nextTripSecured => tr.nextTripSecured,
    completed => tr.completed,
    'Cancelled by rider' => tr.cancelledByRider,
    'Cancelled by driver' => tr.cancelledByDriver,
    'Cancelled by Movera' => tr.cancelledByMovera,
    'Cancelled by driver · reassigned' => tr.cancelledByDriver,
    'Rider no-show' => tr.riderDidNotArrive,
    'Expired' => tr.tripExpired,
    'Failed' => tr.tripFailed,
    _ => statusLabel,
  };

  /// [source] in the driver's language; names such as "Movera Radar" stay.
  String get sourceText => switch (source) {
    exclusiveOfferSource => tr.exclusiveOffer,
    localDemoSource => tr.waybillLocalDemo,
    demoRadarSource => tr.waybillDemoRadar,
    _ => source,
  };

  /// [bonus] as the earnings label, e.g. "40 kr"; null for none.
  static String? bonusLabel(Money? bonus) =>
      bonus == null || bonus.minorUnits <= 0 ? null : bonus.formattedShort;

  /// "incl. +40 kr Movera bonus", under the fare wherever earnings show.
  static String bonusNote(String bonus) => tr.inclBonusMoveraBonus(bonus);

  WaybillRecord copyWith({
    String? fare,
    String? waitingFee,
    String? statusLabel,
    DateTime? issuedAt,
    String? vehicle,
    String? licensePlate,
  }) {
    return WaybillRecord(
      tripId: tripId,
      statusLabel: statusLabel ?? this.statusLabel,
      issuedAt: issuedAt ?? this.issuedAt,
      fare: fare ?? this.fare,
      service: service,
      riderName: riderName,
      pickup: pickup,
      dropoff: dropoff,
      source: source,
      driverName: driverName,
      vehicle: vehicle ?? this.vehicle,
      licensePlate: licensePlate ?? this.licensePlate,
      passengerCapacity: passengerCapacity,
      waitingFee: waitingFee ?? this.waitingFee,
      driverBonus: driverBonus,
    );
  }
}

abstract interface class WaybillRepository {
  WaybillRecord? get current;
  WaybillRecord? get next;
  WaybillRecord? get last;

  ValueListenable<WaybillRecord?> get currentListenable;
  ValueListenable<WaybillRecord?> get nextListenable;
  ValueListenable<WaybillRecord?> get lastListenable;

  void beginCurrent(WaybillRecord record);
  void secureNext(WaybillRecord record);
  void completeCurrent();
  void discardCurrent();
  void clearNext();
  void reset();

  /// Move a secured next trip into the current slot.
  ///
  /// Returns the promoted current record, or null if no trip is queued or
  /// another trip is still active. Never replaces an active trip.
  WaybillRecord? promoteNextToCurrent();
}

/// Frontend implementation. A persistent/backend repository can replace this
/// without changing trip screens.
class InMemoryWaybillRepository implements WaybillRepository {
  InMemoryWaybillRepository._();

  static final InMemoryWaybillRepository instance =
      InMemoryWaybillRepository._();

  final ValueNotifier<WaybillRecord?> _current =
      ValueNotifier<WaybillRecord?>(null);
  final ValueNotifier<WaybillRecord?> _next =
      ValueNotifier<WaybillRecord?>(null);
  final ValueNotifier<WaybillRecord?> _last =
      ValueNotifier<WaybillRecord?>(null);

  @override
  WaybillRecord? get current => _current.value;

  @override
  WaybillRecord? get next => _next.value;

  @override
  WaybillRecord? get last => _last.value;

  @override
  ValueListenable<WaybillRecord?> get currentListenable => _current;

  @override
  ValueListenable<WaybillRecord?> get nextListenable => _next;

  @override
  ValueListenable<WaybillRecord?> get lastListenable => _last;

  @override
  void beginCurrent(WaybillRecord record) {
    // A stale screen must not replace an independently active ride.
    if (current != null && current!.tripId != record.tripId) return;
    _current.value = record;
  }

  @override
  void secureNext(WaybillRecord record) {
    // A queued ride must be explicitly released before a different one wins.
    if (next != null && next!.tripId != record.tripId) return;
    _next.value = record;
  }

  @override
  void completeCurrent() {
    final active = current;
    if (active == null) { return; }

    _last.value = active.copyWith(
      statusLabel: WaybillRecord.completed,
      issuedAt: DateTime.now(),
    );
    _current.value = null;
  }

  @override
  void discardCurrent() {
    _current.value = null;
  }

  @override
  void clearNext() {
    _next.value = null;
  }

  @override
  WaybillRecord? promoteNextToCurrent() {
    final queued = next;
    if (queued == null || current != null) {
      return null;
    }
    final promoted = queued.copyWith(statusLabel: WaybillRecord.currentTrip);
    _current.value = promoted;
    _next.value = null;
    return promoted;
  }

  @override
  void reset() {
    _current.value = null;
    _next.value = null;
    _last.value = null;
  }

  void setLastForTesting(WaybillRecord? record) {
    _last.value = record;
  }
}

/// Compatibility facade while older screens/tests migrate to WaybillRepository.
class WaybillStore {
  WaybillStore._();

  static final InMemoryWaybillRepository _repository =
      InMemoryWaybillRepository.instance;

  static WaybillRecord? get current => _repository.current;
  static set current(WaybillRecord? value) {
    if (value == null) {
      _repository.discardCurrent();
    } else {
      _repository.beginCurrent(value);
    }
  }

  static WaybillRecord? get next => _repository.next;
  static set next(WaybillRecord? value) {
    if (value == null) {
      _repository.clearNext();
    } else {
      _repository.secureNext(value);
    }
  }

  static WaybillRecord? get last => _repository.last;
  static set last(WaybillRecord? value) {
    _repository.setLastForTesting(value);
  }

  static ValueListenable<WaybillRecord?> get currentNotifier =>
      _repository.currentListenable;
  static ValueListenable<WaybillRecord?> get nextNotifier =>
      _repository.nextListenable;
  static ValueListenable<WaybillRecord?> get lastNotifier =>
      _repository.lastListenable;

  static void beginCurrent(WaybillRecord record) =>
      _repository.beginCurrent(record);
  static void secureNext(WaybillRecord record) =>
      _repository.secureNext(record);
  static void completeCurrent() => _repository.completeCurrent();
  static void clearNext() => _repository.clearNext();
  static WaybillRecord? promoteNextToCurrent() =>
      _repository.promoteNextToCurrent();
  static void reset() => _repository.reset();
}

/// What the passenger paid for one trip and what the driver keeps.
///
/// The fare text is the one shown to the driver ("128,40 kr" or
/// "126.75 kr"). Amounts are kept in öre and keep its decimal separator.
class WaybillPayment {
  const WaybillPayment._(this._fareOre, this._comma, this._feeRate, this._bonusOre);

  /// Movera's share of each fare. Placeholder until per-trip pricing comes
  /// from the backend; change here.
  static const double serviceFeeRate = 0.25;

  /// Null when [fare] holds no amount (for example "—"). [feeRate] is
  /// Movera's share. [bonus] (e.g. "40 kr", Q16/Q18) is Movera's extra
  /// already in [fare]: the rider never pays it and Movera takes no fee
  /// on it, so it all goes to the driver's earnings.
  static WaybillPayment? fromFare(
    String fare, {
    double feeRate = serviceFeeRate,
    String? bonus,
  }) {
    final match = RegExp(r'\d+(?:[.,]\d{1,2})?').firstMatch(fare);
    if (match == null) return null;
    final text = match.group(0)!;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return null;
    final fareOre = (value * 100).round();
    final bonusOre = bonus == null ? 0 : Money.parseLabel(bonus)?.minorUnits ?? 0;
    return WaybillPayment._(
      fareOre,
      text.contains(','),
      feeRate,
      bonusOre.clamp(0, fareOre),
    );
  }

  final int _fareOre;
  final bool _comma;
  final double _feeRate;
  final int _bonusOre;

  /// What the rider pays: the fare without Movera's bonus.
  int get _riderOre => _fareOre - _bonusOre;

  int get _feeOre => (_riderOre * _feeRate).round();

  /// Paid by the passenger (the base price).
  String get fare => _format(_riderOre);
  String get serviceFee => _format(_feeOre);

  /// The driver's: the rider's fare after Movera's fee, plus the bonus.
  String get earnings => _format(_fareOre - _feeOre);

  /// Movera's bonus in the earnings; null without one.
  String? get bonus => _bonusOre > 0 ? _format(_bonusOre) : null;

  String _format(int ore) {
    final text = '${ore ~/ 100}.${(ore % 100).toString().padLeft(2, '0')}';
    return '${_comma ? text.replaceAll('.', ',') : text} kr';
  }
}
