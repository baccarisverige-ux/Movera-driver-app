import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-11-24 (screenshot): scrolling the live "Finish sign-up" hold
/// sheet must never slide its text under the radar HOLD button.
void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      authRequired: true,
    );
    DriverRemindersStore.instance.replace(
      DriverReminderList([
        const DriverReminder(
          kind: 'email_unverified',
          level: ReminderLevel.waiting,
        ),
        for (final type in [
          'bank_statement',
          'driving_licence',
          'info_session',
          'f_tax',
          'taxi_driver_licence',
          'taxi_traffic_permit',
        ])
          DriverReminder(
            kind: 'document_in_review',
            level: ReminderLevel.waiting,
            documentType: type,
          ),
      ]),
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    DriverRemindersStore.instance.replace(DriverReminderList.empty);
  });

  for (final size in const [Size(320, 568), Size(390, 844)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('scrolled hold sheet text never paints under HOLD at $at', (
      tester,
    ) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final account =
          DriverAccountSession(
            repository: DriverAccountRepository(
              ApiClient(
                client: client,
                baseUri: Uri.parse('https://api.test.movera.se'),
                tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
              ),
            ),
          )..replace(
            DriverAccount.fromJson(const {
              'driverId': 'd1',
              'accountStatus': 'pending',
              'firstName': 'Amira',
              'version': 3,
              'country': 'SE',
            }),
          );
      final session = DriverSessionController();
      await tester.pumpWidget(
        LayoutViewport(
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              home: DriverRuntimeScope(
                session: session,
                homeBuilder: () => const SizedBox(),
                account: account,
                child: DriverHome(
                  accountPending: true,
                  sessionController: session,
                  locationRepository: _Gps(),
                  activeRideRepository: MemoryActiveRideRepository(),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> frames(int n) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames(20);
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')),
          )
          .onTap!
          .call();
      await frames(15);
      final scroll = find.byKey(const ValueKey('hold-sheet-scroll'));
      expect(scroll, findsOneWidget);
      expect(find.byKey(const ValueKey('hold-being-checked')), findsOneWidget);
      final viewport = tester.getRect(scroll);
      final orb = tester.getRect(find.byType(MoveraRadarOrb).last);
      // Resting layout: the first line sits below the button.
      final headline = tester.getRect(
        find.byKey(const ValueKey('hold-being-checked')),
      );
      expect(headline.top, greaterThanOrEqualTo(orb.bottom));
      // The owner's case: he scrolls the list to read it.
      // (Its own drag is shared with the sheet's; jump to the end the
      // way his scroll leaves it.)
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await frames(5);
      final texts = find.descendant(of: scroll, matching: find.byType(Text));
      var scrolledPast = false;
      for (final element in texts.evaluate()) {
        final box = element.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.top < viewport.top) {
          scrolledPast = true;
        }
        final painted = rect.intersect(viewport);
        if (painted.isEmpty || painted.height <= 0) {
          continue;
        }
        expect(
          painted.overlaps(orb),
          isFalse,
          reason: 'text painted at $painted under the HOLD button $orb',
        );
      }
      expect(scrolledPast, isTrue, reason: 'the list did not scroll');
      await tester.pumpWidget(const SizedBox());
      await frames(50);
    });
  }
}

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
