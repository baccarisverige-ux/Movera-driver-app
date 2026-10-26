/// Movera day map style ("Clean v4", reference palette), the in-app
/// fallback for every driver map through CustomGoogleMap: Android / iOS maps and the web raster map
/// when no Map ID is configured. With a Map ID (web vector map) the cloud
/// style linked to that Map ID draws the map instead and this is not sent.
///
/// Near-white land, grey roads by class (local, arterial, highway), light
/// grey man-made areas, pale pink business and hospital grounds (#F5E0E0,
/// no labels), soft green parks with green labels, light blue
/// water, mid-grey labels with a white halo, blue-grey city names. No POI,
/// transit, neighbourhood names or admin lines. Highway shields stay.
///
/// Zoomed right in ([MoveraMapStyleBand.close]) the roads get a wider,
/// bolder edge ([moveraCloseRoads]), like the reference app close up;
/// zoomed out they keep the SDK's own thin lines.
///
/// Maps JavaScript (web) silently drops ALL styling when the serialised
/// style exceeds 1000 characters. Keep every minified style under 1000
/// characters; test/core/movera_map_style_test.dart guards the budget.
String _style(String park, [String roads = '']) =>
    '['
    '{"elementType":"geometry","stylers":[{"color":"#F8FAF8"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#4D4F51"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"}]},'
    '{"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},'
    '{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#5E7F90"}]},'
    '{"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},'
    '{"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#DDDEE0"}]},'
    '{"featureType":"poi","stylers":[{"visibility":"off"}]},'
    '{"featureType":"poi.business","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#F5E0E0"}]},'
    '{"featureType":"poi.medical","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#F5E0E0"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"$park"}]},'
    '{"featureType":"poi.park","elementType":"labels.text","stylers":[{"visibility":"on"}]},'
    '{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#14793A"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#CACFD2"}]},'
    '{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ACB1B6"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#ACB1B6"}]},'
    '$roads'
    '{"featureType":"transit","stylers":[{"visibility":"off"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#95DFFF"}]}'
    ']';

/// Like the reference app, the green changes with zoom: zoomed out
/// (zoom < [MoveraMapStyleBand.split]) parks are a pale #D8F5DF, zoomed in
/// the stronger #B6EFC2. Water stays #95DFFF at every zoom.
const String moveraParkFar = '#D8F5DF';
const String moveraParkNear = '#B6EFC2';

/// The in-app style zoomed out ([MoveraMapStyleBand.far]).
final String moveraMapStyleFar = _style(moveraParkFar);

/// The in-app style zoomed in ([MoveraMapStyleBand.near]).
final String moveraMapStyleNear = _style(moveraParkNear);

/// Road edge weights (pixels) zoomed right in: the road colour also
/// draws the edge, so a heavier edge reads as a wider, bolder road. Native
/// SDKs and the raster web map honour `weight`; the cloud style (web Map
/// ID) sets its own `strokeWeight` per zoom instead.
const Map<String, num> moveraCloseRoadWeights = {
  'road.local': 2,
  'road.arterial': 2.5,
  'road.highway': 3,
};

final String moveraCloseRoads = [
  for (final MapEntry(key: road, value: weight)
      in moveraCloseRoadWeights.entries)
    '{"featureType":"$road","elementType":"geometry.stroke",'
        '"stylers":[{"weight":$weight}]},',
].join();

/// The in-app style zoomed right in ([MoveraMapStyleBand.close]).
final String moveraMapStyleClose = _style(moveraParkNear, moveraCloseRoads);

/// The near style: what a map without a reported zoom starts with.
final String moveraMapStyle = moveraMapStyleNear;

/// Which style a camera zoom shows. A map keeps its band and swaps the
/// style only when the band changes; each edge has a little hysteresis so
/// a zoom resting near it never flickers. Far / near split at 12.5 (park
/// green); near / close at 15.5 (bolder roads), above every guidance zoom
/// (15 and below, turns 15.4), so driving never swaps the style: only a
/// driver zooming in past the locate view (15) gets the close roads.
enum MoveraMapStyleBand {
  far,
  near,
  close;

  static const double split = 12.5;
  static const double toNear = 12.6;
  static const double toFar = 12.4;
  static const double closeSplit = 15.5;
  static const double toClose = 15.6;
  static const double fromClose = 15.4;

  /// The band for a map opening at [zoom] (no previous band).
  static MoveraMapStyleBand of(double zoom) => zoom >= closeSplit
      ? MoveraMapStyleBand.close
      : zoom >= split
      ? MoveraMapStyleBand.near
      : MoveraMapStyleBand.far;

  /// The band after the camera moved to [zoom] from this band.
  MoveraMapStyleBand at(double zoom) {
    if (!zoom.isFinite) return this;
    if (this == MoveraMapStyleBand.close ? zoom > fromClose : zoom >= toClose) {
      return MoveraMapStyleBand.close;
    }
    if (this == MoveraMapStyleBand.far ? zoom >= toNear : zoom > toFar) {
      return MoveraMapStyleBand.near;
    }
    return MoveraMapStyleBand.far;
  }

  String get style => switch (this) {
    MoveraMapStyleBand.far => moveraMapStyleFar,
    MoveraMapStyleBand.near => moveraMapStyleNear,
    MoveraMapStyleBand.close => moveraMapStyleClose,
  };
}
