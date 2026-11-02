import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/add vehicle/add_vehicle.dart';

class _Store extends LocalVehicleStore {
  int removes = 0;
  Completer<void>? pending;

  @override
  Future<List<Map<String, dynamic>>> list() async => [
    Map.of(LocalVehicleStore.demo),
  ];

  @override
  Future<void> remove(String id) async {
    removes++;
    if (pending != null) await pending!.future;
  }
}

Future<void> _open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('Open vehicle page'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open vehicle page'));
  await tester.pumpAndSettle();
}

Future<void> _removeSheet(WidgetTester tester, _Store store) async {
  await _open(
    tester,
    VehicleDocuments(
      vehicleId: LocalVehicleStore.demo['id'] as String,
      make: 'Mercedes-Benz',
      model: 'E 220',
      year: '2022',
      plate: 'MVR 418',
      store: store,
    ),
  );
  final button = find.widgetWithText(TextButton, 'Remove vehicle');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

VoidCallback _decision(WidgetTester tester, String text) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, text))
    .onPressed!;

void main() {
  testWidgets('repeated year opening and selection preserve the vehicle form', (
    tester,
  ) async {
    await _open(tester, const AddVehicle());
    await tester.enterText(find.byType(TextField).first, 'Mercedes-Benz');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'E 220');
    await tester.pump();
    final yearSelector = find.byWidgetPredicate(
      (w) => w is InkWell && w.child is InputDecorator,
    );
    await tester.ensureVisible(yearSelector);
    await tester.pumpAndSettle();
    final open = tester.widget<InkWell>(yearSelector).onTap!;
    open();
    open();
    await tester.pumpAndSettle();
    expect(find.text('Year'), findsOneWidget);
    final choice = tester
        .widget<ListTile>(
          find.widgetWithText(ListTile, DateTime.now().year.toString()),
        )
        .onTap!;
    choice();
    choice();
    await tester.pumpAndSettle();
    expect(find.byType(AddVehicle), findsOneWidget);
    expect(find.text('License plate number *'), findsOneWidget);
    expect(find.text(DateTime.now().year.toString()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated Keep cannot close vehicle documents', (tester) async {
    final store = _Store();
    await _removeSheet(tester, store);
    final keep = _decision(tester, 'Keep vehicle');
    keep();
    keep();
    await tester.pumpAndSettle();
    expect(find.byType(VehicleDocuments), findsOneWidget);
    expect(store.removes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated Remove preserves documents for failure retry', (
    tester,
  ) async {
    final store = _Store()..pending = Completer<void>();
    await _removeSheet(tester, store);
    final remove = _decision(tester, 'Remove vehicle');
    remove();
    remove();
    await tester.pumpAndSettle();
    expect(store.removes, 1);
    expect(find.byType(VehicleDocuments), findsOneWidget);
    store.pending!.completeError(StateError('Storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Could not remove local draft. Retry.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Remove vehicle'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'late removal ${fail ? 'failure' : 'success'} during Documents dismissal preserves caller',
      (tester) async {
        final store = _Store()..pending = Completer<void>();
        await _removeSheet(tester, store);
        _decision(tester, 'Remove vehicle')();
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(VehicleDocuments));
        Navigator.of(context).pop();
        // Complete before the reverse transition disposes Documents.
        if (fail) {
          store.pending!.completeError(StateError('Storage unavailable'));
        } else {
          store.pending!.complete();
        }
        await tester.pumpAndSettle();
        expect(find.text('Open vehicle page'), findsOneWidget);
        expect(find.byType(VehicleDocuments), findsNothing);
        expect(find.text('Could not remove local draft. Retry.'), findsNothing);
        expect(store.removes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('successful removal closes only Documents', (tester) async {
    final store = _Store();
    await _removeSheet(tester, store);
    _decision(tester, 'Remove vehicle')();
    await tester.pumpAndSettle();
    expect(find.text('Open vehicle page'), findsOneWidget);
    expect(find.byType(VehicleDocuments), findsNothing);
    expect(store.removes, 1);
    expect(tester.takeException(), isNull);
  });
}
