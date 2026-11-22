import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/staging/recording_client.dart';

/// Firebase run 51 (main 2611dd1): TRANSITION:arrived:ERRORS failed on the
/// live-location card's designed probe `PUT /api/v1/trips/<id>/live-location`
/// -> 409 (zone switch off; driver_live_location_card.dart `_probe`). Only
/// that route with that status is allowed; everything else still counts.
RecordedCall call(String method, String path, {int? status, String? error}) =>
    RecordedCall(
        at: DateTime(2026, 11, 22),
        method: method,
        path: path,
        queryNames: const [],
      )
      ..status = status
      ..error = error;

void main() {
  test('the live-location probe answered 409 is not an error', () {
    final c = call('PUT', '/api/v1/trips/t-51/live-location', status: 409);
    expect(c.failed, isTrue);
    expect(c.countsAsError, isFalse);
  });

  test('nothing broader is allowed', () {
    for (final c in [
      call('PUT', '/api/v1/trips/t-51/live-location', status: 400),
      call('PUT', '/api/v1/trips/t-51/live-location', status: 500),
      call('PUT', '/api/v1/trips/t-51/live-location', error: 'SocketException'),
      call('POST', '/api/v1/trips/t-51/live-location', status: 409),
      call('PUT', '/api/v1/trips/t-51/arrive', status: 409),
      call('PUT', '/api/v1/trips/t-51/live-location/x', status: 409),
      call('PUT', '/api/v1/rides/t-51/live-location', status: 409),
    ]) {
      expect(c.countsAsError, isTrue, reason: '$c');
    }
  });

  test('TRANSITION ERRORS uses countsAsError', () {
    final src = File(
      'integration_test/staging/transition_watch.dart',
    ).readAsStringSync();
    expect(src, contains('c.countsAsError'));
    expect(src, isNot(contains('if (c.failed)')));
  });
}
