import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// UI-12: gives the island's side buttons (menu and search) a touch area of
/// at least 48 x 48 dp while the island paints exactly as before.
///
/// Each button is wrapped in an [IslandSideButton]. A touch inside a
/// button's 48 x 48 box (its own rectangle, widened past its outer edge and
/// lengthened downwards) goes to that button, also where the island draws
/// nothing (past its rounded ends or just below it). Elsewhere touches
/// behave as before, and a button that takes no touches (tucked away) gives
/// way. [growth] adds unpainted layout room around the child, so bounded
/// ancestors (such as a pointer interceptor) take touches in those boxes;
/// side room is only added where the width allows it, so a wide island is
/// never squeezed.
class IslandSideHitSlop extends SingleChildRenderObjectWidget {
  const IslandSideHitSlop({
    super.key,
    required this.target,
    this.growth = EdgeInsets.zero,
    required Widget super.child,
  });

  /// The side of each button's touch box, in this widget's own units (for
  /// an island drawn at 80 %, 48 / 0.8).
  final double target;
  final EdgeInsets growth;

  /// The smallest touch target, in logical pixels.
  static const double minTarget = 48;

  @override
  RenderIslandSideHitSlop createRenderObject(BuildContext context) =>
      RenderIslandSideHitSlop(target: target, growth: growth);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderIslandSideHitSlop renderObject,
  ) {
    renderObject
      ..target = target
      ..growth = growth;
  }
}

/// Marks a side button of the island for [IslandSideHitSlop]. [outward] is
/// the side its touch box widens to: left for the menu, right for search.
class IslandSideButton extends SingleChildRenderObjectWidget {
  const IslandSideButton({
    super.key,
    required this.outward,
    required Widget super.child,
  });

  final AxisDirection outward;

  @override
  RenderIslandSideButton createRenderObject(BuildContext context) =>
      RenderIslandSideButton(outward);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderIslandSideButton renderObject,
  ) {
    renderObject.outward = outward;
  }
}

class RenderIslandSideButton extends RenderProxyBox {
  RenderIslandSideButton(this.outward);

  AxisDirection outward;
  RenderIslandSideHitSlop? _slop;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    RenderObject? node = parent;
    while (node != null && node is! RenderIslandSideHitSlop) {
      node = node.parent;
    }
    _slop = node as RenderIslandSideHitSlop?;
    _slop?._buttons.add(this);
  }

  @override
  void detach() {
    _slop?._buttons.remove(this);
    _slop = null;
    super.detach();
  }
}

class RenderIslandSideHitSlop extends RenderShiftedBox {
  RenderIslandSideHitSlop({required double target, required EdgeInsets growth})
    : _target = target,
      _growth = growth,
      super(null);

  final Set<RenderIslandSideButton> _buttons = {};

  double _target;
  set target(double value) => _target = value;

  EdgeInsets _growth;
  set growth(EdgeInsets value) {
    if (value == _growth) {
      return;
    }
    _growth = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(_growth.horizontal, _growth.vertical));
      return;
    }
    // The child keeps all the width it had before.
    child.layout(
      constraints.deflate(
        EdgeInsets.only(top: _growth.top, bottom: _growth.bottom),
      ),
      parentUsesSize: true,
    );
    final spare = constraints.hasBoundedWidth
        ? math.max(0.0, constraints.maxWidth - child.size.width)
        : double.infinity;
    final left = math.min(_growth.left, spare / 2);
    final right = math.min(_growth.right, spare / 2);
    (child.parentData! as BoxParentData).offset = Offset(left, _growth.top);
    size = constraints.constrain(
      Size(
        child.size.width + left + right,
        child.size.height + _growth.vertical,
      ),
    );
  }

  bool _hitChild(BoxHitTestResult result, Offset position, Offset point) {
    final child = this.child!;
    final offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, _) => child.hitTest(result, position: point - offset),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (child == null) {
      return false;
    }
    for (final button in _buttons) {
      if (!button.attached || !button.hasSize) {
        continue;
      }
      final rect = MatrixUtils.transformRect(
        button.getTransformTo(this),
        Offset.zero & button.size,
      );
      final width = math.max(_target, rect.width);
      final height = math.max(_target, rect.height);
      final box = button.outward == AxisDirection.left
          ? Rect.fromLTWH(rect.right - width, rect.top, width, height)
          : Rect.fromLTWH(rect.left, rect.top, width, height);
      if (!box.contains(position)) {
        continue;
      }
      bool reaches(Offset point) {
        final probe = BoxHitTestResult();
        return _hitChild(probe, position, point) &&
            probe.path.any((entry) => entry.target == button);
      }

      // On the button itself, as before.
      if (rect.contains(position) && reaches(position)) {
        break;
      }
      // Elsewhere in its box (past the rounded end, below the island): the
      // touch goes to the button's centre, if the button takes it there.
      if (!reaches(rect.center)) {
        continue;
      }
      _hitChild(result, position, rect.center);
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    if (size.contains(position) && _hitChild(result, position, position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
