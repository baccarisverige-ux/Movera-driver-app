import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';

const _comfort = PickupPayRate(krPerKm: 3, krPerMinute: 1);

PickupPayConfig _config({
  PickupPayRate rate = _comfort,
  Set<PickupPayOfferKind> kinds = PickupPayConfig.defaultKinds,
  PickupPayDisplay display = PickupPayDisplay.totalOnly,
}) => PickupPayConfig(
  categories: <String, PickupPayRate>{'Comfort': rate, 'Movera XL': rate},
  kinds: kinds,
  display: display,
);

String _pay(
  PickupPayConfig config, {
  double km = 4.2,
  int minutes = 9,
  String category = 'Comfort',
  PickupPayOfferKind kind = PickupPayOfferKind.exclusive,
}) => PickupPayCalculator.pay(
  category: category,
  kind: kind,
  leg: PickupLeg(km: km, minutes: minutes),
  config: config,
).formatted;

void main() {
  group('pickup pay calculator', () {
    test('Comfort 3 kr/km + 1 kr/min, 4.2 km / 9 min is 21,60 kr', () {
      expect(_pay(_config()), '21,60 kr');
    });

    test('free km and free minutes come off when they are on', () {
      final rate = _comfort.copyWith(
        freeKm: 1,
        freeKmOn: true,
        freeMinutes: 2,
        freeMinutesOn: true,
      );
      // (4.2 − 1) × 3 + (9 − 2) × 1 = 16,60 kr.
      expect(_pay(_config(rate: rate)), '16,60 kr');
      // Only free km on: 3.2 × 3 + 9 × 1.
      expect(
        _pay(_config(rate: rate.copyWith(freeMinutesOn: false))),
        '18,60 kr',
      );
      // Only free minutes on: 4.2 × 3 + 7 × 1.
      expect(_pay(_config(rate: rate.copyWith(freeKmOn: false))), '19,60 kr');
    });

    test('free values switched off are ignored', () {
      final rate = _comfort.copyWith(freeKm: 5, freeMinutes: 20);
      expect(_pay(_config(rate: rate)), '21,60 kr');
    });

    test('a pickup inside the free km and minutes pays nothing', () {
      final rate = _comfort.copyWith(
        freeKm: 1,
        freeKmOn: true,
        freeMinutes: 2,
        freeMinutesOn: true,
      );
      expect(_pay(_config(rate: rate), km: 0.6, minutes: 2), '0,00 kr');
      // Never negative: only the minutes over the free ones count.
      expect(_pay(_config(rate: rate), km: 0.9, minutes: 3), '1,00 kr');
    });

    test('rounds to öre', () {
      expect(_pay(_config(), km: 1.234, minutes: 0), '3,70 kr');
      final rate = _comfort.copyWith(krPerKm: 2.5, krPerMinute: 0.8);
      expect(_pay(_config(rate: rate), km: 2.1, minutes: 7), '10,85 kr');
    });

    test('no pickup pay when the offer kind is off', () {
      final kinds = {...PickupPayConfig.defaultKinds}
        ..remove(PickupPayOfferKind.radar);
      expect(
        _pay(_config(kinds: kinds), kind: PickupPayOfferKind.radar),
        '0,00 kr',
      );
      expect(
        _pay(_config(kinds: kinds), kind: PickupPayOfferKind.exclusive),
        '21,60 kr',
      );
    });

    test('no pickup pay when the category is off or unknown', () {
      expect(
        _pay(_config(rate: _comfort.copyWith(enabled: false))),
        '0,00 kr',
      );
      expect(_pay(_config(), category: 'Premium'), '0,00 kr');
      // "XL" is the short name of "Movera XL".
      expect(_pay(_config(), category: 'XL'), '21,60 kr');
    });

    test('a reservation taken from the Scheduled rides list never pays', () {
      final everything = _config(kinds: PickupPayOfferKind.values.toSet());
      expect(
        _pay(everything, kind: PickupPayOfferKind.scheduledListReservation),
        '0,00 kr',
      );
      expect(
        PickupPayOfferKind.forHomeOffer(
          onRadar: false,
          reservation: true,
          driverSigned: true,
        ),
        PickupPayOfferKind.scheduledListReservation,
      );
    });

    test('every switchable kind pays by default', () {
      for (final kind in PickupPayConfig.defaultKinds) {
        expect(_pay(_config(), kind: kind), '21,60 kr', reason: '$kind');
      }
    });

    test('Home offers map to their kind', () {
      expect(
        PickupPayOfferKind.forHomeOffer(onRadar: true, reservation: false),
        PickupPayOfferKind.radar,
      );
      expect(
        PickupPayOfferKind.forHomeOffer(onRadar: false, reservation: false),
        PickupPayOfferKind.exclusive,
      );
      // A reservation near pickup, as Exclusive or on Radar.
      for (final onRadar in [true, false]) {
        expect(
          PickupPayOfferKind.forHomeOffer(onRadar: onRadar, reservation: true),
          PickupPayOfferKind.exclusiveReservation,
        );
      }
      expect(
        PickupPayOfferKind.forHomeOffer(
          onRadar: false,
          reservation: true,
          assigned: true,
        ),
        PickupPayOfferKind.assignedByMovera,
      );
    });
  });

  group('pickup pay quote', () {
    final config = _config(
      rate: _comfort.copyWith(
        freeKm: 1,
        freeKmOn: true,
        freeMinutes: 2,
        freeMinutesOn: true,
      ),
    );
    PickupPayQuote quote(double km, int minutes, {PickupPayConfig? rules}) =>
        PickupPayCalculator.quote(
          category: 'Comfort',
          kind: PickupPayOfferKind.exclusive,
          leg: PickupLeg(km: km, minutes: minutes),
          config: rules ?? config,
        );

    test('the same offer shown again after the driver moved is recalculated',
        () {
      const fare = '126,75 kr';
      final first = quote(4.2, 9);
      expect(first.pay.formatted, '16,60 kr');
      expect(first.totalOf(fare), '143,35 kr');
      // Closer now: 2.0 km / 5 min → 1 × 3 + 3 × 1.
      final later = quote(2.0, 5);
      expect(later.pay.formatted, '6,00 kr');
      expect(later.totalOf(fare), '132,75 kr');
    });

    test('total only by default; the pickup line when admin shows it', () {
      expect(quote(4.2, 9).line, isNull);
      final withLine = quote(
        4.2,
        9,
        rules: config.copyWith(display: PickupPayDisplay.fareWithPickupLine),
      );
      expect(withLine.line, 'incl. 16,60 kr pickup · 4.2 km · 9 min');
    });

    test('no pay leaves the fare and shows no line', () {
      final none = quote(
        0.5,
        1,
        rules: config.copyWith(display: PickupPayDisplay.fareWithPickupLine),
      );
      expect(none.hasPay, isFalse);
      expect(none.totalOf('104,80 kr'), '104,80 kr');
      expect(none.line, isNull);
      expect(quote(4.2, 9).totalOf('—'), '—');
    });

    test('Swedish format with a thousands space', () {
      expect(quote(4.2, 9).totalOf('1 230,00 kr'), '1 246,60 kr');
    });
  });

  group('pickup pay distance ranges', () {
    const ranged = PickupPayRate(
      krPerKm: 3,
      krPerMinute: 1,
      ranges: <PickupPayRange>[
        PickupPayRange(fromKm: 0, toKm: 10, krPerKm: 2, krPerMinute: 1),
        PickupPayRange(fromKm: 10, toKm: 20, krPerKm: 4, krPerMinute: 2),
        PickupPayRange(fromKm: 20, toKm: 40, krPerKm: 5, krPerMinute: 3),
      ],
    );

    test('exactly 10 km is in 0–10', () {
      expect(ranged.rangeFor(10)!.toKm, 10);
      // 10 × 2 + 9 × 1, whole leg at the first range.
      expect(_pay(_config(rate: ranged), km: 10), '29,00 kr');
    });

    test('10.1 km is in >10–20, whole leg at that rate', () {
      expect(ranged.rangeFor(10.1)!.fromKm, 10);
      // 10.1 × 4 + 9 × 2.
      expect(_pay(_config(rate: ranged), km: 10.1), '58,40 kr');
    });

    test('beyond the last closed range uses the last range', () {
      expect(ranged.rangeFor(55)!.toKm, 40);
      // 55 × 5 + 9 × 3.
      expect(_pay(_config(rate: ranged), km: 55), '302,00 kr');
    });

    test('an open-ended last range takes any distance', () {
      final rate = ranged.copyWith(
        ranges: const <PickupPayRange>[
          PickupPayRange(fromKm: 0, toKm: 10, krPerKm: 2, krPerMinute: 1),
          PickupPayRange(fromKm: 10, krPerKm: 4, krPerMinute: 2),
        ],
      );
      expect(rate.rangeFor(500)!.openEnded, isTrue);
    });

    test('no ranges pays the single rate as before', () {
      expect(_comfort.rangeFor(10), isNull);
      expect(_pay(_config(), km: 10.1), '39,30 kr');
    });

    test('free km come off the paid km, range by whole leg', () {
      final rate = ranged.copyWith(freeKm: 1, freeKmOn: true);
      // 10.1 km is in >10–20: (10.1 − 1) × 4 + 9 × 2.
      expect(_pay(_config(rate: rate), km: 10.1), '54,40 kr');
    });

    test('a switched-off category with ranges pays nothing', () {
      final rate = ranged.copyWith(enabled: false);
      expect(_pay(_config(rate: rate), km: 15), '0,00 kr');
    });

    test('range JSON round-trips', () {
      const range = PickupPayRange(fromKm: 20, krPerKm: 5, krPerMinute: 3);
      final json = range.toJson();
      expect(json.keys, <String>['fromKm', 'toKm', 'krPerKm', 'krPerMinute']);
      final back = PickupPayRange.fromJson(json);
      expect(back.fromKm, 20);
      expect(back.toKm, isNull);
      expect(back.krPerKm, 5);
      expect(back.krPerMinute, 3);
    });
  });
}
