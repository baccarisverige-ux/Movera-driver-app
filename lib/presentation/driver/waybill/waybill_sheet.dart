import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
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

// Owner decision 2026-10-27: two totals only, what the rider pays and
// what the driver gets (pickup pay, waiting fee and any bonus are in it);
// no breakdown lines.
List<Widget> _rows(WaybillRecord record) {
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
    _Row(tr.yourEarnings, record.fare),
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
