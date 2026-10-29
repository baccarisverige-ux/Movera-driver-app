import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';

/// Owner decisions of 2026-10-29, driver group 2 items 2, 3 and 9: the
/// Home sheet's "Important reminders (N)" box, Movera's own design (the
/// owner's example photos were an idea only). It opens and closes; one
/// line per issue, red when it keeps the driver offline, orange when due
/// soon, grey when Movera acts next; a tap on a line fixes it. Hidden when
/// there is nothing to remind.
class ImportantRemindersBox extends StatefulWidget {
  const ImportantRemindersBox({
    super.key,
    required this.store,
    required this.onFix,
    this.owner = false,
    this.carName,
    this.initiallyOpen = true,
  });

  final DriverRemindersStore store;

  /// A tap on a line with a fix.
  final void Function(DriverReminder reminder) onFix;

  /// The fleet owner (the fleet_no_approved_car fix is his).
  final bool owner;

  /// "ABC 123" for a vehicleId, when known.
  final String? Function(String vehicleId)? carName;
  final bool initiallyOpen;

  static const red = Color(0xFFD03A2B);
  static const orange = Color(0xFFE08A00);
  static const grey = Color(0xFF7D898F);

  static Color colorOf(ReminderLevel level) => switch (level) {
    ReminderLevel.blocksOnline => red,
    ReminderLevel.dueSoon => orange,
    ReminderLevel.waiting => grey,
  };

  @override
  State<ImportantRemindersBox> createState() => _ImportantRemindersBoxState();
}

class _ImportantRemindersBoxState extends State<ImportantRemindersBox> {
  late bool _open = widget.initiallyOpen;

  static const _ink = Color(0xFF172027);
  static const _sub = Color(0xFF66737A);
  static const _line = Color(0xFFE7EBED);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.store,
        OnboardingSettingsStore.instance,
      ]),
      builder: (context, _) {
        final items = widget.store.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final blocking = widget.store.blocksOnline;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            key: const ValueKey('home-reminders'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: blocking
                    ? ImportantRemindersBox.red.withValues(alpha: 0.45)
                    : _line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  expanded: _open,
                  label: _open ? tr.remHide : tr.remShow,
                  child: InkWell(
                    key: const ValueKey('home-reminders-toggle'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _open = !_open),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notification_important_outlined,
                            size: 22,
                            color: blocking
                                ? ImportantRemindersBox.red
                                : ImportantRemindersBox.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr.remTitle(items.length),
                              key: const ValueKey('home-reminders-title'),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            _open
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: _ink,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_open)
                  for (final (i, item) in items.indexed) _reminderLine(item, i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reminderLine(DriverReminder item, int index) {
    final words = reminderWords(
      item,
      nameOf: (type) =>
          OnboardingSettingsStore.instance.nameOf(type, tr.localeName),
      carName: widget.carName,
      owner: widget.owner,
    );
    final color = ImportantRemindersBox.colorOf(item.level);
    final canFix = item.fix != null;
    return InkWell(
      key: ValueKey('home-reminder-$index'),
      onTap: canFix ? () => widget.onFix(item) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                key: ValueKey('home-reminder-$index-${item.level.name}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.title,
                    style: TextStyle(
                      color: item.level == ReminderLevel.waiting ? _ink : color,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (words.detail case final detail?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          color: _sub,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canFix && words.action != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    words.action!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
