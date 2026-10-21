// Wave 5 D5.2 (UI truth), part b: Home, onboarding and profile show only
// what really happened.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/navigation.dart';
import 'package:movera/presentation/driver/auth/sign%20in/sign_in.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/take%20id%20photo/take_id_photo.dart';

/// [first] as the app's first route, inside the app's runtime scope, with
/// [push] opened on top of it.
Future<void> _app(WidgetTester tester, Widget first, [Widget? push]) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(DriverRuntimeScope(
    session: DriverSessionController(),
    homeBuilder: () => const Scaffold(body: Text('Driver home')),
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(navigatorKey: navigator, home: first),
    ),
  ));
  if (push != null) {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => push));
  }
  await tester.pumpAndSettle();
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Home on a phone with [activeRides] as its saved-trip storage.
Future<void> _home(WidgetTester tester, ActiveRideRepository activeRides,
    {WaybillRepository? waybills}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(LayoutViewport(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (_, __) => MaterialApp(
        home: DriverHome(
          sessionController: DriverSessionController(),
          activeRideRepository: activeRides,
          waybillRepository: waybills,
        ),
      ),
    ),
  ));
  await _frames(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('driver-r3-10: "Return to home" at the end of onboarding opens '
      'Home, not the Sign-in screen it started from', (tester) async {
    await _app(tester, const Scaffold(body: Text('Sign in')),
        const TakeIdPhoto());
    await tester.tap(find.byKey(const ValueKey('id-preview-return')));
    await tester.pumpAndSettle();
    expect(find.text('Driver home'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  for (final button in ['Apple', 'Google']) {
    testWidgets('driver-u106: "Continue with $button" says sign-in needs the account '
        'service instead of opening onboarding unsigned', (tester) async {
      await _app(tester, const DriverSignIn());
      await tester.tap(find.text(
          button == 'Apple' ? tr.continueWithApple : tr.continueWithGoogle));
      await tester.pumpAndSettle();
      expect(find.byType(AdditionalInfoNavigation), findsNothing);
      expect(find.text('Apple and Google sign-in require the account service.'),
          findsOneWidget);
    });
  }

  testWidgets('driver-81: Profile does not flash "Vehicle data unavailable" '
      'while the vehicle is being read', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DriverProfile()));
    expect(find.text('Vehicle data unavailable'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Vehicle data unavailable'), findsNothing);
    expect(find.text('Mercedes-Benz E 220'), findsOneWidget);
  });

  testWidgets('driver-u112: blocked storage does not report a saved trip and '
      'the driver can still go online', (tester) async {
    await _home(tester, PrefsActiveRideRepository(
        load: () => Future.error(StateError('SecurityError: storage blocked'))));
    expect(find.text('The saved trip could not be opened.'), findsNothing);
    expect(find.textContaining('could not be opened, so no saved trip'),
        findsOneWidget);
    tester
        .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')))
        .onTap!
        .call();
    await _frames(tester);
    expect(find.text('Finish or close the saved trip before going online.'),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
