import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File('contracts/$path').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final realtime = _json('contract.json')['realtime'] as Map<String, dynamic>;

  test('kinds and afterTerminal = contract.json#realtime', () {
    expect(
      DriverRealtimeKind.values.map((k) => k.wireName).toList(),
      realtime['kinds'],
    );
    expect(
      DriverRealtimeKind.values
          .where((k) => k.passesAfterTerminal)
          .map((k) => k.wireName)
          .toList(),
      realtime['afterTerminal'],
    );
  });

  test('replays fixtures/events.json with identical dispositions', () {
    final cases = (_json('fixtures/events.json')['cases'] as List).cast<Map>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final gate = DriverRealtimeSequenceGate();
      for (final raw in (c['events'] as List).cast<Map>()) {
        final event = DriverRealtimeEvent.fromJson(
          Map<String, dynamic>.from(raw),
        );
        expect(
          gate.evaluate(event).wireName,
          raw['expect'],
          reason: '${c['id']} / ${raw['eventId']}',
        );
      }
    }
  });

  test('envelope reads the wire shape, in UTC', () {
    final event = DriverRealtimeEvent.fromJson({
      'eventId': 'e2',
      'tripId': 'T5',
      'sequence': 2,
      'version': 2,
      'kind': 'rider_cancelled',
      'occurredAt': '2026-10-19T10:30:00+02:00',
      'serverTime': '2026-10-19T08:30:01Z',
      'projection': {'status': 'cancelled_by_rider'},
      'location': {
        'lat': 59.33,
        'lng': 18.07,
        'accuracy': 5,
        'measuredAt': '2026-10-19T08:29:59Z',
      },
      'cancelFee': {'amountMinor': 4500, 'currency': 'SEK'},
    });
    expect(event.eventId, 'e2');
    expect(event.version, 2);
    expect(event.status, TripStatus.cancelledByRider);
    expect(event.occurredAt, DateTime.utc(2026, 10, 19, 8, 30));
    expect(event.occurredAt.isUtc, isTrue);
    expect(event.serverTime!.isUtc, isTrue);
    expect(event.latitude, 59.33);
    expect(event.cancelFee, const Money(minorUnits: 4500));
    final back = event.toJson();
    expect(back['kind'], 'rider_cancelled');
    expect(back['occurredAt'], '2026-10-19T08:30:00.000Z');
    expect(back['cancelFee'], {'amountMinor': 4500, 'currency': 'SEK'});
  });

  test('a seen eventId is a duplicate even with a new sequence', () {
    final gate = DriverRealtimeSequenceGate();
    final at = DateTime.utc(2026, 10, 19);
    DriverRealtimeEvent e(String id, int seq) => DriverRealtimeEvent(
      eventId: id,
      tripId: 'T',
      kind: DriverRealtimeKind.location,
      sequence: seq,
      at: at,
    );
    expect(gate.evaluate(e('a', 1)), DriverRealtimeDisposition.accepted);
    expect(gate.evaluate(e('a', 2)), DriverRealtimeDisposition.duplicate);
    expect(gate.evaluate(e('b', 3)), DriverRealtimeDisposition.acceptedWithGap);
  });

  test('the in-memory bus stands in for the server: ids, sequence, UTC', () {
    final bus = MemoryDriverRealtime();
    final first = bus.emit(tripId: 'T', kind: DriverRealtimeKind.location);
    final second = bus.emit(
      tripId: 'T',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.arrived,
    );
    expect([first.sequence, second.sequence], [1, 2]);
    expect(first.eventId, isNot(second.eventId));
    expect(second.version, greaterThan(0));
    expect(first.occurredAt.isUtc && first.serverTime!.isUtc, isTrue);
    // After a terminal projection, only payment / rating / message pass.
    bus.emit(
      tripId: 'T',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.completed,
    );
    final seen = <DriverRealtimeKind>[];
    final sub = bus.subscribe('T').listen((e) => seen.add(e.kind));
    bus.emit(tripId: 'T', kind: DriverRealtimeKind.location);
    bus.emit(tripId: 'T', kind: DriverRealtimeKind.paymentUpdated);
    addTearDown(() async {
      await sub.cancel();
      bus.dispose();
    });
    return Future<void>.delayed(
      Duration.zero,
    ).then((_) => expect(seen, [DriverRealtimeKind.paymentUpdated]));
  });
}
