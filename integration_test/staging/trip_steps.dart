import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'check_log.dart';
import 'driver_steps.dart';

/// UI steps of the trip lifecycle run, on the real trip screens, by the
/// app's keys (accept_ride_panel.dart, cash_collect_sheet.dart,
/// ride_completed.dart, chat.dart, call_screen.dart).

/// The trip screen the phone shows, or null.
AcceptRide? tripScreen() {
  final f = find.byType(AcceptRide);
  return shows(f) ? f.evaluate().first.widget as AcceptRide : null;
}

/// True when the trip screen is the top page and no drawer is open.
bool onTripTop() {
  final f = find.byType(AcceptRide);
  if (!shows(f)) return false;
  if (shows(byKey('driver-side-menu'))) return false;
  return ModalRoute.of(f.evaluate().first)?.isCurrent ?? false;
}

/// Back until the trip screen is on top again (at most [tries]).
Future<void> backToTrip(WidgetTester tester, {int tries = 4}) async {
  for (var i = 0; i < tries && !onTripTop(); i++) {
    await systemBack(tester);
  }
}

/// The offer control Home shows for an offer: the Exclusive orb or the
/// radar's Accept. Null when none shows.
String? offerControl() {
  for (final key in const ['home-radar-exclusive', 'home-radar-accept']) {
    if (shows(byKey(key))) return key;
  }
  return null;
}

/// Taps the offer control and waits for the trip screen.
Future<bool> acceptOffer(WidgetTester tester, String key) async {
  if (!await tapHit(tester, byKey(key), 'offer control "$key"') &&
      shows(byKey(key))) {
    // Logged as a miss above; the run-5 way (a tap at its centre) still
    // goes out, so a hit-test quirk of the orb never blocks the accept.
    await tester.tap(byKey(key).first, warnIfMissed: false);
  }
  await tester.pump(const Duration(milliseconds: 300));
  return pumpUntil(
    tester,
    () => tripScreen() != null,
    timeout: const Duration(seconds: 30),
  );
}

/// The trip sheet's panel, or null.
SlidingUpPanel? _tripPanelWidget() {
  final panels = find.byType(SlidingUpPanel);
  return shows(panels) ? panels.evaluate().last.widget as SlidingUpPanel : null;
}

/// The trip sheet's panel controller, or null.
PanelController? _tripPanel() {
  final c = _tripPanelWidget()?.controller;
  return c != null && c.isAttached ? c : null;
}

/// The trip sheet's face as the screen shows it: 'compact' (only the bar,
/// `active-ride-compact-dock`: no Arrived, no slide, no trip card),
/// 'middle' (Arrived button, the slide) or 'full' (the trip card with the
/// Waybill shortcut and More); 'none' without a trip sheet. After the
/// accept the sheet rests on the compact face (accept_ride.dart).
String tripSheetFace() {
  if (shows(byKey('active-ride-compact-dock'))) return 'compact';
  if (shows(byKey('active-ride-expanded-header'))) {
    // The app's own rule (trip_sheet_motion.dart fullAt): the full face
    // starts 35 % of the way from the snap point to the top.
    final p = _tripPanel()?.panelPosition;
    final snap = _tripPanelWidget()?.snapPoint;
    if (p == null || snap == null) return 'middle';
    return p > snap + (1 - snap) * 0.35 ? 'full' : 'middle';
  }
  return 'none';
}

/// Brings the trip sheet to [face] ('middle' or 'full') the way a driver
/// does: a tap on the bar (`trip-bar-details`: compact -> middle, middle
/// -> full, full -> middle); the panel's own controller only as the
/// fallback. Says each move in the log.
Future<void> openTripFace(WidgetTester tester, String face) async {
  for (var i = 0; i < 3 && tripSheetFace() != face; i++) {
    final from = tripSheetFace();
    if (from == 'none') return;
    final bar = find.descendant(
      of: byKey(
        from == 'compact'
            ? 'active-ride-compact-dock'
            : 'active-ride-expanded-header',
      ),
      matching: byKey('trip-bar-details'),
    );
    if (tester.any(bar.hitTestable())) {
      CheckLog.say('STEP trip sheet: bar tapped ($from face, want $face)');
      await tester.tap(bar.hitTestable().first, warnIfMissed: false);
      await wait(tester, const Duration(milliseconds: 900));
      continue;
    }
    final panel = _tripPanel();
    if (panel == null) {
      CheckLog.miss('trip bar "trip-bar-details" not tappable ($from face)');
      return;
    }
    CheckLog.say('STEP trip sheet: moved by its controller ($from -> $face)');
    if (face == 'full') {
      await panel.animatePanelToPosition(1);
    } else {
      await panel.animatePanelToSnapPoint();
    }
    await wait(tester, const Duration(milliseconds: 900));
  }
}

/// Waits until [target] can really be tapped (hit-testable: not offstage,
/// not covered), opening the trip sheet to [face] when it is not there.
/// The sheet is opened first, never after waiting for the key: on the
/// compact face the key is not built at all.
Future<bool> revealTripControl(
  WidgetTester tester,
  Finder target, {
  String face = 'middle',
  Duration timeout = const Duration(seconds: 20),
}) async {
  bool ready() => tester.any(target.hitTestable());
  final end = DateTime.now().add(timeout);
  var opens = 0;
  while (!ready() && DateTime.now().isBefore(end) && !pastStepsHardStop) {
    if (opens < 4 && tripSheetFace() != face) {
      opens++;
      await openTripFace(tester, face);
    }
    if (shows(target) && !ready()) {
      try {
        await tester.ensureVisible(target.first);
        await tester.pump(const Duration(milliseconds: 300));
      } catch (_) {
        // Not in a scrollable: waiting below.
      }
    }
    if (ready()) break;
    final left = end.difference(DateTime.now());
    await pumpUntil(
      tester,
      ready,
      timeout: left < const Duration(seconds: 2)
          ? left
          : const Duration(seconds: 2),
    );
  }
  return ready();
}

/// Taps a keyed control on the trip screen, the sheet opened to [face]
/// first when the key is not there. A key that never shows (or never
/// becomes tappable) is a miss with its name and the sheet's face.
Future<bool> tapTripControl(
  WidgetTester tester,
  String key, {
  String face = 'middle',
  Duration timeout = const Duration(seconds: 20),
}) async {
  final target = byKey(key);
  if (!await revealTripControl(tester, target, face: face, timeout: timeout)) {
    CheckLog.miss(
      '"$key" not tappable in ${timeout.inSeconds} s (in tree=${shows(target)}, '
      'sheet face=${tripSheetFace()}, wanted the $face face)',
    );
    return false;
  }
  if (!await tapHit(tester, target, '"$key"')) return false;
  await tester.pump(const Duration(milliseconds: 400));
  return true;
}

/// Slides the trip's primary action (Start trip) all the way. The slide
/// is on the middle face, and only after the server says arrived.
Future<bool> slidePrimary(WidgetTester tester) async {
  const key = 'active-ride-slide-action';
  final action = byKey(key);
  if (!await revealTripControl(
    tester,
    action,
    timeout: const Duration(seconds: 30),
  )) {
    CheckLog.miss(
      '"$key" not tappable in 30 s (in tree=${shows(action)}, '
      'sheet face=${tripSheetFace()}, wanted the middle face)',
    );
    return false;
  }
  final rect = tester.getRect(action.hitTestable().first);
  final gesture = await tester.startGesture(
    Offset(rect.left + 28, rect.center.dy),
  );
  for (var i = 1; i <= 12; i++) {
    await gesture.moveTo(
      Offset(rect.left + 28 + (rect.width - 40) * i / 12, rect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 500));
  return true;
}

/// Answers the sheets a trip step may raise on its way: the pickup PIN
/// (with [pin] from the rider's view), "finish already?" on a short trip.
Future<void> answerStepSheets(WidgetTester tester, {String? pin}) async {
  final pinField = find.descendant(
    of: byKey('pickup-pin-field'),
    matching: find.byType(EditableText),
  );
  if (pin != null && shows(pinField)) {
    CheckLog.say('STEP pickup PIN asked: typed from the rider view');
    await tester.enterText(pinField.first, pin);
    await tester.pump(const Duration(milliseconds: 400));
    if (shows(byKey('pickup-pin-confirm'))) {
      await tester.tap(byKey('pickup-pin-confirm'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
  if (shows(byKey('finish-soon-finish'))) {
    CheckLog.say('STEP short-trip question answered: finish');
    await tester.tap(byKey('finish-soon-finish'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// All texts under [scope] (for amount and field checks; never logged
/// whole: callers log only what they compare).
List<String> textsUnder(Finder scope) => <String>[
  for (final e
      in find.descendant(of: scope, matching: find.byType(Text)).evaluate())
    if ((e.widget as Text).data case final t?)
      t
    else if ((e.widget as Text).textSpan case final s?)
      s.toPlainText(),
];

/// Opens the side menu from the trip screen's island and one page from
/// it ([item]), then Back to the trip. Returns what went wrong, or null.
///
/// On a trip the island shows the route face, which has no menu button.
/// A touch on the island brings the Home-like face with the menu
/// (Tooltip `tr.menu`) for 2 s (trip_island_controller.dart), so the
/// island is touched first, on its right side, away from
/// `island-route-cue` (that cue opens Route & options), and the menu is
/// tapped within those 2 s.
Future<String?> menuPageAndBack(WidgetTester tester, String item) async {
  final menu = find.byTooltip(tr.menu);
  bool menuReady() => tester.any(menu.hitTestable());
  if (!menuReady()) {
    final island = find.byType(AdaptiveTripIsland);
    if (!shows(island)) {
      CheckLog.miss('trip island (AdaptiveTripIsland) not on screen');
      return 'no trip island to open the menu from';
    }
    final rect = tester.getRect(island.first);
    final cue = byKey('island-route-cue');
    var at = Offset(rect.right - 24, rect.top + math.min(rect.height / 2, 36));
    if (shows(cue) && tester.getRect(cue.first).contains(at)) {
      at = Offset(rect.right - 8, rect.bottom - 8);
    }
    CheckLog.say('STEP island touched (away from island-route-cue)');
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntil(
      tester,
      menuReady,
      timeout: const Duration(milliseconds: 1200),
      step: const Duration(milliseconds: 100),
    );
  }
  if (!await tapHit(tester, menu, 'island menu button (Tooltip tr.menu)')) {
    return 'no menu button on the trip island after a touch on it';
  }
  final drawer = byKey('driver-side-menu');
  if (!await pumpUntil(
    tester,
    () => shows(drawer),
    timeout: const Duration(seconds: 5),
  )) {
    CheckLog.miss('"driver-side-menu" did not open after the menu tap');
    return 'menu did not open';
  }
  await tester.pump(const Duration(milliseconds: 400));
  final entry = find.descendant(of: drawer, matching: find.text(item));
  if (!shows(entry)) {
    CheckLog.miss('menu entry "$item" not in "driver-side-menu"');
    await backToTrip(tester);
    return 'menu has no "$item"';
  }
  await tester.ensureVisible(entry.first);
  if (!await tapHit(tester, entry, 'menu entry "$item"')) {
    await backToTrip(tester);
    return 'menu entry "$item" not tappable';
  }
  await wait(tester, const Duration(seconds: 3));
  await backToTrip(tester);
  await wait(tester, const Duration(seconds: 1));
  return onTripTop() ? null : 'Back did not return to the trip screen';
}

bool chatOpen() => shows(find.byType(Chat));

bool callOpen() => shows(find.byType(TripCallScreen));

bool rideCompletedShown() => shows(find.byType(DriverRideCompleted));

/// The text field of the open chat.
Finder chatField() =>
    find.descendant(of: find.byType(Chat), matching: find.byType(EditableText));

/// The unread count on the trip screen's chat button (0 when hidden).
int chatUnread(WidgetTester tester) {
  final f = byKey('active-ride-chat-unread');
  if (!shows(f)) return 0;
  final badge = tester.widget<Badge>(f.first);
  if (!badge.isLabelVisible) return 0;
  final label = badge.label;
  if (label is Text) return int.tryParse(label.data ?? '') ?? 1;
  return 1;
}

/// The call screen's state line ("Calling…", "Call ended", …).
String? callStateLine(WidgetTester tester) {
  final f = byKey('call-state');
  return shows(f) ? tester.widget<Text>(f.first).data : null;
}
