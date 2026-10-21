import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/l10n/app_localizations.dart';

/// driver-u39: OSRM sends type 'continue' (and 'new name') with a turning
/// modifier where the road bends through a junction, and 'continue' +
/// 'uturn' for a turnaround. The words must follow the turn, as the arrow
/// does, instead of reading "Continue straight".
final _en = lookupAppLocalizations(const Locale('en'));
final _fr = lookupAppLocalizations(const Locale('fr'));
final _sv = lookupAppLocalizations(const Locale('sv'));

const _onward = [RouteManeuverType.continueStraight, RouteManeuverType.newName];

String _live(RouteManeuverType type, String modifier, AppLocalizations l) =>
    RouteInstructionCopy.livePrimary(
      cue: RouteInstructionCopy.cue(type: type, modifier: modifier),
      meters: 300,
      strings: l,
    );

void main() {
  test('a turning continue step reads as the turn, in en/fr/sv', () {
    for (final type in _onward) {
      expect(_live(type, 'uturn', _en), 'U-turn in 300 m');
      expect(_live(type, 'uturn left', _en), 'U-turn in 300 m');
      expect(_live(type, 'left', _en), 'Turn left in 300 m');
      expect(_live(type, 'sharp right', _en), 'Turn sharp right in 300 m');
      expect(_live(type, 'slight left', _en), 'Turn slight left in 300 m');
      expect(_live(type, 'left', _sv), 'Sväng vänster om 300 m');
      expect(_live(type, 'uturn', _sv), 'U-sväng om 300 m');
      expect(_live(type, 'left', _fr), 'Tournez à gauche dans 300 m');
      expect(_live(type, 'uturn', _fr), 'Demi-tour dans 300 m');
    }
  });

  test('straight, empty and highway slight modifiers keep their cue', () {
    for (final type in _onward) {
      expect(_live(type, '', _en), 'Continue straight 300 m');
      expect(_live(type, 'straight', _en), 'Continue straight 300 m');
      expect(
        RouteInstructionCopy.cue(
          type: type,
          modifier: 'slight left',
          highway: true,
        ).kind,
        RouteCueKind.keepLeft,
      );
      expect(
        RouteInstructionCopy.cue(type: type, modifier: '', tunnel: true).kind,
        RouteCueKind.tunnelAhead,
      );
    }
  });

  test('the words agree with the arrow for every turning modifier', () {
    const expected = {
      'uturn': RouteCueKind.uTurn,
      'uturn right': RouteCueKind.uTurn,
      'left': RouteCueKind.turnLeft,
      'right': RouteCueKind.turnRight,
      'sharp left': RouteCueKind.sharpLeft,
      'sharp right': RouteCueKind.sharpRight,
      'slight left': RouteCueKind.slightLeft,
      'slight right': RouteCueKind.slightRight,
    };
    for (final type in _onward) {
      expected.forEach((modifier, kind) {
        expect(
          RouteInstructionCopy.cue(type: type, modifier: modifier).kind,
          kind,
          reason: '$type $modifier',
        );
      });
    }
  });

  test('build() says the turn too, with the road name', () {
    for (final type in _onward) {
      expect(
        RouteInstructionCopy.build(
          type: type,
          modifier: 'left',
          roadName: 'Sveavägen',
          strings: _en,
        ),
        'Turn left onto Sveavägen',
      );
      expect(
        RouteInstructionCopy.build(type: type, modifier: 'uturn', strings: _en),
        'Make a U-turn',
      );
      expect(
        RouteInstructionCopy.build(type: type, modifier: 'left', strings: _sv),
        'Sväng vänster',
      );
      expect(
        RouteInstructionCopy.build(
          type: type,
          modifier: 'straight',
          roadName: 'Sveavägen',
          strings: _en,
        ),
        'Continue on Sveavägen',
      );
    }
  });
}
