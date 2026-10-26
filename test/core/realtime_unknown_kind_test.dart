import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

// X14 (driver part): an unknown or newer realtime kind is skipped, never a
// crash of the stream that reads it.
void main() {
  Map<String, dynamic> envelope(String kind, {int sequence = 1}) => {
    'eventId': 'e$sequence',
    'tripId': 'T1',
    'sequence': sequence,
    'version': sequence,
    'kind': kind,
    'occurredAt': '2026-10-19T08:30:00Z',
    'serverTime': '2026-10-19T08:30:00Z',
  };

  test('an unknown kind is skipped, not thrown', () {
    expect(DriverRealtimeEvent.tryParse(envelope('tip_added')), isNull);
    expect(DriverRealtimeEvent.tryParse(envelope('')), isNull);
    expect(DriverRealtimeEvent.tryParse({'tripId': 'T1'}), isNull);
  });

  test('broken envelopes are skipped too', () {
    expect(DriverRealtimeEvent.tryParse(null), isNull);
    expect(DriverRealtimeEvent.tryParse('trip_projection'), isNull);
    expect(
      DriverRealtimeEvent.tryParse({
        ...envelope('trip_projection'),
        'occurredAt': 'yesterday',
      }),
      isNull,
    );
    expect(
      DriverRealtimeEvent.tryParse({...envelope('location'), 'sequence': 'x'}),
      isNull,
    );
  });

  test('known kinds still parse and pass the gate', () {
    final gate = DriverRealtimeSequenceGate();
    final first = DriverRealtimeEvent.tryParse(envelope('trip_projection'));
    expect(first, isNotNull);
    expect(gate.evaluate(first!), DriverRealtimeDisposition.accepted);
    // An unknown kind in between is dropped; the next known one goes on.
    expect(
      DriverRealtimeEvent.tryParse(envelope('surge_changed', sequence: 2)),
      isNull,
    );
    final third = DriverRealtimeEvent.tryParse(
      envelope('driver_arrived', sequence: 3),
    );
    expect(gate.evaluate(third!), DriverRealtimeDisposition.acceptedWithGap);
  });
}
