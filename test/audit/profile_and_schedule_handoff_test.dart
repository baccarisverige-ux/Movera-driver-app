import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScheduledRideStore.reset();
  });

  testWidgets(
    'profile refreshes vehicle identity after returning from Vehicles',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DriverProfile()));
      await tester.pumpAndSettle();
      expect(find.text('Mercedes-Benz E 220'), findsOneWidget);
      await tester.tap(find.text('Vehicles'));
      await tester.pumpAndSettle();
      final store = LocalVehicleStore();
      await store.remove('demo-V418');
      await store.upsert({
        'id': 'new',
        'make': 'Volvo',
        'model': 'XC60',
        'year': '2024',
        'plate': 'NEW 123',
      });
      expect(await store.primaryIdentity(), (
        vehicle: 'Volvo XC60',
        plate: 'NEW 123',
      ));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('Volvo XC60').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.text('Profile'), findsOneWidget);
      expect(
        find.text('Volvo XC60'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .join(' | '),
      );
      expect(find.text('Mercedes-Benz E 220'), findsNothing);
    },
  );

  testWidgets('same-frame logout taps open only one confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DriverProfile()));
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('Log out'),
      matching: find.byType(InkWell),
    );
    final tap = tester.widget<InkWell>(row).onTap!;
    tap();
    tap();
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('pending logout owns navigation and failure restores retry', (
    tester,
  ) async {
    final session = DriverSessionController();
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRuntimeScope(
          session: session,
          homeBuilder: () => const SizedBox(),
          logout: () {
            calls++;
            return pending.future;
          },
          child: const DriverProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Settings',
            ),
          )
          .onPressed,
      isNull,
    );
    final row = find.ancestor(
      of: find.text('Log out'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(row).onTap, isNull);
    pending.completeError(StateError('local data unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not clear local data'), findsOneWidget);
    expect(tester.widget<InkWell>(row).onTap, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('repeated Stay preserves the profile route without logging out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DriverProfile()),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    final stay = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Stay'))
        .onPressed!;
    stay();
    stay();
    await tester.pumpAndSettle();
    expect(find.byType(DriverProfile), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeated logout confirmation preserves profile for save failure retry',
    (tester) async {
      final session = DriverSessionController();
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DriverRuntimeScope(
                      session: session,
                      homeBuilder: () => const SizedBox(),
                      logout: () {
                        calls++;
                        return pending.future;
                      },
                      child: const DriverProfile(),
                    ),
                  ),
                ),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      final confirm = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Log out'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(DriverProfile), findsOneWidget);
      pending.completeError(StateError('local data unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not clear local data'), findsOneWidget);
      expect(find.byType(DriverProfile), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('scheduled list updates after a request is answered on Home', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('02'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(find.text('Gamla vägen, Stockholm'), findsNothing);
  });

  for (final size in [
    const Size(320, 568),
    const Size(320, 700),
    const Size(568, 320),
  ]) {
    testWidgets(
      'scheduled cancellation stays reachable at 200 percent in $size',
      (tester) async {
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          previous?.call(details);
        };
        addTearDown(() => FlutterError.onError = previous);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const ScheduledRidesScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Accepted'));
        await tester.tap(find.text('Accepted'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('184.00 kr'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('184.00 kr').hitTestable(), findsOneWidget);
        await tester.tap(find.text('184.00 kr'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Cancel reservation'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Vehicle issue'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vehicle issue'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel this reservation?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final confirm = find.widgetWithText(FilledButton, 'Cancel reservation');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        expect(confirm.hitTestable(), findsOneWidget);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('Reservation cancelled'), findsOneWidget);
        expect(find.text('184.00 kr'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reset in [false, true]) {
    testWidgets(
      'stale scheduled details cannot accept after ${reset ? 'session reset' : 'external decline'}',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ScheduledRidesScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('126.75 kr'));
        await tester.pumpAndSettle();
        if (reset) {
          ScheduledRideStore.reset();
        } else {
          ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
        }
        await tester.tap(find.text('Accept  •  126.75 kr'));
        await tester.pumpAndSettle();
        expect(find.text('Reservation accepted'), findsNothing);
        expect(ScheduledRideStore.openRequests.value, reset ? 2 : 1);
        await tester.tap(find.text('Accepted'));
        await tester.pumpAndSettle();
        expect(find.text('Gamla vägen, Stockholm'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
