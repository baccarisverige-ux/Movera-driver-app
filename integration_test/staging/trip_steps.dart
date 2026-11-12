import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
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
  await tester.tap(byKey(key).first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  return pumpUntil(
    tester,
    () => tripScreen() != null,
    timeout: const Duration(seconds: 30),
  );
}

/// Opens the trip sheet to its snap point when [target] is not on screen.
Future<void> openTripSheet(WidgetTester tester, Finder target) async {
  if (shows(target) && tester.any(target.hitTestable())) return;
  final panels = find.byType(SlidingUpPanel);
  if (shows(panels)) {
    tester
        .widget<SlidingUpPanel>(panels.last)
        .controller
        ?.animatePanelToSnapPoint();
    await wait(tester, const Duration(milliseconds: 800));
  }
  if (shows(target)) {
    await tester.ensureVisible(target.first);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Taps a keyed control on the trip screen (sheet opened first).
Future<bool> tapTripControl(WidgetTester tester, String key) async {
  final target = byKey(key);
  if (!await pumpUntil(
    tester,
    () => shows(target),
    timeout: const Duration(seconds: 15),
  )) {
    return false;
  }
  await openTripSheet(tester, target);
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  return true;
}

/// Slides the trip's primary action (Start trip) all the way.
Future<bool> slidePrimary(WidgetTester tester) async {
  final action = byKey('active-ride-slide-action');
  if (!await pumpUntil(
    tester,
    () => shows(action),
    timeout: const Duration(seconds: 20),
  )) {
    return false;
  }
  await openTripSheet(tester, action);
  final rect = tester.getRect(action.first);
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
Future<String?> menuPageAndBack(WidgetTester tester, String item) async {
  final menu = find.byTooltip(tr.menu);
  if (!await pumpUntil(
    tester,
    () => shows(menu),
    timeout: const Duration(seconds: 5),
  )) {
    return 'no menu button on the trip screen';
  }
  await tester.tap(menu.first, warnIfMissed: false);
  final drawer = byKey('driver-side-menu');
  if (!await pumpUntil(
    tester,
    () => shows(drawer),
    timeout: const Duration(seconds: 5),
  )) {
    return 'menu did not open';
  }
  await tester.pump(const Duration(milliseconds: 400));
  final entry = find.descendant(of: drawer, matching: find.text(item));
  if (!shows(entry)) {
    await backToTrip(tester);
    return 'menu has no "$item"';
  }
  await tester.ensureVisible(entry.first);
  await tester.tap(entry.first, warnIfMissed: false);
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
