import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reachable camera capture declares NSCameraUsageDescription', () {
    const cameraFiles = <String>[
      'lib/presentation/driver/add vehicle/add_vehicle.dart',
    ];
    for (final path in cameraFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ImageSource.camera'), reason: path);
      expect(source, isNot(contains('ImageSource.gallery')), reason: path);
    }

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
    expect(plist, contains('vehicle and document photos'));
    final value = RegExp(
      r'<key>NSCameraUsageDescription</key>\s*<string>([^<]+)</string>',
    ).firstMatch(plist);
    expect(value, isNotNull);
    expect(value!.group(1)!.trim(), isNotEmpty);
    expect(value.group(1), contains('camera'));
    // driver-u6: image_picker and file_picker reference the photo and media
    // libraries, so App Store processing (ITMS-90683) needs both purpose
    // strings even though the app never asks for them (owner decision,
    // 2026-10-21). They must say so honestly.
    for (final key in [
      'NSPhotoLibraryUsageDescription',
      'NSAppleMusicUsageDescription',
    ]) {
      final purpose = RegExp(
        '<key>$key</key>\\s*<string>([^<]+)</string>',
      ).firstMatch(plist);
      expect(purpose, isNotNull, reason: key);
      expect(purpose!.group(1), contains('only if you choose'), reason: key);
    }
  });
}
