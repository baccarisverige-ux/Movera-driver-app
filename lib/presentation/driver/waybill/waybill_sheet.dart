import 'package:flutter/material.dart';
import 'package:movera/core/waybill/waybill.dart';

/// The trip's waybill: one plain list, label on the left, value on the
/// right. Shows the same facts as a taxi waybill plus what the driver keeps.
Future<void> showMoveraWaybillSheet(
  BuildContext context,
  WaybillRecord record, {
  String title = 'Waybill',
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
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Navigator.of(sheetContext).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: _ink),
                    ),
                  ),
                  Text(
                    title,
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
  final payment = WaybillPayment.fromFare(record.fare, bonus: record.driverBonus);
  final bonus = record.driverBonus;
  return [
    _Row('Trip #', record.tripId),
    _Row('Time', formatWaybillTime(record.issuedAt)),
    _Row('Fare', payment == null ? record.fare : '${record.fare}*'),
    // Q16/Q18: the fare has Movera's bonus in it.
    if (bonus != null)
      _Note(WaybillRecord.bonusNote(bonus), id: 'waybill-fare-bonus'),
    _Row('Passenger', record.riderName),
    _Row('Via', record.source),
    _Row('From', record.pickup),
    _Row('To', record.dropoff),
    const SizedBox(height: 14),
    _Row('Driver', record.driverName),
    _Row('License plate', record.licensePlate),
    _Row('Passenger capacity', '${record.passengerCapacity}'),
    if (payment != null) ...[
      const SizedBox(height: 14),
      _Row('Paid by the passenger', payment.fare),
      const _Row('Payment', 'In the app'),
      _Row('Base price · ${record.service}', payment.fare),
      _Row('Movera fee', '−${payment.serviceFee}'),
      if (payment.bonus case final extra?) _Row('Movera bonus', '+$extra'),
      _Row('Your earnings', payment.earnings),
      if (bonus != null)
      _Note(WaybillRecord.bonusNote(bonus), id: 'waybill-fare-bonus'),
      const SizedBox(height: 16),
      const Text(
        '* Round to the nearest whole krona in the taximeter.',
        style: TextStyle(color: _muted, fontSize: 13),
      ),
    ],
  ];
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "10 Oct 2026, 14:32:05 CEST": date, time to the second, time zone.
String formatWaybillTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.day} ${_months[value.month - 1]} ${value.year}, '
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
