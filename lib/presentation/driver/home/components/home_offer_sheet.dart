import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/offer_route_marks.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:movera/core/geo/driver_distance.dart';

const Color _ink = Color(0xFF111518);
const Color _text = Color(0xFF5D646C);
const Color _label = Color(0xFF8A9399);
const Color _hairline = Color(0xFFEEF0F2);
const Color _softFill = Color(0xFFF1F2F4);

/// The request sheet on Home, shared by the reservation request and the
/// Exclusive offer (design A): the Home sheet rises to about 40 % of the
/// screen with every detail inside it and no map (the Home map shows the
/// route). The radar orb, the Accept, sits centred on the sheet's top
/// edge, half over the map; a small down arrow top-right takes the
/// request off Home.
///
/// It rises smoothly from the bottom while [visible] and [id] is set
/// (slide up and fade in); when it goes, [onLeaving] lets the map's route
/// fade first, then it slides down under the Home sheet and [onHidden]
/// follows. While it goes, the last [content] stays on it.
class HomeOfferSheet extends StatefulWidget {
  const HomeOfferSheet({
    super.key,
    required this.id,
    required this.visible,
    required this.content,
    this.orb,
    this.onDecline,
    this.onShown,
    this.onSettled,
    this.onLeaving,
    this.onHidden,
    this.riseDelay = HomeOfferSheet.defaultRiseDelay,
    this.heightFactor = 0.4,
    this.maxHeight = double.infinity,
    this.sheetKey = const ValueKey<String>('home-offer-sheet'),
    this.closeKey = const ValueKey<String>('offer-sheet-hide'),
    this.closeLabel = 'Hide request',
  });

  /// The request on the sheet; null takes the sheet down.
  final String? id;
  final bool visible;

  /// What the sheet shows for [id]; null while [id] is null.
  final WidgetBuilder? content;

  /// The radar orb on the top edge: tapping it accepts.
  final Widget? orb;

  /// The down arrow: the sheet goes down. Null while a claim is deciding.
  final VoidCallback? onDecline;

  /// Called each time the sheet is nearly up (Accept works from then).
  final VoidCallback? onShown;

  /// Called once the sheet has settled at the top: the map's route fades
  /// in from then.
  final VoidCallback? onSettled;

  /// Called as soon as the sheet is to go: the map's route fades out
  /// during [routeFadeOut], then the sheet slides down.
  final VoidCallback? onLeaving;

  /// Called once the sheet is down and removed.
  final VoidCallback? onHidden;

  /// How long the sheet waits, once it may show, before it rises.
  final Duration riseDelay;

  /// The sheet's height as a part of the screen; taller content grows it
  /// up to [maxHeight], then scrolls.
  final double heightFactor;
  final double maxHeight;

  /// Keys and words of the sheet and its down arrow.
  final Key sheetKey;
  final Key closeKey;
  final String closeLabel;

  /// The orb on the top edge: the Home radar's size.
  static const double orbSize = 104;

  /// A reservation waits this long before it rises, so the driver sees
  /// Radar go live first (and its green flash fade).
  static const Duration defaultRiseDelay = Duration(milliseconds: 1000);

  /// The rise: slide up and fade in.
  static const Duration riseDuration = Duration(milliseconds: 400);

  /// Going: the route fades out first, then the sheet slides down.
  static const Duration routeFadeOut = Duration(milliseconds: 200);
  static const Duration sinkDuration = Duration(milliseconds: 350);

  /// From the request going until the sheet is removed.
  static const Duration leaveDuration = Duration(milliseconds: 550);

  @override
  State<HomeOfferSheet> createState() => _HomeOfferSheetState();
}

class _HomeOfferSheetState extends State<HomeOfferSheet>
    with SingleTickerProviderStateMixin {
  /// 0 hidden below the screen, 1 up; already eased.
  late final AnimationController _rise = AnimationController(vsync: this);

  /// What is on screen; kept while the sheet goes down.
  String? _shownId;
  WidgetBuilder? _shownContent;

  /// The sheet should be (or is going) up.
  bool _up = false;

  /// Going down: the route fades, then the slide; [_shownId] stays.
  bool _leaving = false;
  Timer? _riseTimer;
  Timer? _leaveTimer;

  /// Counts each rise or leave, so a stale animation end does nothing.
  int _run = 0;

  /// [HomeOfferSheet.onShown] ran for this rise.
  bool _told = false;

  /// How far up the sheet is when the radar becomes its Accept.
  static const double _nearlyUp = 0.82;

  bool get _wantUp =>
      widget.visible && widget.id != null && widget.content != null;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _rise.addListener(_tellWhenNearlyUp);
    _sync();
  }

  void _tellWhenNearlyUp() {
    if (_told || !_up || _leaving || _rise.value < _nearlyUp) return;
    _told = true;
    widget.onShown?.call();
  }

  @override
  void didUpdateWidget(HomeOfferSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Called from [initState] or [didUpdateWidget], so a build follows.
  void _sync() {
    final id = widget.id;
    if (_wantUp && id != null) {
      if (_leaving) {
        // The same request back while going: it comes up again. Another
        // one waits until this one is down.
        if (_shownId == id) _comeBack();
        return;
      }
      _shownId = id;
      _shownContent = widget.content;
      if (!_up) {
        _up = true;
        _riseTimer?.cancel();
        if (widget.riseDelay <= Duration.zero) {
          // Rises from the first frame on.
          WidgetsBinding.instance.addPostFrameCallback((_) => _riseNow());
        } else {
          _riseTimer = Timer(widget.riseDelay, _riseNow);
        }
      }
    } else if (_up && !_leaving) {
      _leave();
    } else if (_leaving && widget.content != null && widget.id == _shownId) {
      // Still the same request on its way down: its latest content.
      _shownContent = widget.content;
    }
  }

  void _riseNow() {
    if (!mounted || !_up || _leaving) return;
    final run = ++_run;
    if (_reduceMotion) {
      _rise.value = 1;
      _settled(run);
      return;
    }
    _rise
        .animateTo(
          1,
          duration: HomeOfferSheet.riseDuration,
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(() => _settled(run));
  }

  void _settled(int run) {
    if (!mounted || run != _run || !_up || _leaving || _rise.value < 1) {
      return;
    }
    if (!_told) {
      _told = true;
      widget.onShown?.call();
    }
    widget.onSettled?.call();
  }

  void _comeBack() {
    _leaving = false;
    _leaveTimer?.cancel();
    _riseNow();
  }

  /// The route fades first, then the sheet slides down; then it is gone.
  void _leave() {
    _riseTimer?.cancel();
    _told = false;
    final run = ++_run;
    if (_rise.value <= 0 || _reduceMotion) {
      // Never came up, or no motion: gone at once.
      _rise.stop();
      _rise.value = 0;
      _up = false;
      _shownId = null;
      _shownContent = null;
      widget.onLeaving?.call();
      final onHidden = widget.onHidden;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _up) return;
        onHidden?.call();
      });
      return;
    }
    _leaving = true;
    _rise.stop();
    widget.onLeaving?.call();
    _leaveTimer?.cancel();
    _leaveTimer = Timer(HomeOfferSheet.routeFadeOut, () {
      if (!mounted || run != _run) return;
      _rise
          .animateTo(
            0,
            duration: HomeOfferSheet.sinkDuration,
            curve: Curves.easeInCubic,
          )
          .whenCompleteOrCancel(() => _down(run));
    });
  }

  void _down(int run) {
    if (!mounted || run != _run || !_leaving) return;
    setState(() {
      _leaving = false;
      _up = false;
      _shownId = null;
      _shownContent = null;
      // A request that came while this one went rises now.
      _sync();
    });
    widget.onHidden?.call();
  }

  @override
  void dispose() {
    _riseTimer?.cancel();
    _leaveTimer?.cancel();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _shownContent;
    if (_shownId == null || content == null) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const half = HomeOfferSheet.orbSize / 2;
    final minHeight = screen * widget.heightFactor;
    // Opaque to touches: nothing under the sheet (dock, map) gets them.
    final sheet = PointerInterceptor(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          key: widget.sheetKey,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: widget.maxHeight < minHeight
                  ? minHeight
                  : widget.maxHeight,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // The orb's lower half sits on the top of the sheet.
                  padding: EdgeInsets.only(
                    top: half + 4,
                    bottom: safeBottom + 16,
                  ),
                  child: Builder(builder: content),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: ReservationCloseArrow(
                    key: widget.closeKey,
                    onTap: widget.onDecline,
                    label: widget.closeLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final orb = widget.orb;
    // The orb's upper half stands over the map: the layer starts there, so
    // all of the orb takes taps. Beside it the map stays free.
    final layer = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: half), child: sheet),
        if (orb != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: HomeOfferSheet.orbSize,
            child: Center(child: PointerInterceptor(child: orb)),
          ),
      ],
    );
    return AnimatedBuilder(
      animation: _rise,
      child: layer,
      builder: (context, child) {
        final t = _rise.value.clamp(0.0, 1.0);
        if (t <= 0 && !_up) return const SizedBox.shrink();
        return FractionalTranslation(
          // Hidden: the whole layer is below the screen edge.
          translation: Offset(0, 1 - t),
          child: Opacity(
            // Fully there a little before the slide ends.
            opacity: (t * 1.4).clamp(0.0, 1.0),
            child: IgnorePointer(ignoring: _leaving, child: child),
          ),
        );
      },
    );
  }
}

/// The small round × top-right of the Exclusive and Reservation sheet
/// (R15-2): back to Home.
/// Null [onTap] while a claim is deciding.
class ReservationCloseArrow extends StatelessWidget {
  const ReservationCloseArrow({
    super.key,
    this.onTap,
    this.label = 'Hide reservation request',
  });

  final VoidCallback? onTap;
  final String label;

  static const double size = 34;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: _softFill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.solarClose,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  onTap == null ? const Color(0xFFA2AAB0) : _ink,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stop row on the sheet: its mark, the place and a bold value on
/// the right ("4 min", "12 km").
@immutable
class OfferSheetStop {
  const OfferSheetStop({
    required this.place,
    required this.pickup,
    this.trailing,
  });

  final String place;
  final bool pickup;
  final String? trailing;
}

/// The content shared by the reservation request and the Exclusive offer:
/// chips with "2 of 2" on the right, the big fare with the trip minutes
/// (a picture may sit beside it), pickup and drop-off with their values,
/// and a grey pill at the bottom that only shows. The radar accepts.
///
/// Every key is '[keyPrefix]-…' ("reservation-fare", "exclusive-fare").
class OfferSheetBody extends StatelessWidget {
  const OfferSheetBody({
    super.key,
    required this.keyPrefix,
    required this.category,
    required this.fareWhole,
    required this.fareRest,
    required this.pickup,
    required this.dropoff,
    required this.pillIcon,
    required this.pillLabel,
    required this.pillKey,
    this.bodyKey,
    this.chips = const <Widget>[],
    this.position = 1,
    this.count = 1,
    this.trip,
    this.underFare,
    this.picture,
    this.pictureSize = Size.zero,
    this.stops,
    this.pillSemantics,
  });

  final String keyPrefix;

  /// The whole body's key; '[keyPrefix]-popup' by default.
  final Key? bodyKey;

  /// The black category chip, then [chips] (cash, boost …).
  final String category;
  final List<Widget> chips;

  /// "2 of 2"; hidden while only one waits.
  final int position;
  final int count;

  /// "126" and ",75 kr": the grey decimals.
  final String fareWhole;
  final String fareRest;

  /// "21 min trip" under the fare.
  final String? trip;

  /// Under the trip line, e.g. the pickup pay line.
  final Widget? underFare;

  /// Right of the fare.
  final Widget? picture;
  final Size pictureSize;

  final OfferSheetStop pickup;

  /// "1 stop" between pickup and drop-off.
  final String? stops;
  final OfferSheetStop dropoff;

  /// The grey pill at the bottom: a Solar icon and bold words.
  final String pillIcon;
  final String pillLabel;

  /// '[keyPrefix]-[pillKey]', with '-icon' and '-text' inside.
  final String pillKey;
  final String? pillSemantics;

  @override
  Widget build(BuildContext context) {
    final picture = this.picture;
    return DefaultTextStyle.merge(
      // Tight lines like the design, not the theme's body line height.
      style: const TextStyle(height: 1.2),
      // White and opaque to touches, like the sheet it sits on.
      child: ColoredBox(
        key: bodyKey ?? ValueKey<String>('$keyPrefix-popup'),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [_categoryChip(), ...chips],
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 10),
                    Text(
                      '$position of $count',
                      key: ValueKey<String>('$keyPrefix-count'),
                      maxLines: 1,
                      style: const TextStyle(
                        color: _label,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Clear of the picture's right edge below.
                    const SizedBox(width: 24),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            key: ValueKey<String>('$keyPrefix-fare'),
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: fareWhole,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 34,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                TextSpan(
                                  text: fareRest,
                                  style: const TextStyle(
                                    color: _label,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (trip case final trip?) ...[
                          const SizedBox(height: 4),
                          Text(
                            trip,
                            key: ValueKey<String>('$keyPrefix-trip'),
                            maxLines: 1,
                            style: const TextStyle(color: _text, fontSize: 14),
                          ),
                        ],
                        if (underFare case final under?) under,
                      ],
                    ),
                  ),
                  if (picture != null) ...[
                    const SizedBox(width: 8),
                    SizedBox.fromSize(
                      size: pictureSize,
                      child: ExcludeSemantics(child: picture),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: _hairline),
              const SizedBox(height: 10),
              _place(pickup, '$keyPrefix-pickup'),
              if (stops case final stops?)
                Padding(
                  padding: const EdgeInsets.only(left: 22, bottom: 2),
                  child: Text(
                    stops,
                    key: ValueKey<String>('$keyPrefix-stops'),
                    style: const TextStyle(color: _label, fontSize: 12.5),
                  ),
                ),
              _place(dropoff, '$keyPrefix-dropoff'),
              const SizedBox(height: 12),
              _pill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category,
        key: ValueKey<String>('$keyPrefix-category'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _place(OfferSheetStop stop, String key) {
    final trailing = stop.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        key: ValueKey<String>(key),
        children: [
          SizedBox(
            width: 12,
            child: Center(
              child: stop.pickup
                  ? const OfferStopMark.pickup()
                  : const OfferStopMark.dropoff(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stop.place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 15),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing,
              key: ValueKey<String>('$key-trailing'),
              maxLines: 1,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A light grey pill; only shows, never taps.
  Widget _pill() {
    final key = '$keyPrefix-$pillKey';
    return Semantics(
      label: pillSemantics ?? pillLabel,
      excludeSemantics: true,
      child: Container(
        key: ValueKey<String>(key),
        height: 50,
        decoration: BoxDecoration(
          color: _softFill,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              pillIcon,
              key: ValueKey<String>('$key-icon'),
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            // Shrinks to fit rather than cutting the end off: the end is
            // the seconds left or the pickup time (UI-06).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pillLabel,
                  key: ValueKey<String>('$key-text'),
                  maxLines: 1,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "650 m", "8.5 km", "12 km" (Q20).
  static String km(double km) => driverDistanceKm(km);

  /// "126,75 kr" → "126" and ",75 kr", for the grey decimals.
  static (String, String) fareParts(String fare) {
    final comma = fare.lastIndexOf(',');
    return comma > 0
        ? (fare.substring(0, comma), fare.substring(comma))
        : (fare, '');
  }

  /// The cash chip, when the rider pays cash.
  static Widget cashChip(String keyPrefix) =>
      OfferBadge.cash(key: ValueKey<String>('$keyPrefix-cash'));
}

/// Pickup: a green dot with a soft ring; drop-off: a black square. The
/// same marks as the pins on the map.
class OfferStopMark extends StatelessWidget {
  const OfferStopMark.pickup({super.key}) : _pickup = true;
  const OfferStopMark.dropoff({super.key}) : _pickup = false;

  final bool _pickup;

  @override
  Widget build(BuildContext context) {
    if (!_pickup) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: OfferRouteMarks.green,
        shape: BoxShape.circle,
        // A white ring, then a faint green one (painted first, under it).
        boxShadow: [
          BoxShadow(
            color: OfferRouteMarks.green.withValues(alpha: 0.33),
            spreadRadius: 4,
          ),
          const BoxShadow(color: Colors.white, spreadRadius: 3),
        ],
      ),
    );
  }
}
