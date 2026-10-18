/// Movera day map style ("Fresh blue"), applied to every driver map through
/// CustomGoogleMap. Calm, Uber-like: cool grey land, fresh blue water,
/// green-tinted parks, white roads, grey highways, Movera ink (#2B3036)
/// labels, no POI labels or icons.
///
/// Highway shields are left unstyled so Google's own green E-road shields
/// (E4, E20) show.
///
/// Maps JavaScript (web) silently drops ALL styling when the serialised
/// style exceeds 1000 characters. Keep this minified JSON under 1000
/// characters; test/core/movera_map_style_test.dart guards the budget.
const String moveraMapStyle = '['
    '{"elementType":"geometry","stylers":[{"color":"#F0F2F4"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#2B3036"}]},'
    '{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},'
    '{"featureType":"poi.medical","elementType":"geometry","stylers":[{"color":"#EFE6E3"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#CFE7D7"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},'
    '{"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#BCC3CF"}]},'
    '{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#A6AEBD"}]},'
    '{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#D5DADF"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#A9CBF2"}]}'
    ']';
