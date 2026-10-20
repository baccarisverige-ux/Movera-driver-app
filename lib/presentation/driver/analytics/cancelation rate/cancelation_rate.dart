import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/expantion_tile.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/rate_rule_note.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class CancelationRate extends StatelessWidget {
  const CancelationRate({
    super.key,
    this.performance = DriverPerformanceConfig.sample,
  });

  /// Sample numbers until the driver's real rates exist: the same ones as
  /// Analytics and the Home performance sheet (UI-10).
  final DriverPerformanceConfig performance;

  /// "2.4%" of the counted offers or trips.
  String get _rateShare => performance.cancellationLabel;

  /// What is left of 100 %.
  String get _otherShare {
    final rest = 100 - performance.cancellationRate;
    return '${rest.toStringAsFixed(rest == rest.roundToDouble() ? 0 : 1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actionsPadding: EdgeInsets.all(0),
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.white,
        clipBehavior: Clip.none,
        foregroundColor: AppColor.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () {
            popOwned(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColor.title,
            size: ResSize.h * 18,
          ),
        ),
        centerTitle: true,
        title: TextWidget(
          text: tr.cancelRateTitle,
          color: AppColor.title,
          fontSize: 16,
          fontWeight: fwMedium,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricHero(),
            _tripsConfirmedSection(),
            _moreInformation(),
            24.height,
          ],
        ),
      ),
    );
  }

  Widget _metricHero() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F7),
      padding: EdgeInsets.symmetric(vertical: 50 * ResSize.h),
      child: Column(
        children: [
          TextWidget(
            text: performance.cancellationLabel,
            color: AppColor.black,
            fontSize: 36,
            fontWeight: fwSemiBold,
          ),
          4.height,
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Image.asset(
                AppAssets.triangle,
                color: AppColor.red,
                height: 17 * ResSize.h,
              ),
              6.width,
              TextWidget(
                text: tr.sample,
                color: AppColor.red,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
              6.width,
              TextWidget(
                text: tr.notYourRealRateYet,
                color: AppColor.subtitle,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripsConfirmedSection() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * ResSize.w,
        vertical: 18 * ResSize.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextWidget(
                  text: tr.tripsConfirmed,
                  color: AppColor.title,
                  fontSize: 20,
                  fontWeight: fwSemiBold,
                ),
              ),
              TextWidget(
                text: '100%',
                color: AppColor.title,
                fontSize: 20,
                fontWeight: fwSemiBold,
              ),
            ],
          ),
          14.height,
          Divider(color: AppColor.subtitle, height: 0, thickness: 0.2),
          14.height,
          Row(
            children: [
              Icon(
                Icons.check_rounded,
                color: AppColor.green,
                size: 22 * ResSize.h,
              ),
              12.width,
              Expanded(
                child: TextWidget(
                  text: tr.completedTripsLower,
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
              ),
              TextWidget(
                text: _otherShare,
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
          12.height,
          Row(
            children: [
              Icon(
                Icons.close_rounded,
                color: const Color(0xFFED6C30),
                size: 22 * ResSize.h,
              ),
              12.width,
              Expanded(
                child: TextWidget(
                  text: tr.canceledTrips,
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
              ),
              TextWidget(
                text: _rateShare,
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
          16.height,
          TextWidget(
            text: tr.sampleNumbersNotReal,
            color: AppColor.title,
            fontSize: 12,
            fontWeight: fwMedium,
          ),
          16.height,
          RateRuleNote(
            key: ValueKey<String>('cancel-rate-rule'),
            title: tr.cancelRateKeepLow,
            body: tr.cancelRateEveryCancelCounts,
          ),
          16.height,
          Divider(color: AppColor.subtitle, height: 0, thickness: 0.2),
        ],
      ),
    );
  }

  Widget _moreInformation() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * ResSize.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: tr.moreInformation,
            color: AppColor.title,
            fontSize: 20,
            fontWeight: fwSemiBold,
          ),
          14.height,
          CustomExpansionTile(
            iconAsset: AppAssets.calculator,
            title: tr.cancelRateHowCalculated,
            child: TextWidget(
              text: tr.cancelRateHowBody,
              color: AppColor.subtitle,
              fontSize: 14,
              fontWeight: fwNormal,
            ),
          ),
          // 6.height,
          CustomExpansionTile(
            iconAsset: AppAssets.infoOutl,
            title: tr.cancelRateWhyMatters,
            child: TextWidget(
              text: tr.cancelRateWhyBody,
              color: AppColor.subtitle,
              fontSize: 14,
              fontWeight: fwNormal,
            ),
          ),
        ],
      ),
    );
  }
}
