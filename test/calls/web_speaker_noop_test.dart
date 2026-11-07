import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/calls/webrtc_call_engine.dart';

/// Coordinator C3 check (as rider #545, proof5 (3), owner 2026-11-07 "keep
/// the speaker button"): the in-call speaker switch called flutter_webrtc's
/// native-only Helper.setSpeakerphoneOn, which throws
/// MissingPluginException on the web. A test VM has no WebRTC plugin
/// either, like the web, so the native call shows the same failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PROOF: the native speaker call has no plugin here (as on the web)',
    () async {
      final native = WebRtcCallEngine(isWeb: false);
      await expectLater(
        native.setSpeaker(true),
        throwsA(isA<MissingPluginException>()),
      );
    },
  );

  test('web: the speaker button does nothing and throws nothing', () async {
    var calls = 0;
    final web = WebRtcCallEngine(
      isWeb: true,
      setSpeakerphone: (_) async {
        calls++;
        throw MissingPluginException('setSpeakerphoneOn');
      },
    );
    await web.setSpeaker(true);
    await web.setSpeaker(false);
    expect(calls, 0);
  });

  test('native store builds still switch the speaker', () async {
    final seen = <bool>[];
    final phone = WebRtcCallEngine(
      isWeb: false,
      setSpeakerphone: (on) async => seen.add(on),
    );
    await phone.setSpeaker(true);
    await phone.setSpeaker(false);
    expect(seen, [true, false]);
  });
}
