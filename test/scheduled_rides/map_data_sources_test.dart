import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';

/// v0.18.172 (contract.json#preferredAreas.attribution): the terms end with
/// the map data credit (SCB, IGN); the privacy policy does not.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('terms show the map data sources, privacy does not', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(home: LegalDocumentScreen.terms),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('legal-map-data-sources')),
      findsOneWidget,
    );
    expect(find.textContaining('© SCB'), findsOneWidget);
    expect(find.textContaining('© IGN'), findsOneWidget);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(home: LegalDocumentScreen.privacy),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('legal-map-data-sources')), findsNothing);
  });
}
