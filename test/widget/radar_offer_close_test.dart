import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  testWidgets('the small × on a Home Radar card removes that offer (R8-2)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dispatch = DemoDispatchRepository();
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await tester.pump(const Duration(milliseconds: 1550));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(DriverOfferRules.current.exclusiveAcceptTime);
    await tester.pump(const Duration(milliseconds: 900));

    final card = find.byKey(const ValueKey<String>('radar-offer-card-nearby-1'));
    expect(card, findsOneWidget);
    // The radar's orange contour (R8-5).
    final box = tester.widget<Container>(card).decoration! as BoxDecoration;
    expect((box.border! as Border).top.color, MoveraRadarOrb.offerAccent);

    // The front card's × is the one on top.
    final close = find.byKey(const ValueKey<String>('radar-offer-close'));
    expect(tester.getSize(close.hitTestable().first).width, greaterThanOrEqualTo(40));
    await tester.tap(close.hitTestable().first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(card, findsNothing);

    tester.takeException();
    await tester.pumpWidget(const SizedBox());
    dispatch.dispose();
  });
}
