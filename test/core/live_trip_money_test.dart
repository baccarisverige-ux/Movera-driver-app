import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_trip_money.dart';
import 'package:movera/core/money/money.dart';

/// Owner N9 (live test 2026-10-26): the money of a completed live trip
/// as the server's projection carries it. The numbers are the local
/// server's answer to a driver `complete` 1.2 km into a 208 kr trip,
/// 5.8 km from the drop-off: the ride part raised to the minimum
/// (`minimum_adjust`), the driver's earnings following it.
void main() {
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  final completed = <String, dynamic>{
    'tripId': 'trp_1',
    'status': 'completed',
    'version': 10,
    'fare': money(5400),
    'quote': {'quoteId': 'q', 'total': money(20800)},
    'fareLines': [
      {'code': 'base', 'amount': money(2900)},
      {'code': 'distance', 'amount': money(1735)},
      {'code': 'time', 'amount': money(32)},
      {'code': 'minimum_adjust', 'amount': money(233)},
      {'code': 'app_fee', 'amount': money(490)},
      {'code': 'rounding', 'amount': money(10)},
    ],
    'driverEarnings': money(3920),
    'commission': money(1400),
    'pickupPay': money(80),
  };

  test('the driver\'s pay is the earnings plus the pickup pay; the rider '
      'pays the final fare, not the booked one', () {
    final parsed = LiveTripMoney.tryParse(completed)!;
    expect(parsed.riderFare, Money.ore(5400));
    expect(parsed.driverEarnings, Money.ore(3920));
    expect(parsed.driverPay, Money.ore(4000));
    expect(parsed.driverPay.formatted, '40,00 kr');
    expect(parsed.riderFare.formatted, '54,00 kr');
    expect(parsed.waitingFee, isNull);
    // Cash: the whole fare unless a wallet paid part of it.
    expect(parsed.cash, Money.ore(5400));
    final wallet = {
      ...completed,
      'walletApplied': money(1000),
      'cashToCollect': money(4400),
    };
    expect(LiveTripMoney.tryParse(wallet)!.cash, Money.ore(4400));
  });

  test('the waiting lines are the driver\'s waiting fee', () {
    final waited = {
      ...completed,
      'fareLines': [
        ...completed['fareLines'] as List,
        {'code': 'waiting', 'amount': money(1200)},
        {'code': 'stop_waiting', 'amount': money(300)},
      ],
    };
    expect(LiveTripMoney.tryParse(waited)!.waitingFee, Money.ore(1500));
  });

  test('without the driver\'s money there is nothing to take', () {
    expect(
      LiveTripMoney.tryParse({'status': 'completed', 'fare': money(5400)}),
      isNull,
    );
    expect(LiveTripMoney.tryParse({'status': 'completed'}), isNull);
    final noPickupPay = {...completed}..remove('pickupPay');
    expect(LiveTripMoney.tryParse(noPickupPay)!.driverPay, Money.ore(3920));
  });
}
