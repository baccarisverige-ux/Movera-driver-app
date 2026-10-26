import 'package:movera/core/l10n/driver_l10n.dart';
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
  const DriverDestinationPicker({super.key, this.origin, this.routeRepository});

  /// The car. With it, a chosen place opens the confirm map (arc + one
  /// "Fastest route" option) and only "Confirm destination" returns it.
  final LatLng? origin;
  final RouteRepository? routeRepository;

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

  static const List<_DestinationPlace> _places = [
    _DestinationPlace(
      id: 'stockholm-central',
      name: 'Stockholm Central',
      address: 'Centralplan 15, Stockholm',
      position: LatLng(59.3300, 18.0581),
      icon: Icons.train_rounded,
    ),
    _DestinationPlace(
      id: 'solna',
      name: 'Solna centrum',
      address: 'Solna Torg, Solna',
      position: LatLng(59.3603, 18.0009),
      icon: Icons.location_city_rounded,
    ),
    _DestinationPlace(
      id: 'kista',
      name: 'Kista centrum',
      address: 'Kista Galleria, Stockholm',
      position: LatLng(59.4032, 17.9448),
      icon: Icons.apartment_rounded,
    ),
    _DestinationPlace(
      id: 'sodertalje',
      name: 'Södertälje centrum',
      address: 'Storgatan, Södertälje',
      position: LatLng(59.1955, 17.6253),
      icon: Icons.location_on_rounded,
    ),
    _DestinationPlace(
      id: 'arlanda',
      name: 'Arlanda Airport',
      address: 'Stockholm Arlanda Airport',
      position: LatLng(59.6519, 17.9186),
      icon: Icons.flight_takeoff_rounded,
    ),
    _DestinationPlace(
      id: 'bromma',
      name: 'Bromma Airport',
      address: 'Flygplatsinfarten, Bromma',
      position: LatLng(59.3544, 17.9422),
      icon: Icons.flight_rounded,
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _selectionReturned = false;

  List<_DestinationPlace> get _results {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _places.take(4).toList();
    }
    return _places.where((place) {
      return place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(_DestinationPlace place) {
    // A closing route remains mounted during its reverse animation. A second
    // tap must not return another result or pop the screen beneath the picker.
    if (_selectionReturned ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _selectionReturned = true;
    final picked = DriverDestinationResult(
      position: place.position,
      address: place.address,
      name: place.name,
    );
    final origin = widget.origin;
    if (origin == null) {
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
                  onChanged: (_) => setState(() {}),
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
                              setState(() {});
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
                      _searchController.text.trim().isEmpty
                          ? tr.destSuggestedAddresses
                          : tr.destResults,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_searchController.text.trim().isNotEmpty)
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
              child: results.isEmpty
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
                          onTap: () => _select(place),
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

  final _DestinationPlace place;
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
                  place.icon,
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
  const _NoDestinationResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              color: Color(0xFF9AA4A0),
              size: 30,
            ),
            SizedBox(height: 10),
            Text(
              tr.destNoAddressFound,
              style: TextStyle(
                color: Color(0xFF252E3A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              tr.destTryAnother,
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

class _DestinationPlace {
  const _DestinationPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.icon,
  });

  final String id;
  final String name;
  final String address;
  final LatLng position;
  final IconData icon;
}
