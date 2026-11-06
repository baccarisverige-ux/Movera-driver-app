import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/settings/sound%20&%20voice/sound_voice.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// L-a driver (owner answers Q1, Q3, Q4, Q6, Q7 in Rules
/// decisions/driver-g15.md; plan/LA-BUILD-PLAN-2026-11-06.md §5): a live
/// build shows only what the server sent.
class _SpyHistory extends PrefsTripHistoryRepository {
  final archived = <WaybillRecord>[];

  @override
  Future<void> archive(
    WaybillRecord record, {
    DateTime? completedAt,
    String? distance,
    String? duration,
    String? tip,
    String? paymentMethod,
    String? cashCollected,
    TripStatus status = TripStatus.completed,
    String? cancellationActor,
    String? cancellationReasonCode,
    bool authoritative = false,
    String? feeEarned,
    GeoPoint? pickupPoint,
    GeoPoint? dropoffPoint,
  }) async {
    archived.add(record);
  }
}

bool _isStockPhoto(Widget w) =>
    (w is CircleAvatar &&
        w.backgroundImage is AssetImage &&
        (w.backgroundImage! as AssetImage).assetName == AppAssets.profileImg) ||
    (w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == AppAssets.profileImg);

void main() {
  late DriverRuntimeConfig previous;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ApiClient api(http.Response Function(http.Request) answer) => ApiClient(
    client: MockClient((request) async => answer(request)),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );

  DriverAccountSession session({String? first = 'Amira', String? last}) {
    final s = DriverAccountSession(
      repository: DriverAccountRepository(api((_) => json(503, {}))),
    );
    if (first != null) {
      s.replace(
        DriverAccount.fromJson({
          'driverId': 'd1',
          'accountStatus': 'active',
          'firstName': first,
          'lastName': ?last,
          'version': 3,
          'country': 'SE',
        }),
      );
    }
    return s;
  }

  void live() => DriverRuntimeConfig.current = const DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: false,
    skipAccountActivation: true,
    authRequired: true,
  );

  Future<void> pumpScoped(
    WidgetTester tester,
    Widget child, {
    DriverAccountSession? account,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = DriverSessionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRuntimeScope(
            session: controller,
            homeBuilder: () => const SizedBox(),
            account: account,
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    PickupPayConfig.current = const PickupPayConfig();
  });

  group('Q1 real name, no photo (D1, D2, D4, D11)', () {
    testWidgets('live side menu: the server name and initials, never "MD"', (
      tester,
    ) async {
      await pumpScoped(
        tester,
        const Scaffold(body: DriverSideMenu()),
        account: session(first: 'Amira', last: 'Benali'),
      );
      expect(find.text('Amira Benali'), findsOneWidget);
      expect(find.text('AB'), findsOneWidget);
      expect(find.text('MD'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('menu-profile-name')),
        findsOneWidget,
      );
    });

    testWidgets('live side menu before the profile is read: "—"', (
      tester,
    ) async {
      final account = session(first: null);
      await pumpScoped(
        tester,
        const Scaffold(body: DriverSideMenu()),
        account: account,
      );
      expect(find.text('MD'), findsNothing);
      expect(find.text('—'), findsNWidgets(2));
      account.replace(
        DriverAccount.fromJson({
          'driverId': 'd1',
          'accountStatus': 'active',
          'firstName': 'Sara',
          'lastName': 'Lind',
          'version': 4,
          'country': 'SE',
        }),
      );
      await tester.pump();
      expect(find.text('Sara Lind'), findsOneWidget);
      expect(find.text('SL'), findsOneWidget);
    });

    testWidgets('live Profile: initials, no stock photo', (tester) async {
      live();
      await pumpScoped(
        tester,
        const DriverProfile(),
        account: session(first: 'Amira', last: 'Benali'),
      );
      expect(find.byWidgetPredicate(_isStockPhoto), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-header-initials')),
        findsOneWidget,
      );
      expect(find.text('AB'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rider sheet on a trip: initials, no stock photo', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bus = MemoryDriverRealtime();
      addTearDown(bus.dispose);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(tripId: 'la-trip', realtime: bus),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 160));
      tester
          .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .controller!
          .animatePanelToSnapPoint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump(const Duration(milliseconds: 300));
      final card = find.byKey(const ValueKey<String>('active-ride-rider-card'));
      await tester.tap(
        find.descendant(of: card, matching: find.byType(InkWell)).first,
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byWidgetPredicate(_isStockPhoto), findsNothing);
      expect(
        find.byKey(const ValueKey('rider-sheet-initials')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('Q3 Sound & voice: no "Local demo preferences" text (D5)', (
    tester,
  ) async {
    live();
    await pumpScoped(tester, const SoundAndVoice());
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('Demo'), findsNothing);
  });

  group('Q6 the waybill keeps the real source (D10)', () {
    WaybillRecord record() => WaybillRecord(
      tripId: 'la-w1',
      statusLabel: WaybillRecord.completed,
      issuedAt: DateTime.utc(2026, 11, 6, 9),
      fare: '120,00 kr',
      service: 'Movera',
      riderName: 'Lars',
      pickup: 'A',
      dropoff: 'B',
      source: WaybillRecord.scheduledRideSource,
      driverName: 'Amira Benali',
      vehicle: 'Volvo XC40',
      licensePlate: 'ABC123',
      passengerCapacity: 4,
    );

    test('live replay: never "Local demo"; driver and car kept', () async {
      live();
      CompletionJournal.resetForTesting();
      final history = _SpyHistory();
      await CompletionJournal(
        active: MemoryActiveRideRepository(),
        history: history,
      ).finish(record());
      final saved = history.archived.single;
      expect(saved.source, isNot(WaybillRecord.localDemoSource));
      expect(saved.source, WaybillRecord.scheduledRideSource);
      expect(saved.driverName, 'Amira Benali');
      expect(saved.licensePlate, 'ABC123');
    });

    test('an older live journal without a source: Movera Radar', () async {
      live();
      CompletionJournal.resetForTesting();
      SharedPreferences.setMockInitialValues({
        CompletionJournal.key: jsonEncode({
          'schemaVersion': 2,
          'tripId': 'old-1',
          'status': 'completed',
          'authoritative': false,
          'completedAt': '2026-11-05T10:00:00.000Z',
          'record': {
            'tripId': 'old-1',
            'riderName': 'Lars',
            'fare': '99,00 kr',
            'service': 'Movera',
            'pickup': 'A',
            'dropoff': 'B',
          },
        }),
      });
      final history = _SpyHistory();
      await CompletionJournal(
        active: MemoryActiveRideRepository(),
        history: history,
      ).reconcile();
      expect(history.archived.single.source, WaybillRecord.moveraRadarSource);
    });
  });
}
