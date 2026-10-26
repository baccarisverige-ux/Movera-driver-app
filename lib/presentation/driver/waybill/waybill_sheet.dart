import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

/// The trip's waybill: one plain list, label on the left, value on the
/// right. Shows the same facts as a taxi waybill plus what the driver
/// earns: the record's fare is the driver's own money, after Movera's
/// commission, and (owner N11, live test 2026-10-26) what the rider pays
/// is on it too, the one place the driver sees it.
Future<void> showMoveraWaybillSheet(
  BuildContext context,
  WaybillRecord record, {
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, controller) {
          return Container(
            key: ValueKey<String>('waybill-${record.tripId}'),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: tr.close,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Navigator.of(sheetContext).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: _ink),
                    ),
                  ),
                  Text(
                    title ?? tr.waybill,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._rows(record),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

const _ink = Color(0xFF303A3F);
const _muted = Color(0xFF7D898F);

List<Widget> _rows(WaybillRecord record) {
  final bonus = record.driverBonus;
  final earnings = Money.parseLabel(record.fare);
  final wait = record.waitingFee == null || earnings == null
      ? null
      : Money.parseLabel(record.waitingFee!, currency: earnings.currency);
  final extra = bonus == null || earnings == null
      ? null
      : Money.parseLabel(bonus, currency: earnings.currency);
  // The trip's own part of the earnings: without the waiting fee (Q43,
  // driver-u50) and Movera's bonus (Q16/Q18), which have their own rows.
  final base = earnings == null
      ? null
      : earnings -
            (wait ?? Money(minorUnits: 0, currency: earnings.currency)) -
            (extra ?? Money(minorUnits: 0, currency: earnings.currency));
  return [
    _Row(tr.trip, record.tripId),
    _Row(tr.time, formatWaybillTime(record.issuedAt)),
    _Row(tr.passenger, record.riderNameText),
    _Row(tr.via, record.sourceText),
    _Row(tr.from, record.pickup),
    _Row(tr.to2, record.dropoff),
    const SizedBox(height: 14),
    _Row(tr.driver, record.driverNameText),
    _Row(tr.licensePlate, record.licensePlateText),
    _Row(tr.passengerCapacity, '${record.passengerCapacity}'),
    const SizedBox(height: 14),
    _Row(tr.payment, record.paidByCash ? tr.cash : tr.inApp),
    if (record.riderFare case final paid?) _Row(tr.riderPays, paid),
    if (base != null) ...[
      _Row(tr.earningsBaseService(record.service), base.formatted),
      // Q43: the waiting fee is all the driver's.
      if (wait case final fee? when !fee.isZero)
        _Row(tr.waitingTime, '+${fee.formatted}'),
      if (extra case final money? when !money.isZero)
        _Row(tr.moveraBonus, '+${money.formattedShort}'),
    ],
    _Row(tr.yourEarnings, record.fare),
    if (bonus != null)
      _Note(WaybillRecord.bonusNote(bonus), id: 'waybill-fare-bonus'),
  ];
}

/// "10 Oct 2026, 14:32:05 CEST": date, time to the second, time zone. The
/// month is in the driver's language ("10 oct. 2026", "10 okt. 2026").
String formatWaybillTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${DriverDates.dayMonth(value)} ${value.year}, '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)} '
      '${value.timeZoneName}';
}

/// A small muted line under a row, e.g. "incl. +40 kr Movera bonus".
class _Note extends StatelessWidget {
  const _Note(this.text, {required this.id});

  final String text;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        key: ValueKey<String>(id),
        style: const TextStyle(color: _muted, fontSize: 13),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
