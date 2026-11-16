import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_bonuses.dart';
import 'package:movera/presentation/driver/promotions/campaign_area_map.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// BQ-V44 (contract v0.18.110 `bonusCampaigns.apps.driver`): the
/// Campaigns screen of a live build. It reads `GET /driver/bonuses` and
/// shows, per campaign, the server's progress, target, amount and state;
/// "Earned" when the server says so, and NEW from `isNew`. Opening it
/// sends `POST /driver/bonuses/opened` once for the new ones.
///
/// Nothing is worked out here (owner R8): the bar is done / target as the
/// server sends them, the amount is the server's Money.
class LiveCampaigns extends StatefulWidget {
  const LiveCampaigns({super.key, required this.bonuses});

  final LiveBonuses bonuses;

  @override
  State<LiveCampaigns> createState() => _LiveCampaignsState();
}

/// The progress line: trips as plain numbers, online hours as the
/// server's minutes in "4 h 20 min" (contract `progressFormat`).
String campaignProgressText(DriverBonus bonus) => switch (bonus.measure) {
  BonusMeasure.trips => tr.campaignProgressTrips(
    '${bonus.done}',
    '${bonus.target}',
  ),
  BonusMeasure.onlineHours => tr.campaignProgressHours(
    campaignDuration(bonus.done),
    campaignDuration(bonus.target),
  ),
};

/// Minutes as `texts.duration` ("4 h 20 min"), or `texts.durationWholeHours`
/// when no minutes are left ("10 h").
String campaignDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? tr.campaignDurationWholeHours(h) : tr.campaignDuration(h, m);
}

class _LiveCampaignsState extends State<LiveCampaigns> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);
  static const Color _green = Color(0xFF1C6B45);
  static const Color _newRed = Color(0xFFD64545);

  late Future<List<DriverBonus>> _load;
  bool _openedSent = false;

  @override
  void initState() {
    super.initState();
    _load = _read();
  }

  Future<List<DriverBonus>> _read() async {
    final items = await widget.bonuses.list();
    if (!_openedSent) {
      final fresh = [
        for (final item in items)
          if (item.isNew) item.bonusId,
      ];
      if (fresh.isNotEmpty) {
        _openedSent = true;
        unawaited(widget.bonuses.opened(fresh));
      }
    }
    return items;
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _load = _read();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: Text(
          tr.campaignsTitle,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FutureBuilder<List<DriverBonus>>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _failed();
          final items = snapshot.data ?? const <DriverBonus>[];
          if (items.isEmpty) return _message(tr.campaignsEmpty);
          return ListView.separated(
            key: const ValueKey<String>('campaigns-list'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _card(items[index]),
          );
        },
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _muted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _failed() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr.campaignsCouldNotLoad,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _retry,
            child: Text(
              tr.retry,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );

  String? _dateLine(DriverBonus bonus) => switch (bonus.state) {
    BonusState.scheduled => tr.campaignStartsOn(
      DriverDates.dayMonth(bonus.startDate),
    ),
    BonusState.active ||
    BonusState.paused => tr.campaignEndsOn(DriverDates.dayMonth(bonus.endDate)),
    BonusState.ended => null,
  };

  String? _stateChip(DriverBonus bonus) => switch (bonus.state) {
    BonusState.paused => tr.campaignPaused,
    BonusState.ended => tr.campaignEnded,
    _ => null,
  };

  Widget _pill(String text, {required Color color, required Color ink}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _card(DriverBonus bonus) {
    final date = _dateLine(bonus);
    final chip = _stateChip(bonus);
    // The bar shows the server's two numbers; nothing is counted here.
    final share = (bonus.done / bonus.target).clamp(0.0, 1.0);
    return Container(
      key: ValueKey<String>('campaign-${bonus.bonusId}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      bonus.nameIn(DriverAppTexts.language),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (bonus.isNew)
                      _pill(tr.orbNew, color: _newRed, ink: Colors.white),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bonus.amount.formatted,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          // Plan §8: the area on a small map; none when the server sent
          // no usable outline.
          if (bonus.area case final area?) ...[
            const SizedBox(height: 10),
            CampaignAreaMap(
              key: ValueKey<String>('campaign-map-${bonus.bonusId}'),
              area: area,
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: _line,
              color: bonus.earned ? _green : _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            campaignProgressText(bonus),
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (bonus.earned) ...[
            const SizedBox(height: 6),
            Text(
              tr.campaignEarned,
              style: const TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (date != null || chip != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chip != null)
                  _pill(chip, color: const Color(0xFFEFF1F3), ink: _muted),
                if (date != null)
                  Text(
                    date,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
