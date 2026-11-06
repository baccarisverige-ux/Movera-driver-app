import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account.dart';

/// FIX JOB 4 "take-back" (contract v0.18.35 §59, contract.json#bookedTakeBack;
/// owner Q2 / Q-A / job-4 Q4 of 2026-11-04). The server sends two new driver
/// notices with their own sv / fr / en texts: `reservation_taken_back` (a late
/// booked ride went to another driver, counts on the cancel record, no fee)
/// and `heading_not_to_rider` (every minute while not heading to the pickup).
void main() {
  final contract =
      jsonDecode(File('contracts/contract.json').readAsStringSync())
          as Map<String, dynamic>;

  ServerNotification notice(String kind) => ServerNotification.fromJson({
    'notificationId': 'ntf_1',
    'kind': kind,
    'title': 'T',
    'body': 'B',
    'at': '2026-11-05T10:00:00Z',
    'read': false,
    'tripId': 'trp_1',
  });

  test('the contract has both kinds with sv / fr / en texts', () {
    final heading = (contract['pickupWaiting'] as Map)['headingCheck'] as Map;
    final notHeading = heading['notHeadingNotice'] as Map;
    expect(notHeading['kind'], 'heading_not_to_rider');
    for (final lang in ['sv', 'fr', 'en']) {
      expect((notHeading['title'] as Map)[lang], isNotEmpty);
      expect((notHeading['body'] as Map)[lang], isNotEmpty);
    }
    final push = (contract['bookLater'] as Map)['push'] as Map;
    expect(push['kinds'], contains('reservation_taken_back'));
    final texts = (push['texts'] as Map)['reservation_taken_back'] as Map;
    for (final lang in ['sv', 'fr', 'en']) {
      expect((texts['title'] as Map)[lang], isNotEmpty);
    }
    // Owner Q-A: a live ride is never taken back.
    expect(
      ((contract['configDefaults'] as Map)['headingCheck'] as Map)['reassign'],
      false,
    );
  });

  test('both notices are trip warnings in the bell list (warning icon)', () {
    expect(notice('heading_not_to_rider').isTripWarning, isTrue);
    expect(notice('reservation_taken_back').isTripWarning, isTrue);
    expect(notice('trip_taken_back').isTripWarning, isTrue);
    expect(notice('reservation_reminder').isTripWarning, isFalse);
    expect(notice('fleet_invitation').isTripWarning, isFalse);
  });
}
