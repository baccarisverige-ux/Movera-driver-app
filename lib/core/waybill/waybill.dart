import 'package:flutter/foundation.dart';

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
      statusLabel: 'Completed',
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
    final promoted = queued.copyWith(statusLabel: 'Current trip');
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
  const WaybillPayment._(this._fareOre, this._comma, this._feeRate);

  /// Movera's share of each fare. Placeholder until per-trip pricing comes
  /// from the backend; change here.
  static const double serviceFeeRate = 0.25;

  /// Null when [fare] holds no amount (for example "—"). [feeRate] is
  /// Movera's share.
  static WaybillPayment? fromFare(
    String fare, {
    double feeRate = serviceFeeRate,
  }) {
    final match = RegExp(r'\d+(?:[.,]\d{1,2})?').firstMatch(fare);
    if (match == null) return null;
    final text = match.group(0)!;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null) return null;
    return WaybillPayment._((value * 100).round(), text.contains(','), feeRate);
  }

  final int _fareOre;
  final bool _comma;
  final double _feeRate;

  int get _feeOre => (_fareOre * _feeRate).round();

  String get fare => _format(_fareOre);
  String get serviceFee => _format(_feeOre);
  String get earnings => _format(_fareOre - _feeOre);

  String _format(int ore) {
    final text = '${ore ~/ 100}.${(ore % 100).toString().padLeft(2, '0')}';
    return '${_comma ? text.replaceAll('.', ',') : text} kr';
  }
}
