import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_public_profile.dart';

/// v0.18.147 driver profile (owner 2026-11-20 "Now build all";
/// contract.json#driverProfile.apps.driver): Profile › My profile. The
/// driver picks the languages he speaks, shows or hides his city and years,
/// sees the compliments and reviews riders gave him and opens "View as
/// rider". Read once when the screen opens; saved on each change.
class MyPublicProfileScreen extends StatefulWidget {
  const MyPublicProfileScreen({super.key, required this.api});

  final PublicProfileApi api;

  @override
  State<MyPublicProfileScreen> createState() => _MyPublicProfileScreenState();
}

const _ink = Color(0xFF0E1B2C);
const _muted = Color(0xFF5C656C);
const _line = Color(0xFFE3E8EE);
const _blue = Color(0xFF1F6FEB);
const _gold = Color(0xFFC9A227);

String complimentLabel(String code) => switch (code) {
  'great_service' => tr.complimentGreatService,
  'knew_the_way' => tr.complimentKnewTheWay,
  'friendly' => tr.complimentFriendly,
  'clean_car' => tr.complimentCleanCar,
  'safe_driving' => tr.complimentSafeDriving,
  'good_music' => tr.complimentGoodMusic,
  _ => code,
};

/// "2026-11" → "november 2026" in the driver's language.
String profileMonthText(String month) {
  final parts = month.split('-');
  if (parts.length != 2) return month;
  final at = DateTime(
    int.tryParse(parts[0]) ?? 2000,
    int.tryParse(parts[1]) ?? 1,
  );
  return DriverDates.monthYear(at);
}

class _MyPublicProfileScreenState extends State<MyPublicProfileScreen> {
  OwnPublicProfile? _profile;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await widget.api.read();
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save({
    List<String>? languages,
    bool? showCity,
    bool? showYears,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final p = await widget.api.save(
        languages: languages,
        showCity: showCity,
        showYears: showYears,
      );
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(tr.mppSaveError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleLanguage(String code) {
    final now = [...?_profile?.languages];
    if (now.contains(code)) {
      now.remove(code);
    } else if (now.length < maxProfileLanguages) {
      now.add(code);
    } else {
      return;
    }
    _save(languages: now);
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(tr.mppTitle),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: p == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr.mppLoadError),
                        TextButton(onPressed: _load, child: Text(tr.mppRetry)),
                      ],
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  tr.mppIntro,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                if (!p.profileOn) ...[
                  const SizedBox(height: 8),
                  _note(tr.mppProfileOff),
                ],
                const SizedBox(height: 16),
                _section(
                  tr.mppLanguages,
                  subtitle: p.languages.length >= maxProfileLanguages
                      ? tr.mppLanguagesMax
                      : tr.mppLanguagesHint,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in profileLanguageNames.entries)
                        FilterChip(
                          key: ValueKey('mpp-lang-${e.key}'),
                          label: Text(e.value),
                          selected: p.languages.contains(e.key),
                          // At 6, the chips not picked are off.
                          onSelected:
                              _saving ||
                                  (!p.languages.contains(e.key) &&
                                      p.languages.length >= maxProfileLanguages)
                              ? null
                              : (_) => _toggleLanguage(e.key),
                          selectedColor: const Color(0xFFE6F0FF),
                          checkmarkColor: _blue,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  null,
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('mpp-show-city'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr.mppShowCity),
                        value: p.showCity,
                        onChanged: _saving ? null : (v) => _save(showCity: v),
                      ),
                      SwitchListTile(
                        key: const ValueKey('mpp-show-years'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr.mppShowYears),
                        value: p.showYears,
                        onChanged: _saving ? null : (v) => _save(showYears: v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  tr.mppCompliments,
                  child: p.compliments.isEmpty
                      ? Text(
                          tr.mppNoCompliments,
                          style: const TextStyle(color: _muted),
                        )
                      : ComplimentGrid(compliments: p.compliments),
                ),
                const SizedBox(height: 12),
                _section(
                  tr.mppReviews,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!p.reviewsOn) _note(tr.mppReviewsOff),
                      if (p.reviews.isEmpty)
                        Text(
                          tr.mppNoReviews,
                          style: const TextStyle(color: _muted),
                        )
                      else
                        for (final r in p.reviews) _reviewTile(r),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('mpp-view-as-rider'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        DriverProfilePreviewSheet(preview: p.preview),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(tr.mppViewAsRider),
                ),
              ],
            ),
    );
  }

  Widget _note(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13, color: _ink)),
  );

  Widget _section(String? title, {String? subtitle, required Widget child}) =>
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              if (title != null) const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );

  Widget _reviewTile(ProfileReview r) {
    final status = switch (r.status) {
      'approved' => tr.mppReviewApproved,
      'hidden' => tr.mppReviewHidden,
      _ => tr.mppReviewPending,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${r.text}”',
            style: const TextStyle(fontSize: 14, color: _ink),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.name ?? tr.mppAnonymous} · ${r.month}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: r.status == 'approved'
                      ? const Color(0xFF1A7F37)
                      : _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The compliment tiles: the phone's own emoji (Text, no image), count, label.
class ComplimentGrid extends StatelessWidget {
  const ComplimentGrid({super.key, required this.compliments});
  final List<ProfileCompliment> compliments;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final c in compliments)
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                complimentEmoji[c.code] ?? '',
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.count}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                complimentLabel(c.code),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ),
    ],
  );
}

/// "View as rider": the same parts the rider's profile sheet shows.
class DriverProfilePreviewSheet extends StatelessWidget {
  const DriverProfilePreviewSheet({super.key, required this.preview});
  final PublicProfilePreview preview;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final langs = p.languages
        .map((l) => profileLanguageNames[l] ?? l)
        .join(' · ');
    return Container(
      key: const ValueKey('mpp-preview'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0E1B2C), Color(0xFF1F6FEB)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold,
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFE3E8EE),
                      child: Text(
                        p.firstName.isEmpty ? '' : p.firstName[0],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.firstName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      if (p.verified)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.verified_rounded,
                            color: _blue,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  if (p.sinceMonth != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tr.mppSince(profileMonthText(p.sinceMonth!)),
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (langs.isNotEmpty)
                        _pill(Icons.translate_rounded, langs),
                      if (p.city != null) _pill(Icons.place_outlined, p.city!),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _kpi('${p.tripCount}', tr.mppTrips),
                        _kpi(
                          p.rating == null
                              ? '–'
                              : '${p.rating!.toStringAsFixed(1)} ★',
                          tr.mppRating,
                        ),
                        // Contract: years 0 shows only the since month.
                        if ((p.years ?? 0) > 0) _kpi('${p.years}', tr.mppYears),
                      ],
                    ),
                  ),
                  if (p.compliments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      tr.mppCompliments,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ComplimentGrid(compliments: p.compliments),
                  ],
                  if (p.milestones.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      tr.mppMilestones,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final m in p.milestones)
                      ListTile(
                        key: ValueKey('mpp-milestone-$m'),
                        dense: true,
                        leading: Text(
                          m == 'trips_1000' ? '\u{1F3C6}' : '\u{1F31F}',
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          m == 'trips_1000'
                              ? tr.mppMilestoneTrips1000
                              : tr.mppMilestoneTopRating,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                  if (p.latestReview != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      tr.mppLatestReview,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '“${p.latestReview!.text}”\n${p.latestReview!.name ?? tr.mppAnonymous} · ${profileMonthText(p.latestReview!.month)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: _ink)),
      ],
    ),
  );

  Widget _kpi(String value, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    ),
  );
}
