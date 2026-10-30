import 'dart:async';

import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_confirm.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverDestinationResult {
  const DriverDestinationResult({
    required this.position,
    required this.address,
    this.name,
    this.distanceMeters,
    this.durationSeconds,
  });

  final LatLng position;
  final String address;

  /// Place name shown on the confirm sheet ("Stockholm Central").
  final String? name;

  /// Road (or estimated) distance and time from the car when confirmed.
  final double? distanceMeters;
  final double? durationSeconds;
}

class DriverDestinationPicker extends StatefulWidget {
  const DriverDestinationPicker({
    super.key,
    this.origin,
    this.routeRepository,
    this.search,
  });

  /// The car. With it, a chosen place opens the confirm map (arc + one
  /// "Fastest route" option) and only "Confirm destination" returns it.
  final LatLng? origin;
  final RouteRepository? routeRepository;

  /// G3-D3: where addresses are searched. Default: the server's address
  /// search on a live build, the demo's sample places otherwise.
  final DestinationSearch? search;

  static Future<DriverDestinationResult?> open(BuildContext context) {
    return pushSingle<DriverDestinationResult>(
      context,
      MaterialPageRoute(builder: (_) => const DriverDestinationPicker()),
    );
  }

  @override
  State<DriverDestinationPicker> createState() =>
      _DriverDestinationPickerState();
}

class _DriverDestinationPickerState extends State<DriverDestinationPicker> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE3E8E5);
  static const Color _softGreen = Color(0xFFF0F6F2);

  /// How long typing pauses before the server is asked.
  static const Duration _debounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _selectionReturned = false;

  late final DestinationSearch _search =
      widget.search ??
      switch (LiveDriverServices.instance) {
        final live? => ApiDestinationSearch(api: live.api),
        null => const DemoDestinationSearch(),
      };

  /// G3-D3: the driver's last 5 destinations (on this phone).
  List<DestinationPlace> _recent = const [];
  List<DestinationPlace> _found = const [];
  bool _searching = false;
  bool _searchFailed = false;
  Timer? _typing;
  int _asked = 0;

  String get _query => _searchController.text.trim();

  /// Before typing: his recent destinations, then (demo only) the sample
  /// places. A live build has no fixed list (G3-D3).
  List<DestinationPlace> get _results {
    if (_query.isEmpty) {
      final search = _search;
      return [
        ..._recent,
        if (search is DemoDestinationSearch)
          for (final place in search.suggestions)
            if (!_recent.any((r) => r.address == place.address)) place,
      ];
    }
    return _found;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
    unawaited(
      RecentDestinations.load().then((recent) {
        if (mounted) {
          setState(() => _recent = recent);
        }
      }),
    );
  }

  @override
  void dispose() {
    _typing?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _typing?.cancel();
    final query = _query;
    setState(() {
      _searchFailed = false;
      if (query.isEmpty) {
        _found = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (query.isEmpty) {
      return;
    }
    if (_search is DemoDestinationSearch) {
      unawaited(_runSearch(query));
    } else {
      _typing = Timer(_debounce, () => unawaited(_runSearch(query)));
    }
  }

  Future<void> _runSearch(String query) async {
    final asked = ++_asked;
    final origin = widget.origin;
    List<DestinationPlace> found;
    var failed = false;
    try {
      found = await _search.search(
        query,
        near: origin == null
            ? null
            : GeoPoint(origin.latitude, origin.longitude),
      );
    } catch (_) {
      found = const [];
      failed = true;
    }
    if (!mounted || asked != _asked || query != _query) {
      return;
    }
    setState(() {
      _found = found;
      _searching = false;
      _searchFailed = failed;
    });
  }

  Future<void> _select(DestinationPlace choice) async {
    // A closing route remains mounted during its reverse animation. A second
    // tap must not return another result or pop the screen beneath the picker.
    if (_selectionReturned ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _selectionReturned = true;
    final place = await _search.resolve(choice);
    if (!mounted) {
      return;
    }
    final point = place?.position;
    if (place == null || point == null) {
      _selectionReturned = false;
      setState(() => _searchFailed = true);
      return;
    }
    final picked = DriverDestinationResult(
      position: LatLng(point.latitude, point.longitude),
      address: place.address,
      name: place.name,
    );
    final origin = widget.origin;
    if (origin == null) {
      unawaited(RecentDestinations.remember(place));
      Navigator.of(context).pop(picked);
      return;
    }
    Navigator.of(context)
        .push<DriverDestinationResult>(
          MaterialPageRoute(
            builder: (_) => DestinationConfirmScreen(
              origin: origin,
              destination: picked,
              routeRepository: widget.routeRepository,
            ),
          ),
        )
        .then((confirmed) {
          if (!mounted) {
            return;
          }
          if (confirmed == null) {
            _selectionReturned = false; // Back to the list: pick again.
            return;
          }
          unawaited(RecentDestinations.remember(place));
          Navigator.of(context).pop(confirmed);
        });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFB),
      body: SafeArea(
        bottom: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    elevation: 1,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: tr.back,
                      key: const ValueKey<String>('destination-picker-back'),
                      onPressed: () => popOwned(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.destination,
                          style: TextStyle(
                            color: _ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          tr.destChooseOneAddress,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                decoration: BoxDecoration(
                  color: _softGreen,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDEAE2)),
                ),
                child: Row(
                  children: [
                    _DirectionBadge(),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.destTripsInYourDirection,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            tr.destMoveraPrioritizes,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  key: const ValueKey<String>('destination-search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (_) => _onQueryChanged(),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: tr.destAddAddress,
                    hintStyle: const TextStyle(
                      color: Color(0xFF9BA4A8),
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 3),
                      child: Icon(Icons.search_rounded, color: _ink, size: 22),
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: tr.close,
                            key: const ValueKey<String>(
                              'destination-search-clear',
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onQueryChanged();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 19,
                              color: _muted,
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFE6EAE8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFFBFD1C6),
                        width: 1.4,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 19),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _query.isNotEmpty
                          ? tr.destResults
                          : _recent.isNotEmpty
                          ? tr.destRecentAddresses
                          : tr.destSuggestedAddresses,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_query.isNotEmpty && !_searching)
                    Text(
                      tr.destResultsFound(results.length),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              child: _searching && results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: _ink,
                          ),
                        ),
                      ),
                    )
                  : _searchFailed
                  ? _NoDestinationResults(
                      title: tr.destSearchUnavailable,
                      body: tr.destSearchTryAgain,
                    )
                  : results.isEmpty && _query.isEmpty
                  ? _NoDestinationResults(
                      icon: Icons.search_rounded,
                      title: tr.destSearchStart,
                      body: tr.destSearchStartBody,
                    )
                  : results.isEmpty
                  ? const _NoDestinationResults()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 18 + bottomInset),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 66,
                        endIndent: 10,
                        color: _line,
                      ),
                      itemBuilder: (context, index) {
                        final place = results[index];
                        return _DestinationRow(
                          place: place,
                          onTap: () => unawaited(_select(place)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7E1)),
      ),
      child: const Icon(
        Icons.near_me_rounded,
        color: Color(0xFF315E4D),
        size: 18,
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.place, required this.onTap});

  final DestinationPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('destination-result-${place.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  place.recent
                      ? Icons.history_rounded
                      : Icons.location_on_rounded,
                  color: const Color(0xFF46534D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DriverDestinationPickerState._ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DriverDestinationPickerState._muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9AA3A0),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoDestinationResults extends StatelessWidget {
  const _NoDestinationResults({
    this.icon = Icons.location_off_outlined,
    this.title,
    this.body,
  });

  final IconData icon;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Color(0xFF9AA4A0), size: 30),
            SizedBox(height: 10),
            Text(
              title ?? tr.destNoAddressFound,
              style: TextStyle(
                color: Color(0xFF252E3A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              body ?? tr.destTryAnother,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7D898F),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
