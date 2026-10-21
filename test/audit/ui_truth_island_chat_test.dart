// Wave 5 D5.2 (UI truth), part a: messages the app shows must be backed
// by what really happened.
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/island/island_waiting_signals.dart';

void main() {
  test('driver-u20: outside the demo the admin area demand never promises '
      'a trip soon, a busy area or rising demand', () {
    final tips = IslandWaitingSignals.fromHome(
      const DriverHomeAdminContentService().load(),
      now: DateTime(2026, 10, 21, 9),
    ).tips().map((t) => t.title);
    expect(tips, isNot(contains('Expect a trip in 2–5 min')));
    expect(tips, isNot(contains('Busy area · trips expected soon')));
    expect(tips, isNot(contains('Demand rising near you')));
  });
}
