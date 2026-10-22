import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc_phone.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign%20in%20phone/sign_in_phone.dart';
import 'package:movera/presentation/driver/auth/sign%20in/sign_in.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_confirm.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/my%20queue%20position/my_queue_pos.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

import 'd51_translations_test.dart' as d51 show show;
import 'd51_translations_test.dart' show languages, speak, words;

/// [d51.show], after clearing the screen: a const screen pumped again in
/// another language is built anew, as the app root does on a switch.
Future<void> show(WidgetTester tester, String code, Widget home) async {
  await tester.pumpWidget(const SizedBox());
  await d51.show(tester, code, home);
}

/// The country flag the phone field starts with, by ISO code.
Finder flag(String iso) => find.byWidgetPredicate((widget) =>
    widget is Image &&
    widget.image is AssetImage &&
    (widget.image as AssetImage).assetName.endsWith('/$iso.png'));

/// A ride Movera assigned for [day] 07:40, with no date of its own.
ReservationRequestPreview assignedRide(String day) => ReservationRequestPreview(
  id: 'assigned-0740',
  category: 'Comfort',
  fare: '126,75 kr',
  pickupLabel: 'Pickup today at 07:40',
  pickupAddress: 'Odlarvägen 22',
  dropoffAddress: 'T-Centralen',
  pickupTime: '07:40',
  pickupDay: day,
  tripMinutes: 18,
  tripKm: 9.4,
  pickup: const GeoPoint(59.3134, 18.0727),
  dropoff: const GeoPoint(59.3300, 18.0581),
);

/// Scheduled rides in [code], on its Accepted tab.
Future<void> showAccepted(WidgetTester tester, String code) async {
  await show(tester, code, const ScheduledRidesScreen());
  await tester.tap(find.text(tr.schedAcceptedTab).first);
  await tester.pump(const Duration(milliseconds: 600));
}

/// A finished trip in History, paid by [payment] as the journal keeps it.
TripHistoryRecord historyTrip(
  String payment, {
  TripStatus status = TripStatus.completed,
}) => TripHistoryRecord(
  tripId: 'trip-1',
  riderName: 'Lars',
  whenLabel: '21 Oct',
  pickup: 'Odlarvägen 22',
  dropoff: 'T-Centralen',
  fare: '126,00 kr',
  category: 'Comfort',
  paymentMethod: payment,
  status: status,
  completedAt: DateTime.now(),
);

/// Wave 5 D5.1 (parts c, d and e): texts that stayed in English, or in
/// the language they were made in, now follow the driver's language.
void main() {
  testWidgets('driver-57: the English code prompt is grammatical',
      (tester) async {
    await show(tester, 'en', const DriverPhoneVerification());
    expect(words('Didn’t get the code?'), findsOneWidget);
    expect(words('Did you don’t'), findsNothing);
  });

  testWidgets('driver-u105: phone screens start on Sweden, +46', (tester) async {
    final screens = <Widget>[
      const DriverSignInPhone(),
      const DriverCreateAccountPhone(),
    ];
    for (final screen in screens) {
      await show(tester, 'sv', screen);
      expect(flag('se'), findsOneWidget, reason: '${screen.runtimeType}');
      expect(flag('us'), findsNothing);
    }
  });

  testWidgets('driver-58: the sign-in divider word is translated',
      (tester) async {
    for (final (code, or) in [('fr', 'ou'), ('sv', 'eller')]) {
      await show(tester, code, const DriverSignIn());
      expect(find.text(or), findsOneWidget, reason: code);
      expect(find.text('or'), findsNothing);
    }
  });

  test('driver-u107: the destination summary uses the decimal comma', () {
    for (final code in languages) {
      speak(code);
      expect(destinationDistanceTimeLabel(38100, 2040), '38,1 km · 34 min');
    }
    speak('en');
    expect(destinationDistanceTimeLabel(38100, 2040), '38.1 km · 34 min');
  });

  testWidgets('driver-60: the destination search count is translated',
      (tester) async {
    for (final (code, query, count) in [
      ('fr', 'airport', '2 trouvés'),
      ('sv', 'kista', '1 träff'),
    ]) {
      await show(tester, code, const DriverDestinationPicker());
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      expect(find.text(count), findsOneWidget, reason: code);
      expect(words('found'), findsNothing);
    }
  });

  test('driver-62: a cancel fee keeps its own currency', () {
    speak('fr');
    String fee(int minor, String currency) => HomeIslandNotices.feeSuffix(
        Money(minorUnits: minor, currency: currency));
    expect(fee(500, 'EUR'), ' · +5 €');
    expect(fee(5000, 'TND'), ' · +5 DT');
    expect(fee(4500, 'SEK'), ' · +45 kr');
    expect(fee(4550, 'SEK'), ' · +45,50 kr');
  });

  testWidgets('driver-u139: a new scheduled ride notice says the day in '
      'the driver\'s language', (tester) async {
    final feed = DriverNotificationFeed.instance
      ..reset()
      ..arrivals = const [];
    // As Home adds it: the reservation's stored English day.
    feed.add(DriverNotices.newScheduledRide(
      at: feed.now, day: 'Today', time: '09:30', fare: '126,75 kr',
    ));
    for (final (code, today) in [('sv', 'Idag'), ('fr', 'Aujourd’hui')]) {
      await show(tester, code, const DriverNotificationsScreen());
      expect(words('$today 09:30'), findsOneWidget, reason: code);
      expect(words('Today 09:30'), findsNothing);
    }
  });

  testWidgets('driver-96: scheduled ride cards say Today in the driver\'s '
      'language', (tester) async {
    addTearDown(ScheduledRideStore.reset);
    for (final (code, today) in [('sv', 'Idag 07:40'), ('fr', 'Aujourd’hui, 07:40')]) {
      speak(code);
      ScheduledRideStore.reset();
      // As Home hands it over: the stored English day.
      ScheduledRideStore.acceptAssigned(assignedRide('Today'));
      await showAccepted(tester, code);
      expect(find.text(today), findsOneWidget, reason: code);
      expect(words('Today'), findsNothing);
    }
  });

  testWidgets('driver-u145: scheduled notes and cards made in English read '
      'in Swedish', (tester) async {
    addTearDown(ScheduledRideStore.reset);
    speak('en');
    ScheduledRideStore.reset();
    final kept = assignedRide('Today');
    final given = ReservationRequestPreview(
      category: 'Comfort', fare: '99,00 kr', pickupLabel: '',
      pickupAddress: 'Solna', dropoffAddress: 'Kista', pickupTime: '09:10',
      pickupDay: 'Today', tripMinutes: 12, tripKm: 6.2,
      pickup: const GeoPoint(59.36, 18.0), dropoff: const GeoPoint(59.40, 17.94),
    );
    ScheduledRideStore.acceptAssigned(kept);
    ScheduledRideStore.acceptAssigned(given);
    ScheduledRideStore.giveToBackup(given);
    // As Home's 1 h reminder sets it.
    ScheduledRideStore.reminder.say(
        () => tr.pickupAtPickupTimeInLeft('07:40', '1 h', 'Odlarvägen 22'));
    final english = [
      tr.pickupAtPickupTimeInLeft('07:40', '1 h', 'Odlarvägen 22'),
      tr.schedBackupNote('09:10'),
      'Today, 07:40',
      '9.4 km',
    ];
    await showAccepted(tester, 'sv');
    expect(words(tr.pickupAtPickupTimeInLeft('07:40', '1 h', 'Odlarvägen 22')),
        findsOneWidget);
    expect(words(tr.schedBackupNote('09:10')), findsOneWidget);
    expect(find.text('Idag 07:40'), findsOneWidget);
    expect(find.text('9,4 km'), findsWidgets);
    for (final text in english) {
      expect(words(text), findsNothing, reason: text);
    }
  });

  testWidgets('driver-u146: the queue preview is translated and matches '
      'the 10-ahead card', (tester) async {
    for (final (code, wait) in [
      ('fr', 'Environ 15 à 30 min d’attente'),
      ('sv', 'Cirka 15–30 min väntetid'),
    ]) {
      await show(tester, code, const Scaffold(body: MyQueuePosition()));
      expect(find.text(wait), findsOneWidget, reason: code);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      for (final english in ['15-30 mins EST time', 'Van']) {
        expect(words(english), findsNothing, reason: english);
      }
    }
  });

  test('driver-80: the saved-categories message is pluralized', () {
    final said = {
      'en': ('1 ride category saved', '6 ride categories saved'),
      'fr': ('1 catégorie de course enregistrée',
          '6 catégories de course enregistrées'),
      'sv': ('1 resekategori sparad', '6 resekategorier sparade'),
    };
    for (final MapEntry(key: code, value: (one, six)) in said.entries) {
      speak(code);
      expect(tr.prefCategoriesSaved(1), one);
      expect(tr.prefCategoriesSaved(6), six);
    }
  });

  testWidgets('driver-u155: the payment method is in the driver\'s '
      'language, card trips included', (tester) async {
    for (final (code, cash, card) in [
      ('sv', 'Kontant', 'Kort'),
      ('fr', 'Espèces', 'Carte'),
    ]) {
      for (final (stored, shown) in [('Cash', cash), ('Card', card)]) {
        await show(tester, code, DriverRideHistoryDetail(
          record: historyTrip(stored),
          loadRideChecks: (_) async => const [],
        ));
        expect(find.text(shown), findsOneWidget, reason: '$code $stored');
        expect(find.text(stored), findsNothing);
      }
      await show(tester, code, const DriverRideCompleted(paymentMethod: 'Card'));
      expect(find.text(card), findsOneWidget, reason: '$code completed');
    }
  });

  testWidgets('driver-86: All rides names each outcome in the driver\'s '
      'language', (tester) async {
    for (final code in languages) {
      speak(code);
      final outcomes = {
        TripStatus.cancelledByRider: tr.cancelledByRider,
        TripStatus.searching: tr.cancelledByDriver,
        TripStatus.noShow: tr.riderDidNotArrive,
      };
      await show(tester, code, DriverRideHistory(loadHistory: () async => [
        for (final status in outcomes.keys)
          historyTrip('Cash', status: status),
      ]));
      await tester.pump();
      await tester.tap(find.text(tr.allRides).last);
      await tester.pump(const Duration(milliseconds: 400));
      for (final said in outcomes.values) {
        expect(words(said), findsWidgets, reason: '$code $said');
      }
      for (final wire in ['cancelled_by_rider', 'cancelled_by_driver', 'no_show']) {
        expect(words(wire), findsNothing, reason: wire);
      }
    }
  });

  testWidgets('driver-90: the Radar list count says OFFERS in the driver\'s '
      'language', (tester) async {
    for (final (code, offers) in [('fr', 'OFFRES'), ('sv', 'ERBJUDANDEN')]) {
      await show(tester, code, const RideRequests());
      await tester.pump(const Duration(milliseconds: 120));
      final count = find.byKey(const ValueKey<String>('radar-live-count'));
      expect(find.descendant(of: count, matching: find.text(offers)),
          findsOneWidget, reason: code);
      expect(find.text('OFFERS'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
