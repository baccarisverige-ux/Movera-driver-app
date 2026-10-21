import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';

class _FakePlayer implements RadarSoundPlayer {
  final calls = <String>[];
  @override
  Future<void> startLoop() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> prime() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  d17();
  test('R15-5: loops while offers show, stops on tap or none, '
      'a new offer starts it again', () {
    final player = _FakePlayer();
    final sound = RadarOfferSound(player: player);

    sound.sync(['a']);
    expect(sound.playing, isTrue);
    sound.sync(['a']); // the same offer: no restart
    expect(player.calls, ['start']);

    // A tap anywhere (or Match): quiet, and the same offers stay quiet.
    sound.silence();
    sound.sync(['a']);
    expect(sound.playing, isFalse);

    // A new offer starts it again.
    sound.sync(['a', 'b']);
    expect(sound.playing, isTrue);

    // No offers left: it stops.
    sound.sync(const []);
    expect(sound.playing, isFalse);
    expect(player.calls, ['start', 'stop', 'start', 'stop']);

    // The same offer coming back later counts as new.
    sound.sync(['a']);
    expect(sound.playing, isTrue);
  });
}

/// A stand-in for the native player: records each call; play takes a while.
class _FakeAudio implements AudioPlayer {
  _FakeAudio({this.playTime = const Duration(milliseconds: 5)});
  final Duration playTime;
  final calls = <String>[];
  bool released = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString()
        .replaceAll('Symbol("', '')
        .replaceAll('")', '');
    calls.add(name);
    if (name == 'dispose') released = true;
    return name == 'play'
        ? Future<void>.delayed(playTime)
        : Future<void>.value();
  }
}

void d17() {
  test('D-17: player calls run one after another, then the player is '
      'released', () async {
    final audio = _FakeAudio();
    var made = 0;
    final player = AudioRadarSound(create: () {
      made++;
      return audio;
    });
    // A tap primes while an offer starts the loop: no interleaving.
    final prime = player.prime();
    final start = player.startLoop();
    await Future.wait([prime, start]);
    expect(audio.calls, [
      'setVolume', 'play', 'stop', 'setVolume',
      'setReleaseMode', 'play',
    ]);
    await player.stop();
    await player.dispose();
    expect(audio.released, isTrue);
    expect(made, 1);
    // Nothing plays after dispose.
    await player.startLoop();
    expect(audio.calls.last, 'dispose');
  });

  test('D-17: the Home sound releases the player it made', () async {
    final audio = _FakeAudio(playTime: Duration.zero);
    RadarOfferSound.debugCreate = () => AudioRadarSound(create: () => audio);
    addTearDown(() => RadarOfferSound.debugCreate = null);
    final sound = RadarOfferSound();
    sound.sync(['a']);
    await pumpEventQueue();
    expect(audio.calls, contains('play'));
    sound.dispose();
    await pumpEventQueue();
    expect(audio.released, isTrue);
  });

  test('D-17: an injected player is not released', () async {
    final audio = _FakeAudio();
    final sound = RadarOfferSound(
      player: AudioRadarSound(create: () => audio),
    );
    sound.sync(['a']);
    sound.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // An injected player belongs to whoever passed it in.
    expect(audio.released, isFalse);
  });
}
