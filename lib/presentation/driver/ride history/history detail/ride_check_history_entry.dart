import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/safety/ride_check_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_log.dart';

Widget _solar(String asset, Color color, double size) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

/// "Ride check" in a trip's details: when it opened, why, and the answers.
/// Shows nothing when the trip had no Ride check.
class RideCheckHistoryEntry extends StatefulWidget {
  const RideCheckHistoryEntry({super.key, required this.tripId, this.load});

  final String tripId;

  /// Defaults to the Ride checks saved on this phone.
  final Future<List<RideCheckRecord>> Function(String tripId)? load;

  @override
  State<RideCheckHistoryEntry> createState() => _RideCheckHistoryEntryState();
}

class _RideCheckHistoryEntryState extends State<RideCheckHistoryEntry> {
  static const Color _ink = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF7C868D);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _red = Color(0xFFC2453A);

  late final Future<List<RideCheckRecord>> _checks =
      (widget.load ?? PrefsRideCheckLog().forTrip)(
        widget.tripId,
      ).catchError((Object _) => const <RideCheckRecord>[]);

  static String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RideCheckRecord>>(
    future: _checks,
    builder: (context, snapshot) {
      final checks = snapshot.data ?? const <RideCheckRecord>[];
      if (checks.isEmpty) return const SizedBox.shrink();
      return Column(
        key: const ValueKey('ride-check-history'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final check in checks) _entry(check)],
      );
    },
  );

  Widget _entry(RideCheckRecord check) {
    final answers = check.answers;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: check.alertSent
                  ? _red.withValues(alpha: .12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: _solar(
              AppAssets.solarShieldWarning,
              check.alertSent ? _red : _ink,
              18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr.rideCheck,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _time(check.openedAt),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${check.trigger.text} · ${check.reasonText}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                if (answers.isEmpty)
                  Text(
                    tr.noAnswer,
                    style: TextStyle(color: _ink, fontSize: 13.5),
                  ),
                for (final answer in answers)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      answer.question == RideCheckAnswer.first
                          ? tr.answerAnswer(rideCheckAnswerWords(answer.answer))
                          : '${rideCheckQuestionWords(answer.question)} '
                                '${rideCheckAnswerWords(answer.answer)}',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: answer.question == RideCheckAnswer.first
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                if (check.alertSent) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _solar(AppAssets.solarBellBing, _red, 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          check.alertReachedMovera
                              ? tr.moveraSafetyTeamAlerted
                              : tr.safetyAlertKeptOnPhoneDemo,
                          style: TextStyle(
                            color: _red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (check.audioSeconds != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _solar(AppAssets.solarMicrophone, _muted, 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tr.audioSavedOnlyOnThisPhone(
                            '${check.audioSeconds! ~/ 60}:${(check.audioSeconds! % 60).toString().padLeft(2, '0')}',
                          ),
                          style: const TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
