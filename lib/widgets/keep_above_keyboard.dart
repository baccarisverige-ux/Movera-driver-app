import 'package:flutter/widgets.dart';

/// Owner 2026-10-30 (screen video, sign-in on iPhone): "When clic on any box
/// to fill, why the botton continue doesnt show up with keyboard!?"
///
/// Wrap a form's main button (Continue, Verify, Save…) with this. When the
/// keyboard opens or grows while a text field of the same scroll view has
/// focus, the scroll view moves so that this button sits just above the
/// keyboard; the focused field stays visible too (it wins when both do not
/// fit). Everything between them (the terms tick, the error line) is then
/// on screen.
///
/// Works the same in the store apps and in the browser: Flutter's web
/// engine reports the keyboard as `viewInsets` from `window.visualViewport`
/// (iPhone Safari, Android Chrome), and the [Scaffold] shrinks its body by
/// it ([Scaffold.resizeToAvoidBottomInset], on by default). The scroll
/// view itself only brings the focused field into view, never the button
/// under it: that is the bug this widget fixes.
class KeepAboveKeyboard extends StatefulWidget {
  const KeepAboveKeyboard({super.key, required this.child, this.gap = 8});

  final Widget child;

  /// Space kept between the button and the keyboard.
  final double gap;

  @override
  State<KeepAboveKeyboard> createState() => _KeepAboveKeyboardState();
}

class _KeepAboveKeyboardState extends State<KeepAboveKeyboard>
    with WidgetsBindingObserver {
  final _area = GlobalKey();
  double _lastInset = 0;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_focusMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastInset = _keyboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_focusMoved);
    super.dispose();
  }

  double _keyboard() {
    final view = View.maybeOf(context);
    if (view == null) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = _keyboard();
    final grew = inset > _lastInset + 0.5;
    _lastInset = inset;
    if (!grew || inset <= 0) return;
    _schedule();
  }

  /// The keyboard stays up while the person moves to the next field.
  void _focusMoved() {
    if (!mounted || _keyboard() <= 0) return;
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    // After the frame that lays the page out in its new, shorter size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      reveal();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Moves the page so the button and the focused field are both visible.
  void reveal() {
    if (!mounted) return;
    final focused = FocusManager.instance.primaryFocus?.context;
    final area = _area.currentContext;
    if (focused == null || area == null) return;
    final page = Scrollable.maybeOf(area);
    if (page == null || !_inside(focused, page.context)) return;
    // The button at the bottom edge of what is visible, then the field
    // back in view if that pushed it off the top.
    Scrollable.ensureVisible(
      area,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      focused,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  static bool _inside(BuildContext child, BuildContext ancestor) {
    if (child == ancestor) return true;
    var found = false;
    child.visitAncestorElements((element) {
      if (element == ancestor) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: _area,
      // The gap is part of what must be visible, so the button does not
      // touch the keyboard's edge.
      padding: EdgeInsets.only(bottom: widget.gap),
      child: widget.child,
    );
  }
}
