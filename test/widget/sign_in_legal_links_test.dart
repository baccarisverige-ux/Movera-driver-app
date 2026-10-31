import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState;

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/signed_out_notice.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';

/// Contract G1-B2 (live iPhone check 2026-10-31): on the sign-in screen
/// "terms" and "privacy policy" in the consent sentence are two visible
/// links, each opening its own legal page, and a tap on them does not tick
/// the consent box.
void main() {
  setUp(() {
    DriverAppTexts.language = 'en';
    SignedOutNotice.clear();
  });

  Future<void> pumpSignIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryTokenStore();
    final auth = AuthController(
      repository: AuthRepository(
        api: ApiClient(
          client: MockClient((_) async => http.Response('{}', 404)),
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: store,
        ),
        tokens: store,
      ),
    );
    await tester.pumpWidget(
      // The legal page sizes itself with ScreenUtil, as in the app.
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          home: DriverSignIn(controller: auth, showTestAccounts: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
  }

  FinderBase<TextRangeContext> inConsent(String text) =>
      find.textRange.ofSubstring(
        text,
        descendentOf: find.byKey(const ValueKey('auth-consent')),
      );

  TextSpan spanOf(WidgetTester tester, String text) {
    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-consent')),
        matching: find.byType(RichText),
      ),
    );
    TextSpan? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    return found!;
  }

  bool ticked(WidgetTester tester) {
    final node = tester.getSemantics(
      find.byKey(const ValueKey('auth-consent-box')),
    );
    return node.getSemanticsData().flagsCollection.isChecked ==
        CheckedState.isTrue;
  }

  testWidgets('"terms" and "privacy policy" look like links (underlined) '
      'and are links for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSignIn(tester);
    for (final word in [tr.authConsentTerms, tr.authConsentPrivacy]) {
      final span = spanOf(tester, word);
      expect(span.recognizer, isNotNull, reason: word);
      expect(span.style?.decoration, TextDecoration.underline, reason: word);
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.label == word &&
              node.getSemanticsData().flagsCollection.isLink,
        ),
        findsOne,
        reason: word,
      );
    }
    // The rest of the sentence is plain text.
    expect(spanOf(tester, tr.authAnd).style?.decoration, isNull);
    semantics.dispose();
  });

  for (final (name, kind) in [
    ('terms', LegalKind.terms),
    ('privacy policy', LegalKind.privacy),
  ]) {
    testWidgets('a tap on "$name" opens that legal page and does not tick '
        'the box', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSignIn(tester);
      expect(ticked(tester), isFalse);
      final word = kind == LegalKind.terms
          ? tr.authConsentTerms
          : tr.authConsentPrivacy;
      await tester.tapOnText(inConsent(word));
      await tester.pumpAndSettle();
      final page = tester.widget<LegalDocumentScreen>(
        find.byType(LegalDocumentScreen),
      );
      expect(page.kind, kind);
      Navigator.of(tester.element(find.byType(LegalDocumentScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentScreen), findsNothing);
      expect(ticked(tester), isFalse, reason: 'a link tap is not a tick');
      semantics.dispose();
    });
  }
}
