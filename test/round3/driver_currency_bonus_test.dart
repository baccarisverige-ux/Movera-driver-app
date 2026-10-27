import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

WaybillRecord _record({String fare = '128,60 kr', String? bonus = '30 kr'}) =>
    WaybillRecord(
      tripId: 'bonus-trip',
      statusLabel: 'Current trip',
      issuedAt: DateTime(2026, 10, 20, 12),
      fare: fare,
      service: 'Movera',
      riderName: 'Karim',
      pickup: 'Tegnérgatan 8, Stockholm',
      dropoff: 'Hammarby sjöstad, Stockholm',
      source: 'Assigned by Movera',
      driverName: 'Movera Driver',
      vehicle: 'Car',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
      driverBonus: bonus,
    );

void main() {
  group('Money labels in every currency', () {
    test('SEK reads exactly like before', () {
      for (final label in ['104,80 kr', '126.75 kr', '2 994,80 kr', '40 kr']) {
        expect(
          Money.parseLabel(label),
          Money.parseSekLabel(label),
          reason: label,
        );
      }
    });

    test('EUR and TND use their symbol and exponent', () {
      expect(
        Money.parseLabel('24,50 €'),
        const Money(minorUnits: 2450, currency: 'EUR'),
      );
      expect(
        Money.parseLabel('12,500 DT'),
        const Money(minorUnits: 12500, currency: 'TND'),
      );
      expect(
        Money.parseLabel('1 012,5 DT'),
        const Money(minorUnits: 1012500, currency: 'TND'),
      );
      expect(
        Money.parseLabel('+3 €'),
        const Money(minorUnits: 300, currency: 'EUR'),
      );
      // Its symbol says another currency.
      expect(Money.parseLabel('24,50 €', currency: 'SEK'), isNull);
      expect(Money.parseLabel('—'), isNull);
    });
  });

  group('Waiting fee in all currencies (Q42/Q43)', () {
    WaitingTerms terms(Money perMinute) => WaitingTerms(
      freeMinutes: 5,
      perMinute: perMinute,
      noShowAfterMinutes: 5,
      noShowFee: Money(minorUnits: 0, currency: perMinute.currency),
    );

    test('SEK', () {
      final fee = terms(const Money(minorUnits: 1226)).driverWaitingFee(90);
      expect(WaitingTerms.addFee('100,00 kr', fee), '118,39 kr');
    });

    test('EUR: 90 s at 0,50 € / min', () {
      final fee = terms(
        const Money(minorUnits: 50, currency: 'EUR'),
      ).driverWaitingFee(90);
      expect(fee, const Money(minorUnits: 75, currency: 'EUR'));
      expect(WaitingTerms.addFee('24,00 €', fee), '24,75 €');
    });

    test('TND: 90 s at 0,300 DT / min, three decimals', () {
      final fee = terms(
        const Money(minorUnits: 300, currency: 'TND'),
      ).driverWaitingFee(90);
      expect(fee, const Money(minorUnits: 450, currency: 'TND'));
      expect(WaitingTerms.addFee('12,500 DT', fee), '12,950 DT');
    });

    test('a fare in another currency than the fee is left alone', () {
      final fee = terms(
        const Money(minorUnits: 50, currency: 'EUR'),
      ).driverWaitingFee(90);
      expect(WaitingTerms.addFee('100,00 kr', fee), '100,00 kr');
    });

    test('cash balance reads EUR labels', () {
      final balance = CashBalance.fromLabels(
        fare: '24,75 €',
        cashCollected: '30 €',
      );
      expect(balance?.balance, const Money(minorUnits: -525, currency: 'EUR'));
    });
  });

  group('Movera bonus in the earnings (Q16/Q18)', () {
    test('the rider pays the fare without it and no fee is taken on it', () {
      final payment = WaybillPayment.fromFare('128,60 kr', bonus: '30 kr')!;
      // 98,60 kr from the rider; 25% of that is Movera's.
      expect(payment.fare, '98,60 kr');
      expect(payment.serviceFee, '24,65 kr');
      expect(payment.bonus, '30,00 kr');
      expect(payment.earnings, '103,95 kr');
      // Without a bonus, as before.
      expect(WaybillPayment.fromFare('128,60 kr')!.bonus, isNull);
    });

    test('labels', () {
      expect(WaybillRecord.bonusLabel(const Money(minorUnits: 3000)), '30 kr');
      expect(WaybillRecord.bonusLabel(const Money(minorUnits: 0)), isNull);
      expect(WaybillRecord.bonusLabel(null), isNull);
      expect(_record().copyWith(fare: '130,00 kr').driverBonus, '30 kr');
    });

    test('the saved trip keeps it across a restore', () {
      final saved = PersistedActiveRide(
        tripId: 'bonus-trip',
        stage: ActiveRideStage.onTrip,
        fare: '128,60 kr',
        driverBonus: const Money(minorUnits: 3000),
      );
      final back = PersistedActiveRide.fromJson(saved.toJson());
      expect(back?.driverBonus, const Money(minorUnits: 3000));
    });

    test('the earnings history keeps it after completion', () async {
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
      await CompletionJournal(
        active: MemoryActiveRideRepository(),
      ).finish(_record());
      final rows = await PrefsTripHistoryRepository().list();
      expect(rows.single.driverBonus, '30 kr');
      expect(rows.single.fare, '128,60 kr');
    });
  });
}
