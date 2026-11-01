import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class MyBank extends StatelessWidget {
  const MyBank({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColor.title,
            size: ResSize.h * 18,
          ),
        ),
        centerTitle: true,
        title: TextWidget(
          text: tr.myBank,
          color: AppColor.title,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        // Audit 2026-11-01: no preview form on a live build.
        actions: [
          if (!LiveDriverServices.active)
            IconButton(
              tooltip: tr.bankPreviewAccountDetails,
              onPressed: () {
                pushSingle(
                  context,
                  TopToBottomTransition(const AddNewAccount()),
                );
              },
              icon: Icon(Icons.add_rounded, size: ResSize.h * 25),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          12.height,
          Text(
            tr.noPayoutAccountConnected,
            style: TextStyle(
              color: Color(0xFF252E3A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (LiveDriverServices.active)
            Text(
              tr.liveBankSoon,
              style: TextStyle(color: Color(0xFF7D898F), height: 1.4),
            )
          else ...[
            Text(
              tr.bankLocalPreviewOnly,
              style: TextStyle(color: Color(0xFF7D898F), height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              tr.bankCheckInPreview,
              style: TextStyle(color: Color(0xFF7D898F), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
