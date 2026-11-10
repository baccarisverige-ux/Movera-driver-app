import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/calls/trip_call_session.dart';
import 'package:movera/core/chat/chat_message_alert.dart';
import 'package:movera/core/chat/chat_speech_io.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/app_tones.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calls/in_app_call_test.dart' show FakeApi, FakeEngine;

/// Rules REMINDERS rows 28–29 (contract v0.18.56 §78, §62): Movera's own
/// new-message sound (admin `chat.sound`), "Read rider messages" on
/// Android / iOS (the phone's text-to-speech) and the ring of an incoming
/// in-app call until it is answered, declined or missed.
class FakeTones implements TonePlayer {
  final List<String> log = [];
  @override
  Future<void> playOnce(String asset) async => log.add('once:$asset');
  @override
  Future<void> loop(String asset) async => log.add('loop:$asset');
  @override
  Future<void> stop() async => log.add('stop');
  @override
  Future<void> dispose() async => log.add('dispose');
}

class FakeSpeech implements SpeechEngine {
  final List<String> said = [];
  @override
  Future<void> speak(String text, String locale) async =>
      said.add('$locale:$text');
}

void main() {
  late FakeTones tones;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tones = FakeTones();
    AppTones.debugReset();
    AppTones.debugCreate = () => tones;
  });

  tearDown(() {
    AppTones.debugCreate = null;
    AppTones.debugReset();
    ChatSpeech.engine = FlutterTtsEngine();
    DriverAppTexts.language = 'en';
  });

  test('a new message plays chat_message.wav only while admin sound is on, '
      'and reads it aloud with the phone voice in the app language', () async {
    final speech = FakeSpeech();
    ChatSpeech.engine = speech;
    DriverAppTexts.language = 'sv';
    final repo = SettingsRepository();
    await ChatMessageAlert.forMessage(
      'Hej',
      sound: true,
      readAloudDefault: false,
      repository: repo,
    );
    await pumpEventQueue();
    expect(tones.log, ['once:${AppTones.chatMessage}']);
    expect(speech.said, isEmpty);

    tones.log.clear();
    await repo.save('sound', {'readRiderMessages': true});
    await ChatMessageAlert.forMessage(
      'Hej',
      sound: false,
      readAloudDefault: false,
      repository: repo,
    );
    await pumpEventQueue();
    expect(tones.log, isEmpty);
    expect(speech.said, ['sv-SE:Hej']);
  });

  test('a speech engine that fails stays quiet', () {
    ChatSpeech.engine = _BrokenSpeech();
    expect(deviceSpeak('Hi', 'fr'), isTrue);
    expect(ChatSpeech.locale('fr'), 'fr-FR');
    expect(ChatSpeech.locale('xx'), 'en-GB');
  });

  test('ringtone loops while ringing and stops once', () {
    final ring = CallRingtone(player: tones)
      ..update(true)
      ..update(true)
      ..update(false)
      ..update(false);
    ring.dispose();
    expect(tones.log, ['loop:${AppTones.callRing}', 'stop', 'dispose']);
  });

  Future<TripCallSession> show(
    WidgetTester tester, {
    bool incoming = true,
  }) async {
    final session = incoming
        ? TripCallSession.incoming(
            api: FakeApi(),
            engine: FakeEngine(),
            call: const IncomingCall(
              callId: 'cll_1',
              tripId: 't1',
              from: 'rider',
            ),
            side: 'driver',
            ice: const [],
          )
        : TripCallSession.outgoing(
            api: FakeApi(),
            engine: FakeEngine(),
            tripId: 't1',
            side: 'driver',
          );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripCallScreen(session: session),
      ),
    );
    return session;
  }

  testWidgets('the incoming call rings until Answer', (tester) async {
    final session = await show(tester);
    expect(tones.log, ['loop:${AppTones.callRing}']);
    await session.answer();
    await tester.pump();
    expect(tones.log, ['loop:${AppTones.callRing}', 'stop']);
    await tester.pumpWidget(const SizedBox());
    expect(tones.log.last, 'dispose');
  });

  testWidgets('Decline and a missed call stop the ring', (tester) async {
    final session = await show(tester);
    await session.decline();
    await tester.pump();
    expect(tones.log, ['loop:${AppTones.callRing}', 'stop']);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());

    tones.log.clear();
    final missed = await show(tester);
    await missed.receive('call_missed', {'callId': 'cll_1'});
    await tester.pump();
    expect(tones.log, ['loop:${AppTones.callRing}', 'stop']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an outgoing call does not ring here', (tester) async {
    await show(tester, incoming: false);
    expect(tones.log, isEmpty);
  });
}

class _BrokenSpeech implements SpeechEngine {
  @override
  Future<void> speak(String text, String locale) async =>
      throw StateError('no voice');
}
