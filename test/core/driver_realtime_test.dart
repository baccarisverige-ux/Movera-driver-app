import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

void main() {
  String activeRideLibrary() {
    const dir = 'lib/presentation/driver/accept ride';
    return File('$dir/accept_ride.dart').readAsStringSync() +
        File('$dir/accept_ride_trip.dart').readAsStringSync() +
        File('$dir/accept_ride_panel.dart').readAsStringSync();
  }

  test('sequence gate rejects duplicate and reordered events', () {
    final gate = DriverRealtimeSequenceGate();
    final at = DateTime(2026, 9, 30);

    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:4,at:at,
      )),
      DriverRealtimeDisposition.accepted,
    );
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:4,at:at,
      )),
      DriverRealtimeDisposition.duplicate,
    );
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:3,at:at,
      )),
      DriverRealtimeDisposition.duplicate,
    );
  });

  test('invalid envelopes cannot advance sequence or poison terminal trip', () {
    final gate = DriverRealtimeSequenceGate();
    final at = DateTime(2026, 10, 8);
    const trip = 'trip-1';
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId: trip,
        kind: DriverRealtimeKind.riderCancelled,
        sequence: 0,
        at: at,
        status: TripStatus.cancelledByRider,
      )),
      DriverRealtimeDisposition.invalid,
    );
    expect(gate.lastSequenceFor(trip), isNull);
    expect(gate.isTerminal(trip), isFalse);
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId: '  ',
        kind: DriverRealtimeKind.riderCancelled,
        sequence: 1,
        at: at,
        status: TripStatus.cancelledByRider,
      )),
      DriverRealtimeDisposition.invalid,
    );
    expect(gate.lastSequenceFor('  '), isNull);
    expect(gate.isTerminal('  '), isFalse);
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId: trip,
        kind: DriverRealtimeKind.tripProjection,
        sequence: 1,
        at: at,
        status: TripStatus.inTrip,
      )),
      DriverRealtimeDisposition.accepted,
    );
    expect(gate.isTerminal(trip), isFalse);
  });

  test('sequence gate exposes gaps so the adapter can resync', () {
    final gate = DriverRealtimeSequenceGate();
    final at = DateTime(2026, 9, 30);
    gate.evaluate(DriverRealtimeEvent(
      tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:1,at:at,
    ));

    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:3,at:at,
      )),
      DriverRealtimeDisposition.acceptedWithGap,
    );
    expect(gate.lastSequenceFor('trip-1'),3);
  });

  test('terminal realtime event dominates later non-terminal events', () {
    final gate = DriverRealtimeSequenceGate();
    final at = DateTime(2026, 9, 30);

    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',
        kind:DriverRealtimeKind.riderCancelled,
        sequence:5,
        at:at,
        status:TripStatus.cancelledByRider,
      )),
      DriverRealtimeDisposition.accepted,
    );
    expect(gate.isTerminal('trip-1'),isTrue);
    expect(
      gate.evaluate(DriverRealtimeEvent(
        tripId:'trip-1',
        kind:DriverRealtimeKind.riderOnTheWay,
        sequence:6,
        at:at,
      )),
      DriverRealtimeDisposition.blockedAfterTerminal,
    );
  });

  test('reconnect replays newest event even after an older publish', () async {
    final bus = MemoryDriverRealtime();
    final at = DateTime(2026, 9, 30);
    bus.publish(DriverRealtimeEvent(
      tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:10,at:at,
      latitude:59.33,
    ));
    bus.publish(DriverRealtimeEvent(
      tripId:'trip-1',kind:DriverRealtimeKind.location,sequence:8,at:at,
      latitude:1,
    ));

    final seen=<DriverRealtimeEvent>[];
    final sub=bus.subscribe('trip-1').listen(seen.add);
    await bus.reconnectAndResync('trip-1');
    await Future<void>.delayed(Duration.zero);

    expect(seen,hasLength(1));
    expect(seen.single.sequence,10);
    expect(seen.single.latitude,59.33);
    await sub.cancel();
    bus.dispose();
  });

  test('events are sequence-numbered and filtered by tripId', () async {
    final bus = MemoryDriverRealtime();
    final seen = <DriverRealtimeEvent>[];
    final sub = bus.subscribe('trip-1').listen(seen.add);

    bus.emit(
      tripId: 'trip-1',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.inTrip,
    );
    bus.emit(
      tripId: 'trip-2',
      kind: DriverRealtimeKind.riderCancelled,
      status: TripStatus.cancelledByRider,
    );
    bus.emit(
      tripId: 'trip-1',
      kind: DriverRealtimeKind.riderCancelled,
      status: TripStatus.cancelledByRider,
    );

    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(2));
    expect(seen.first.sequence, 1);
    expect(seen.last.sequence, 2);
    expect(seen.last.kind, DriverRealtimeKind.riderCancelled);
    expect(seen.last.status, TripStatus.cancelledByRider);
    await sub.cancel();
    bus.dispose();
  });

  test('pickup communication signals round-trip through realtime seam', () async {
    final bus = MemoryDriverRealtime();
    final seen = <DriverRealtimeEvent>[];
    final sub = bus.subscribe('trip-1').listen(seen.add);

    await bus.sendSignal(
      tripId: 'trip-1',
      kind: DriverRealtimeKind.driverArrived,
      message: 'Your driver has arrived at the pickup point.',
    );
    await bus.sendSignal(
      tripId: 'trip-1',
      kind: DriverRealtimeKind.riderOnTheWay,
      message: "I'm on the way",
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(2));
    expect(seen.first.kind, DriverRealtimeKind.driverArrived);
    expect(seen.last.kind, DriverRealtimeKind.riderOnTheWay);
    expect(seen.last.message, "I'm on the way");
    await sub.cancel();
    bus.dispose();
  });

  test('arrival action remains wired in the expanded sheet', () {
    final rideSource = activeRideLibrary();
    final dockSource = File(
      'lib/presentation/driver/accept ride/trip_bottom_bar.dart',
    ).readAsStringSync();

    expect(rideSource.contains('_confirmPickupArrival'), isTrue);
    expect(rideSource.contains('DriverRealtimeKind.driverArrived'), isTrue);
    expect(rideSource.contains('_buildPrimaryAction()'), isTrue);
    expect(dockSource.contains("active-ride-arrived-button"), isFalse);
    expect(rideSource.contains("I've arrived"), isTrue);
  });

  test('active ride consumes rider cancellation as rider-owned terminal state', () {
    final source = activeRideLibrary();

    expect(
      source.contains('case DriverRealtimeKind.riderCancelled'),
      isTrue,
    );
    expect(
      source.contains('TripStatus.cancelledByRider'),
      isTrue,
    );
    expect(source.contains('showRiderCancelledSheet'), isTrue);
  });

  test('reconnect replays the last event for the trip', () async {
    final bus = MemoryDriverRealtime();
    bus.emit(
      tripId: 'trip-1',
      kind: DriverRealtimeKind.location,
      latitude: 59.3293,
      longitude: 18.0686,
    );

    final seen = <DriverRealtimeEvent>[];
    final sub = bus.subscribe('trip-1').listen(seen.add);
    await bus.reconnectAndResync('trip-1');
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.kind, DriverRealtimeKind.location);
    expect(seen.single.latitude, 59.3293);
    await sub.cancel();
    bus.dispose();
  });
}

