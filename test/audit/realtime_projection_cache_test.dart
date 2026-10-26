import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

void main() {
  test('interleaved trips keep contiguous independent sequences', () {
    final bus = MemoryDriverRealtime();
    expect(
      bus.emit(tripId: 'A', kind: DriverRealtimeKind.location).sequence,
      1,
    );
    expect(
      bus.emit(tripId: 'B', kind: DriverRealtimeKind.location).sequence,
      1,
    );
    expect(
      bus.emit(tripId: 'A', kind: DriverRealtimeKind.location).sequence,
      2,
    );
    bus.dispose();
  });
  test(
    'resync projection is accepted by sequence gate after newer GPS',
    () async {
      final bus = MemoryDriverRealtime();
      final gate = DriverRealtimeSequenceGate();
      final at = DateTime.utc(2026, 10, 8);
      final projection = bus.emit(
        tripId: 'trip-a',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.arrived,
        at: at,
      );
      expect(projection.sequence, 1);
      bus.emit(tripId: 'trip-a', kind: DriverRealtimeKind.location);
      final recent = bus.emit(
        tripId: 'trip-a',
        kind: DriverRealtimeKind.location,
      );
      expect(recent.sequence, 3);
      expect(gate.evaluate(recent), DriverRealtimeDisposition.accepted);

      final received = <DriverRealtimeEvent>[];
      final sub = bus.subscribe('trip-a').listen(received.add);
      await bus.reconnectAndResync('trip-a');
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.single.status, TripStatus.arrived);
      expect(received.single.sequence, greaterThan(recent.sequence));
      expect(
        gate.evaluate(received.single),
        DriverRealtimeDisposition.accepted,
      );
      await sub.cancel();
      bus.dispose();
    },
  );

  test(
    'resync retains lifecycle projection despite later locations and terminal dominates',
    () async {
      final bus = MemoryDriverRealtime();
      bus.emit(
        tripId: 'A',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.inTrip,
      );
      bus.emit(tripId: 'A', kind: DriverRealtimeKind.location);
      final seen = <DriverRealtimeEvent>[];
      final sub = bus.subscribe('A').listen(seen.add);
      await bus.reconnectAndResync('A');
      await Future<void>.delayed(Duration.zero);
      expect(seen.single.status, TripStatus.inTrip);
      seen.clear();
      bus.emit(
        tripId: 'A',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.completed,
      );
      bus.emit(
        tripId: 'A',
        kind: DriverRealtimeKind.tripProjection,
        status: TripStatus.inTrip,
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.single.status, TripStatus.completed);
      bus.unsubscribe();
      seen.clear();
      await bus.reconnectAndResync('A');
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      await sub.cancel();
      bus.dispose();
    },
  );
}
