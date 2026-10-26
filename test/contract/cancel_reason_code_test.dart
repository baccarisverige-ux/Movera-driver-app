import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/cancel_reason_code.dart';
import 'package:movera/core/ride/cancel_reasons.dart';

void main() {
  final reasons =
      (jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>)['cancelReasons']
          as Map<String, dynamic>;

  test('CancelReasonCode = contract.json#cancelReasons, every group', () {
    expect(
      CancelReasonGroupId.values.map((g) => g.wireName).toList(),
      reasons.keys.toList(),
    );
    for (final group in CancelReasonGroupId.values) {
      expect(
        CancelReasonCode.inGroup(group).map((c) => c.wireName).toList(),
        reasons[group.wireName],
        reason: group.wireName,
      );
    }
    for (final code in CancelReasonCode.values) {
      expect(CancelReasonCode.tryParse(code.wireName), code);
    }
    expect(CancelReasonCode.tryParse('rider_cancelled'), isNull);
  });

  test(
    'the app reason sheets only offer contract codes of the right group',
    () {
      const groups = {
        CancelReasonGroup.driverBeforeTrip:
            CancelReasonGroupId.driverBeforeTrip,
        CancelReasonGroup.driverDuringTrip:
            CancelReasonGroupId.driverDuringTrip,
        CancelReasonGroup.driverNextTrip: CancelReasonGroupId.driverNextTrip,
        CancelReasonGroup.scheduled: CancelReasonGroupId.scheduled,
        CancelReasonGroup.rider: CancelReasonGroupId.rider,
      };
      const local = CancelReasons();
      for (final entry in groups.entries) {
        expect(
          local.of(entry.key).map((r) => r.code).toList(),
          reasons[entry.value.wireName],
          reason: entry.key.name,
        );
      }
      expect(
        CancelReasonCode.tryParse(local.noShow.code)?.group,
        CancelReasonGroupId.noShow,
      );
    },
  );
}
