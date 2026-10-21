import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

void main() {
  group('driver-32: a fare of 1 000 kr or more', () {
    test('the waybill reads every digit group of a grouped fare', () {
      final label = Money.ore(123450).formatted;
      expect(label, '1 234,50 kr');
      final payment = WaybillPayment.fromFare(label)!;
      expect(payment.fare, '1 234,50 kr');
      expect(payment.serviceFee, '308,63 kr');
      expect(payment.earnings, '925,87 kr');
    });

    test('the net-fare offer card shows the driver share of the whole fare',
        () {
      const details = OfferCardDetails(netFare: true);
      expect(
        details.fare('1 234,50 kr', commissionRate: 0.25),
        '925,87 kr',
      );
    });

    test('short fares keep their format', () {
      expect(WaybillPayment.fromFare('139,00 kr')!.earnings, '104,25 kr');
      expect(WaybillPayment.fromFare('126.75 kr')!.earnings, '95.06 kr');
      expect(WaybillPayment.fromFare('—'), isNull);
    });
  });
}
