import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';

/// `GET /driver/earnings?period=day` (contract `EarningsReport`): today's
/// earnings as the server counts them, in the zone's currency. A live
/// build shows these, not a sum of the trips this device happens to hold
/// (audit Phase 1 R3: zero on a new device, always "kr").
class LiveEarnings {
  LiveEarnings({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/earnings';

  /// Today's `net`, or null when the server could not say.
  Future<Money?> today({DateTime? now}) async {
    try {
      final report = await _api.get('$path?period=day');
      return todayOf(report, now ?? DateTime.now());
    } catch (error) {
      DriverLog.warn('earnings not read: $error', name: 'live');
      return null;
    }
  }

  /// This week's `net` (audit 2026-11-01: the wallet's balance on live);
  /// throws when the server could not answer, null when nothing is earned.
  Future<Money?> thisWeek({DateTime? now}) async => (await week(now: now)).net;

  /// Contract v0.18.14 `deepFix1.earnings`: this week's report in one
  /// [currency] (`?currency=SEK|EUR`; the server's default without it:
  /// the currency of the driver's first zone) with every currency he
  /// earned in, for a kr / € switch. Throws when the server could not
  /// answer.
  Future<EarningsWeek> week({String? currency, DateTime? now}) async {
    final query = currency == null
        ? 'period=week'
        : 'period=week&currency=${Uri.encodeQueryComponent(currency)}';
    final report = await _api.get('$path?$query');
    return EarningsWeek.of(report, now ?? DateTime.now());
  }

  /// G28 step 1: the totals of [from]..[to] (instants, sent in UTC) as
  /// the server counts them, `GET /driver/earnings?period=day&from&to`
  /// summed over its day periods, in one [currency] (null: the server's
  /// default). Throws when the server could not answer.
  ///
  /// A range that ends now leaves [to] out: the server then counts up to
  /// its own now, included (a phone clock behind the server's would cut
  /// off a trip just finished, as it counts `at < to`).
  Future<EarningsTotals> range({
    required DateTime from,
    DateTime? to,
    String? currency,
  }) async {
    final query = [
      'period=day',
      'from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}',
      if (to != null)
        'to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}',
      if (currency != null) 'currency=${Uri.encodeQueryComponent(currency)}',
    ].join('&');
    final report = await _api.get('$path?$query');
    return EarningsTotals.of(report);
  }

  /// `GET /driver/payouts` (newest first): the driver's own payouts.
  /// Throws when the server could not answer.
  Future<List<DriverPayout>> payouts({int limit = 10}) async =>
      (await payoutPage(limit: limit)).items;

  /// `GET /driver/payouts` with the page's next payout moment (contract
  /// v0.18.94 `DriverPayoutPage`, job A5). Throws when the server could
  /// not answer.
  Future<DriverPayoutPage> payoutPage({int limit = 10}) async =>
      DriverPayoutPage.of(
        await _api.get('/api/v1/driver/payouts?limit=$limit'),
      );

  /// `GET /driver/pay-movera` (contract v0.18.139 `driverPayRequest.read`):
  /// what he owes Movera now, the reference and, while his country's
  /// monthly pay request is on, the payment link. Throws when the server
  /// could not answer or the answer cannot be read.
  Future<PayMovera> payMovera() async =>
      PayMovera.of(await _api.get('/api/v1/driver/pay-movera'));

  /// DRAFT (contract driverPayRequest.stripe): a Stripe PaymentIntent for
  /// what he owes now; the app sends no amount (the server's only).
  Future<StripeDriverPayment> startStripePayment() async =>
      StripeDriverPayment.of(
        await _api.post('/api/v1/driver/pay-movera/pay', body: const {}),
      );

  /// The period holding [now] (else the newest one) of an `EarningsReport`;
  /// null when there is none.
  static Map? periodOf(Map<String, dynamic> report, DateTime now) {
    final periods = report['periods'];
    if (periods is! List || periods.isEmpty) return null;
    for (final period in periods) {
      if (period is! Map) continue;
      final start = DateTime.tryParse('${period['periodStart']}');
      final end = DateTime.tryParse('${period['periodEnd']}');
      if (start != null &&
          end != null &&
          !now.isBefore(start) &&
          now.isBefore(end)) {
        return period;
      }
    }
    return periods.last is Map ? periods.last as Map : null;
  }

  /// The period holding [now] (else the newest one) of an
  /// `EarningsReport`; its `net`. Null when there is none.
  static Money? todayOf(Map<String, dynamic> report, DateTime now) {
    final chosen = periodOf(report, now);
    final net = chosen?['net'];
    if (net is! Map) return null;
    try {
      return Money.fromJson(Map<String, dynamic>.from(net));
    } on FormatException {
      return null;
    }
  }
}

/// The page of `GET /driver/payouts` (contract v0.18.94 `DriverPayoutPage`,
/// job A5 / BQ-M13, owner decisions/driver-g10.md:6): the payouts and when
/// the next one is made.
class DriverPayoutPage {
  const DriverPayoutPage({required this.items, this.nextPayoutLocal});

  factory DriverPayoutPage.of(Map<String, dynamic> page) {
    final items = page['items'];
    return DriverPayoutPage(
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map)
              ?DriverPayout.tryParse(Map<String, dynamic>.from(item)),
      ],
      nextPayoutLocal: _wallClock(page['nextPayoutLocal']),
    );
  }

  final List<DriverPayout> items;

  /// The next payout as wall-clock time in the payout zone
  /// (`nextPayoutLocal`, "2026-11-16T08:00"), held as a UTC [DateTime]
  /// whose fields are that wall clock: shown as it is, never moved to the
  /// phone's time zone, and never shifted by the phone's own summer-time
  /// gap (a phone-local 02:30 on its spring-forward night would read as
  /// 03:30). Null when the server sends none (paused payouts, older server).
  final DateTime? nextPayoutLocal;

  static final _pattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$');

  static DateTime? _wallClock(Object? value) =>
      value is String && _pattern.hasMatch(value)
      ? DateTime.tryParse('$value:00Z')
      : null;
}

/// One payout of `GET /driver/payouts` (contract Payout, driver view).
class DriverPayout {
  const DriverPayout({
    required this.amount,
    required this.paid,
    required this.periodStart,
    required this.periodEnd,
    required this.tripCount,
    this.summary,
    this.parts,
  });

  final Money amount;

  /// v0.18.92 (BQ-M22, contract.json#priceDisplay.payoutSummary): the
  /// server's two numbers for this payout, his view; null from an older
  /// server (the card then shows [amount] only). Never worked out here.
  final PayoutSummary? summary;

  /// v0.18.133 (S5 J15, contract.json#payoutLines): Earned / Owed to Movera /
  /// Paid out (+ carriedOut) as the server sent them; null on a payout made
  /// before the switch or from an older server (the card keeps [summary]).
  final PayoutParts? parts;
  final bool paid;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int tripCount;

  static DriverPayout? tryParse(Map<String, dynamic> json) {
    final amount = json['amount'];
    final start = DateTime.tryParse('${json['periodStart']}');
    final end = DateTime.tryParse('${json['periodEnd']}');
    if (amount is! Map || start == null || end == null) return null;
    try {
      return DriverPayout(
        amount: Money.fromJson(Map<String, dynamic>.from(amount)),
        paid: json['status'] == 'paid',
        periodStart: start,
        periodEnd: end,
        tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
        summary: PayoutSummary.tryParse(json['summary']),
        parts: PayoutParts.tryParse(json),
      );
    } on FormatException {
      return null;
    }
  }
}

/// v0.18.133 (S5 J15, contract.json#payoutLines.driver; owner 2026-11-19
/// "driver payout 3 lines", "carry line only when needed"): the payout's parts,
/// each one server amount. The app never works money out.
class PayoutParts {
  const PayoutParts({
    required this.earned,
    required this.owedToMovera,
    required this.paidOut,
    required this.carriedOut,
  });

  final Money earned;
  final Money owedToMovera;
  final Money paidOut;

  /// "Moves to next week": shown only when above 0.
  final Money carriedOut;

  bool get movesToNextWeek => carriedOut.amountMinor > 0;

  /// Null unless all four amounts are there (never a half card).
  static PayoutParts? tryParse(Map<String, dynamic> json) {
    final values = [
      json['earned'],
      json['owedToMovera'],
      json['paidOut'],
      json['carriedOut'],
    ];
    if (values.any((v) => v is! Map)) return null;
    try {
      final m = [
        for (final v in values)
          Money.fromJson(Map<String, dynamic>.from(v as Map)),
      ];
      return PayoutParts(
        earned: m[0],
        owedToMovera: m[1],
        paidOut: m[2],
        carriedOut: m[3],
      );
    } on FormatException {
      return null;
    }
  }
}

/// `Payout.summary { driverGets, moveraGets }` (contract v0.18.92, owner
/// 2026-11-14 "how much driver get and how much movera get thats all no
/// details"): two amounts, shown as they come.
class PayoutSummary {
  const PayoutSummary({required this.driverGets, required this.moveraGets});

  final Money driverGets;
  final Money moveraGets;

  /// Null when absent or not two valid amounts (never a half summary).
  static PayoutSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    final driver = json['driverGets'];
    final movera = json['moveraGets'];
    if (driver is! Map || movera is! Map) return null;
    try {
      return PayoutSummary(
        driverGets: Money.fromJson(Map<String, dynamic>.from(driver)),
        moveraGets: Money.fromJson(Map<String, dynamic>.from(movera)),
      );
    } on FormatException {
      return null;
    }
  }
}

/// One currency of an `EarningsReport` (contract v0.18.14): its `net` for
/// the period holding now, the report's `currency` and `currencies`.
class EarningsWeek {
  const EarningsWeek({
    this.net,
    this.currency,
    this.currencies = const [],
    this.cashCollected,
    this.moveraBalance,
  });

  factory EarningsWeek.of(Map<String, dynamic> report, DateTime now) {
    final listed = report['currencies'];
    final currency = report['currency'] is String
        ? report['currency'] as String
        : null;
    return EarningsWeek(
      net: LiveEarnings.todayOf(report, now),
      cashCollected: _cashOf(report, now, currency),
      // Only a balance in the report's own currency is shown next to it
      // (never "kr" under the € tab).
      moveraBalance: MoveraBalance.tryParse(
        report['moveraBalance'],
        currency: currency,
      ),
      currency: currency,
      currencies: [
        if (listed is List)
          for (final c in listed)
            if (c is String && c.isNotEmpty) c,
      ],
    );
  }

  final Money? net;
  final String? currency;

  /// Contract v0.18.139 `driverWalletBalance.cash`: the server's
  /// `cashCollected` of the same period as [net]; 0 in the report's
  /// currency when the week has no entry (the server sends no period then);
  /// null when the period carries none (the field is optional) or the
  /// report cannot be read.
  final Money? cashCollected;

  /// Contract v0.18.139 `EarningsReport.moveraBalance`: what he owes Movera
  /// now, or Movera owes him, as the server counts it; null from an older
  /// server. Never worked out here (never net − cash, never a sum of trips).
  final MoveraBalance? moveraBalance;

  /// Every currency earned in during the range; two or more → the switch.
  final List<String> currencies;

  static Money? _cashOf(
    Map<String, dynamic> report,
    DateTime now,
    String? currency,
  ) {
    final periods = report['periods'];
    if (periods is! List) return null;
    final period = LiveEarnings.periodOf(report, now);
    if (period == null) {
      return periods.isEmpty && currency != null
          ? Money(minorUnits: 0, currency: currency)
          : null;
    }
    final cash = period['cashCollected'];
    if (cash is! Map) return null;
    try {
      return Money.fromJson(Map<String, dynamic>.from(cash));
    } on FormatException {
      return null;
    }
  }
}

/// `EarningsReport.moveraBalance { owedToMovera, moveraOwesYou }` (contract
/// v0.18.139, owner 2026-11-20 "Yes, server + app (Rec.)"): the two sides
/// of the server's one sum, shown as they come.
class MoveraBalance {
  const MoveraBalance({
    required this.owedToMovera,
    required this.moveraOwesYou,
  });

  final Money owedToMovera;
  final Money moveraOwesYou;

  bool get driverOwes => owedToMovera.minorUnits > 0;
  bool get moveraOwes => !driverOwes && moveraOwesYou.minorUnits > 0;

  /// Null when absent or not what the contract promises: two valid amounts
  /// of one currency ([currency] when given: the report's), both 0 or
  /// above and at least one of them 0. A broken answer shows no line at
  /// all, never half a balance or a number that contradicts itself.
  static MoveraBalance? tryParse(Object? json, {String? currency}) {
    if (json is! Map) return null;
    final owed = json['owedToMovera'];
    final owes = json['moveraOwesYou'];
    if (owed is! Map || owes is! Map) return null;
    try {
      final balance = MoveraBalance(
        owedToMovera: Money.fromJson(Map<String, dynamic>.from(owed)),
        moveraOwesYou: Money.fromJson(Map<String, dynamic>.from(owes)),
      );
      final a = balance.owedToMovera, b = balance.moveraOwesYou;
      if (a.minorUnits < 0 || b.minorUnits < 0) return null;
      if (a.minorUnits > 0 && b.minorUnits > 0) return null;
      if (a.currency != b.currency) return null;
      if (currency != null && a.currency != currency) return null;
      return balance;
    } on FormatException {
      return null;
    }
  }
}

/// `DriverPayMovera` of `GET /driver/pay-movera` (contract v0.18.139
/// `driverPayRequest`, owner 2026-11-20: the TEMPORARY monthly pay request).
class PayMovera {
  const PayMovera({
    required this.enabled,
    required this.owedToMovera,
    required this.reference,
    this.payLink,
    this.stripe = false,
  });

  /// Throws [FormatException] when the amount or the reference is missing
  /// (never a screen with a made-up amount).
  factory PayMovera.of(Map<String, dynamic> json) {
    final owed = json['owedToMovera'];
    final reference = json['reference'];
    if (owed is! Map || reference is! String || reference.isEmpty) {
      throw FormatException('pay-movera answer', json);
    }
    final amount = Money.fromJson(Map<String, dynamic>.from(owed));
    // The contract promises 0 or above: a negative amount is a broken
    // answer (the error screen, never "Settled" over a minus number).
    if (amount.minorUnits < 0) {
      throw FormatException('pay-movera amount below 0', json);
    }
    return PayMovera(
      enabled: json['enabled'] == true,
      owedToMovera: amount,
      reference: reference,
      payLink: json['enabled'] == true ? linkOf(json['payLink']) : null,
      stripe: json['enabled'] == true && json['stripe'] == true,
    );
  }

  /// The country's monthly pay request is on.
  final bool enabled;

  /// What he owes Movera now (the server's number).
  final Money owedToMovera;

  /// What he writes on the payment so Movera finds him and the month.
  final String reference;

  /// The admin's payment link, opened as it is; null while off or when it
  /// is not a plain https link (nothing else is ever opened).
  final Uri? payLink;

  /// DRAFT (driverPayRequest.stripe): the Pay button pays by Stripe (card,
  /// Apple Pay) instead of opening the link.
  final bool stripe;

  /// The Stripe Pay button shows only when the server says so and he owes.
  bool get canPayByCard => stripe && owedToMovera.minorUnits > 0;

  /// The Pay button shows only with a link and something to pay.
  bool get canPay => payLink != null && owedToMovera.minorUnits > 0;

  /// A plain https link, as the server's own rule (movera-server
  /// src/drivers/payRequestSetting.ts): "https://" then printable ASCII
  /// only (no white space, control, invisible or look-alike character) and
  /// no backslash (a browser reads it as "/", hiding the real host), at
  /// most 500 characters, a host, and no "user:password@" part: the
  /// address he reads is where it goes.
  static Uri? linkOf(Object? value) {
    if (value is! String || value.length > 500) return null;
    if (!_linkShape.hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static final RegExp _linkShape = RegExp(r'^https://[\x21-\x5B\x5D-\x7E]+$');
}

/// G28 step 1: an `EarningsReport` summed over all its periods: `net`,
/// `tripCount`, `cashCollected` and `tips` + `fees`, in the report's one
/// currency.
class EarningsTotals {
  const EarningsTotals({
    required this.net,
    required this.tripCount,
    required this.cashCollected,
    this.tipsAndFees,
    this.bonus,
    this.currencies = const [],
  });

  /// Throws [FormatException] when the report or one of its amounts
  /// cannot be read (never a partial sum shown as the truth).
  factory EarningsTotals.of(Map<String, dynamic> report) {
    final currency = report['currency'];
    if (currency is! String) {
      throw FormatException('report currency missing', currency);
    }
    final periods = report['periods'];
    if (periods is! List) throw FormatException('periods missing', periods);
    Money sum(Money total, Object? amount) {
      if (amount == null) return total;
      if (amount is! Map) throw FormatException('amount', amount);
      return total + Money.fromJson(Map<String, dynamic>.from(amount));
    }

    var net = Money(minorUnits: 0, currency: currency);
    var cash = Money(minorUnits: 0, currency: currency);
    Money? tipsAndFees = Money(minorUnits: 0, currency: currency);
    Money? bonus;
    var trips = 0;
    for (final period in periods) {
      if (period is! Map) throw FormatException('period', period);
      net = sum(net, period['net']);
      // v0.18.110 `EarningsPeriod.bonus` (optional): already inside `net`,
      // summed for its own line only, never added to [net] again.
      if (period['bonus'] != null) {
        bonus = sum(
          bonus ?? Money(minorUnits: 0, currency: currency),
          period['bonus'],
        );
      }
      cash = sum(cash, period['cashCollected']);
      // `tips` is required by the contract, `fees` (v0.5.1) optional: a
      // period without `tips` → the sum is not known.
      tipsAndFees = period['tips'] == null || tipsAndFees == null
          ? null
          : sum(sum(tipsAndFees, period['tips']), period['fees']);
      trips += (period['tripCount'] as num?)?.toInt() ?? 0;
    }
    final listed = report['currencies'];
    return EarningsTotals(
      net: net,
      tripCount: trips,
      cashCollected: cash,
      tipsAndFees: tipsAndFees,
      bonus: bonus,
      currencies: [
        if (listed is List)
          for (final c in listed)
            if (c is String && c.isNotEmpty) c,
      ],
    );
  }

  final Money net;
  final int tripCount;
  final Money cashCollected;

  /// The driver's tips and his shares of cancel / no-show fees over the
  /// range (both in [net]); null when the report does not give them.
  final Money? tipsAndFees;

  /// BQ-V44 (contract v0.18.110 `EarningsPeriod.bonus`): the trip bonuses
  /// and campaign bonuses over the range, a PART of [net] (the server
  /// counts them in it); null from a server that does not send it.
  final Money? bonus;

  /// Every currency earned in during the range.
  final List<String> currencies;
}

/// DRAFT (contract driverPayRequest.stripe, `StripeDriverPayment`): the
/// PaymentIntent the server made for what he owes now. Test keys only.
class StripeDriverPayment {
  const StripeDriverPayment({
    required this.amount,
    required this.clientSecret,
    required this.publishableKey,
  });

  factory StripeDriverPayment.of(Map<String, dynamic> json) {
    final amount = json['amount'];
    final secret = json['clientSecret'];
    final key = json['publishableKey'];
    if (amount is! Map ||
        secret is! String ||
        secret.isEmpty ||
        key is! String ||
        !key.startsWith('pk_test_')) {
      throw FormatException('pay-movera/pay answer', json);
    }
    return StripeDriverPayment(
      amount: Money.fromJson(Map<String, dynamic>.from(amount)),
      clientSecret: secret,
      publishableKey: key,
    );
  }

  final Money amount;
  final String clientSecret;
  final String publishableKey;
}
