import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home offer radar orchestration is outside the widget file', () {
    final home = File(
      'lib/presentation/driver/home/home.dart',
    ).readAsStringSync();
    final offers = File(
      'lib/presentation/driver/home/home_offer_radar.dart',
    ).readAsStringSync();

    expect(home, contains("part 'home_offer_radar.dart';"));
    expect(home, contains('class DriverHome'));
    expect(home, isNot(contains('void _scheduleVisibleOffers')));
    expect(offers, contains("part of 'home.dart';"));
    expect(offers, contains('extension _HomeOfferRadar on _DriverHomeState'));
    expect(offers, contains('Duration(milliseconds: 2200)'));
    expect(offers, contains('Duration(milliseconds: 11500)'));
    expect(offers, contains('Duration(milliseconds: 14500)'));
    expect(offers, contains('Duration(milliseconds: 17500)'));
    expect(offers, contains('Duration(milliseconds: 50000)'));
    // The reservation's near-pickup step counts the minutes before its
    // pickup time on the demo day, with the admin's minutes; the demo day
    // reaches it 40 s after start (admin jobs L1–L3).
    final scheduled = File(
      'lib/presentation/driver/home/home_scheduled.dart',
    ).readAsStringSync();
    expect(offers, contains('_HomeScheduled(this)._untilExclusiveStep()'));
    expect(scheduled, contains('_rules.exclusiveBeforeMinutes'));
    expect(scheduled, isNot(contains('setState(')));
    expect(
      File('lib/core/admin/driver_home_admin_content.dart').readAsStringSync(),
      contains('nearPickupAfter = Duration(milliseconds: 40000)'),
    );
    expect(home, contains('Duration(milliseconds: 1400)'));
    expect(home, contains('void _rebuild('));
    expect(offers, isNot(contains('setState(')));
  });
}
