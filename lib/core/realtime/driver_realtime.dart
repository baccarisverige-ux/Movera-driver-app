import 'dart:async';

import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';

/// Platform realtime envelope (P5 / D8). Sequence-numbered, no WebSocket yet.
enum DriverRealtimeKind {
  tripProjection,
  riderCancelled,
  location,
  driverArrived,
  riderOnTheWay,
}

enum DriverRealtimeDisposition {
  accepted,
  acceptedWithGap,
  staleOrDuplicate,
  blockedAfterTerminal,
}

class DriverRealtimeSequenceGate {
  final Map<String, int> _lastSequenceByTrip = <String, int>{};
  final Set<String> _terminalTrips = <String>{};

  DriverRealtimeDisposition evaluate(DriverRealtimeEvent event) {
    // Reject invalid envelopes before mutating the per-trip sequence or
    // terminal cache. One bad cancellation must not close a real trip.
    if (event.sequence < 1 || event.tripId.trim().isEmpty) {
      return DriverRealtimeDisposition.staleOrDuplicate;
    }
    final last = _lastSequenceByTrip[event.tripId];
    if (last != null && event.sequence <= last) {
      return DriverRealtimeDisposition.staleOrDuplicate;
    }

    if (_terminalTrips.contains(event.tripId)) {
      _lastSequenceByTrip[event.tripId] = event.sequence;
      return DriverRealtimeDisposition.blockedAfterTerminal;
    }

    final hasGap = last != null && event.sequence > last + 1;
    _lastSequenceByTrip[event.tripId] = event.sequence;
    if (_isTerminal(event)) {
      _terminalTrips.add(event.tripId);
    }
    return hasGap
        ? DriverRealtimeDisposition.acceptedWithGap
        : DriverRealtimeDisposition.accepted;
  }

  int? lastSequenceFor(String tripId) => _lastSequenceByTrip[tripId];

  bool isTerminal(String tripId) => _terminalTrips.contains(tripId);

  bool _isTerminal(DriverRealtimeEvent event) {
    if (event.kind == DriverRealtimeKind.riderCancelled) { return true; }
    final status = event.status;
    return status == TripStatus.completed ||
        status == TripStatus.cancelledByRider ||
        status == TripStatus.cancelledByDriver ||
        status == TripStatus.cancelledByAdmin ||
        status == TripStatus.noShow ||
        status == TripStatus.expired ||
        status == TripStatus.failed;
  }
}

class DriverRealtimeEvent {
  const DriverRealtimeEvent({
    required this.tripId,
    required this.kind,
    required this.sequence,
    required this.at,
    this.status,
    this.latitude,
    this.longitude,
    this.message,
    this.cancelFee,
  });

  final String tripId;
  final DriverRealtimeKind kind;
  final int sequence;
  final DateTime at;
  final TripStatus? status;
  final double? latitude;
  final double? longitude;
  final String? message;

  /// R15-7: with [DriverRealtimeKind.riderCancelled], the driver's cancel
  /// fee as decided by the backend (zero: no fee; null: not decided).
  final Money? cancelFee;
}

/// Mirror of Rider's [RideRealtime] shape so both apps hit the same seam.
abstract interface class DriverRealtime {
  Stream<DriverRealtimeEvent> subscribe(String tripId);

  Future<void> reconnectAndResync(String tripId);

  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  });

  void unsubscribe();

  void dispose();
}

/// In-memory bus. A WebSocket adapter replaces this class later.
class MemoryDriverRealtime implements DriverRealtime {
  MemoryDriverRealtime();

  final _controller = StreamController<DriverRealtimeEvent>.broadcast();
  final _lastByTrip = <String, DriverRealtimeEvent>{};
  int _sequence = 0;
  int _generation = 0;
  bool _disposed = false;
  final _sequencesByTrip = <String,int>{};
  final _projectionsByTrip = <String,DriverRealtimeEvent>{};
  String? _tripId;

  int get sequence => _sequence;

  void publish(DriverRealtimeEvent event) {
    if(_disposed) { return; }
    if(event.sequence<1 || event.tripId.trim().isEmpty) { throw ArgumentError('Valid trip ID and positive per-trip sequence required'); }
    final projection=_projectionsByTrip[event.tripId];
    if(projection?.status?.isTerminal == true || projection?.kind==DriverRealtimeKind.riderCancelled) { return; }
    final previous = _lastByTrip[event.tripId];
    if (previous == null || event.sequence > previous.sequence) {
      _lastByTrip[event.tripId] = event;
    }
    if(previous!=null && event.sequence<=previous.sequence) { return; }
    _sequencesByTrip[event.tripId]=event.sequence;
    if(event.kind==DriverRealtimeKind.tripProjection || event.kind==DriverRealtimeKind.riderCancelled) _projectionsByTrip[event.tripId]=event;
    if (event.sequence > _sequence) { _sequence = event.sequence; }
    _controller.add(event);
  }

  DriverRealtimeEvent emit({
    required String tripId,
    required DriverRealtimeKind kind,
    TripStatus? status,
    double? latitude,
    double? longitude,
    String? message,
    DateTime? at,
    Money? cancelFee,
  }) {
    if (_disposed) throw StateError('Realtime disposed');
    final nextSequence=(_sequencesByTrip[tripId] ?? 0)+1;
    final event = DriverRealtimeEvent(
      tripId: tripId,
      kind: kind,
      sequence: nextSequence,
      at: at ?? DateTime.now(),
      status: status,
      latitude: latitude,
      longitude: longitude,
      message: message,
      cancelFee: cancelFee,
    );
    publish(event);
    return event;
  }

  @override
  Stream<DriverRealtimeEvent> subscribe(String tripId) {
    if(_disposed) { throw StateError('Realtime disposed'); }
    if (tripId.trim().isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'Trip ID is required');
    }
    _tripId = tripId;
    final generation=++_generation;
    return _controller.stream.where((event) => !_disposed && generation==_generation && _tripId==tripId && event.tripId == tripId);
  }

  @override
  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  }) async {
    emit(
      tripId: tripId,
      kind: kind,
      message: message,
    );
  }

  @override
  Future<void> reconnectAndResync(String tripId) async {
    if(_disposed || _tripId!=tripId) { return; }
    final projection = _projectionsByTrip[tripId];
    final last = projection ?? _lastByTrip[tripId];
    if (last == null) return;

    // A cached nonterminal projection may predate subsequent location events.
    // Replaying its old sequence would be dropped by the receiving sequence
    // gate, leaving the driver's ride stage unrestored. Re-issue the current
    // projection as a new mock event while preserving its lifecycle status.
    // Terminal snapshots retain their original identity and cannot be revived.
    final newest = _lastByTrip[tripId];
    if (projection != null &&
        projection.status?.isTerminal != true &&
        projection.kind != DriverRealtimeKind.riderCancelled &&
        newest != null &&
        newest.sequence > projection.sequence) {
      emit(
        tripId: tripId,
        kind: projection.kind,
        status: projection.status,
        latitude: projection.latitude,
        longitude: projection.longitude,
        message: projection.message,
      );
      return;
    }
    _controller.add(last);
  }

  @override
  void unsubscribe() {
    _generation++;
    _tripId = null;
  }

  @override
  void dispose() {
    if(_disposed) { return; }
    _disposed=true;
    unsubscribe();
    _controller.close();
  }

  String? get subscribedTripId => _tripId;
}
