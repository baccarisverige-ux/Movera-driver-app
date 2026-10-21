import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/presentation/driver/add vehicle/add_vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';

// driver-50: Back from the documents page to Add vehicle and Continue
// again must not drop the document photos already saved for the draft.
// Form filling copied from vehicle_form_save_races_test.dart.

Future<void> _fill(WidgetTester tester, LocalVehicleStore store) async {
  await tester.pumpWidget(MaterialApp(home: AddVehicle(store: store)));
  await tester.enterText(find.byType(TextField).first, 'Mercedes');
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(1), 'E220');
  await tester.pump();
  final yearSelector = find.byWidgetPredicate(
    (widget) => widget is InkWell && widget.child is InputDecorator,
  );
  await tester.ensureVisible(yearSelector);
  await tester.tap(yearSelector);
  await tester.pumpAndSettle();
  await tester.tap(find.text(DateTime.now().year.toString()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(TextField).at(2));
  await tester.enterText(find.byType(TextField).at(2), 'ABC123');
  await tester.pump();
}

Future<void> _continue(WidgetTester tester) async {
  tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
      .onPressed!();
  await tester.pumpAndSettle();
  expect(find.byType(VehicleDocuments), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('driver-50 Continue again keeps the saved document photos', (
    tester,
  ) async {
    final store = LocalVehicleStore();
    final photo = base64Encode(const [1, 2, 3, 4]);
    await _fill(tester, store);
    await _continue(tester);

    // The photo page saves into the same row, as VehicleDocuments does.
    Map<String, dynamic> draft(List<Map<String, dynamic>> rows) =>
        rows.singleWhere((row) => '${row['id']}'.startsWith('local-'));
    final row = draft((await tester.runAsync(store.list))!);
    await tester.runAsync(
      () => store.upsert({...row, 'registrationPhoto': photo}),
    );
    Navigator.of(tester.element(find.byType(VehicleDocuments))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AddVehicle), findsOneWidget);

    // A typo fixed in the plate, then Continue again.
    await tester.enterText(find.byType(TextField).at(2), 'ABC124');
    await tester.pump();
    await _continue(tester);

    final saved = draft((await tester.runAsync(store.list))!);
    expect(saved['id'], row['id']);
    expect(saved['plate'], 'ABC124');
    expect(saved['registrationPhoto'], photo);
    expect(tester.takeException(), isNull);
  });
}
