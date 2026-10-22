import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/safety/ride_check_l10n.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';

// Solar line icons only in this feature, tinted to the text around them.
Widget _solar(String asset, Color color, double size) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

/// Look of the Ride check card (see the approved mockup).
abstract final class RideCheckStyle {
  static const Color glass = Color(0xBD080A0C); // black at 74 %
  static const Color red = Color(0xFFE5372A);
  static const Color dot = Color(0xFFFF4D3D);
  static const Color redRowIcon = Color(0xFFFF7A6E);
  static const Color ink = Color(0xFF111518);
  static const double radius = 34;
  static const double margin = 10;
  static const double blur = 24;

  static Color white(double alpha) => Colors.white.withValues(alpha: alpha);

  /// A Solar icon, e.g. for the demo entries in the island's tools sheet.
  static Widget icon(String asset, {required Color color, double size = 22}) =>
      _solar(asset, color, size);

  /// Icon for each row.
  static String topicIcon(RideCheckTopic topic) => switch (topic) {
    RideCheckTopic.accident => AppAssets.solarDangerTriangle,
    RideCheckTopic.hurt => AppAssets.solarHeartPulse,
    RideCheckTopic.unsafe => AppAssets.solarShieldUser,
    RideCheckTopic.carProblem => AppAssets.solarCar,
    RideCheckTopic.riderAskedStop => AppAssets.solarMapPointWave,
    RideCheckTopic.traffic => AppAssets.solarRouting3,
    RideCheckTopic.riderStopHere => AppAssets.solarMapPointWave,
    RideCheckTopic.riderChangedDestination => AppAssets.solarMapArrowSquare,
    RideCheckTopic.roadClosed => AppAssets.solarForbiddenCircle,
    RideCheckTopic.riderOtherRoute => AppAssets.solarRouting2,
    RideCheckTopic.somethingElse => AppAssets.solarChatRoundDots,
  };

  /// Icon in the reason chip.
  static String triggerIcon(RideCheckTrigger trigger) => switch (trigger) {
    RideCheckTrigger.longStop => AppAssets.solarClockCircle,
    RideCheckTrigger.droppedFar => AppAssets.solarMapPoint,
    RideCheckTrigger.offRoute => AppAssets.solarRouting3,
    RideCheckTrigger.possibleCrash => AppAssets.solarDangerTriangle,
  };
}

/// The island's first face: a black pill that pulses red.
class RideCheckPillFace extends StatelessWidget {
  const RideCheckPillFace({super.key});

  static String get title => tr.isEverythingOkQuestion;

  /// Same size as the trip's Home island, so the change is only its face.
  static Size sizeFor(double available) => Size(
    math.min(available, TripIslandGeometry.width),
    TripIslandGeometry.height,
  );

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: tr.rideCheckTitle(title),
    excludeSemantics: true,
    child: _Pulse(
      builder: (context, pulse) => DecoratedBox(
        key: const ValueKey('ride-check-pill'),
        decoration: BoxDecoration(
          color: RideCheckStyle.red.withValues(alpha: .22 * pulse),
          borderRadius: BorderRadius.circular(TripIslandGeometry.height / 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PulseDot(pulse: pulse),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The card over the trip map. It grows from the island, blocks everything
/// under it, and only closes after an answer. No close button, no swipe, and
/// Back does nothing.
class RideCheckLayer extends StatefulWidget {
  const RideCheckLayer({
    super.key,
    required this.controller,
    required this.top,
    required this.maxHeight,
  });

  final RideCheckController controller;

  /// Where the island sits.
  final double top;
  final double maxHeight;

  @override
  State<RideCheckLayer> createState() => _RideCheckLayerState();
}

class _RideCheckLayerState extends State<RideCheckLayer>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    reverseDuration: RideCheckController.closeDuration,
  );
  late final AnimationController _resize = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  RideCheckPhase _phase = RideCheckPhase.idle;
  Object? _screen;
  Size? _visible;
  Size? _resizeFrom;
  final TextEditingController _note = TextEditingController();

  RideCheckController get _c => widget.controller;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _sync();
  }

  @override
  void didUpdateWidget(RideCheckLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _sync();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _open.dispose();
    _resize.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _changed() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  void _sync() {
    final phase = _c.phase;
    final screen = (_c.step, _c.topic, _c.event);
    if (phase != _phase) {
      final instant = _c.instant || _reduced;
      switch (phase) {
        case RideCheckPhase.card:
          _note.clear();
          if (instant) {
            _open.value = 1;
          } else {
            _open.forward(from: 0);
          }
          _resize.value = 1;
        case RideCheckPhase.closing:
          if (instant) {
            _open.value = 0;
          } else {
            _open.reverse(from: _open.value);
          }
        case RideCheckPhase.idle:
        case RideCheckPhase.pill:
          _open.value = 0;
      }
    } else if (phase == RideCheckPhase.card && screen != _screen) {
      // A new screen of the card: its height changes smoothly.
      _resizeFrom = _visible;
      if (_resizeFrom != null && !_reduced && !_open.isAnimating) {
        _resize.forward(from: 0);
      }
    }
    _phase = phase;
    _screen = screen;
  }

  @override
  Widget build(BuildContext context) {
    final phase = _c.phase;
    if (phase == RideCheckPhase.idle || _c.event == null) {
      return const SizedBox.shrink();
    }
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          // Nothing under the card can be used until the driver answers;
          // the map stays visible around it.
          const Positioned.fill(
            child: ModalBarrier(
              key: ValueKey('ride-check-barrier'),
              dismissible: false,
              color: Colors.transparent,
            ),
          ),
          if (phase != RideCheckPhase.pill)
            Positioned(
              top: widget.top,
              left: RideCheckStyle.margin,
              right: RideCheckStyle.margin,
              child: Align(
                alignment: Alignment.topCenter,
                child: LayoutBuilder(
                  builder: (context, constraints) => _morph(constraints),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _morph(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    // The pill matches the island inside its 12 px trip margins.
    final pill = RideCheckPillFace.sizeFor(
      width + 2 * RideCheckStyle.margin - 24,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_open, _resize]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_open.value);
        final resizing = _resize.value < 1 && _resizeFrom != null;
        final from = resizing ? _resizeFrom! : pill;
        final progress = resizing
            ? Curves.easeOutCubic.transform(_resize.value)
            : t;
        final radius = ui.lerpDouble(pill.height / 2, RideCheckStyle.radius, t)!;
        final cardOpacity = ((t - .15) / .85).clamp(0.0, 1.0);
        final pillOpacity = (1 - t / .35).clamp(0.0, 1.0);
        final shape = BorderRadius.circular(radius);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: const Color(0x59000000).withValues(alpha: .35 * t),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          position: DecorationPosition.background,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(color: RideCheckStyle.white(.9), width: .5),
            ),
            child: ClipRRect(
              borderRadius: shape,
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: RideCheckStyle.blur,
                  sigmaY: RideCheckStyle.blur,
                ),
                child: ColoredBox(
                  color: Color.lerp(
                    const Color(0xF5080A0C),
                    RideCheckStyle.glass,
                    t,
                  )!,
                  child: _Reveal(
                    from: from,
                    progress: progress,
                    onLayout: (visible) => _visible = visible,
                    child: SizedBox(
                      width: width,
                      child: Stack(
                        children: [
                          IgnorePointer(
                            ignoring: cardOpacity < .5 ||
                                _c.phase != RideCheckPhase.card,
                            child: Opacity(
                              opacity: cardOpacity,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: math.max(
                                    pill.height,
                                    widget.maxHeight,
                                  ),
                                ),
                                child: RideCheckCard(
                                  controller: _c,
                                  note: _note,
                                ),
                              ),
                            ),
                          ),
                          if (pillOpacity > 0)
                            Positioned(
                              top: 0,
                              left: (width - pill.width) / 2,
                              width: pill.width,
                              height: pill.height,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: pillOpacity,
                                  child: const RideCheckPillFace(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// All the card's content, top to bottom, for the current screen.
class RideCheckCard extends StatelessWidget {
  const RideCheckCard({super.key, required this.controller, required this.note});

  final RideCheckController controller;
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final event = c.event!;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Semantics(
          key: const ValueKey('ride-check-card'),
          container: true,
          liveRegion: true,
          label: tr.rideCheck,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: switch (c.step) {
              RideCheckStep.main => _main(event),
              RideCheckStep.followUp => _followUp(c.topic!),
              RideCheckStep.called => _called(),
            },
          ),
        ),
      ),
    );
  }

  Widget _header(String text) => Row(
    children: [
      _solar(AppAssets.solarShieldWarning, RideCheckStyle.white(.65), 14),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: RideCheckStyle.white(.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
      ),
      const _Pulse(builder: _dot),
    ],
  );

  static Widget _dot(BuildContext context, double pulse) =>
      _PulseDot(pulse: pulse);

  Widget _main(RideCheckEvent event) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(tr.rideCheck),
        const SizedBox(height: 8),
        Text(
          tr.isEverythingOkQuestion,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('ride-check-reason'),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: RideCheckStyle.white(.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _solar(
                RideCheckStyle.triggerIcon(event.trigger),
                RideCheckStyle.white(.8),
                18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: event.reason.lead),
                      TextSpan(
                        text: event.reason.bold,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: event.reason.trail),
                    ],
                  ),
                  style: TextStyle(
                    color: RideCheckStyle.white(.8),
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // driver-u92: side by side only when both labels fit whole;
        // otherwise one above the other, so "Call 112" keeps its number.
        LayoutBuilder(
          builder: (context, constraints) {
            final call = _button(
              key: const ValueKey('ride-check-call-112'),
              label: tr.call112,
              icon: AppAssets.solarPhoneCalling,
              background: RideCheckStyle.red,
              foreground: Colors.white,
              onTap: c.callEmergency,
            );
            final ok = _button(
              key: const ValueKey('ride-check-ok'),
              label: tr.iMOk,
              icon: AppAssets.solarCheckCircle,
              background: Colors.white,
              foreground: RideCheckStyle.ink,
              onTap: c.imOk,
            );
            final room = (constraints.maxWidth - 9) / 2 - _buttonIconRoom;
            final scaler = MediaQuery.textScalerOf(context);
            if (_labelFits(tr.call112, room, scaler) && _labelFits(tr.iMOk, room, scaler)) {
              return Row(
                children: [
                  Expanded(child: call),
                  const SizedBox(width: 9),
                  Expanded(child: ok),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [call, const SizedBox(height: 9), ok],
            );
          },
        ),
        // Owner decision 10: hidden while the option is off, except a
        // recording already under way, which keeps its Stop.
        if (_RecordAudio.shown(c)) ...[
          const SizedBox(height: 10),
          _RecordAudio(controller: c),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
          child: Text(
            tr.orTellUsWhatSHappening,
            style: TextStyle(
              color: RideCheckStyle.white(.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (index, topic) in c.topics.indexed)
          _row(topic, last: index == c.topics.length - 1),
        _footer(tr.yourAnswerIsSavedToThis),
      ],
    );
  }

  Widget _row(RideCheckTopic topic, {required bool last}) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      key: ValueKey('ride-check-row-${topic.name}'),
      onTap: () => controller.choose(topic),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: RideCheckStyle.white(.12),
                    width: .5,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: topic.red
                    ? RideCheckStyle.red.withValues(alpha: .22)
                    : RideCheckStyle.white(.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: _solar(
                RideCheckStyle.topicIcon(topic),
                topic.red ? RideCheckStyle.redRowIcon : Colors.white,
                18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                topic.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _solar(AppAssets.solarAltArrowRight, RideCheckStyle.white(.35), 15),
          ],
        ),
      ),
    ),
  );

  Widget _followUp(RideCheckTopic topic) {
    final c = controller;
    final questions = topic.questions;
    final children = <Widget>[
      _header(tr.rideCheckShort(topic.shortText)),
      const _Steps(),
    ];
    if (topic == RideCheckTopic.somethingElse) {
      children.addAll([
        _Question(tr.whatIsHappeningQuestion),
        const SizedBox(height: 10),
        _NoteField(controller: note, onChanged: c.setNote),
      ]);
    } else if (questions.isEmpty) {
      children.add(_Question(tr.thanksThisIsSavedToTrip));
    }
    for (final (index, question) in questions.indexed) {
      children.addAll([
        if (index > 0) const SizedBox(height: 18),
        _Question(question.shown, small: index > 0),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, option) in question.options.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Choice(
                  key: ValueKey('ride-check-option-${question.text}-$option'),
                  label: RideCheckQuestionText.option(option),
                  selected: c.pick(question) == option,
                  onTap: () => c.answer(question, option),
                ),
              ),
            ],
          ],
        ),
        if (index == 0 && topic.red) ...[
          if (c.alertSent || c.alertFailed) _alertNote(),
          _big112(),
        ],
      ]);
    }
    children.addAll([
      const SizedBox(height: 16),
      _button(
        key: const ValueKey('ride-check-done'),
        label: tr.done,
        background: Colors.white,
        foreground: RideCheckStyle.ink,
        height: 48,
        onTap: c.done,
      ),
      _footer(tr.yourAnswersAreSavedToThis),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _called() {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(tr.rideCheck112),
        const _Steps(),
        _Question(tr.call112OnYourPhone),
        const SizedBox(height: 6),
        Text(
          c.dialFailed
              ? tr.couldNotOpenDialerDial112
              : tr.yourDialerOpensWith112Movera,
          key: const ValueKey('ride-check-dial-status'),
          style: TextStyle(
            color: RideCheckStyle.white(.8),
            fontSize: 13.5,
            height: 1.35,
          ),
        ),
        if (c.alertSent || c.alertFailed) _alertNote(),
        _big112(),
        const SizedBox(height: 16),
        _button(
          key: const ValueKey('ride-check-done'),
          label: tr.done,
          background: Colors.white,
          foreground: RideCheckStyle.ink,
          height: 48,
          onTap: c.done,
        ),
        _footer(tr.yourAnswersAreSavedToThis),
      ],
    );
  }

  Widget _alertNote() {
    final failed = controller.alertFailed;
    // driver-49: the demo outbox keeps the alert in memory; nothing reached
    // Movera, so the card must not say the safety team was alerted.
    final demo = !failed && controller.services.alerts is DemoSafetyAlertRepository;
    return Container(
      key: ValueKey(failed ? 'ride-check-alert-failed' : 'ride-check-alert-sent'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RideCheckStyle.white(.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _solar(AppAssets.solarBellBing, Colors.white, 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: failed
                        ? tr.moveraCouldNotBeAlerted
                        : demo
                        ? tr.safetyAlertKeptOnPhoneDemo
                        : tr.moveraSafetyTeamAlerted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: failed || demo
                        ? tr.call112IfYouNeedHelp
                        : tr.tripDriverAndRiderDetailsWere,
                  ),
                ],
              ),
              style: TextStyle(
                color: RideCheckStyle.white(.8),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _big112() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Material(
      color: RideCheckStyle.red,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('ride-check-big-112'),
        onTap: controller.callEmergency,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RideCheckStyle.white(.18),
                  shape: BoxShape.circle,
                ),
                child: _solar(AppAssets.solarPhoneCalling, Colors.white, 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.call112Now,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr.ifSomeoneIsHurtOrIn,
                      style: TextStyle(
                        color: RideCheckStyle.white(.92),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _footer(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        _solar(
          AppAssets.solarLockKeyholeMinimalistic,
          RideCheckStyle.white(.45),
          13,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: RideCheckStyle.white(.45),
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    ),
  );

  static const TextStyle _buttonLabel = TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700);

  /// The icon and its gap before a button label.
  static const double _buttonIconRoom = 19 + 8;

  static bool _labelFits(String label, double room, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _buttonLabel),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= room;
    painter.dispose();
    return fits;
  }

  static Widget _button({
    required Key key,
    required String label,
    String? icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
    double height = 52,
  }) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                _solar(icon, foreground, 19),
                const SizedBox(width: 8),
              ],
              // Never cut: a label that still does not fit scales down.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: _buttonLabel.copyWith(color: foreground),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Question extends StatelessWidget {
  const _Question(this.text, {this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: small ? 18 : 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -.4,
      height: 1.2,
    ),
  );
}

/// Three steps: the check, this screen, done.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
    child: Row(
      children: [
        for (final (index, on) in const [true, true, false].indexed) ...[
          if (index > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: on ? Colors.white : RideCheckStyle.white(.18),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? Colors.white : RideCheckStyle.white(.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              // "Someone else" on a small phone: smaller, never cut.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? RideCheckStyle.ink : Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('ride-check-note'),
    controller: controller,
    onChanged: onChanged,
    minLines: 2,
    maxLines: 4,
    maxLength: 200,
    cursorColor: Colors.white,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      hintText: tr.tellUsInFewWords,
      hintStyle: TextStyle(color: RideCheckStyle.white(.45)),
      counterStyle: TextStyle(color: RideCheckStyle.white(.45)),
      filled: true,
      fillColor: RideCheckStyle.white(.08),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

/// "Record audio · saved only on this phone". The file never leaves it.
class _RecordAudio extends StatelessWidget {
  const _RecordAudio({required this.controller});
  final RideCheckController controller;

  /// Offered (owner decision 10's switch), or a recording to stop.
  static bool shown(RideCheckController c) =>
      SafetyAudioOption.enabled ||
      c.audio == RideCheckAudio.recording ||
      c.audio == RideCheckAudio.starting;

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final recording = c.audio == RideCheckAudio.recording;
    final (title, detail) = switch (c.audio) {
      RideCheckAudio.recording => (
        tr.recordingTime(_clock(c.audioSeconds)),
        tr.savedOnlyOnThisPhone,
      ),
      RideCheckAudio.starting => (tr.recordAudio, tr.recordAudioStarting),
      RideCheckAudio.saved => (
        tr.audioSavedTime(_clock(c.audioSeconds)),
        c.audioStoppedInBackground
            ? tr.audioStoppedWhenAppLeft
            : tr.onlyOnThisPhone,
      ),
      RideCheckAudio.unavailable => (
        tr.recordAudio,
        tr.notAvailableOnThisDevice,
      ),
      RideCheckAudio.denied => (tr.recordAudio, tr.allowMicrophoneFirst),
      RideCheckAudio.failed => (tr.recordAudio, tr.couldNotRecordTryAgain),
      RideCheckAudio.idle => (tr.recordAudio, tr.savedOnlyOnThisPhone),
    };
    return Semantics(
      button: true,
      label: '$title, $detail',
      excludeSemantics: true,
      child: Material(
        color: RideCheckStyle.white(.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('ride-check-record-audio'),
          onTap: c.toggleRecording,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (recording)
                  const _Pulse(builder: RideCheckCard._dot)
                else
                  _solar(AppAssets.solarMicrophone, Colors.white, 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(text: ' · $detail'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RideCheckStyle.white(.55),
                      fontSize: 13,
                    ),
                  ),
                ),
                if (recording) ...[
                  const SizedBox(width: 8),
                  _solar(AppAssets.solarStopCircle, Colors.white, 18),
                  const SizedBox(width: 5),
                  Text(
                    tr.stop,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: Center(
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: RideCheckStyle.dot,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: RideCheckStyle.dot.withValues(alpha: .25 + .2 * pulse),
              spreadRadius: 2 + 1.5 * pulse,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A slow 0..1..0 pulse; still at 1 when animations are reduced.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.builder});
  final Widget Function(BuildContext context, double pulse) builder;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) =>
        widget.builder(context, Curves.easeInOut.transform(_pulse.value)),
  );
}

/// Sizes itself between [from] and its child's size by [progress], top
/// center aligned; the child is laid out at its own size and clipped by the
/// shape around it, never scaled.
class _Reveal extends SingleChildRenderObjectWidget {
  const _Reveal({
    required this.from,
    required this.progress,
    required this.onLayout,
    required super.child,
  });

  final Size from;
  final double progress;
  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReveal(from, progress, onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderReveal renderObject) {
    renderObject
      ..from = from
      ..progress = progress
      ..onLayout = onLayout;
  }
}

class _RenderReveal extends RenderShiftedBox {
  _RenderReveal(this._from, this._progress, this.onLayout) : super(null);

  Size _from;
  double _progress;
  ValueChanged<Size> onLayout;

  set from(Size value) {
    if (value == _from) return;
    _from = value;
    markNeedsLayout();
  }

  set progress(double value) {
    if (value == _progress) return;
    _progress = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(_from);
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    final target = child.size;
    size = constraints.constrain(Size.lerp(_from, target, _progress)!);
    (child.parentData! as BoxParentData).offset = Offset(
      (size.width - target.width) / 2,
      0,
    );
    onLayout(size);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    return super.hitTestChildren(result, position: position);
  }
}
