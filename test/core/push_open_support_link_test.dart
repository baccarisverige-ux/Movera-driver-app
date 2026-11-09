// START-HERE step 32 (contract v0.18.53 §75, owner Q39 2026-11-09): a
// support answer pushes the ticket's owner (kind support_reply, deep link
// movera-driver://support/{ticketId}, data { ticketId }). PushOpen must read
// the ticket id so main.dart _openPush opens the ticket instead of the bell
// list; unknown links stay unknown.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/push/push_platform.dart';

Map<String, dynamic> _contract() =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

PushOpen _open(String link) => PushOpen(
  notificationId: 'ntf_1',
  deepLink: link.replaceFirst('{ticketId}', 'tkt_1'),
);

void main() {
  test('support answer push link gives the ticket id', () {
    final contract = _contract();
    final push = (contract['support'] as Map)['answerPush'] as Map;
    expect(push['kind'], 'support_reply');
    final link = (push['deepLink'] as Map)['driver'] as String;
    expect(link, 'movera-driver://support/{ticketId}');
    final open = _open(link);
    expect(open.supportTicketId, 'tkt_1');
    expect(open.offerId, isNull);
    expect(open.routeChangeTripId, isNull);
  });

  test('other and unknown links are not support links', () {
    expect(_open('movera-driver://trips/trp_1').supportTicketId, isNull);
    expect(_open('movera-driver://offers/off_1').supportTicketId, isNull);
    expect(_open('movera-driver://support/').supportTicketId, isNull);
    expect(_open('movera-driver://supportx/tkt_1').supportTicketId, isNull);
    expect(_open('movera-driver://notifications').supportTicketId, isNull);
    expect(const PushOpen(notificationId: 'ntf_1').supportTicketId, isNull);
  });
}
