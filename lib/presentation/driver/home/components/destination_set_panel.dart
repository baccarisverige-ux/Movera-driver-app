import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class DestinationSetPanel extends StatefulWidget {
  final Widget body;
  final VoidCallback? onClose;
  final PanelController controller;

  /// The destination the driver picked (driver group 3: was a fixed demo
  /// address, "1141 central park, DHA"); empty while it is looked up.
  final String address;

  const DestinationSetPanel({
    super.key,
    required this.onClose,
    required this.controller,
    required this.body,
    required this.address,
  });

  @override
  State<DestinationSetPanel> createState() => _DestinationSetPanelState();
}

class _DestinationSetPanelState extends State<DestinationSetPanel> {
  bool isPanelOpen = false;
  // final PanelController _panelController = PanelController();
  @override
  Widget build(BuildContext context) {
    return SlidingUpPanel(
      color: AppColor.white,
      backdropColor: Colors.transparent,
      backdropOpacity: 0,
      backdropEnabled: false, // Changed to false
      backdropTapClosesPanel: false,
      controller: widget.controller,
      margin: EdgeInsets.all(0),
      minHeight: ResSize.h * 95,
      padding: EdgeInsets.symmetric(vertical: ResSize.h * 19),
      boxShadow: [],
      isDraggable: true,
      defaultPanelState: PanelState.OPEN,
      maxHeight: ResSize.h * 461,
      parallaxEnabled: false,
      onPanelSlide: (double pos) {
        setState(() {
          isPanelOpen = pos > 0.3;
        });
      },
      collapsed: InkWell(
        onTap: () {
          widget.controller.open();
        },
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 150),
                opacity: 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        widget.controller.open(); // Use the passed controller
                      },
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: ResSize.h * 24,
                        color: AppColor.title,
                      ),
                    ),
                    Column(
                      children: [
                        TextWidget(
                          text: tr.destinationSet,
                          fontSize: 16,
                          fontWeight: fwSemiBold,
                          color: AppColor.darkTitle,
                        ),
                        2.height,
                        TextWidget(
                          text: widget.address,
                          fontSize: 14,
                          fontWeight: fwMedium,
                          color: AppColor.subtitle,
                        ),
                      ],
                    ),
                    Image.asset(
                      AppAssets.menu,
                      height: ResSize.h * 12,
                      color: AppColor.title,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      panelBuilder: (ScrollController sc) => panelColumn(sc),
      body: widget.body,
    );
  }

  Widget panelColumn(ScrollController sc) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 150),
      opacity: isPanelOpen ? 1.0 : 0.0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    widget.controller.close(); // Use the passed controller
                    widget.onClose
                        ?.call(); // Call the onClose callback if provided
                  },
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: ResSize.h * 24,
                    color: AppColor.title,
                  ),
                ),
                TextWidget(
                  text: tr.recommendations,
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwSemiBold,
                ),
                SizedBox(width: ResSize.w * 24),
              ],
            ),
          ),
          24.height,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenHorizPadding,
                vertical: ResSize.h * 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xffDADADA), width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: ResSize.h * 24,
                    width: ResSize.w * 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColor.primary,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        size: ResSize.h * 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  16.width,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: tr.destination,
                          color: AppColor.title,
                          fontSize: 16,
                          fontWeight: fwSemiBold,
                        ),
                        6.height,
                        TextWidget(
                          text: widget.address,
                          color: AppColor.subtitle,
                          fontSize: 14,
                          fontWeight: fwNormal,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_vert_rounded,
                    size: ResSize.h * 24,
                    color: AppColor.title,
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColor.white,
              border: Border(
                top: BorderSide(color: Color(0xffEFEFEF), width: 1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
              child: Column(
                children: [
                  11.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(AppAssets.homeImage1, height: ResSize.h * 36),
                      InkWell(
                        onTap: widget.onClose,
                        child: Container(
                          height: ResSize.h * 57,
                          width: ResSize.w * 57,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: Center(
                            child: Image.asset(
                              AppAssets.homeImage2,
                              height: ResSize.h * 40,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Image.asset(AppAssets.homeImage3, height: ResSize.h * 36),
                    ],
                  ),
                  55.height,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
