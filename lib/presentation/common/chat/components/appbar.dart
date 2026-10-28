import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/common/chat/trip_call.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class ChatAppBar extends StatelessWidget {
  const ChatAppBar({
    super.key,
    required this.riderDisplayName,
    this.tripId,
    this.onCall,
  });

  final String riderDisplayName;

  /// The trip whose rider a call reaches through a masked number.
  final String? tripId;

  /// Test seam; by default [callRider].
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actionsPadding: EdgeInsets.all(0),
      automaticallyImplyLeading: false,
      backgroundColor: AppColor.white,
      clipBehavior: Clip.none,
      foregroundColor: AppColor.white,
      surfaceTintColor: Colors.transparent,
      leadingWidth: MediaQuery.of(context).size.width * 0.7,
      elevation: 0,
      leading: Row(
        children: [
          8.width,
          IconButton(
            tooltip: tr.back,
            onPressed: () {
              popOwned(context);
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColor.title,
              size: ResSize.h * 23,
            ),
          ),
          Expanded(
            child: Text(
              riderDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwBold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: tr.callRider,
          onPressed: () {
            if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
              return;
            }
            // Contract v0.13.0 §22: a masked call, never the rider's number.
            if (onCall case final call?) return call();
            callRider(context, tripId: tripId);
          },
          icon: Image.asset(AppAssets.phoneOutl, height: ResSize.h * 23),
        ),
        8.width,
      ],
    );
  }
}
