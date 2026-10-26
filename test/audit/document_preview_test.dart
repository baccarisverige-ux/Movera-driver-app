import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/documents/documents.dart';

void main() {
  testWidgets('each document opens its own unverified preview', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverDocuments()));
    expect(find.text('Completed'), findsNothing);
    await tester.tap(find.text('Driver’s license'));
    await tester.pumpAndSettle();
    expect(find.text('Driver’s license'), findsWidgets);
    expect(find.textContaining('No document was uploaded'), findsOneWidget);
  });
}
