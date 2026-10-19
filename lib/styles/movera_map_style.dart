/// Movera day map style ("Clean v3"), the in-app fallback for every driver
/// map through CustomGoogleMap: Android / iOS maps and the web raster map
/// when no Map ID is configured. With a Map ID (web vector map) the cloud
/// style linked to that Map ID draws the map instead and this is not sent.
///
/// Near-white land, grey roads by class (local, arterial, highway), light
/// grey man-made areas, soft green parks with green labels, light blue
/// water, mid-grey labels with a white halo, blue-grey city names. No POI,
/// transit, neighbourhood names or admin lines. Highway shields stay.
///
/// Maps JavaScript (web) silently drops ALL styling when the serialised
/// style exceeds 1000 characters. Keep this minified JSON under 1000
/// characters; test/core/movera_map_style_test.dart guards the budget.
const String moveraMapStyle = '['
    '{"elementType":"geometry","stylers":[{"color":"#FAFCFA"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#575C60"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"}]},'
    '{"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},'
    '{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#6F8B9D"}]},'
    '{"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},'
    '{"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#E1E4E5"}]},'
    '{"featureType":"poi","stylers":[{"visibility":"off"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#C8F0CC"}]},'
    '{"featureType":"poi.park","elementType":"labels.text","stylers":[{"visibility":"on"}]},'
    '{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#3D8549"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#C8CCD0"}]},'
    '{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#A1A6AB"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#8A8F96"}]},'
    '{"featureType":"transit","stylers":[{"visibility":"off"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#ADE2FC"}]}'
    ']';
