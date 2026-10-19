import 'package:flutter/painting.dart';

/// The Movera map colours ("Clean v3", [moveraMapStyle] and the cloud style
/// linked to the web Map ID) as Flutter colours, for drawn map pictures that
/// are not Google maps (Scheduled rides route preview, notifications area
/// map). Keep in step with movera_map_style.dart;
/// test/widgets/movera_map_palette_test.dart checks both match.
abstract final class MoveraMapPalette {
  static const Color land = Color(0xFFFAFCFA);
  static const Color building = Color(0xFFE1E4E5);
  static const Color park = Color(0xFFC8F0CC);
  static const Color parkLabel = Color(0xFF3D8549);
  static const Color water = Color(0xFFADE2FC);
  static const Color road = Color(0xFFC8CCD0);
  static const Color mainRoad = Color(0xFFA1A6AB);
  static const Color highway = Color(0xFF8A8F96);
  static const Color label = Color(0xFF575C60);
  static const Color labelHalo = Color(0xFFFFFFFF);
  static const Color cityLabel = Color(0xFF6F8B9D);

  /// Footpaths and tracks. Drawn maps only: the Google styles for Android
  /// and iOS have no footpath class, so Google's own path colour shows there.
  static const Color path = Color(0xFFDBD3B2);

  /// Every colour the map style uses, in the order the map style lists them.
  static const List<Color> all = [
    land,
    label,
    labelHalo,
    cityLabel,
    building,
    park,
    parkLabel,
    road,
    mainRoad,
    highway,
    water,
  ];

  /// "#RRGGBB" for [color], as written in the map style JSON.
  static String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Paint _line(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width;

  /// Draws a highway: one flat dark-grey line, no edge.
  static void drawHighway(Canvas canvas, Path path, double width) {
    canvas.drawPath(path, _line(highway, width));
  }

  /// Paint for an ordinary (local) grey street of [width].
  static Paint street(double width) => _line(road, width);

  /// Paint for a main (arterial) street of [width].
  static Paint mainStreet(double width) => _line(mainRoad, width);

  /// Paint for a beige footpath or track of [width].
  static Paint footpath(double width) => _line(path, width);
}
