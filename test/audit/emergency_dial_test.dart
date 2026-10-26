import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/emergency_dial.dart';

void main() {
  test('dialer success is distinct from a placed call', () async {
    expect(
      await handoffEmergencyDial(() async => true),
      EmergencyDialResult.opened,
    );
  });
  test('false and throwing launchers are unavailable', () async {
    expect(
      await handoffEmergencyDial(() async => false),
      EmergencyDialResult.unavailable,
    );
    expect(
      await handoffEmergencyDial(() async => throw StateError('denied')),
      EmergencyDialResult.unavailable,
    );
  });
}
