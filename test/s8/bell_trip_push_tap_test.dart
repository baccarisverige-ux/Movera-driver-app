// S8 R2 (2026-11-07): driver #484 made main.dart _openPush return without
// doing anything for every movera-driver://trip(s)/{id} link. Server #110
// (Q9) sends the "your pay changed" notice (bell true, often hours after
// the trip) and server #123 (L1) the « Course annulée » notice (bell true)
// as movera-driver://trips/{id}: a tap opened nothing. Now a trip push
// opens the bell list on the notice unless it is about the trip on screen
// (or the trip Home is restoring).
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/ride/open_trip_screens.dart';

void main() {
  tearDown(OpenTripScreens.reset);

  String tripOf(String link) =>
      PushOpen(notificationId: 'ntf', deepLink: link).routeChangeTripId!;

  test('pay change notice about a finished trip opens the bell list', () {
    final trip = tripOf('movera-driver://trips/trp_done');
    expect(openTripPush(trip), isFalse);
    expect(openTripPush(trip, activeTripId: 'trp_now'), isFalse);
  });

  test('L1 « Course annulée » notice about a trip no longer driven opens '
      'the bell list', () {
    expect(openTripPush(tripOf('movera-driver://trips/trp_1')), isFalse);
  });

  test('a push about the trip on screen brings it back (no bell list)', () {
    var front = 0;
    void bring() => front++;
    OpenTripScreens.add('trp_1', bring);
    expect(openTripPush(tripOf('movera-driver://trip/trp_1')), isTrue);
    expect(front, 1);
    OpenTripScreens.remove('trp_1', bring);
    expect(OpenTripScreens.isOpen('trp_1'), isFalse);
  });

  test(
    'a cold start: Home is still restoring the active trip, no bell list',
    () {
      expect(
        openTripPush(
          tripOf('movera-driver://trips/trp_1'),
          activeTripId: 'trp_1',
        ),
        isTrue,
      );
    },
  );
}
