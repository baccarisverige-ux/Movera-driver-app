/// Movera reference day palette, picked pixel by pixel with Pillow from four
/// user screenshots of 16 Oct 2026 (Märsta, E20, Norra Djurgården,
/// Kungsholmen; 1206x2622). Hex values are dominant pixels of clean map
/// regions (UI and location dot excluded); feature-type assignment is
/// inferred. Land #EDF0F5, every street white with no outline, motorways and
/// ramps lavender #9CA9D4 (Google JSON styles are zoom-independent, so one
/// value covers the thinner city-zoom shade), railway #BECAD1, parks and
/// forest #B6DEBB, hospital/school #F1E1E1, water #BBD9FB. Restaurants need
/// poi.business: JSON styles cannot isolate food POIs, so business labels are
/// on with greyscale icons and #576167 text; other POI labels stay off.
/// Motorway shields (E20 green) are drawn by Google and cannot be recoloured
/// here. Route/traffic overlays are separate.
/// Maps JavaScript (web) serialises `styles` into one compact string and
/// silently drops ALL styling when it exceeds 1000 characters (it only logs
/// "Custom style string for ..."). Keep rules minimal: omit any rule that
/// repeats its parent's value. test/core/reference_map_style_test.dart
/// guards the budget. The same string styles native maps (GoogleMap.style).
const String moveraReferenceMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#EDF0F5"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#576167"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#FFFFFF"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#596171"}]},
  {"featureType": "administrative.neighborhood", "elementType": "labels.text.fill", "stylers": [{"color": "#8FA2D3"}]},
  {"featureType": "landscape.natural.landcover", "elementType": "geometry", "stylers": [{"color": "#B6DEBB"}]},
  {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "elementType": "labels", "stylers": [{"visibility": "on"}]},
  {"featureType": "poi.business", "elementType": "labels.icon", "stylers": [{"saturation": -100}]},
  {"featureType": "poi.park", "elementType": "labels", "stylers": [{"visibility": "on"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#B6DEBB"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#478660"}]},
  {"featureType": "poi.medical", "elementType": "geometry", "stylers": [{"color": "#F1E1E1"}]},
  {"featureType": "poi.school", "elementType": "geometry", "stylers": [{"color": "#F1E1E1"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#FFFFFF"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#444444"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#9CA9D4"}]},
  {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#BECAD1"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#BBD9FB"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4A6C9B"}]}
]
''';
