import 'dart:convert';
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

  test('the copy is contract v0.18.87', () {
    expect(
      File('contracts/contract.json').readAsStringSync(),
      contains('"version": "0.18.87"'),
    );
    expect(TripTransitions.contractVersion, '0.18.87');
  });

  // v0.18.87 (owner 2026-11-13 "Movera commission is how much movera
  // keep", moneyBase.commissionRow): the "Movera commission" rows read
  // TripProjection.moveraKeepsNow; the copy must carry the field and the
  // driver row rule.
  test(
    'v0.18.87: TripProjection.moveraKeepsNow and commissionRow are in the copy',
    () {
      final openapi = File('contracts/openapi.yaml').readAsStringSync();
      expect(openapi, contains('moveraKeepsNow'));
      final contract =
          jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>;
      final moneyBase = contract['moneyBase'] as Map<String, dynamic>;
      final row = moneyBase['commissionRow'] as Map<String, dynamic>;
      expect(row['driver'], isA<String>());
      expect(row['driver'] as String, contains('moveraKeepsNow'));
    },
  );
}
