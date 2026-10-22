import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:circle_progress_bar/circle_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/add_vehicle.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/select%20document%20type/select_doc_typ.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/upload_id.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/vehicle_insurance.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/vehicle_registeration.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class AdditionalInfoNavigationController {
  final ValueNotifier<int> currentPageIndex = ValueNotifier<int>(0);
  final PageController pageController = PageController();
  bool _moving = false;
  bool _closed = false;

  final List<Widget> pages = [
    AdditionDetailAddVehicle(
      circleProgress: (index, total) =>
          ProgressWidget(currentPageIndex: index, totalPages: total),
    ),
    AdditionDetailVehicleRegisteration(
      circleProgress: (index, total) =>
          ProgressWidget(currentPageIndex: index, totalPages: total),
    ),
    AdditionDetailVehicleInsurance(
      circleProgress: (index, total) =>
          ProgressWidget(currentPageIndex: index, totalPages: total),
    ),
    AdditionDetailUploadId(
      circleProgress: (index, total) =>
          ProgressWidget(currentPageIndex: index, totalPages: total),
    ),
  ];

  Future<void> moveToNextStep(BuildContext context) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_moving || _closed || !pageController.hasClients) return;
    _moving = true;
    try {
      if (currentPageIndex.value < pages.length - 1) {
        final next = currentPageIndex.value + 1;
        if (MediaQuery.disableAnimationsOf(context)) {
          pageController.jumpToPage(next);
        } else {
          await pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        }
        if (!_closed) currentPageIndex.value = next;
      } else {
        await pushSingle(context, TopToBottomTransition(SelectDocumentType()));
      }
    } finally {
      _moving = false;
    }
  }

  Future<void> moveToPreviousStep(BuildContext context) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_moving || _closed || !pageController.hasClients) return;
    if (currentPageIndex.value == 0) {
      Navigator.maybePop(context);
      return;
    }
    _moving = true;
    try {
      final previous = currentPageIndex.value - 1;
      if (MediaQuery.disableAnimationsOf(context)) {
        pageController.jumpToPage(previous);
      } else {
        await pageController.animateToPage(
          previous,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
      if (!_closed) currentPageIndex.value = previous;
    } finally {
      _moving = false;
    }
  }

  void onClose() {
    _closed = true;
    pageController.dispose();
    currentPageIndex.dispose();
  }
}

class AdditionalInfoNavigation extends StatefulWidget {
  const AdditionalInfoNavigation({super.key});
  @override
  State<AdditionalInfoNavigation> createState() =>
      _AdditionalInfoNavigationState();
}

class _AdditionalInfoNavigationState extends State<AdditionalInfoNavigation> {
  final controller = AdditionalInfoNavigationController();
  @override
  void dispose() {
    controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // driver-u98: system back (and predictive back) goes one step back,
    // like the on-screen arrow; only the first step leaves the wizard.
    return ValueListenableBuilder<int>(
      valueListenable: controller.currentPageIndex,
      builder: (context, page, scaffold) => PopScope(
        canPop: page == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.moveToPreviousStep(context);
        },
        child: scaffold!,
      ),
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        child: Column(
          children: [
            46.height,
            Row(
              children: [
                IconButton(
                  tooltip: tr.back,
                  onPressed: () => controller.moveToPreviousStep(context),
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: AppColor.title,
                    size: ResSize.h * 22,
                  ),
                ),
              ],
            ),
            16.height,
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: PageView.builder(
                  controller: controller.pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.pages.length,
                  // driver-r3-8: a step keeps what was entered (its
                  // fields and picked document) when it scrolls off.
                  itemBuilder: (BuildContext context, int index) {
                    return _KeepStep(child: controller.pages[index]);
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
              child: ValueListenableBuilder<int>(
                valueListenable: controller.currentPageIndex,
                builder: (context, _, __) => CustomButton(
                  centerContent:
                      controller.currentPageIndex.value <
                          controller.pages.length - 1
                      ? tr.navContinue
                      : tr.verifyAction,
                  onPressed: () {
                    controller.moveToNextStep(context);
                  },
                ),
              ),
            ),
            20.height,
          ],
        ),
      ),
    );
  }
}

/// Keeps an onboarding step's State alive off screen.
class _KeepStep extends StatefulWidget {
  const _KeepStep({required this.child});
  final Widget child;
  @override
  State<_KeepStep> createState() => _KeepStepState();
}

class _KeepStepState extends State<_KeepStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Each progress indicator owns its ticker; no global Get registration.
class ProgressWidget extends StatefulWidget {
  final int currentPageIndex;
  final int totalPages;
  const ProgressWidget({
    super.key,
    required this.currentPageIndex,
    required this.totalPages,
  });
  @override
  State<ProgressWidget> createState() => _ProgressWidgetState();
}

class _ProgressWidgetState extends State<ProgressWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  double get _value => widget.totalPages <= 0
      ? 0
      : ((widget.currentPageIndex + 1) / widget.totalPages).clamp(0.0, 1.0);
  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: _value,
    );
  }

  @override
  void didUpdateWidget(ProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageIndex != widget.currentPageIndex ||
        oldWidget.totalPages != widget.totalPages) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _progress.value = _value;
      } else {
        _progress.animateTo(_value);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.value = _value;
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (_, __) => SizedBox(
      height: ResSize.h * 65,
      width: ResSize.w * 65,
      child: CircleProgressBar(
        animationDuration: Duration.zero,
        strokeWidth: 6,
        backgroundColor: const Color(0xffECECEC),
        foregroundColor: AppColor.primary,
        value: _progress.value,
        child: Center(
          child: TextWidget(
            text: tr.stepOfTotal('${widget.currentPageIndex + 1}', '${widget.totalPages}'),
            fontSize: 12,
            fontWeight: fwSemiBold,
            color: AppColor.title,
          ),
        ),
      ),
    ),
  );
}
