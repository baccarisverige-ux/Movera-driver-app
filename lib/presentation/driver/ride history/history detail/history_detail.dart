import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:flutter/material.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/ride_check_history_entry.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class DriverRideHistoryDetail extends StatefulWidget {
  const DriverRideHistoryDetail({
    super.key,
    required this.record,
    this.loadRideChecks,
  });

  final TripHistoryRecord record;

  /// Ride checks of this trip; the ones saved on this phone by default.
  final Future<List<RideCheckRecord>> Function(String tripId)? loadRideChecks;

  @override
  State<DriverRideHistoryDetail> createState() =>
      _DriverRideHistoryDetailState();
}

class _DriverRideHistoryDetailState extends State<DriverRideHistoryDetail> {
  final PanelController _panelController = PanelController();
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(59.3293, 18.0686),
    zoom: 14.0,
  );

  TripHistoryRecord get _ride => widget.record;

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
    return Scaffold(
      body: SlidingUpPanel(
        color: AppColor.white,
        backdropColor: Colors.transparent,
        backdropOpacity: 0,
        backdropEnabled: true,
        backdropTapClosesPanel: true,
        controller: _panelController,
        margin: EdgeInsets.all(0),
        minHeight: ResSize.h * 120,
        padding: EdgeInsets.symmetric(vertical: ResSize.h * 19),
        boxShadow: [],
        defaultPanelState: PanelState.OPEN,
        maxHeight: ResSize.h * 550,
        parallaxEnabled: false,
        panelBuilder: (ScrollController sc) => panelColumn(sc),
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          child: Stack(
            children: [
              CustomGoogleMap(
                initialPosition: _initialPosition,
                markers: const <Marker>{},
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                trafficEnabled: false,
                buildingsEnabled: true,
                indoorViewEnabled: false,
                mapType: MapType.normal,
                onTap: (LatLng position) {},
              ),
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Text(
                    tr.illustrativeMapArchivedRouteUnavailable,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF252E3A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
                  child: Column(
                    children: [
                      // driver-u154: a named 48 px back target; the circle
                      // is drawn where it was (12 px of the box above it).
                      43.height,
                      Row(
                        children: [
                          Tooltip(
                            message: tr.back,
                            child: InkWell(
                              onTap: () {
                                popOwned(context);
                              },
                              child: SizedBox.square(
                                dimension: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    height: ResSize.h * 24,
                                    width: ResSize.w * 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColor.white,
                                      boxShadow: [
                                        BoxShadow(
                                          offset: const Offset(0, 4),
                                          // ignore: deprecated_member_use
                                          color: Color(0xff606060)
                                              .withValues(alpha: 0.12),
                                          spreadRadius: 6,
                                          blurRadius: 40,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_ios_rounded,
                                        color: AppColor.black,
                                        size: ResSize.h * 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget panelColumn(ScrollController sc) {
    return SingleChildScrollView(
      controller: sc,
      child: Column(
        children: [
          10.height,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
            child: Row(
              children: [
                Container(
                  height: ResSize.h * 56,
                  width: ResSize.w * 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: AssetImage(AppAssets.profileImg),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                12.width,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: _when,
                        color: AppColor.title,
                        fontSize: 16,
                        fontWeight: fwBold,
                      ),
                      3.height,
                      TextWidget(
                        text: _ride.riderName,
                        color: AppColor.subtitle,
                        fontSize: 16,
                        fontWeight: fwBold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          16.height,
          Container(
            height: ResSize.h * 4,
            width: double.infinity,
            color: Color(0xffF9F9F9),
          ),
          16.height,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
            child: _buildPickupDropSection(),
          ),
          16.height,
          Container(
            height: ResSize.h * 4,
            width: double.infinity,
            color: Color(0xffF9F9F9),
          ),
          16.height,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
            child: _buildSummaryRows(context),
          ),
          16.height,
          Container(
            height: ResSize.h * 4,
            width: double.infinity,
            color: Color(0xffF9F9F9),
          ),
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
          50.height,
        ],
      ),
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
    // A trip that did not complete earned no fare and no bonus (as the
    // list shows it); its record keeps only the quoted fare.
    final completed = _ride.status == TripStatus.completed;
    return Column(
      children: [
        _detailRow(tr.rideCost, completed ? _ride.fare : '—'),
        // Q16/Q18: Movera's bonus is in the fare.
        if (_ride.driverBonus case final bonus? when completed) ...[
          6.height,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              WaybillRecord.bonusNote(bonus),
              key: const ValueKey<String>('history-driver-bonus'),
              style: const TextStyle(
                color: Color(0xFF7D898F),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        16.height,
        _detailRow(tr.tip, _ride.tip),
        16.height,
        _detailRow(
          tr.paymentMethod,
          paymentMethodText(_ride.paymentMethod),
          paymentIcon: true,
        ),
        16.height,
        _detailRow(tr.rideType, _ride.category),
        // Q23 / R8-4: on a cash trip, the fare, the cash the driver
        // collected, and the balance: fare − cash, owed by (−) or to (+)
        // the driver, settled in the next payout.
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
              cash.balance.minorUnits == 0
                  ? tr.cashMatchedYourFare
                  : tr.settledInYourNextPayout,
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
