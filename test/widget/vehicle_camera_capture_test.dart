import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/add vehicle/add_vehicle.dart';

class _PhotoStore extends LocalVehicleStore {
  int writes = 0;

  @override
  Future<List<Map<String, dynamic>>> list() async => [
    Map.of(LocalVehicleStore.demo),
  ];

  @override
  Future<void> upsert(Map<String, dynamic> row) async {
    writes++;
  }
}

Future<void> _open(
  WidgetTester tester,
  _PhotoStore store,
  Future<XFile?> Function() capture,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VehicleDocuments(
        vehicleId: LocalVehicleStore.demo['id'] as String,
        make: 'Mercedes-Benz',
        model: 'E 220',
        year: '2022',
        plate: 'MVR 418',
        store: store,
        capturePhoto: capture,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vehicle Registration Certificate (Front Page)'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one pending capture and cancellation permits a fresh retry', (
    tester,
  ) async {
    final store = _PhotoStore();
    final gate = Completer<XFile?>();
    var calls = 0;
    await _open(tester, store, () {
      calls++;
      return calls == 1 ? gate.future : Future.value(null);
    });
    final callback = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(calls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    gate.complete(null);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(store.writes, 0);
    expect(find.text('Take photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera result during route close cannot pop documents or save', (
    tester,
  ) async {
    final store = _PhotoStore();
    final gate = Completer<XFile?>();
    final photo = XFile.fromData(File(AppAssets.profileImg).readAsBytesSync());
    await _open(tester, store, () => gate.future);
    await tester.tap(find.text('Take photo'));
    await tester.pump();
    // Complete while the reverse route transition is still running: mounted
    // alone cannot establish that this page still owns Navigator.pop.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    gate.complete(photo);
    await tester.pumpAndSettle();
    expect(find.byType(VehicleDocuments), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture errors keep the page usable for retry', (tester) async {
    var calls = 0;
    final store = _PhotoStore();
    await _open(tester, store, () async {
      calls++;
      if (calls == 1) throw StateError('Camera denied');
      return null;
    });
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Camera is not available in this preview.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });
}
