import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept%20ride/rider_cancelled_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:movera/presentation/driver/analytics/acceptance%20rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/documents/document_preview.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D3: screens and sheets on small phones with large text. Every case runs
// at 320x568 (iPhone SE 1) and 375x667 (iPhone SE 2/3) with text at 130 %.

const _sizes = <Size>[Size(320, 568), Size(375, 667)];
const _scale = 1.3;

Future<void> _pumpAt(WidgetTester tester, Size size, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(_scale),
            ),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A page with one button that opens [open].
Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );

/// [target] is on screen and a tap at its centre reaches it.
void _expectTappable(WidgetTester tester, Finder target, Size size) {
  expect(target, findsOneWidget);
  final rect = tester.getRect(target);
  final screen = Offset.zero & size;
  expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight - const Offset(1, 1)),
      isTrue, reason: '$rect is not inside $screen');
  final hits = tester.hitTestOnBinding(rect.center);
  final box = tester.renderObject(target);
  expect(hits.path.any((entry) => entry.target == box), isTrue,
      reason: 'something covers the centre of $target');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()} @$_scale';

    // UI-01: the non-dismissible outcome sheets keep their only button on
    // screen; the text above it scrolls.
    for (final wasOnTrip in [true, false]) {
      testWidgets(
          'UI-01 rider cancelled (${wasOnTrip ? 'on trip' : 'pickup'}, fee) '
          'can be acknowledged at $at', (tester) async {
        await _pumpAt(
          tester,
          size,
          _opener((context) => showRiderCancelledSheet(
                context,
                riderName: 'Alexandra Lindqvist',
                wasOnTrip: wasOnTrip,
                fee: Money.sek(4500),
              )),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        const ok = ValueKey<String>('rider-cancelled-acknowledge');
        _expectTappable(tester, find.byKey(ok), size);
        await tester.tap(find.byKey(ok));
        await tester.pump();
        expect(find.byType(RiderCancelledSheet), findsNothing);
      });
    }

    for (final status in [
      TripStatus.noShow,
      TripStatus.cancelledByAdmin,
      TripStatus.failed,
    ]) {
      testWidgets('UI-01 outcome ${status.name} can be acknowledged at $at',
          (tester) async {
        await _pumpAt(
          tester,
          size,
          _opener((context) => showTripOutcomeSheet(
                context,
                status: status,
                hasNext: true,
              )),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        const ok = ValueKey<String>('trip-outcome-acknowledge');
        _expectTappable(tester, find.byKey(ok), size);
        await tester.tap(find.byKey(ok));
        await tester.pump();
        expect(find.byType(TripOutcomeSheet), findsNothing);
      });
    }

    // UI-13: the document upload sheet scrolls instead of overflowing.
    testWidgets('UI-13 document upload sheet fits at $at', (tester) async {
      final document = TrackedDocument(
        id: 'DOC-INS-1',
        title: 'Insurance letter',
        shortTitle: 'Insurance',
        expiresOn: DateTime(2030),
      );
      await _pumpAt(
        tester,
        size,
        _opener((context) => showDocumentUploadSheet(
              context,
              document,
              store: DocumentExpiryStore(),
            )),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final send = find.byKey(const ValueKey<String>('document-upload-send'));
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      _expectTappable(tester, send, size);
    });

    // UI-06: the Exclusive pill shrinks; the seconds are never cut off.
    testWidgets('UI-06 Exclusive pill keeps its seconds at $at',
        (tester) async {
      await _pumpAt(
        tester,
        size,
        const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: ExclusiveRequestSheet(
                  offer: RadarOfferView(
                    id: 'd3',
                    category: 'Comfort',
                    payment: 'Card',
                    rating: '4.96',
                    fare: '104,80 kr',
                    pickupMinutes: 3,
                    pickupKm: 0.9,
                    tripMinutes: 14,
                    tripKm: 7.6,
                    pickup: 'Kungsgatan 42, Stockholm',
                    dropoff: 'Hornstull, Stockholm',
                  ),
                  secondsLeft: 13,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = find.text(ExclusiveRequestSheet.pillLabel(13));
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: 'the pill label is ellipsized');
    });

    // UI-09: the ride option tiles keep their description.
    testWidgets('UI-09 ride preferences tiles do not clip at $at',
        (tester) async {
      await _pumpAt(tester, size, const Preferences());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });


    // UI-02: Documents says it is a sample, not a real checklist.
    testWidgets('UI-02 Documents is labelled as a sample at $at',
        (tester) async {
      await _pumpAt(tester, size, const DriverDocuments());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('documents-sample-notice')),
        findsOneWidget,
      );
      await _pumpAt(
        tester,
        size,
        const DocumentPreview(title: 'Driver’s license'),
      );
      expect(find.textContaining('Not available yet'), findsOneWidget);
    });

    // UI-10: one set of sample numbers, formatted the same everywhere.
    testWidgets('UI-10 sample rates agree between Analytics and details '
        'at $at', (tester) async {
      const sample = DriverPerformanceConfig.sample;
      await _pumpAt(tester, size, const Analytics());
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text(sample.acceptanceLabel), 120,
          scrollable: scrollable);
      expect(find.text(sample.cancellationLabel), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sample · ${sample.acceptanceLabel} of offers accepted'),
        120,
        scrollable: scrollable,
      );
      expect(
        find.text('Sample · ${sample.cancellationLabel} of accepted trips'),
        findsOneWidget,
      );

      await _pumpAt(tester, size, const AcceptanceRate());
      await tester.pumpAndSettle();
      expect(find.text(sample.acceptanceLabel, skipOffstage: false),
          findsWidgets);
      expect(find.text('%90'), findsNothing);
      expect(find.text('Sample'), findsOneWidget);

      await _pumpAt(tester, size, const CancelationRate());
      await tester.pumpAndSettle();
      expect(find.text(sample.cancellationLabel, skipOffstage: false),
          findsWidgets);
      expect(find.text('%5.0'), findsNothing);
      expect(find.text('Sample'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
