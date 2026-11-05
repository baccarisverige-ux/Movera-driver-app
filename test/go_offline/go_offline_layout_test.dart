import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/offline_after_trips.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';

import '../audit/phase5/live_fixture.dart';

/// Screenshot review of driver #469 (2026-11-05): the banner must not cut
/// the trip header at 390 px, the Trip settings row uses the same white
/// card and text style as the other rows, and Undo is a real button
/// (TextButton, accent colour, 48 px tap target).

Future<void> _at390(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void _realUndo(WidgetTester tester, Finder key) {
  final undo = find.descendant(
    of: key,
    matching: find.byType(TextButton),
    matchRoot: true,
  );
  expect(undo, findsOneWidget, reason: 'Undo is a TextButton');
  final button = tester.widget<TextButton>(undo);
  final fg = button.style?.foregroundColor?.resolve(<WidgetState>{});
  expect(fg, AppColor.primary, reason: 'Undo uses the accent colour');
  final size = tester.getSize(undo);
  expect(size.height, greaterThanOrEqualTo(48), reason: '48 px tap target');
  expect(size.width, greaterThanOrEqualTo(48), reason: '48 px tap target');
}

void main() {
  tearDown(() {
    OfflineAfterTrips.pending.value = false;
    OfflineAfterTrips.undoAction = null;
    LiveDriverServices.instance = null;
  });

  testWidgets(
    '390 px: with the banner the header text is never cut; banner full width',
    (tester) async {
      OfflineAfterTrips.pending.value = true;
      await _at390(
        tester,
        TripBottomBar(
          instruction: 'Drop off Maya',
          address: 'Medborgarplatsen',
          onPreferences: () {},
          onTap: () {},
        ),
      );
      for (final key in ['trip-bar-instruction', 'trip-bar-next-address']) {
        final p = tester.renderObject<RenderParagraph>(
          find.byKey(ValueKey(key)),
        );
        expect(p.didExceedMaxLines, isFalse, reason: '$key is cut');
      }
      final banner = tester.getRect(
        find.byKey(const ValueKey('trip-bar-going-offline')),
      );
      expect(banner.width, greaterThanOrEqualTo(340), reason: 'full width');
      final header = tester.getRect(
        find.byKey(const ValueKey('trip-bar-instruction')),
      );
      expect(
        banner.top,
        greaterThanOrEqualTo(header.bottom),
        reason: 'under the header',
      );
      _realUndo(
        tester,
        find.byKey(const ValueKey('trip-bar-going-offline-undo')),
      );
    },
  );

  testWidgets(
    'Trip settings: the row sits in a white rounded card with the same text style; Undo is a real button',
    (tester) async {
      final live = installLive();
      final session = DriverSessionController(initialOnline: true);
      live.presence.attach(session);
      session.beginTrip('trp_layout');
      OfflineAfterTrips.pending.value = true;
      await _at390(tester, const TripSettings());
      await tester.pump(const Duration(milliseconds: 300));
      final row = find.byKey(const ValueKey('trip-settings-go-offline'));
      expect(row, findsOneWidget);
      final card = find.ancestor(
        of: row,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container || w.decoration is! BoxDecoration) return false;
          final d = w.decoration! as BoxDecoration;
          return d.color == Colors.white &&
              d.borderRadius == BorderRadius.circular(18);
        }),
      );
      expect(
        card,
        findsOneWidget,
        reason: 'inside the same white card as the other rows',
      );
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('trip-settings-go-offline-title')),
      );
      final ref = tester.widget<Text>(find.text('Ride preferences'));
      expect(title.style?.color, ref.style?.color);
      expect(title.style?.fontWeight, ref.style?.fontWeight);
      expect(title.style?.fontSize, ref.style?.fontSize);
      _realUndo(
        tester,
        find.byKey(const ValueKey('trip-settings-go-offline-undo')),
      );
      live.presence.detach();
      live.reporter.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    },
  );
}
