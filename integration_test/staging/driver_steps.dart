import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_controls.dart';
import 'package:movera/presentation/driver/home/home.dart';

import 'check_log.dart';

/// UI steps of the staging device run, on the real app, through its keys.
///
/// The binding waits in real time: `pump(d)` lets `d` pass on the phone,
/// with real network calls going on meanwhile.

Finder byKey(String key) => find.byKey(ValueKey<String>(key));

bool shows(Finder finder) => finder.evaluate().isNotEmpty;

/// Pumps until [done] or [timeout]; taps known one-off prompts meanwhile.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
  bool dismiss = true,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (done()) return true;
    if (dismiss) await dismissPrompts(tester);
  }
  return done();
}

/// Lets [duration] pass on the phone, dismissing one-off prompts.
Future<void> wait(WidgetTester tester, Duration duration) =>
    pumpUntil(tester, () => false, timeout: duration);

/// Prompts a fresh install may show over Home. The test answers them the
/// way a driver would to get on with the work (later / close / accept the
/// staging terms), and says so in the log.
const List<String> _prompts = <String>[
  'push-later',
  'content-update-close',
  'content-terms-accept',
  'legal-accept-button',
];

Future<void> dismissPrompts(WidgetTester tester) async {
  for (final key in _prompts) {
    final finder = byKey(key);
    if (!shows(finder)) continue;
    CheckLog.say('STEP prompt "$key" answered');
    await tester.tap(finder.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// The error line the sign-in screens show, if any (the app's words; they
/// never repeat the number).
String? authError() {
  final errors = find.byType(AuthErrorText);
  if (!shows(errors)) return null;
  return (errors.evaluate().first.widget as AuthErrorText).message;
}

/// Signs in with [phone] and [code] through the real screens.
///
/// Returns null on Home, else why not. Already signed in: straight to Home.
Future<String?> signIn(
  WidgetTester tester, {
  required String phone,
  required String code,
}) async {
  final first = await pumpUntil(
    tester,
    () =>
        shows(find.byType(DriverSignIn)) ||
        shows(find.byType(DriverHome)) ||
        shows(find.byType(DriverDetailsScreen)),
    timeout: const Duration(seconds: 60),
    dismiss: false,
  );
  if (!first) return 'neither the sign-in screen nor Home showed in 60 s';
  if (shows(find.byType(DriverHome))) return null;
  if (shows(find.byType(DriverDetailsScreen))) {
    return 'the account asks for driver details (not an active test driver)';
  }

  final field = byKey('auth-phone-field');
  if (!shows(field)) return 'sign-in screen has no phone field';
  await tester.enterText(field, phone);
  await tester.pump(const Duration(milliseconds: 400));
  final box = byKey('auth-consent-box');
  await tester.ensureVisible(box);
  await tester.tap(box, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  final next = byKey('auth-continue');
  await tester.ensureVisible(next);
  await tester.tap(next, warnIfMissed: false);
  // A sleeping staging server answers in up to ~60 s.
  final codeScreen = await pumpUntil(
    tester,
    () => shows(find.byType(DriverPhoneVerification)) || authError() != null,
    timeout: const Duration(seconds: 90),
    dismiss: false,
  );
  if (!codeScreen || !shows(find.byType(DriverPhoneVerification))) {
    return 'no code screen after Continue: ${authError() ?? 'timeout 90 s'}';
  }

  final pin = find.descendant(
    of: byKey('auth-code'),
    matching: find.byType(EditableText),
  );
  if (!shows(pin)) return 'code screen has no code field';
  await tester.enterText(pin.first, code);
  await tester.pump(const Duration(milliseconds: 600));
  // The last digit sends the code by itself; Verify is the fallback.
  final verify = byKey('auth-verify');
  if (shows(verify) && !shows(find.byType(DriverHome))) {
    await tester.pump(const Duration(seconds: 2));
    if (shows(verify) && !shows(find.byType(DriverHome))) {
      await tester.tap(verify, warnIfMissed: false);
    }
  }
  final home = await pumpUntil(
    tester,
    () =>
        shows(find.byType(DriverHome)) ||
        shows(find.byType(DriverDetailsScreen)) ||
        (shows(find.byType(DriverPhoneVerification)) && authError() != null),
    timeout: const Duration(seconds: 90),
    dismiss: false,
  );
  if (shows(find.byType(DriverDetailsScreen))) {
    return 'signed in, but the account asks for driver details';
  }
  if (!home || !shows(find.byType(DriverHome))) {
    return 'code not taken: ${authError() ?? 'Home did not open in 90 s'}';
  }
  return null;
}

/// Keys inside the reason layer that are not a reason themselves.
const Set<String> _reasonParts = <String>{
  'home-reason-layer',
  'home-reason-close',
  'home-reason-action',
};

/// Reason cards Home shows instead of going online (`home-reason-<id>`).
List<String> homeReasons() => <String>[
  for (final element
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('home-reason-') &&
                !_reasonParts.contains((w.key! as ValueKey<String>).value),
          )
          .evaluate())
    (element.widget.key! as ValueKey<String>).value,
];

/// Taps the radar ring above the closed sheet (the go-online control).
Future<bool> tapGoOnline(WidgetTester tester) async {
  final orb = byKey('trip-radar-touch-target');
  final ready = await pumpUntil(
    tester,
    () => shows(orb),
    timeout: const Duration(seconds: 45),
  );
  if (!ready) return false;
  final rect = tester.getRect(orb.first);
  await tester.tapAt(Offset(rect.center.dx, rect.top + 12));
  await tester.pump(const Duration(milliseconds: 300));
  return true;
}

/// Holds the online radar, then confirms "Go offline?".
Future<bool> goOffline(WidgetTester tester) async {
  final radar = byKey('home-radar-hold-off');
  final ready = await pumpUntil(
    tester,
    () => shows(radar),
    timeout: const Duration(seconds: 20),
  );
  if (!ready) return false;
  final gesture = await tester.startGesture(tester.getCenter(radar.first));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await gesture.up();
  final asked = await pumpUntil(
    tester,
    () => shows(byKey('go-offline-yes')),
    timeout: const Duration(seconds: 5),
    dismiss: false,
  );
  if (!asked) return false;
  await tester.tap(byKey('go-offline-yes'), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 500));
  return true;
}

/// Android Back, as the system button sends it.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 600));
}

/// True when Home is the only page on the root navigator, no drawer open.
bool onHomeOnly(WidgetTester tester) {
  if (!shows(find.byType(DriverHome))) return false;
  if (shows(byKey('driver-side-menu'))) return false;
  final navigators = find.byType(Navigator).evaluate();
  if (navigators.isEmpty) return false;
  final root = (navigators.first as StatefulElement).state as NavigatorState;
  return !root.canPop();
}

/// Back until Home is alone again (at most [tries] presses).
Future<int> backToHome(WidgetTester tester, {int tries = 3}) async {
  var presses = 0;
  while (presses < tries && !onHomeOnly(tester)) {
    await systemBack(tester);
    presses++;
  }
  return presses;
}
