import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

Future<T?> showMyQueuePositionSheet<T>(BuildContext context) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return MyQueuePosition();
    },
  );
}

// ignore: must_be_immutable
class MyQueuePosition extends StatelessWidget {
  MyQueuePosition({super.key});

  List<String> categories = [
    "Electric",
    "Comfort",
    "Electric",
    "Electric",
    "Van",
    "Van",
  ];
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            31.height,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: tr.queueClose,
                    onPressed: () => popOwned(context),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: ResSize.h * 24,
                      color: AppColor.title,
                    ),
                  ),
                  Expanded(
                    child: TextWidget(
                      text: tr.queueMyPosition,
                      textAlign: TextAlign.center,
                      color: AppColor.title,
                      fontSize: 16,
                      fontWeight: fwSemiBold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            24.height,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.border, width: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResSize.w * 8,
                        vertical: ResSize.h * 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                AppAssets.hourGlass,
                                height: ResSize.h * 30,
                              ),
                              12.width,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: tr.queueMediumWait,
                                      color: AppColor.black,
                                      fontSize: 16,
                                      fontWeight: fwSemiBold,
                                    ),
                                    2.height,
                                    TextWidget(
                                      text: "15-30 mins EST time",
                                      color: AppColor.subtitle,
                                      fontSize: 14,
                                      fontWeight: fwNormal,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: ResSize.w * 64,
                                child: Image.asset(
                                  AppAssets.queue,
                                  height: ResSize.h * 60,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                          20.height,
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Icon(
                                    Icons.star_outline_rounded,
                                    size: ResSize.h * 28,
                                    color: AppColor.title,
                                  ),
                                  TextWidget(
                                    text: tr.queueSampleRank,
                                    color: AppColor.title,
                                    fontSize: 14,
                                    fontWeight: fwMedium,
                                  ),
                                ],
                              ),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Image.asset(
                                    AppAssets.taxiAhead,
                                    height: ResSize.h * 20,
                                    color: AppColor.title,
                                  ),
                                  TextWidget(
                                    text: tr.queueSampleRank,
                                    color: AppColor.title,
                                    fontSize: 14,
                                    fontWeight: fwMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    AppAssets.medal,
                                    height: ResSize.h * 20,
                                  ),
                                  TextWidget(
                                    text: "2",
                                    color: AppColor.title,
                                    fontSize: 20,
                                    fontWeight: fwSemiBold,
                                  ),
                                  20.width,
                                ],
                              ),
                              Row(
                                children: [
                                  20.width,
                                  TextWidget(
                                    text: "1",
                                    color: AppColor.title,
                                    fontSize: 20,
                                    fontWeight: fwSemiBold,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  16.height,
                  CustomButton(centerContent: tr.queueUnavailablePreview, onPressed: null),
                  24.height,
                  Row(
                    children: [
                      SizedBox(
                        width: ResSize.w * 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Center(
                              child: TextWidget(
                                text: tr.queueRanks,
                                color: AppColor.subtitle,
                                fontSize: 16,
                                fontWeight: fwMedium,
                              ),
                            ),
                            19.height,
                            ...List.generate(
                              categories.length,
                              (index) => Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: ResSize.h * 6,
                                ),
                                child: index > 2
                                    ? TextWidget(
                                        text: "#${index + 1}",
                                        color: AppColor.title,
                                        fontSize: 16,
                                        fontWeight: fwMedium,
                                      )
                                    : Image.asset(
                                        index == 0
                                            ? AppAssets.yellowMedal
                                            : AppAssets.medal,
                                        height: ResSize.h * 25,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      20.width,
                      Expanded(
                        child: SizedBox(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text: tr.category,
                                color: AppColor.subtitle,
                                fontSize: 16,
                                fontWeight: fwMedium,
                              ),
                              19.height,
                              ...List.generate(
                                categories.length,
                                (index) => Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: ResSize.h * 6,
                                  ),
                                  child: TextWidget(
                                    text: categories[index],
                                    color: AppColor.title,
                                    fontSize: 16,
                                    fontWeight: fwMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            60.height,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
