import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/notifications/driver_notifications.dart';

/// The parts of a published DriverAppConfig the app puts in use besides the
/// waiting, destination, next-trip, reservation and auto-offline rules
/// (owner 2026-10-27, settings flow): pickup pay, ride check, the admin's
/// texts, the notice switches and the cancel fees. Each is null when the
/// document has none, and the app keeps what it uses.
class DriverConfigParts {
  const DriverConfigParts({
    this.offers,
    this.pickupPay,
    this.rideCheck,
    this.texts,
    this.noticesOff,
    this.cancelFees,
  });

  /// `offers` as published (timers, card, reasons, Exclusive while
  /// driving); [DriverOfferRules.withOffers] reads it.
  final Map<String, dynamic>? offers;
  final PickupPayConfig? pickupPay;
  final RideCheckAdminConfig? rideCheck;
  final DriverAppTextOverrides? texts;
  final Set<DriverNoticeKind>? noticesOff;
  final DriverCancelFees? cancelFees;

  static DriverConfigParts fromJson(
    Map<dynamic, dynamic> json,
    String currency,
  ) {
    final offers = json['offers'];
    return DriverConfigParts(
      offers: offers is Map ? Map<String, dynamic>.from(offers) : null,
      pickupPay: _pickupPay(json['pickupPay'], currency),
      rideCheck: _rideCheck(json['rideCheck']),
      texts: _texts(json['texts']),
      noticesOff: _noticesOff(json['notices']),
      cancelFees: DriverCancelFees.fromJson(json['cancelFees']),
    );
  }

  /// Puts the parts in use (only those the document has).
  void apply() {
    if (pickupPay case final value?) PickupPayConfig.current = value;
    if (rideCheck case final value?) RideCheckAdminConfig.current = value;
    if (texts case final value?) DriverAppTexts.overrides = value;
    if (noticesOff case final value?) {
      DriverNoticeRules.current = DriverNoticeRules(off: value);
    }
    if (cancelFees case final value?) DriverCancelFees.current = value;
  }

  static double? _major(Object? raw, String currency) {
    if (raw is! Map) return null;
    final money = Money.fromJson(Map<String, dynamic>.from(raw));
    if (money.currency != currency) return null;
    return money.minorUnits / _factor(currency);
  }

  static int _factor(String currency) {
    var factor = 1;
    for (var i = 0; i < (Money.exponents[currency] ?? 2); i++) {
      factor *= 10;
    }
    return factor;
  }

  static PickupPayConfig? _pickupPay(Object? raw, String currency) {
    if (raw is! Map) return null;
    final byCategory = raw['byCategory'];
    if (byCategory is! Map) return null;
    final rates = <String, PickupPayRate>{};
    for (final entry in byCategory.entries) {
      final rate = entry.value;
      if (entry.key is! String || rate is! Map) continue;
      final ranges = <PickupPayRange>[
        for (final range
            in (rate['ranges'] is List ? rate['ranges'] as List : const []))
          if (range is Map && range['fromKm'] is num)
            PickupPayRange(
              fromKm: (range['fromKm'] as num).toDouble(),
              toKm: (range['toKm'] as num?)?.toDouble(),
              krPerKm: _major(range['perKm'], currency) ?? 0,
              krPerMinute: _major(range['perMin'], currency) ?? 0,
            ),
      ];
      final paid = ranges.where((r) => r.krPerKm > 0 || r.krPerMinute > 0);
      rates[entry.key as String] = PickupPayRate(
        enabled: rate['enabled'] != false,
        krPerKm: paid.isEmpty ? 0 : paid.first.krPerKm,
        krPerMinute: paid.isEmpty ? 0 : paid.first.krPerMinute,
        ranges: ranges,
      );
    }
    final offers = raw['offers'];
    final kinds = offers is Map
        ? {
            if (offers['radar'] == true) PickupPayOfferKind.radar,
            if (offers['exclusive'] == true) PickupPayOfferKind.exclusive,
            if (offers['exclusiveReservation'] == true)
              PickupPayOfferKind.exclusiveReservation,
            if (offers['assigned'] == true) PickupPayOfferKind.assignedByMovera,
            if (offers['nextTrip'] == true)
              PickupPayOfferKind.nextTripWhileDriving,
          }
        : PickupPayConfig.defaultKinds;
    return PickupPayConfig(categories: rates, kinds: kinds);
  }

  static RideCheckAdminConfig? _rideCheck(Object? raw) {
    if (raw is! Map) return null;
    final stop = raw['stopMinutes'];
    final far = raw['finishFarFromDropoffKm'];
    return const RideCheckAdminConfig().copyWith(
      longStopMinutes: stop is int && stop >= 1 ? stop : null,
      finishFarFromDropoffKm: far is num && far > 0 ? far.toDouble() : null,
    );
  }

  static DriverAppTextOverrides? _texts(Object? raw) {
    final byLanguage = raw is Map ? raw['byLanguage'] : null;
    if (byLanguage is! Map) return null;
    return DriverAppTextOverrides({
      for (final entry in byLanguage.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: {
            for (final text in (entry.value as Map).entries)
              if (text.key is String && text.value is String)
                text.key as String: text.value as String,
          },
    });
  }

  static Set<DriverNoticeKind>? _noticesOff(Object? raw) {
    final off = raw is Map ? raw['off'] : null;
    if (off is! List) return null;
    return {
      for (final kind in DriverNoticeKind.values)
        if (off.contains(kind.name)) kind,
    };
  }
}

/// `DriverAppConfig.cancelFees` (contract v0.8.0): the driver's share of a
/// rider's cancel fee in this zone (default 100 %). The server pays the
/// share a trip was booked with; the app shows today's.
class DriverCancelFees {
  const DriverCancelFees({this.driverSharePct = 100});

  static DriverCancelFees current = const DriverCancelFees();

  final int driverSharePct;

  /// The driver's part of a cancel fee of [minorUnits].
  int driverPartOf(int minorUnits) => minorUnits * driverSharePct ~/ 100;

  static DriverCancelFees? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final share = raw['driverSharePct'];
    return DriverCancelFees(
      driverSharePct: share is num && share >= 0 && share <= 100
          ? share.round()
          : 100,
    );
  }
}
