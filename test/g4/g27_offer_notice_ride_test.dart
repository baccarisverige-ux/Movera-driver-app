import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// G27 fix round 2 (supervisor NO-GO on 92a2c99a): under the owner's
// "Keep both" rule a notice replaces a waiting or showing one only when it
// is about the same ride. "Matching…" is tagged with the offer's id, so
// the "Trip unavailable" that follows must be tagged with it too, or the
// stale "Matching…" stays its full 2 s.

RideOffer _trip(String id) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 8810, currency: 'SEK'),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 3,
  pickupKm: 0.9,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3428, 18.0475),
  isNearby: true,
  followsDestination: true,
);

class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final claim = Completer<ClaimResult>();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    final sub = _nearby.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
    sink.addSync(offers);
  }, isBroadcast: true);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) => claim.future;

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

/// Every `HomeIslandNotices.<name>` whose group is about one offer,
/// reservation or booked ride, read from the notices file itself.
Set<String> _rideNotices() {
  final source = File(
    'lib/presentation/driver/home/components/home_island_notices.dart',
  ).readAsStringSync();
  final decl = RegExp(
    r'static IslandMessage (?:get )?(\w+)\b([\s\S]*?)(?=\n  static |\n}\s*$)',
  );
  const groups = {'radar-match', 'exclusive', 'reservation', 'scheduled'};
  return {
    for (final m in decl.allMatches(source))
      if (groups.any((g) => m.group(2)!.contains("group: '$g'"))) m.group(1)!,
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    RideCheckGate.set(false);
  });

  testWidgets('Match pressed, the offer is gone: "Trip unavailable" replaces '
      '"Matching…" at once', (tester) async {
    // The demo reservation's own Exclusive offer stays out of it.
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
    final dispatch = _Dispatch()..offers = [_trip('gone-1')];
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: dispatch,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await _until(
      tester,
      find.byKey(const ValueKey<String>('radar-offer-card-gone-1')),
    );
    // Let the island's own messages ("Radar online"…) pass first.
    await _frames(tester, const Duration(seconds: 6));
    IslandMessages.reset();

    tester
        .widget<RadarOfferCard>(
          find.ancestor(
            of: find.byKey(const ValueKey<String>('radar-offer-card-gone-1')),
            matching: find.byType(RadarOfferCard),
          ),
        )
        .onMatch!
        .call();
    await _frames(tester, const Duration(milliseconds: 400));
    // On the card and on the island.
    expect(find.text('Matching…'), findsNWidgets(2));

    // Dispatch answers: the trip is no longer there.
    dispatch.claim.complete(const ClaimResult.unavailable());
    // Well within "Matching…"'s own 2 s.
    await _frames(tester, const Duration(milliseconds: 400));

    expect(find.text('Trip unavailable'), findsOneWidget);
    expect(find.text('Matching…'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, const Duration(seconds: 4));
  });

  // Guard (supervisor nit on 92a2c99a): every offer, reservation and
  // scheduled notice posted from Home's offer files says which ride it is
  // about, so "Keep both" never keeps a stale one beside its follow-up.
  test('offer, reservation and scheduled notices on Home carry forRide', () {
    final names = _rideNotices();
    expect(
      names,
      containsAll(<String>['matching', 'tripUnavailable', 'exclusiveRide']),
    );
    final use = RegExp(r'HomeIslandNotices\.(\w+)');
    final missing = <String>[];
    final files = Directory(
      'lib/presentation/driver/home',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final m in use.allMatches(source)) {
        if (!names.contains(m.group(1))) continue;
        // The statement the notice is used in must tag it.
        final end = source.indexOf(';', m.end);
        if (!source.substring(m.end, end).contains('.forRide(')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          missing.add('${file.path}:$line ${m.group(1)}');
        }
      }
    }
    expect(missing, isEmpty, reason: 'post these with .forRide(id)');
  });
}
