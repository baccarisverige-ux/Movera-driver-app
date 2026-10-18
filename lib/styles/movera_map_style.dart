/// Movera day map style (R10-10, option B "adapted to Movera"), applied to
/// every driver map through CustomGoogleMap. Calm, Uber-like: cool grey
/// land, light blue water, green-tinted parks, white roads, grey highways,
/// no POI labels or icons.
///
/// Google styling cannot recolour highway shield fills; the shield icons are
/// desaturated and darkened towards Movera ink (#2B3036) instead.
///
/// Maps JavaScript (web) silently drops ALL styling when the serialised
/// style exceeds 1000 characters. Keep this minified JSON under 1000
/// characters; test/core/movera_map_style_test.dart guards the budget.
const String moveraMapStyle = '['
    '{"elementType":"geometry","stylers":[{"color":"#EEF0F2"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#5D646C"}]},'
    '{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},'
    '{"featureType":"poi.medical","elementType":"geometry","stylers":[{"color":"#EFE6E3"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#CFE7D7"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},'
    '{"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#B7BECB"}]},'
    '{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#A6AEBD"}]},'
    '{"featureType":"road.highway","elementType":"labels.icon","stylers":[{"saturation":-100},{"lightness":-50}]},'
    '{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#D5DADF"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#C4DCF5"}]}'
    ']';
