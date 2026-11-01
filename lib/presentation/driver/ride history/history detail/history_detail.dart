import 'dart:async';
import 'dart:math' as math;

import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/history/trip_path.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/ride_check_history_entry.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/widgets/map_control_button.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

/// The route of a past ride: the server's path (contract v0.17.0 §25,
/// driven or planned), else the two pins this phone saved, else nothing.
Future<TripPath?> loadPastRidePath(TripHistoryRecord record) async {
  final api = LiveDriverServices.instance?.api;
  final fromServer = api == null
      ? null
      : await LiveTripPath(api: api).load(record.tripId);
  if (fromServer != null) return fromServer;
  final pickup = record.pickupPoint;
  final dropoff = record.dropoffPoint;
  return pickup != null && dropoff != null
      ? TripPath.pinsOnly(pickup, dropoff)
      : null;
}

/// v0.18.10 (owner G8 item 1): a tip the rider gave after the driver left
/// the finished screen: the server's receipt (`GET /driver/trips/{id}/
/// receipt`) has it. Null without a live build, a tip or an answer.
Future<String?> loadPastRideTip(TripHistoryRecord record) async {
  final api = LiveDriverServices.instance?.api;
  if (api == null) return null;
  try {
    final receipt = await api.get(
      '/api/v1/driver/trips/${Uri.encodeComponent(record.tripId)}/receipt',
    );
    return TripTipInfo.tryParse(receipt['tip'])?.amount.formatted;
  } catch (_) {
    return null;
  }
}

/// The Movera line icon of a ride category (the Preferences grid's icons);
/// the car for a category admin added.
String rideCategoryIcon(String category) =>
    switch (category.trim().toLowerCase()) {
      'movera' || 'economy' => AppAssets.rideMovera,
      'comfort' => AppAssets.rideComfort,
      'premium' => AppAssets.ridePremium,
      'priority' => AppAssets.ridePriority,
      'xl' || 'movera xl' => AppAssets.rideXl,
      'electric' => AppAssets.rideElectric,
      'pet' || 'movera pet' => AppAssets.ridePet,
      'booster seat' || 'child_seat' => AppAssets.rideBooster,
      _ => AppAssets.solarCar,
    };

/// A past ride (owner 2026-10-29): the map stays fixed at the top (about
/// 40 % of the screen) with the whole route and the pickup and drop-off
/// pins; only the details below it scroll; back is always on the map.
class DriverRideHistoryDetail extends StatefulWidget {
  const DriverRideHistoryDetail({
    super.key,
    required this.record,
    this.loadRideChecks,
    this.loadPath,
    this.loadTip,
  });

  final TripHistoryRecord record;

  /// Ride checks of this trip; the ones saved on this phone by default.
  final Future<List<RideCheckRecord>> Function(String tripId)? loadRideChecks;

  /// The ride's route; [loadPastRidePath] by default.
  final Future<TripPath?> Function(TripHistoryRecord record)? loadPath;

  /// v0.18.10: reads a tip given after the trip (tests pass their own).
  final Future<String?> Function(TripHistoryRecord record)? loadTip;

  /// Share of the screen height the map takes.
  static const double mapShare = 0.4;

  @override
  State<DriverRideHistoryDetail> createState() =>
      _DriverRideHistoryDetailState();
}

class _DriverRideHistoryDetailState extends State<DriverRideHistoryDetail> {
  static const Color _ink = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF7C868D);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _done = Color(0xFF05663F);
  static const Color _doneFill = Color(0xFFE6F4EC);

  late final Future<TripPath?> _path = (widget.loadPath ?? loadPastRidePath)(
    widget.record,
  );

  TripHistoryRecord get _ride => widget.record;

  /// The server's tip, once read (a tip given after the trip).
  String? _serverTip;

  @override
  void initState() {
    super.initState();
    if (_ride.status == TripStatus.completed ||
        _ride.status == TripStatus.cancelledByRider) {
      (widget.loadTip ?? loadPastRideTip)(_ride).then((tip) {
        if (mounted && tip != null) setState(() => _serverTip = tip);
      });
    }
  }

  /// When the trip ended, in the driver's language; the saved words for
  /// an older record without a time.
  String get _when {
    final at = _ride.completedAt;
    return at == null
        ? _ride.whenLabel
        : '${DriverDates.numericDate(at)}, ${DriverDates.time(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColor.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight =
              constraints.maxHeight * DriverRideHistoryDetail.mapShare;
          return Column(
            children: [
              SizedBox(
                key: const ValueKey<String>('history-detail-map'),
                height: mapHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FutureBuilder<TripPath?>(
                        future: _path,
                        builder: (context, snapshot) => _PastRideMap(
                          path: snapshot.data,
                          topInset: safe.top + 56,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: safe.top + 8,
                      child: MapControlButton(
                        key: const ValueKey<String>('history-detail-back'),
                        tooltip: tr.back,
                        size: 48,
                        onTap: () => popOwned(context),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: _ink,
                          size: 24,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: FutureBuilder<TripPath?>(
                        future: _path,
                        builder: (context, snapshot) =>
                            snapshot.connectionState == ConnectionState.done
                            ? _sourceChip(snapshot.data?.source)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey<String>('history-detail-scroll'),
                  padding: EdgeInsets.only(bottom: safe.bottom + 24),
                  child: _details(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceChip(TripPathSource? source) {
    final text = switch (source) {
      TripPathSource.driven => tr.pastRideRouteDriven,
      TripPathSource.planned => tr.pastRidePlannedRoute,
      TripPathSource.pins || null => tr.pastRideRouteUnavailable,
    };
    return Container(
      key: const ValueKey<String>('history-route-source'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172027).withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 8, color: const Color(0xffF9F9F9));

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            screenHorizPadding,
            20,
            screenHorizPadding,
            16,
          ),
          child: _header(),
        ),
        _divider(),
        16.height,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: _buildPickupDropSection(),
        ),
        16.height,
        _divider(),
        16.height,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: _buildSummaryRows(context),
        ),
        16.height,
        _divider(),
        16.height,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: RideCheckHistoryEntry(
            tripId: _ride.tripId,
            load: widget.loadRideChecks,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: _buildMetaRows(),
        ),
      ],
    );
  }

  /// The ride's category icon, when it ended and how (owner 2026-10-29:
  /// no person photo).
  Widget _header() {
    final completed = _ride.status == TripStatus.completed;
    return Row(
      children: [
        Container(
          key: const ValueKey<String>('history-category-icon'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _tile,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            rideCategoryIcon(_ride.category),
            colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
          ),
        ),
        14.width,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _when,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              6.height,
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    key: const ValueKey<String>('history-status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: completed ? _doneFill : _tile,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tripOutcomeText(_ride.status),
                      style: TextStyle(
                        color: completed ? _done : _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    categoryNameText(_ride.category),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickupDropSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: ResSize.h * 92,
          child: Column(
            children: [
              5.height,
              Container(
                height: ResSize.h * 32,
                width: ResSize.w * 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.liteBlue,
                ),
                child: Center(
                  child: Image.asset(
                    AppAssets.locationFill,
                    height: ResSize.h * 20,
                  ),
                ),
              ),
              Expanded(
                child: DottedLine(
                  dashLength: 3,
                  dashGapLength: 3,
                  lineThickness: 1.4,
                  dashColor: AppColor.black,
                  direction: Axis.vertical,
                ),
              ),
              Container(
                height: ResSize.h * 32,
                width: ResSize.w * 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.liteBlue,
                ),
                child: Center(
                  child: Image.asset(AppAssets.arrowUp, height: ResSize.h * 16),
                ),
              ),
            ],
          ),
        ),
        12.width,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    text: tr.pickupFrom,
                    color: const Color(0xffA3A3A3),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: _ride.pickup,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColor.title,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              18.height,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    text: tr.dropOffLocation,
                    color: const Color(0xffA3A3A3),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: _ride.dropoff,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColor.title,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool paymentIcon = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextWidget(
            text: label,
            color: AppColor.subtitle,
            fontSize: 16,
            fontWeight: fwBold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              if (paymentIcon && value != '—') ...[
                Image.asset(
                  AppAssets.wallet2,
                  color: AppColor.title,
                  height: 22,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: TextWidget(
                  text: value,
                  color: AppColor.title,
                  textAlign: TextAlign.end,
                  fontSize: 16,
                  fontWeight: fwBold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRows(BuildContext context) {
    // A trip that did not complete earned nothing and no bonus (as the
    // list shows it); its record keeps only the quoted pay.
    final completed = _ride.status == TripStatus.completed;
    return Column(
      children: [
        // The driver's own money (owner decision 2026-10-26), or a cancel
        // or no-show fee the driver earned (driver-r5-13).
        _detailRow(
          tr.yourEarnings,
          completed ? _ride.fare : _ride.feeEarned ?? '—',
        ),
        16.height,
        _detailRow(tr.tip, _serverTip ?? _ride.tip),
        16.height,
        _detailRow(
          tr.paymentMethod,
          paymentMethodText(_ride.paymentMethod),
          paymentIcon: true,
        ),
        16.height,
        _detailRow(tr.rideType, categoryNameText(_ride.category)),
        // Q23 / R8-4: on a cash trip, the cash the driver collected and
        // the balance: earnings − cash, owed by (−) or to (+) the driver,
        // settled in the next payout.
        if (_ride.cashBalance case final cash?) ...[
          16.height,
          _detailRow(tr.cashCollected, cash.cashCollected.formatted),
          16.height,
          KeyedSubtree(
            key: const ValueKey<String>('history-cash-balance'),
            child: _detailRow(cash.directionLabel, cash.signedLabel),
          ),
          8.height,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              // driver-r5-34: a zero balance means the cash matched the
              // driver's earnings (the record's fare, owner decision
              // 2026-10-26), never a rider's fare.
              cash.balance.minorUnits != 0
                  ? tr.settledInYourNextPayout
                  : tr.cashMatchedYourEarnings,
              key: const ValueKey<String>('history-owed-note'),
              style: const TextStyle(
                color: Color(0xFF7D898F),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRows() {
    final outcome = _ride.status == TripStatus.completed
        ? tr.rideCompletedOn
        : tripOutcomeText(_ride.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow(tr.tripId, _ride.tripId),
        20.height,
        _detailRow(outcome, _when),
      ],
    );
  }
}

/// The past ride's map: the route line in the Movera route colours, the
/// Movera pickup and drop-off pins, fitted to the whole route. It does not
/// move with a finger: the screen around it stays put.
class _PastRideMap extends StatefulWidget {
  const _PastRideMap({required this.path, required this.topInset});

  final TripPath? path;

  /// Room the back button takes at the top.
  final double topInset;

  @override
  State<_PastRideMap> createState() => _PastRideMapState();
}

class _PastRideMapState extends State<_PastRideMap> {
  static const LatLng _stockholm = LatLng(59.3293, 18.0686);
  GoogleMapController? _controller;
  Set<Marker> _markers = const {};
  Timer? _fitTimer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_buildMarkers());
  }

  @override
  void didUpdateWidget(covariant _PastRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      unawaited(_buildMarkers());
      _fit();
    }
  }

  @override
  void dispose() {
    _generation++;
    _fitTimer?.cancel();
    super.dispose();
  }

  Future<void> _buildMarkers() async {
    final generation = ++_generation;
    final path = widget.path;
    if (path == null) return;
    Future<Marker> pin(String id, GeoPoint at, RouteMarkKind kind) async {
      BitmapDescriptor icon;
      try {
        icon = await RouteMarkPins.pin(kind);
      } catch (_) {
        icon = BitmapDescriptor.defaultMarker;
      }
      return Marker(
        markerId: MarkerId(id),
        position: at.toLatLng(),
        icon: icon,
        anchor: RouteMarkPins.pinAnchor,
        zIndexInt: kind == RouteMarkKind.stop ? 1 : 2,
      );
    }

    final markers = <Marker>{
      await pin('history-pickup', path.pickup, RouteMarkKind.pickup),
      for (var i = 0; i < path.stops.length; i++)
        await pin('history-stop-$i', path.stops[i], RouteMarkKind.stop),
      await pin('history-dropoff', path.dropoff, RouteMarkKind.dropoff),
    };
    if (mounted && generation == _generation) {
      setState(() => _markers = markers);
    }
  }

  LatLngBounds? _bounds() {
    final points = widget.path?.extent;
    if (points == null || points.isEmpty) return null;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _fit() {
    final controller = _controller;
    final bounds = _bounds();
    if (controller == null || bounds == null) return;
    // Let the map lay out first: fitting a map of no size throws.
    _fitTimer?.cancel();
    _fitTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      try {
        await controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 48));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final bounds = _bounds();
    return CustomGoogleMap(
      initialPosition: CameraPosition(
        target: bounds == null
            ? _stockholm
            : LatLng(
                (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
                (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
              ),
        zoom: 12,
      ),
      markers: _markers,
      polylines: path == null || path.points.length < 2
          ? const <Polyline>{}
          : DriverRouteStyle.polylines(
              id: 'history-route',
              points: [for (final p in path.points) p.toLatLng()],
              zoom: 12,
            ),
      padding: EdgeInsets.only(top: widget.topInset, bottom: 36),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      webCameraControlEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _fit();
      },
    );
  }
}
