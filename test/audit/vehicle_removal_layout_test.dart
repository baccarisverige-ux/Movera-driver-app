import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/add%20vehicle/add_vehicle.dart';

class _Store extends LocalVehicleStore {
  int removes = 0;
  @override
  Future<List<Map<String, dynamic>>> list() async => [
    {
      'id': 'car',
      'make': 'Mercedes',
      'model': 'E220',
      'year': '2022',
      'plate': 'ABC123',
    },
  ];
  @override
  Future<void> remove(String id) async {
    removes++;
  }
}

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('vehicle removal stays reachable at 200% $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: VehicleDocuments(
            vehicleId: 'car',
            make: 'Mercedes',
            model: 'E220',
            year: '2022',
            plate: 'ABC123',
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final remove = find.widgetWithText(TextButton, 'Remove vehicle');
      await tester.scrollUntilVisible(
        remove,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final keep = find.text('Keep vehicle');
      await tester.ensureVisible(keep);
      await tester.pumpAndSettle();
      await tester.tap(keep);
      await tester.pumpAndSettle();
      expect(store.removes, 0);
      expect(find.text('Remove local vehicle draft?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
