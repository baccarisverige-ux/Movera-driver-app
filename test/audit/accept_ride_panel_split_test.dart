import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AcceptRide panel and contact presentation sit outside the widget file',
    () {
      final ride = File(
        'lib/presentation/driver/accept ride/accept_ride.dart',
      ).readAsStringSync();
      final panel = File(
        'lib/presentation/driver/accept ride/accept_ride_panel.dart',
      ).readAsStringSync();

      expect(ride, contains("part 'accept_ride_panel.dart';"));
      expect(ride, contains('class AcceptRide'));
      expect(ride, contains('Widget build(BuildContext context)'));
      expect(ride, isNot(contains('Widget _buildRidePanel')));
      expect(ride, isNot(contains('Widget _buildRiderRow')));
      expect(panel, contains("part of 'accept_ride.dart';"));
      expect(panel, contains('extension _AcceptRidePanel on _AcceptRideState'));
      expect(panel, contains('Widget _buildRidePanel'));
      expect(panel, contains('Widget _buildRiderRow'));
      expect(
        panel,
        // LT-4 (owner 2026-11-03): Chat now opens through its loader.
        contains(
          'chatScreen(riderDisplayName: _riderName, tripId: widget.tripId)',
        ),
      );
      expect(panel, isNot(contains('setState(')));
      // Phase 2: was < 1800 before `dart format` (tall style); same code
      // measured 1798 → 2146 lines, so the limit scales by the same factor.
      // Base job B8: +3 `part` lines for the trip part files (2149 → 2152).
      expect(ride.split('\n').length, lessThan(2153));
    },
  );

  // Rule 25 (owner 2026-11-07, "split first"): accept_ride_panel.dart was
  // 1496 lines. The offer card and the trip options / cancel sheets were
  // moved word for word into their own part files (no behaviour change).
  test('AcceptRide panel split: offer card and trip options parts', () {
    String read(String f) =>
        File('lib/presentation/driver/accept ride/$f').readAsStringSync();
    final ride = read('accept_ride.dart');
    final panel = read('accept_ride_panel.dart');
    final card = read('accept_ride_offer_card.dart');
    final options = read('accept_ride_trip_options.dart');

    expect(ride, contains("part 'accept_ride_offer_card.dart';"));
    expect(ride, contains("part 'accept_ride_trip_options.dart';"));
    expect(card, contains("part of 'accept_ride.dart';"));
    expect(
      card,
      contains('extension _AcceptRideOfferCard on _AcceptRideState'),
    );
    expect(card, contains('Widget _buildIncomingRideCard()'));
    expect(card, contains('Widget _offerLocationRow('));
    expect(options, contains("part of 'accept_ride.dart';"));
    expect(
      options,
      contains('extension _AcceptRideTripOptions on _AcceptRideState'),
    );
    expect(options, contains('Future<void> _showRiderProfile()'));
    expect(options, contains('Future<void> _showTripOptions()'));
    expect(options, contains('Future<void> _showCancellationReasons('));
    for (final moved in [
      'Widget _buildIncomingRideCard()',
      'Widget _offerLocationRow(',
      'Future<void> _showRiderProfile()',
      'Future<void> _showTripOptions()',
      'Future<void> _showCancellationReasons(',
    ]) {
      expect(panel, isNot(contains(moved)), reason: moved);
    }
    for (final part in [card, options]) {
      expect(part, isNot(contains('setState(')));
    }
    expect(panel.split('\n').length, lessThan(1000));
    expect(card.split('\n').length, lessThan(1000));
    expect(options.split('\n').length, lessThan(1000));
  });

  // Rule 25 (owner): no hand-written Dart source file in lib/ may reach
  // 1500 lines. Generated l10n outputs are exempt.
  test('Rule 25: every hand-written lib/ Dart file is under 1500 lines', () {
    final tooBig = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final name = f.path.replaceAll('\\', '/');
      if (name.contains('lib/l10n/app_localizations') ||
          name.endsWith('.g.dart') ||
          name.endsWith('.freezed.dart')) {
        continue;
      }
      final lines = f.readAsStringSync().split('\n').length;
      if (lines >= 1500) tooBig.add('$name ($lines)');
    }
    expect(tooBig, isEmpty);
  });
}
