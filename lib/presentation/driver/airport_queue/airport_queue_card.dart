import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/airport/airport_queue.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

/// Fix job 9 (contract v0.18.36 §60): the Home card with the driver's real
/// place in the airport queue (server), shown only while he is in one; when
/// he leaves it the app says "You left the airport queue".
class AirportQueueCard extends StatefulWidget {
  const AirportQueueCard({super.key, this.poll = true});

  /// Reads GET /driver/airport-queue every 20 s (off in tests).
  final bool poll;

  @override
  State<AirportQueueCard> createState() => _AirportQueueCardState();
}

class _AirportQueueCardState extends State<AirportQueueCard> {
  final AirportQueue _queue = AirportQueue.instance;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_changed);
    final api = LiveDriverServices.instance?.api;
    if (widget.poll && api != null) {
      _queue.startPolling(api);
      _polling = true;
    }
  }

  @override
  void dispose() {
    _queue.removeListener(_changed);
    if (_polling) _queue.stopPolling();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_queue.takeLeftNotice()) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(tr.airportQueueLeft)));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final status = _queue.status;
    if (status == null || !status.inQueue) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('airport-queue-card'),
      padding: EdgeInsets.symmetric(
        horizontal: ResSize.w * 16,
        vertical: ResSize.h * 11,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColor.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff262626).withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(AppAssets.flight, height: ResSize.h * 42),
          16.width,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: tr.airportQueueTitle,
                  fontSize: 16,
                  fontWeight: fwSemiBold,
                  color: AppColor.title,
                ),
                4.height,
                TextWidget(
                  text: tr.airportQueuePlace('${status.position}'),
                  fontSize: 14,
                  fontWeight: fwSemiBold,
                  color: AppColor.title,
                ),
                4.height,
                TextWidget(
                  text: tr.airportQueueAheadWaiting(
                    '${status.ahead}',
                    '${status.waitingMin ?? 0}',
                  ),
                  fontSize: 12,
                  fontWeight: fwMedium,
                  color: AppColor.subtitle,
                ),
                4.height,
                TextWidget(
                  text: tr.airportQueueHow,
                  fontSize: 12,
                  fontWeight: fwMedium,
                  color: AppColor.subtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
