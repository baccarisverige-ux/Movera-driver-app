import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/analytics/acceptance%20rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:movera/presentation/driver/earning%20stats/earning_stats.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/pin%20verification/pin_verification.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/promotions/promotions.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/presentation/driver/settings/sound%20&%20voice/sound_voice.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/presentation/driver/vehicles/vehicles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audit Phase 5 (N3): every screen reachable from the profile and the
/// side menu opens and lays out on a small phone with large text in each
/// language, and the system Back leaves it without a crash.
void main() {
  final screens = <String, Widget Function()>{
    'Analytics': () => const Analytics(),
    'AcceptanceRate': () => const AcceptanceRate(),
    'CancelationRate': () => const CancelationRate(),
    'EarningStats': () => const EarningStatsScreen(),
    'Wallet': () => const WalletScreen(),
    'MyBank': () => const MyBank(),
    'AddNewAccount': () => const AddNewAccount(),
    'Promotions': () => const Promotions(),
    'DrivingLogs': () => const DrivingLogs(),
    'Preferences': () => const Preferences(),
    'Settings': () => const Settings(),
    'Accessibility': () => const Accessibility(),
    'SoundAndVoice': () => const SoundAndVoice(),
    'EmergencyContacts': () => const EmergencyContactsScreen(),
    'PinVerification': () => const PinVerification(),
    'Notifications': () => const DriverNotificationsScreen(),
    'RideHistory': () => DriverRideHistory(loadHistory: () async => const []),
    'Documents': () => const DriverDocuments(),
    'Vehicles': () => const DriverVehicles(),
    'SupportInbox': () => const SupportInboxScreen(),
    'ScheduledRides': () => const ScheduledRidesScreen(),
  };

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    DriverAppTexts.language = 'en';
    ScheduledRideStore.reset();
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final (language, size, scale) in [
    ('sv', const Size(320, 568), 2.0),
    ('fr', const Size(320, 568), 2.0),
    ('en', const Size(320, 568), 2.0),
    ('sv', const Size(390, 844), 1.0),
  ]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} · $language · ${size.width.toInt()}w · '
          'text x$scale: opens, lays out, Back leaves it', (tester) async {
        DriverAppTexts.language = language;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              minTextAdapt: true,
              useInheritedMediaQuery: true,
              builder: (_, __) => MaterialApp(
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        key: const ValueKey('open'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => entry.value(),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await frames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('open')), findsNothing);
        // The system Back (Android button, browser back, iOS edge swipe).
        await tester.binding.handlePopRoute();
        await frames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('open')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
      });
    }
  }
}
