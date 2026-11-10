import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/core/live/live_driver_services.dart';

import 'request_budget_harness.dart';

/// Global plan step 62 (T3): the request budget per state of the driver
/// app. A state that sends more than its budget (+ [margin]) fails here. A
/// PR that raises a number changes [budgets] AND docs/request-budgets.md
/// and says why (GLOBAL-SAFE-PLAN T3).
const Map<DriverState, Map<String, double>> budgets = {
  DriverState.offline: {
    'GET /api/v1/driver/profile': 1.0,
    'GET /api/v1/notifications': 1.0,
    'GET /api/v1/driver/reminders': 1.0,
    'GET /api/v1/driver/onboarding/settings': 1.0,
  },
  DriverState.onlineIdle: {
    'GET /api/v1/driver/profile': 1.0,
    'GET /api/v1/notifications': 1.0,
    'GET /api/v1/driver/reminders': 1.0,
    'GET /api/v1/driver/onboarding/settings': 1.0,
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/driver/surge-map': 1.0,
  },
  DriverState.offerShown: {
    'GET /api/v1/driver/profile': 1.0,
    'GET /api/v1/notifications': 1.0,
    'GET /api/v1/driver/reminders': 1.0,
    'GET /api/v1/driver/onboarding/settings': 1.0,
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/driver/surge-map': 1.0,
  },
  DriverState.toPickup: {
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/routes/driving/{coords}': 0.7,
  },
  DriverState.atPickup: {'POST /api/v1/driver/location': 6.0},
  DriverState.onTrip: {
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/routes/driving/{coords}': 0.7,
  },
  DriverState.tripFinished: {'POST /api/v1/driver/location': 6.0},
  DriverState.background: {'POST /api/v1/driver/location': 6.0},
  DriverState.offlineConfigStreamDown: {
    'GET /api/v1/driver/profile': 1.0,
    'GET /api/v1/notifications': 1.0,
    'GET /api/v1/driver/reminders': 1.0,
    'GET /api/v1/driver/onboarding/settings': 1.0,
    'GET /api/v1/driver/config': 1.1,
    'GET /api/v1/driver/config/stream (SSE open)': 1.1,
  },
  DriverState.onlineOffersStreamDown: {
    'GET /api/v1/driver/profile': 1.0,
    'GET /api/v1/notifications': 1.0,
    'GET /api/v1/driver/reminders': 1.0,
    'GET /api/v1/driver/onboarding/settings': 1.0,
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/driver/surge-map': 1.0,
    'GET /api/v1/driver/offers/stream (SSE open)': 2.0,
  },
  DriverState.toPickupTripStreamDown: {
    'POST /api/v1/driver/location': 6.0,
    'GET /api/v1/routes/driving/{coords}': 0.7,
    'GET /api/v1/trips/{tripId}': 6.0,
    'GET /api/v1/trips/{tripId}/events (SSE open)': 2.0,
  },
};

/// Allowed over a budget: 10 % or 0.5 a minute, whichever is larger.
double margin(double budget) => budget * 0.1 > 0.5 ? budget * 0.1 : 0.5;

/// Every endpoint over its budget (an endpoint with no budget has 0).
List<String> overBudget(StateMeasure m) {
  final allowed = budgets[m.state]!;
  return [
    for (final e in m.perMinute.entries)
      if (e.value > (allowed[e.key] ?? 0) + margin(allowed[e.key] ?? 0))
        '${m.state.name}: ${e.key} ${e.value.toStringAsFixed(2)}/min '
            '> budget ${allowed[e.key] ?? 0}',
  ];
}

void main() {
  final measured = {for (final s in DriverState.values) s: measure(s)};

  test('prints the measured table (docs/request-budgets.md)', () {
    final out = StringBuffer();
    for (final m in measured.values) {
      final keys = {...m.perMinute.keys, ...m.onEntry.keys}.toList()..sort();
      for (final k in keys) {
        out.writeln(
          '| ${m.state.name} | `$k` | ${budgets[m.state]?[k] ?? 0} | '
          '${(m.perMinute[k] ?? 0).toStringAsFixed(2)} | ${m.onEntry[k] ?? 0} |',
        );
      }
    }
    for (final m in measured.values) {
      out.writeln('| ${m.state.name} | ${m.total.toStringAsFixed(2)} |');
    }
    // ignore: avoid_print
    print(out);
  });

  for (final state in DriverState.values) {
    test('${state.name} stays inside its request budget', () {
      expect(overBudget(measured[state]!), isEmpty);
    });
  }

  test('every budget is written in docs/request-budgets.md', () {
    final doc = File('docs/request-budgets.md').readAsStringSync();
    for (final entry in budgets.entries) {
      for (final b in entry.value.entries) {
        expect(
          doc.contains('| ${entry.key.name} | `${b.key}` | ${b.value} |'),
          isTrue,
          reason: '${entry.key.name} ${b.key} ${b.value} missing in the doc',
        );
      }
    }
  });

  test('the check fails on one extra poll (Rule 35 guard)', () {
    // An extra 30 s read of the airport queue on Home (which is not read
    // away from an airport): +2 a minute.
    final m = measure(
      DriverState.onlineIdle,
      extra: (LiveDriverServices live, stops) {
        final t = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(AirportQueue.instance.refresh(live.api)),
        );
        stops.add(t.cancel);
      },
    );
    expect(overBudget(m), isNotEmpty);
  });
}
