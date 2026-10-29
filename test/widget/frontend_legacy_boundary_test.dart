import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_composition_guard.dart';

void main() {
  test('028 preview is allowed and production rejects demo composition', () {
    expect(() => validateDriverComposition(production: false), returnsNormally);
    expect(() => validateDriverComposition(production: true), throwsStateError);
    expect(driverProductionRequested, false);
  });
}
