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
}

void main() {
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
