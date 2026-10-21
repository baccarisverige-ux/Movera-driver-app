import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/demo_mode_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// driver-u175: the demo banner takes the status-bar inset. The screens
/// below it must not pad for the status bar a second time.
void main() {
  testWidgets('screens under the demo banner do not get the top inset again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverStartPosition.clearMemory();
    await (await SharedPreferences.getInstance())
        .setString(DriverStartPosition.key, '{"lat":59.3326,"lng":18.0649}');
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 150, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 150, bottom: 102);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MoveraApp());
    await tester.pump(const Duration(milliseconds: 120));

    final banner = tester.getRect(find.byType(DemoModeBanner));
    expect(banner.top, 0);
    expect(banner.bottom, greaterThan(50), reason: 'the banner keeps the 50 px status bar');
    final home = tester.element(find.byType(DriverHome));
    expect(tester.getTopLeft(find.byType(DriverHome)).dy, banner.bottom);
    expect(MediaQuery.paddingOf(home).top, 0);
    expect(MediaQuery.viewPaddingOf(home).top, 0);
    expect(MediaQuery.paddingOf(home).bottom, 34, reason: 'the home indicator inset stays');
    expect(MediaQuery.sizeOf(home), const Size(390, 844), reason: 'LayoutViewport size is kept');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
