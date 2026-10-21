import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';

// driver-u49: a refused silent prime (a phone browser outside a user
// activation) must not leave later offer alerts muted.

/// Records the volume; play is refused while [refuse] is set.
class _Audio implements AudioPlayer {
  double level = 1;
  bool refuse = true;
  @override
  Future<void> setVolume(double volume) async => level = volume;
  @override
  Future<void> play(Source source, {double? volume, double? balance,
      AudioContext? ctx, Duration? position, PlayerMode? mode}) async {
    if (refuse) throw StateError('NotAllowedError');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Player implements RadarSoundPlayer {
  int primes = 0;
  bool fail = true;
  @override
  Future<void> prime() async {
    primes++;
    if (fail) throw StateError('NotAllowedError');
  }

  @override
  Future<void> startLoop() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  test('driver-u49: a refused prime puts the volume back to full', () async {
    final audio = _Audio();
    final player = AudioRadarSound(create: () => audio);
    await expectLater(player.prime(), throwsStateError);
    expect(audio.level, 1, reason: 'later offer alerts must be audible');
  });

  test('driver-u49: after a refused prime the next tap primes again',
      () async {
    final player = _Player();
    final sound = RadarOfferSound(player: player);
    sound.tap();
    await Future<void>.delayed(Duration.zero);
    expect(player.primes, 1);
    player.fail = false;
    sound.tap();
    await Future<void>.delayed(Duration.zero);
    expect(player.primes, 2);
    sound.tap();
    await Future<void>.delayed(Duration.zero);
    expect(player.primes, 2, reason: 'once it worked, once is enough');
    sound.dispose();
  });
}
