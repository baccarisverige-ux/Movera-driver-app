import 'dart:async';

import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';

/// Trip realtime envelope, `contracts/contract.json#realtime` (v0.3.0).
///
/// `{eventId, tripId, sequence, version, kind, occurredAt, serverTime}` plus
/// optional `projection, location, etaSeconds, cancelFee, message`. The
/// server assigns `eventId` and `sequence`; clients never number events.
/// There is no transport yet (SSE/WebSocket on `GET /trips/{tripId}/events`).
enum DriverRealtimeKind {
  tripProjection('trip_projection'),
  riderCancelled('rider_cancelled'),
  driverCancelled('driver_cancelled'),
  location('location'),
  driverArrived('driver_arrived'),
  riderOnTheWay('rider_on_the_way'),
  paymentUpdated('payment_updated'),
  ratingUpdated('rating_updated'),
  message('message');

  const DriverRealtimeKind(this.wireName);
  final String wireName;

  /// `contract.json#realtime.afterTerminal`: still accepted once the trip
  /// reached a terminal status (payment and rating are not trip statuses).
  static const Set<DriverRealtimeKind> afterTerminal = {
    DriverRealtimeKind.paymentUpdated,
    DriverRealtimeKind.ratingUpdated,
    DriverRealtimeKind.message,
  };

  bool get passesAfterTerminal => afterTerminal.contains(this);

  static DriverRealtimeKind? tryParse(String? value) {
    for (final kind in DriverRealtimeKind.values) {
      if (kind.wireName == value || kind.name == value) return kind;
    }
    return null;
  }
}

/// Gate outcome. [wireName] matches `fixtures/events.json` `expect`.
enum DriverRealtimeDisposition {
  accepted('accepted'),
  acceptedWithGap('accepted_with_gap'),
  duplicate('duplicate'),
  blockedAfterTerminal('blocked_after_terminal'),
  invalid('invalid');

  const DriverRealtimeDisposition(this.wireName);
  final String wireName;

  /// Accepted (with or without a gap): the event may be applied.
  bool get isAccepted => this == accepted || this == acceptedWithGap;
}

/// Device GPS fix on the wire (`GeoFix`): `{lat, lng, accuracy, heading?,
/// measuredAt}`.
class RealtimeGeoFix {
  const RealtimeGeoFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.headingDegrees,
    this.measuredAt,
  });

  factory RealtimeGeoFix.fromJson(Map<String, dynamic> json) => RealtimeGeoFix(
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    accuracyMeters: (json['accuracy'] as num?)?.toDouble(),
    headingDegrees: (json['heading'] as num?)?.toDouble(),
    measuredAt: json['measuredAt'] is String
        ? DateTime.parse(json['measuredAt'] as String).toUtc()
        : null,
  );

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? headingDegrees;
  final DateTime? measuredAt;

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    if (accuracyMeters != null) 'accuracy': accuracyMeters,
    if (headingDegrees != null) 'heading': headingDegrees,
    if (measuredAt != null) 'measuredAt': measuredAt!.toUtc().toIso8601String(),
  };
}

/// Chat message on the envelope (`Message`, kind `message` only).
class RealtimeMessage {
  const RealtimeMessage({
    required this.messageId,
    required this.from,
    required this.text,
    this.at,
  });

  factory RealtimeMessage.fromJson(Map<String, dynamic> json) =>
      RealtimeMessage(
        messageId: json['messageId'] as String,
        from: json['from'] as String,
        text: json['text'] as String,
        at: json['at'] is String
            ? DateTime.parse(json['at'] as String).toUtc()
            : null,
      );

  final String messageId;

  /// `rider`, `driver` or `support`.
  final String from;
  final String text;
  final DateTime? at;
}

class DriverRealtimeEvent {
  const DriverRealtimeEvent({
    required this.tripId,
    required this.kind,
    required this.sequence,
    required this.at,
    String? eventId,
    this.version = 0,
    this.serverTime,
    TripStatus? status,
    this.location,
    double? latitude,
    double? longitude,
    this.etaSeconds,
    this.message,
    this.chat,
    this.cancelFee,
    this.acceptedAt,
  }) : _eventId = eventId,
       _status = status,
       _latitude = latitude,
       _longitude = longitude;

  /// X14: what a transport reads. An unknown or newer [kind] (or a broken
  /// envelope) is skipped and returns null; it never stops the stream.
  static DriverRealtimeEvent? tryParse(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    if (DriverRealtimeKind.tryParse(map['kind'] as String?) == null) {
      return null;
    }
    try {
      return DriverRealtimeEvent.fromJson(map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Reads one wire envelope; throws on an unknown kind (see [tryParse]).
  /// Lifecycle status comes from
  /// `projection.status` (or the top-level `status` shorthand the contract
  /// fixtures use). Times are normalised to UTC.
  factory DriverRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final kind = DriverRealtimeKind.tryParse(json['kind'] as String?);
    if (kind == null) {
      throw FormatException('Unknown realtime kind', json['kind']);
    }
    final projection = json['projection'];
    final rawStatus = projection is Map
        ? projection['status'] as String?
        : json['status'] as String?;
    final location = json['location'];
    final message = json['message'];
    final cancelFee = json['cancelFee'];
    final accepted = projection is Map ? projection['acceptedAt'] : null;
    DateTime? time(String key) => json[key] is String
        ? DateTime.parse(json[key] as String).toUtc()
        : null;
    return DriverRealtimeEvent(
      eventId: json['eventId'] as String?,
      tripId: json['tripId'] as String? ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      kind: kind,
      at:
          time('occurredAt') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      serverTime: time('serverTime'),
      status: rawStatus == null ? null : TripStatusWire.parse(rawStatus),
      location: location is Map
          ? RealtimeGeoFix.fromJson(Map<String, dynamic>.from(location))
          : null,
      etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
      chat: message is Map
          ? RealtimeMessage.fromJson(Map<String, dynamic>.from(message))
          : null,
      cancelFee: cancelFee is Map
          ? Money.fromJson(Map<String, dynamic>.from(cancelFee))
          : null,
      acceptedAt: accepted is String ? DateTime.parse(accepted).toUtc() : null,
    );
  }

  final String tripId;
  final DriverRealtimeKind kind;

  /// Server-assigned, contiguous per trip (≥ 1).
  final int sequence;

  /// When the change happened. Prefer [occurredAt] (always UTC).
  final DateTime at;
  final String? _eventId;

  /// Projection version after this event (0: not sent by the in-memory bus).
  final int version;
  final DateTime? serverTime;
  final TripStatus? _status;
  final RealtimeGeoFix? location;
  final double? _latitude;
  final double? _longitude;
  final int? etaSeconds;

  /// Short text for the driver (e.g. "I'm on the way"). Chat messages use
  /// [chat].
  final String? message;
  final RealtimeMessage? chat;

  /// With [DriverRealtimeKind.riderCancelled], the driver's cancel fee as
  /// decided by the backend (zero: no fee; null: not decided).
  final Money? cancelFee;

  /// `projection.acceptedAt` (contract v0.4.0): when the driver accepted;
  /// the live free-cancel clock counts from it (owner Q12).
  final DateTime? acceptedAt;

  /// Server-assigned dedupe key. Envelopes without one (legacy in-process
  /// events) fall back to `tripId#sequence`.
  String get eventId => _eventId ?? '$tripId#$sequence';

  DateTime get occurredAt => at.toUtc();

  /// Lifecycle status of the projection this event carries, if any.
  TripStatus? get status => _status;

  double? get latitude => _latitude ?? location?.latitude;
  double? get longitude => _longitude ?? location?.longitude;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'tripId': tripId,
    'sequence': sequence,
    'version': version,
    'kind': kind.wireName,
    'occurredAt': occurredAt.toIso8601String(),
    'serverTime': (serverTime ?? at).toUtc().toIso8601String(),
    if (status != null || acceptedAt != null)
      'projection': {
        if (status != null) 'status': status!.wireName,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
      },
    if (location != null)
      'location': location!.toJson()
    else if (latitude != null && longitude != null)
      'location': {'lat': latitude, 'lng': longitude},
    if (etaSeconds != null) 'etaSeconds': etaSeconds,
    if (cancelFee != null) 'cancelFee': cancelFee!.toJson(),
  };
}

/// Client gate, the same in all apps (`contract.json#realtime.rules`):
/// - invalid: `sequence < 1` or a blank `tripId` (never mutates state);
/// - duplicate: a seen `eventId`, or `sequence <=` the last seen;
/// - gap (`sequence > last + 1`): accepted, and the caller resyncs;
/// - after a terminal status only payment, rating and message kinds pass.
class DriverRealtimeSequenceGate {
  final Map<String, int> _lastSequenceByTrip = <String, int>{};
  final Map<String, Set<String>> _seenByTrip = <String, Set<String>>{};
  final Set<String> _terminalTrips = <String>{};

  DriverRealtimeDisposition evaluate(DriverRealtimeEvent event) {
    if (event.sequence < 1 || event.tripId.trim().isEmpty) {
      return DriverRealtimeDisposition.invalid;
    }
    final seen = _seenByTrip.putIfAbsent(event.tripId, () => <String>{});
    final last = _lastSequenceByTrip[event.tripId];
    if (seen.contains(event.eventId) ||
        (last != null && event.sequence <= last)) {
      return DriverRealtimeDisposition.duplicate;
    }
    _lastSequenceByTrip[event.tripId] = event.sequence;
    seen.add(event.eventId);

    if (_terminalTrips.contains(event.tripId) &&
        !event.kind.passesAfterTerminal) {
      return DriverRealtimeDisposition.blockedAfterTerminal;
    }

    final hasGap = last != null && event.sequence > last + 1;
    if (_isTerminal(event)) {
      _terminalTrips.add(event.tripId);
    }
    return hasGap
        ? DriverRealtimeDisposition.acceptedWithGap
        : DriverRealtimeDisposition.accepted;
  }

  int? lastSequenceFor(String tripId) => _lastSequenceByTrip[tripId];

  bool isTerminal(String tripId) => _terminalTrips.contains(tripId);

  // One terminal set: contract.json#tripStatus.terminal. A rider cancel
  // always ends the trip, even when the projection is not attached.
  bool _isTerminal(DriverRealtimeEvent event) =>
      event.kind == DriverRealtimeKind.riderCancelled ||
      (event.status?.isTerminal ?? false);
}

/// Mirror of Rider's realtime seam; both apps read the same envelope.
abstract interface class DriverRealtime {
  Stream<DriverRealtimeEvent> subscribe(String tripId);

  Future<void> reconnectAndResync(String tripId);

  /// Demo only: a driver signal shown to the in-process rider stand-in.
  /// With a backend these are commands (`POST /trips/{id}/arrive`), and the
  /// resulting event comes back from the server.
  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  });

  void unsubscribe();

  void dispose();
}

/// In-memory bus. It stands in for the server: [emit] assigns the per-trip
/// `sequence`, the `eventId` and UTC times the way the backend will. A
/// WebSocket/SSE adapter replaces this class later and never numbers events.
class MemoryDriverRealtime implements DriverRealtime {
  MemoryDriverRealtime();

  final _controller = StreamController<DriverRealtimeEvent>.broadcast();
  final _lastByTrip = <String, DriverRealtimeEvent>{};
  int _sequence = 0;
  int _generation = 0;
  bool _disposed = false;
  final _sequencesByTrip = <String, int>{};
  final _projectionsByTrip = <String, DriverRealtimeEvent>{};
  String? _tripId;

  int get sequence => _sequence;

  void publish(DriverRealtimeEvent event) {
    if (_disposed) {
      return;
    }
    if (event.sequence < 1 || event.tripId.trim().isEmpty) {
      throw ArgumentError(
        'Valid trip ID and positive per-trip sequence required',
      );
    }
    final projection = _projectionsByTrip[event.tripId];
    final ended =
        projection?.status?.isTerminal == true ||
        projection?.kind == DriverRealtimeKind.riderCancelled;
    if (ended && !event.kind.passesAfterTerminal) {
      return;
    }
    final previous = _lastByTrip[event.tripId];
    if (previous == null || event.sequence > previous.sequence) {
      _lastByTrip[event.tripId] = event;
    }
    if (previous != null && event.sequence <= previous.sequence) {
      return;
    }
    _sequencesByTrip[event.tripId] = event.sequence;
    // A location event never replaces the cached projection.
    if (event.kind == DriverRealtimeKind.tripProjection ||
        event.kind == DriverRealtimeKind.riderCancelled) {
      _projectionsByTrip[event.tripId] = event;
    }
    if (event.sequence > _sequence) {
      _sequence = event.sequence;
    }
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
    final nextSequence = (_sequencesByTrip[tripId] ?? 0) + 1;
    final previousVersion = _projectionsByTrip[tripId]?.version ?? 0;
    final changesProjection = status != null;
    final now = DateTime.now().toUtc();
    final event = DriverRealtimeEvent(
      eventId: 'mem-$tripId-$nextSequence',
      tripId: tripId,
      kind: kind,
      sequence: nextSequence,
      version: changesProjection
          ? previousVersion + 1
          : (previousVersion < 1 ? 1 : previousVersion),
      at: (at ?? now).toUtc(),
      serverTime: now,
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
    if (_disposed) {
      throw StateError('Realtime disposed');
    }
    if (tripId.trim().isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'Trip ID is required');
    }
    _tripId = tripId;
    final generation = ++_generation;
    return _controller.stream.where(
      (event) =>
          !_disposed &&
          generation == _generation &&
          _tripId == tripId &&
          event.tripId == tripId,
    );
  }

  @override
  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  }) async {
    emit(tripId: tripId, kind: kind, message: message);
  }

  @override
  Future<void> reconnectAndResync(String tripId) async {
    if (_disposed || _tripId != tripId) {
      return;
    }
    final projection = _projectionsByTrip[tripId];
    final last = projection ?? _lastByTrip[tripId];
    if (last == null) return;

    // A cached nonterminal projection may predate subsequent location events.
    // Replaying its old sequence would be dropped by the receiving sequence
    // gate, leaving the driver's ride stage unrestored. Re-issue the current
    // projection as a new event (new sequence and eventId, as a server
    // resync would return) while preserving its lifecycle status.
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
    if (_disposed) {
      return;
    }
    _disposed = true;
    unsubscribe();
    _controller.close();
  }

  String? get subscribedTripId => _tripId;
}
