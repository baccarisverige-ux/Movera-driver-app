import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:movera/presentation/driver/earning%20stats/earning_stats.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/presentation/driver/vehicles/vehicles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B16 (2026-11-04): the Google mark is shown on the sign-in button and on
/// no other screen. Replaces the source-reading B9 guard (archived in
/// Rules/archive/old-tests/Movera-driver-app/) by opening the screens.
bool _isGoogleMark(Widget w) =>
    w is Image &&
    w.image is AssetImage &&
    (w.image as AssetImage).assetName.endsWith('images/google.png');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    DriverAppTexts.language = 'en';
    ScheduledRideStore.reset();
  });

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(home: screen),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('B9: the sign-in button carries the Google mark', (tester) async {
    final store = MemoryTokenStore();
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{}', 404)),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: store,
    );
    await open(
      tester,
      DriverSignIn(
        controller: AuthController(
          repository: AuthRepository(api: api, tokens: store),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.byWidgetPredicate(_isGoogleMark), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  final others = <String, Widget Function()>{
    'Analytics': () => const Analytics(),
    'EarningStats': () => const EarningStatsScreen(),
    'Wallet': () => const WalletScreen(),
    'MyBank': () => const MyBank(),
    'AddNewAccount': () => const AddNewAccount(),
    'Promotions': () => const Promotions(),
    'DrivingLogs': () => const DrivingLogs(),
    'Preferences': () => const Preferences(),
    'Settings': () => const Settings(),
    'Notifications': () => const DriverNotificationsScreen(),
    'RideHistory': () => DriverRideHistory(loadHistory: () async => const []),
    'Documents': () => const DriverDocuments(),
    'Vehicles': () => const DriverVehicles(),
    'SupportInbox': () => const SupportInboxScreen(),
    'ScheduledRides': () => const ScheduledRidesScreen(),
    'Safety': () => const SafetyToolKits(),
  };
  others.forEach((name, build) {
    testWidgets('B9: $name shows no Google mark', (tester) async {
      await open(tester, build());
      expect(
        find.byWidgetPredicate(_isGoogleMark, skipOffstage: false),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });
}
