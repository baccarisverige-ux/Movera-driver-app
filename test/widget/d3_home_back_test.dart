import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';
import 'island_side_targets.dart';

// D3 on Home, at 320x568 and 375x667 with text at 130 %:
// UI-03 Android Back closes what is on top of Home before it leaves the app;
// UI-02 the account-hold sheet's "Contact support" can be tapped and opens
// support; UI-12 the Cash rides switch is read with its label.

const _sizes = <Size>[Size(320, 568), Size(375, 667)];
const _scale = 1.3;

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(const <RideOffer>[]);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  Size size, {
  bool pending = false,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  if (pending) {
    final config = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = DriverRuntimeConfig(
      simulatedArrival: config.simulatedArrival,
      externalRouting: config.externalRouting,
      skipAccountActivation: false,
      liveMapTicker: config.liveMapTicker,
      reservationPopup: config.reservationPopup,
      islandHint: config.islandHint,
      radarSound: config.radarSound,
    );
    addTearDown(() => DriverRuntimeConfig.current = config);
  }
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(_scale)),
            child: child!,
          ),
          home: DriverHome(
            accountPending: pending,
            sessionController: DriverSessionController(),
            dispatchRepository: _Dispatch(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _tapRadar(WidgetTester tester) async {
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
}

PanelController _panel(WidgetTester tester) =>
    tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel)).controller!;

/// System Back, as Android sends it; the number of app exits so far.
Future<int> _back(WidgetTester tester, int Function() exits) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  return exits();
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()} @$_scale';

    testWidgets('UI-03 Back closes the open Home sheet, then leaves at $at', (
      tester,
    ) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            exits++;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpHome(tester, size);
      _panel(tester).open();
      await _frames(tester, const Duration(milliseconds: 700));
      expect(_panel(tester).panelPosition, greaterThan(0.9));

      expect(await _back(tester, () => exits), 0);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(_panel(tester).panelPosition, lessThan(0.05));

      // Nothing up any more: Back leaves Home as before.
      expect(await _back(tester, () => exits), 1);
      await _end(tester);
    });

    testWidgets('UI-03 Back skips a live Exclusive offer before it leaves '
        'at $at', (tester) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            exits++;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpHome(tester, size);
      await _tapRadar(tester);
      const card = ValueKey<String>('exclusive-offer-card-home-direct-close');
      for (var i = 0; i < 400 && find.byKey(card).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.byKey(card), findsOneWidget);
      await _frames(tester, const Duration(milliseconds: 600));

      expect(await _back(tester, () => exits), 0);
      await _frames(tester, const Duration(milliseconds: 1200));
      expect(find.byKey(card), findsNothing);
      await _end(tester);
    });

    testWidgets('UI-02 hold sheet: Contact support is tappable and opens '
        'support at $at', (tester) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            exits++;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpHome(tester, size, pending: true);
      await _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 900));
      final contact = find.text('Contact support');
      expect(contact, findsOneWidget);
      // Nothing (the red dock) sits on top of it.
      final centre = tester.getCenter(contact);
      expect(centre.dy, lessThan(size.height));
      final hits = tester.hitTestOnBinding(centre);
      expect(
        hits.path.any((e) => e.target == tester.renderObject(contact)),
        isTrue,
        reason: 'the red dock covers Contact support',
      );
      // Back closes the hold sheet first; Home stays.
      expect(await _back(tester, () => exits), 0);
      await _frames(tester, const Duration(milliseconds: 900));
      expect(_panel(tester).panelPosition, lessThan(0.05));
      await _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 900));
      await tester.tap(find.text('Contact support'));
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.byType(SupportInboxScreen), findsOneWidget);
      await _end(tester);
    });

    testWidgets('UI-12 the Cash rides switch is read with its label at $at', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester, size);
      _panel(tester).open();
      await _frames(tester, const Duration(milliseconds: 700));
      final cash = find.byKey(const ValueKey<String>('home-sheet-cash-switch'));
      await tester.ensureVisible(cash);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSemantics(cash).label, contains('Cash rides'));
      semantics.dispose();
      await _end(tester);
    });

    testWidgets('UI-12 island Menu and Search take touches in 48x48 at $at', (
      tester,
    ) async {
      await _pumpHome(tester, size);
      // Asleep (small island) first, then awake.
      for (final wait in const [Duration.zero, Duration(seconds: 2)]) {
        await _frames(tester, wait);
        final menuFinder = find.descendant(
          of: find.byTooltip('Menu'),
          matching: find.byType(InkWell),
        );
        final searchFinder = find.byKey(
          const ValueKey<String>('destination-mode-open'),
        );
        final menu = tester.getRect(menuFinder);
        final search = tester.getRect(searchFinder);
        // The island paints exactly as on main: 54 x 50.4 at 80 %.
        for (final visible in [menu, search]) {
          expect(visible.width, closeTo(54 * 0.8, .01));
          expect(visible.height, closeTo(50.4 * 0.8, .01));
        }
        final shell = tester.getRect(
          find.ancestor(
            of: menuFinder,
            matching: find.byType(DigitalIslandShell),
          ),
        );
        expect(shell.height, closeTo(50.4 * 0.8, .01));
        expectSideTargets(
          tester,
          menu: menuFinder,
          search: searchFinder,
          middle: find.byKey(const ValueKey<String>('last-trip-launcher')),
          screenWidth: size.width,
        );
      }
      await _end(tester);
    });

    testWidgets('UI-12 Home offline has no unlabelled tap targets at $at', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpHome(tester, size);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      await _end(tester);
    });
  }
}
