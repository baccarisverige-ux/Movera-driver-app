// Wave 5 D5.2 (UI truth), part a: the trip screen shows only what really
// happened.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';

Widget _island({String? status, double width = 390}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 220,
          child: AdaptiveTripIsland(
            status: 'To pickup',
            address: 'Sveavägen 20',
            detail: 'Picking up Angelica',
            eta: '2 min',
            progress: .4,
            navigationStatus: status,
            waitingMessage: 'Waiting for Angelica',
            lastTripLabel: '120 kr',
            onRadar: () {},
            onMenu: () {},
            onSearch: () {},
            onHistory: () {},
            onRoute: () {},
            onSafety: () {},
            onWait: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('driver-u88: a long status island stops at the documented '
      'maximum width', (tester) async {
    await tester.pumpWidget(_island(status: 'Mise à jour de la position…'));
    await tester.pump(const Duration(seconds: 1));
    final shell = tester.getSize(find.byKey(const ValueKey('island-morph-shell')));
    expect(shell.width, lessThanOrEqualTo(TripIslandGeometry.maximumWidth + .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
