import 'package:flutter/painting.dart';

/// The Home map colours ([moveraMapStyle], "Fresh blue") as Flutter colours,
/// for drawn map pictures that are not Google maps (Scheduled rides route
/// preview, notifications area map). Keep in step with movera_map_style.dart;
/// test/widgets/movera_map_palette_test.dart checks both match.
abstract final class MoveraMapPalette {
  static const Color land = Color(0xFFF0F2F4);
  static const Color water = Color(0xFFA9CBF2);
  static const Color park = Color(0xFFCFE7D7);
  static const Color road = Color(0xFFFFFFFF);
  static const Color highway = Color(0xFFBCC3CF);
  static const Color highwayEdge = Color(0xFFA6AEBD);
  static const Color label = Color(0xFF2B3036);

  /// Every colour above, in the order the map style lists them.
  static const List<Color> all = [
    land,
    water,
    park,
    road,
    highway,
    highwayEdge,
    label,
  ];

  /// "#RRGGBB" for [color], as written in the map style JSON.
  static String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Draws a highway: a [highwayEdge] outline around a [highway] fill.
  static void drawHighway(Canvas canvas, Path path, double width) {
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = highwayEdge
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width + 1.5,
      )
      ..drawPath(
        path,
        Paint()
          ..color = highway
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width,
      );
  }

  /// Paint for an ordinary white street of [width].
  static Paint street(double width) => Paint()
    ..color = road
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;
}
