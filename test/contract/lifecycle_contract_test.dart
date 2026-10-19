import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File('contracts/$path').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final contract = _json('contract.json');
  final statuses = contract['tripStatus'] as Map<String, dynamic>;

  List<String> wire(Iterable<TripStatus> values) =>
      values.map((s) => s.wireName).toList();

  group('TripStatus = contract.json#tripStatus', () {
    test('values, in order', () {
      expect(wire(TripStatus.values), statuses['values']);
    });

    test('one terminal set and the assigned / onboard sets', () {
      expect(wire(TripStatus.values.where((s) => s.isTerminal)),
          statuses['terminal']);
      expect(wire(TripStatus.values.where((s) => s.isDriverAssigned)),
          statuses['driverAssigned']);
      expect(wire(TripStatus.values.where((s) => s.isRiderOnboard)),
          statuses['riderOnboard']);
    });

    test('parse reads wire names and legacy camelCase saves', () {
      for (final status in TripStatus.values) {
        expect(TripStatusWire.parse(status.wireName), status);
        expect(TripStatusWire.parse(status.name), status);
      }
      expect(TripStatusWire.parse('cancelled_by_system'),
          TripStatus.cancelledBySystem);
      expect(TripStatusWire.tryParse('paymentProcessing'), isNull);
      expect(() => TripStatusWire.parse('done'), throwsFormatException);
    });
  });

  group('transition table = contract.json#transitions', () {
    test('row by row', () {
      final rows = (contract['transitions'] as List).cast<Map<String, dynamic>>();
      expect(TripTransitions.table.length, rows.length);
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final dart = TripTransitions.table[i];
        final where = 'row $i (${row['command']} by ${row['actor']})';
        expect(dart.command.wireName, row['command'], reason: where);
        expect(dart.actor.wireName, row['actor'], reason: where);
        expect(wire(dart.from), row['from'], reason: where);
        expect(dart.to.wireName, row['to'], reason: where);
        expect(dart.when?.wireName, row['when'], reason: where);
      }
    });

    test('commands and actors are the contract vocabulary', () {
      final commands = (contract['transitions'] as List)
          .map((row) => (row as Map)['command'])
          .toSet();
      expect(TripCommand.values.map((c) => c.wireName).toSet(), commands);
      expect(TripActor.values.map((a) => a.wireName).toList(),
          contract['actors']);
    });
  });

  test('replays fixtures/scenarios.json with identical results', () {
    final scenarios = (_json('fixtures/scenarios.json')['scenarios'] as List)
        .cast<Map<String, dynamic>>();
    expect(scenarios, isNotEmpty);
    for (final scenario in scenarios) {
      final kind = TripKind.tryParse(scenario['kind'] as String)!;
      var status = TripStatus.draft;
      for (final step in (scenario['steps'] as List).cast<List>()) {
        final command = TripCommand.tryParse(step[0] as String);
        final actor = TripActor.tryParse(step[1] as String);
        expect(command, isNotNull, reason: '${step[0]}');
        expect(actor, isNotNull, reason: '${step[1]}');
        final next =
            TripTransitions.target(status, command!, actor!, kind: kind);
        expect(next?.wireName ?? 'invalid_transition', step[2],
            reason: '${scenario['id']}: ${step[0]} by ${step[1]} '
                'from ${status.wireName}');
        if (next == null) {
          expect(() => TripTransitions.apply(status, command, actor, kind: kind),
              throwsA(isA<InvalidTripTransition>()));
        } else {
          status = next;
        }
      }
    }
  });
}
