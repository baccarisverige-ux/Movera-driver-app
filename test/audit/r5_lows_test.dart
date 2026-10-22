// Audit round 5, the low bugs (Wave 6b).
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';

void main() {
  test('driver-r5-8: admin\'s scheduled-rides "until" is a local time', () {
    final access = ScheduledRidesDriverAccess.fromJson(
        {'on': false, 'until': '2026-10-23T22:30:00Z'});
    expect(access.until!.isUtc, isFalse,
        reason: 'the notice formats its date: a UTC date can be a day early');
    expect(access.until!.isAtSameMomentAs(DateTime.utc(2026, 10, 23, 22, 30)),
        isTrue);
  });
}
