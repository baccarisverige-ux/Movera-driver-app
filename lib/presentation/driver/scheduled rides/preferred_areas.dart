import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';

/// Contract v0.18.172 (`contract.json#preferredAreas`, owner 2026-11-27
/// and 2026-11-28 "Yes, both ways"; mockup v4 row B): the driver picks the
/// areas whose booked rides he wants first. One search field takes an area
/// name or a full address. Areas come from `GET /driver/areas/search`; an
/// address goes through the existing address service ([DestinationSearch],
/// `POST /locations/autocomplete`, `/locations/geocode` only when a
/// suggestion has no position), then `GET /driver/areas/at`, and only the
/// AREA is added. The address text and the point are dropped at once: never
/// kept on the phone, never sent in `PUT /driver/preferred-areas`.
/// The picker only changes the ORDER of booked rides, never who sees one.
class PreferredAreasScreen extends StatefulWidget {
  const PreferredAreasScreen({
    super.key,
    required this.api,
    required this.addresses,
    this.near,
    this.initial,
  });

  final PreferredAreasApi api;

  /// The existing address service (reused, read only).
  final DestinationSearch addresses;

  /// The phone's position, to rank address suggestions nearby.
  final GeoPoint? near;

  /// His saved areas when already known; else read from the server.
  final List<PreferredArea>? initial;

  /// Address search starts at this many characters
  /// (`contract.json#preferredAreas.addressMinChars`).
  static const int addressMinChars = 3;

  /// One search per pause in typing (`addressDebounceMs`): typing "Klock"
  /// fast is one address call, not five.
  static const Duration debounce = Duration(milliseconds: 250);

  /// Address rows shown (the service answers up to 8).
  static const int addressRows = 5;

  @override
  State<PreferredAreasScreen> createState() => _PreferredAreasScreenState();
}

const _ink = Color(0xFF12201C);
const _grey = Color(0xFF7A848A);
const _line = Color(0xFFE6E9EB);

TextStyle _title(double size, {FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: _ink,
      letterSpacing: -0.4,
    );
TextStyle _body(double size, {Color color = _ink, FontWeight? weight}) =>
    GoogleFonts.poppins(
      fontSize: size,
      color: color,
      fontWeight: weight ?? FontWeight.w400,
    );

class _PreferredAreasScreenState extends State<PreferredAreasScreen> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _timer;
  int _searchSeq = 0;

  /// What the server has saved, and what is ticked now.
  List<PreferredArea> _saved = const [];
  final List<PreferredArea> _chosen = [];

  /// Areas of his zone (empty search), and the current search answers.
  List<PreferredArea> _zoneAreas = const [];
  List<PreferredArea> _areas = const [];
  List<DestinationPlace> _addresses = const [];
  bool _loading = true;
  bool _saving = false;
  bool _showEmptyState = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    List<PreferredArea> saved = widget.initial ?? const [];
    List<PreferredArea> zone = const [];
    try {
      if (widget.initial == null) saved = await widget.api.loadPreferredAreas();
      zone = await widget.api.searchAreas('');
    } catch (_) {
      if (mounted) _toast(tr.islandNoConnection);
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _chosen
        ..clear()
        ..addAll(saved);
      _zoneAreas = zone;
      _loading = false;
      _showEmptyState = saved.isEmpty;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _changed {
    if (_chosen.length != _saved.length) return true;
    for (var i = 0; i < _chosen.length; i++) {
      if (_chosen[i].areaId != _saved[i].areaId) return true;
    }
    return false;
  }

  void _onQuery(String text) {
    _timer?.cancel();
    setState(() => _showEmptyState = false);
    _timer = Timer(PreferredAreasScreen.debounce, () => _search(text));
  }

  Future<void> _search(String text) async {
    final seq = ++_searchSeq;
    final q = text.trim();
    if (q.isEmpty) {
      setState(() {
        _areas = const [];
        _addresses = const [];
      });
      return;
    }
    List<PreferredArea> areas = const [];
    List<DestinationPlace> addresses = const [];
    var failed = false;
    await Future.wait([
      widget.api.searchAreas(q).then((found) => areas = found).catchError((
        Object _,
      ) {
        failed = true;
        return const <PreferredArea>[];
      }),
      if (q.length >= PreferredAreasScreen.addressMinChars)
        widget.addresses
            .search(q, near: widget.near)
            .then((found) => addresses = found)
            .catchError((Object _) => const <DestinationPlace>[]),
    ]);
    if (!mounted || seq != _searchSeq) return;
    if (failed && addresses.isEmpty) _toast(tr.islandNoConnection);
    setState(() {
      _areas = areas;
      _addresses = addresses.take(PreferredAreasScreen.addressRows).toList();
    });
  }

  void _toggle(PreferredArea area) {
    setState(() {
      if (_chosen.contains(area)) {
        _chosen.remove(area);
      } else {
        _chosen.add(area);
      }
    });
  }

  /// An address: its point, then the smallest area holding it. Only the
  /// area is kept; [place] and its point are dropped when this returns.
  Future<void> _pickAddress(DestinationPlace place) async {
    final label = place.name;
    DestinationPlace? located;
    try {
      located = await widget.addresses.resolve(place);
    } catch (_) {
      located = null;
    }
    final point = located?.position;
    if (!mounted) return;
    if (point == null) {
      _toast(tr.schedPreferredAreasAddressNotFound);
      return;
    }
    PreferredArea? area;
    try {
      area = await widget.api.areaAt(point.latitude, point.longitude);
    } on ApiError catch (error) {
      if (mounted) {
        _toast(
          error.code == ApiError.network || error.code == ApiError.timeout
              ? tr.islandNoConnection
              : tr.schedPreferredAreasAddressNotFound,
        );
      }
      return;
    } catch (_) {
      if (mounted) _toast(tr.islandNoConnection);
      return;
    }
    if (!mounted) return;
    if (area == null) {
      _toast(tr.schedPreferredAreasNoAreaForAddress);
      return;
    }
    if (_chosen.contains(area)) {
      _toast(tr.schedPreferredAreasAlreadyChosen(area.name));
    } else {
      setState(() => _chosen.add(area!));
      _toast(tr.schedPreferredAreasAddressAdded(label, area.nameWithParent));
    }
    _timer?.cancel();
    _query.clear();
    setState(() {
      _areas = const [];
      _addresses = const [];
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await widget.api.setPreferredAreas([
      for (final a in _chosen) a.areaId,
    ]);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved == null) {
      _toast(tr.islandNoConnection);
      return;
    }
    PreferredAreasStore.saved.value = saved;
    _toast(tr.schedPreferredAreasSaved);
    Navigator.of(context).maybePop(saved);
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Empty search: his ticked areas first, then his zone's areas A-Z.
  List<PreferredArea> get _suggestions => [
    ..._chosen,
    for (final a in _zoneAreas)
      if (!_chosen.contains(a)) a,
  ];

  @override
  Widget build(BuildContext context) {
    final searching = _query.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('preferred-areas-back'),
                    tooltip: tr.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left, color: _ink, size: 28),
                  ),
                  const Spacer(),
                  if (!_showEmptyState)
                    TextButton(
                      key: const ValueKey('preferred-areas-clear'),
                      onPressed: _chosen.isEmpty
                          ? null
                          : () => setState(_chosen.clear),
                      child: Text(
                        tr.schedPreferredAreasClear,
                        style: _body(14, color: _grey),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(tr.schedPreferredAreasTitle, style: _title(28)),
            ),
            if (!_showEmptyState)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Text(
                  tr.schedPreferredAreasSubtitle,
                  style: _body(14, color: _grey),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _ink,
                        strokeWidth: 2,
                      ),
                    )
                  : _showEmptyState
                  ? _empty()
                  : _list(searching),
            ),
            if (_changed && !_showEmptyState)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _line)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('preferred-areas-save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      tr.schedPreferredAreasSave(_chosen.length),
                      style: _body(
                        15,
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on_outlined, color: _ink, size: 34),
        const SizedBox(height: 16),
        Text(
          tr.schedPreferredAreasEmptyTitle,
          textAlign: TextAlign.center,
          style: _title(20),
        ),
        const SizedBox(height: 8),
        Text(
          tr.schedPreferredAreasEmptyBody,
          textAlign: TextAlign.center,
          style: _body(14, color: _grey),
        ),
        const SizedBox(height: 18),
        InkWell(
          key: const ValueKey('preferred-areas-choose'),
          onTap: () {
            setState(() => _showEmptyState = false);
            _focus.requestFocus();
          },
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _ink)),
            ),
            child: Text(
              tr.schedPreferredAreasChoose,
              style: _body(14, weight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    ),
  );

  Widget _list(bool searching) {
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        child: TextField(
          key: const ValueKey('preferred-areas-search'),
          controller: _query,
          focusNode: _focus,
          onChanged: _onQuery,
          style: _body(15),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: tr.schedPreferredAreasSearchHint,
            hintStyle: _body(15, color: _grey),
            prefixIcon: const Icon(Icons.search, color: _grey, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _ink, width: 1.25),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _ink, width: 1.5),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Text(
          tr.schedPreferredAreasAddressPrivacy,
          style: _body(11.5, color: _grey),
        ),
      ),
    ];
    if (!searching) {
      rows.add(_header(tr.schedPreferredAreasSuggestions));
      rows.addAll(_suggestions.map(_areaRow));
    } else {
      if (_areas.isNotEmpty) {
        rows.add(_header(tr.schedPreferredAreasAreasHeader));
        rows.addAll(_areas.map(_areaRow));
      }
      if (_addresses.isNotEmpty) {
        rows.add(_header(tr.schedPreferredAreasAddressesHeader));
        rows.addAll(_addresses.map(_addressRow));
      }
      if (_areas.isEmpty && _addresses.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Text(
              tr.schedPreferredAreasNoMatch,
              style: _body(14, color: _grey),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 4),
    child: Text(
      text.toUpperCase(),
      style: _body(
        11,
        color: _grey,
        weight: FontWeight.w500,
      ).copyWith(letterSpacing: 1.1),
    ),
  );

  Widget _areaRow(PreferredArea area) {
    final on = _chosen.contains(area);
    return InkWell(
      key: ValueKey('preferred-area-${area.areaId}'),
      onTap: () => _toggle(area),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(area.name, style: _body(15.5, weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    area.parentName == null || area.kind == 'kommun'
                        ? area.kindLabel
                        : '${area.kindLabel} · ${area.parentName}',
                    style: _body(12, color: _grey),
                  ),
                ],
              ),
            ),
            _Check(on: on),
          ],
        ),
      ),
    );
  }

  Widget _addressRow(DestinationPlace place) => InkWell(
    key: ValueKey('preferred-address-${place.id}'),
    onTap: () => _pickAddress(place),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: _grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: _body(15, weight: FontWeight.w500)),
                if (place.address.isNotEmpty && place.address != place.name)
                  Text(
                    place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(12, color: _grey),
                  ),
              ],
            ),
          ),
          const Icon(Icons.add, color: _ink, size: 20),
        ],
      ),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? _ink : Colors.white,
      border: Border.all(
        color: on ? _ink : const Color(0xFFC9CED1),
        width: 1.25,
      ),
    ),
    child: on ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
  );
}

/// The house-pin icon on Booked rides with the black count badge ("2" =
/// two areas set). Opens [PreferredAreasScreen].
class PreferredAreasButton extends StatelessWidget {
  const PreferredAreasButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<PreferredArea>>(
        valueListenable: PreferredAreasStore.saved,
        builder: (context, saved, _) => Semantics(
          button: true,
          label: tr.schedPreferredAreasTitle,
          child: InkWell(
            key: const ValueKey('preferred-areas-house'),
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.home_work_outlined,
                    color: Color(0xFF425058),
                    size: 22,
                  ),
                  if (saved.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: const ValueKey('preferred-areas-count'),
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${saved.length}',
                        style: _body(
                          11,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

/// v0.18.172: opens the picker from Booked rides (live builds only), then
/// [then] reads the list again: its order is the server's.
Future<void> openPreferredAreas(
  BuildContext context, {
  required Future<void> Function(LiveReservations live) then,
}) async {
  final services = LiveDriverServices.instance;
  if (services == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PreferredAreasScreen(
        api: services.reservations,
        addresses: ApiDestinationSearch(api: services.api),
        near: services.reporter.lastKnownPoint,
      ),
    ),
  );
  await then(services.reservations);
}
