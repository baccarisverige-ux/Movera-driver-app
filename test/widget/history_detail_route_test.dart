import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/history/trip_path.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/ride history/history detail/history_detail.dart';
import 'package:movera/widgets/custom_google_map.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-10-29 (driver past ride detail): the map stays fixed at the
/// top with the whole route and the pickup and drop-off pins, only the
/// details scroll, back is always shown; no person photo but the ride
/// category's icon, the date and time and the status.
void main() {
  const pickup = GeoPoint(59.1955, 17.6253);
  const dropoff = GeoPoint(59.1960, 17.6268);
  final record = TripHistoryRecord(
    tripId: 'trp_past',
    riderName: 'Stored rider',
    whenLabel: '29/10/2026, 12:50',
    pickup: 'Klockarvägen 37, 151 62 Södertälje, Sweden',
    dropoff: 'Södertälje centrum, 151 32 Södertälje, Sweden',
    fare: '68,64 kr',
    paymentMethod: 'Cash',
    category: 'Premium',
    status: TripStatus.completed,
    completedAt: DateTime(2026, 10, 29, 12, 50),
  );
  final driven = TripPath(
    source: TripPathSource.driven,
    points: const [pickup, GeoPoint(59.1958, 17.626), dropoff],
    pickup: pickup,
    dropoff: dropoff,
  );

  Future<void> show(
    WidgetTester tester,
    Future<TripPath?> Function(TripHistoryRecord) loadPath, {
    String language = 'en',
    TripHistoryRecord? ride,
  }) async {
    DriverAppTexts.language = language;
    addTearDown(() => DriverAppTexts.language = 'en');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DriverRideHistoryDetail(
            record: ride ?? record,
            loadRideChecks: (_) async => const [],
            loadPath: loadPath,
          ),
        ),
      ),
    );
    await tester.pump();
    // The pins are painted off the test clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  CustomGoogleMap map(WidgetTester tester) =>
      tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));

  testWidgets('the map is fixed on the top 40 % and only the details '
      'scroll; back stays visible', (tester) async {
    await show(tester, (_) async => driven);
    final box = tester.getRect(
      find.byKey(const ValueKey('history-detail-map')),
    );
    expect(box.top, 0);
    expect(box.height, closeTo(844 * 0.4, 1));
    final back = find.byKey(const ValueKey('history-detail-back'));
    expect(back, findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('history-detail-scroll')),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('history-detail-map'))),
      box,
    );
    expect(tester.getRect(back).top, lessThan(box.bottom));
    expect(find.byTooltip(tr.back), findsOneWidget);
    expect(map(tester).scrollGesturesEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the driven route is drawn with Movera pickup and drop-off '
      'pins', (tester) async {
    await show(tester, (_) async => driven);
    final shown = map(tester);
    expect(shown.polylines, isNotEmpty);
    final drawn = shown.polylines!.expand((l) => l.points).toSet();
    expect(drawn, containsAll(const [LatLng(59.1955, 17.6253)]));
    expect(
      shown.markers!.map((m) => m.markerId.value),
      containsAll(['history-pickup', 'history-dropoff']),
    );
    expect(
      shown.markers!
          .firstWhere((m) => m.markerId.value == 'history-pickup')
          .position,
      const LatLng(59.1955, 17.6253),
    );
    expect(find.text('Route driven'), findsOneWidget);
  });

  testWidgets('an older ride shows the planned route; no route says so', (
    tester,
  ) async {
    await show(
      tester,
      (_) async => TripPath(
        source: TripPathSource.planned,
        points: const [pickup, dropoff],
        pickup: pickup,
        dropoff: dropoff,
      ),
    );
    expect(find.text('Planned route'), findsOneWidget);
    await show(tester, (_) async => null);
    expect(find.text('Route not available'), findsOneWidget);
    expect(map(tester).polylines, isEmpty);
    expect(map(tester).markers, isEmpty);
    await show(tester, (_) async => TripPath.pinsOnly(pickup, dropoff));
    expect(find.text('Route not available'), findsOneWidget);
    expect(map(tester).polylines, isEmpty);
    expect(map(tester).markers, hasLength(2));
  });

  testWidgets('no person photo: the category icon, date and time, and '
      'Completed', (tester) async {
    await show(tester, (_) async => driven);
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.where(
        (i) =>
            i.image is AssetImage &&
            (i.image as AssetImage).assetName == AppAssets.profileImg,
      ),
      isEmpty,
    );
    expect(
      tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.image != null),
      isEmpty,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('history-category-icon')),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    expect(find.text('29/10/2026, 12:50'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('history-status')),
        matching: find.text('Completed'),
      ),
      findsOneWidget,
    );
    expect(find.text('Stored rider'), findsNothing);
    expect(
      find.text('Illustrative map · archived route unavailable'),
      findsNothing,
    );
  });

  for (final (code, drivenText, plannedText, none) in [
    ('sv', 'Körd rutt', 'Planerad rutt', 'Rutten är inte tillgänglig'),
    (
      'fr',
      'Itinéraire parcouru',
      'Itinéraire prévu',
      'Itinéraire indisponible',
    ),
  ]) {
    testWidgets('the route words in $code', (tester) async {
      await show(tester, (_) async => driven, language: code);
      expect(find.text(drivenText), findsOneWidget);
      await show(
        tester,
        (_) async => TripPath(
          source: TripPathSource.planned,
          points: const [pickup, dropoff],
          pickup: pickup,
          dropoff: dropoff,
        ),
        language: code,
      );
      expect(find.text(plannedText), findsOneWidget);
      await show(tester, (_) async => null, language: code);
      expect(find.text(none), findsOneWidget);
    });
  }

  test('the category icons are Movera\'s ride icons', () {
    expect(rideCategoryIcon('Premium'), AppAssets.ridePremium);
    expect(rideCategoryIcon('Comfort'), AppAssets.rideComfort);
    expect(rideCategoryIcon('Movera'), AppAssets.rideMovera);
    expect(rideCategoryIcon('economy'), AppAssets.rideMovera);
    expect(rideCategoryIcon('Movera XL'), AppAssets.rideXl);
    expect(rideCategoryIcon('Priority'), AppAssets.ridePriority);
    expect(rideCategoryIcon('Electric'), AppAssets.rideElectric);
    expect(rideCategoryIcon('Movera Pet'), AppAssets.ridePet);
    expect(rideCategoryIcon('Booster Seat'), AppAssets.rideBooster);
    expect(rideCategoryIcon('Taxi Deluxe'), AppAssets.solarCar);
  });

  test('without the server, the pins this phone saved; else none', () async {
    final withPoints = TripHistoryRecord(
      tripId: 'trp_saved',
      riderName: 'r',
      whenLabel: 'w',
      pickup: 'a',
      dropoff: 'b',
      fare: '1 kr',
      category: 'Comfort',
      pickupPoint: pickup,
      dropoffPoint: dropoff,
    );
    final pins = await loadPastRidePath(withPoints);
    expect(pins!.source, TripPathSource.pins);
    expect(pins.pickup, pickup);
    expect(await loadPastRidePath(record), isNull);
  });
}
