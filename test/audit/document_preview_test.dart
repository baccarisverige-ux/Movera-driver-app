import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/documents/documents.dart';

void main() {
  // Owner group 2 item 4 (replaces the old "not available" preview): a
  // document opens its upload guide, with the drawn example and the list
  // of what must be visible; the demo uploads nothing.
  testWidgets('each document opens its upload guide', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverDocuments()));
    expect(find.text('Completed'), findsNothing);
    await tester.tap(find.text('Driver’s license'));
    await tester.pumpAndSettle();
    expect(find.text('Driving licence'), findsWidgets);
    expect(find.text('Example drawn by Movera'), findsOneWidget);
    expect(find.text('Front and back of the licence'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('guide-upload')));
    await tester.tap(find.byKey(const ValueKey('guide-upload')));
    await tester.pump();
    expect(find.textContaining('No document was uploaded'), findsOneWidget);
  });
}
