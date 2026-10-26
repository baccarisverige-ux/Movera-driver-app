import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';

Widget _harness({
  required ArrivalPointKind kind,
  required double distanceMeters,
  required String label,
  required String address,
  bool arrived = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: NavigationInstructionBanner(
        arrivalPointKind: kind,
        arrivalDistanceMeters: distanceMeters,
        arrivalLabel: label,
        arrivalAddress: address,
        arrivalArrived: arrived,
      ),
    ),
  );
}

void main() {
  testWidgets('pickup approach uses green pin and distance', (tester) async {
    await tester.pumpWidget(
      _harness(
        kind: ArrivalPointKind.pickup,
        distanceMeters: 180,
        label: 'Pickup',
        address: 'Vasagatan 10, Stockholm',
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.byKey(const ValueKey<String>('arrival-approach-banner')),
      findsOneWidget,
    );
    expect(find.text('PICKUP'), findsOneWidget);
    expect(find.text('180 m'), findsOneWidget);
    final pin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('arrival-pin-pickup')),
    );
    expect(pin.color, const Color(0xFF17A673));
  });

  testWidgets('intermediate stop approach uses blue pin', (tester) async {
    await tester.pumpWidget(
      _harness(
        kind: ArrivalPointKind.stop,
        distanceMeters: 92,
        label: 'Stop 2',
        address: 'Sveavägen 44, Stockholm',
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('STOP 2'), findsOneWidget);
    expect(find.text('92 m'), findsOneWidget);
    final pin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('arrival-pin-stop')),
    );
    expect(pin.color, const Color(0xFF2F80ED));
  });

  testWidgets('final destination arrived state uses red pin', (tester) async {
    await tester.pumpWidget(
      _harness(
        kind: ArrivalPointKind.destination,
        distanceMeters: 8,
        label: 'Destination',
        address: 'Scandic Grand Central',
        arrived: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('DESTINATION'), findsOneWidget);
    expect(find.text('ARRIVED'), findsOneWidget);
    final pin = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('arrival-pin-destination')),
    );
    expect(pin.color, const Color(0xFFE13B2D));
  });
}
