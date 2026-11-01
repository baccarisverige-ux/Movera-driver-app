import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_transitions.dart';

/// `contracts/` is a byte-for-byte copy of the shared Movera contract. Change
/// it upstream and re-sync; never edit it here.
void main() {
  test('every contracts/ file matches contracts/CHECKSUMS', () {
    final dir = Directory('contracts');
    final lines = File(
      'contracts/CHECKSUMS',
    ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
    expect(lines, isNotEmpty);
    final listed = <String, String>{};
    for (final line in lines) {
      final match = RegExp(r'^([0-9a-f]{64})  (.+)$').firstMatch(line);
      expect(match, isNotNull, reason: 'Bad CHECKSUMS line: $line');
      listed[match!.group(2)!] = match.group(1)!;
    }
    final onDisk = dir
        .listSync(recursive: true)
        .whereType<File>()
        .map(
          (file) => file.path
              .substring(dir.path.length + 1)
              .replaceAll(Platform.pathSeparator, '/'),
        )
        .where((path) => path != 'CHECKSUMS' && !path.contains('__pycache__'))
        .toSet();
    expect(
      onDisk,
      listed.keys.toSet(),
      reason: 'contracts/ has files missing from or extra to CHECKSUMS',
    );
    for (final entry in listed.entries) {
      final digest = sha256.convert(
        File('contracts/${entry.key}').readAsBytesSync(),
      );
      expect(digest.toString(), entry.value, reason: '${entry.key} drifted');
    }
  });

  test('the copy is contract v0.18.8', () {
    expect(
      File('contracts/contract.json').readAsStringSync(),
      contains('"version": "0.18.8"'),
    );
    expect(TripTransitions.contractVersion, '0.18.8');
  });
}
