# Reference map palette — October 16, 2026

Driver day map (`lib/styles/reference_map_style.dart`). Picked pixel by pixel
with Pillow from four user screenshots of 16 Oct 2026 (Märsta, E20, Norra
Djurgården, Kungsholmen; 1206x2622). This replaces the 10 Oct Waze day
palette. The same string is passed to `GoogleMap.style`, so it styles web,
iOS and Android alike. There is no separate dark map style yet.

| Layer | Applied color | Google selector |
| --- | --- | --- |
| Land / background | `#EDF0F5` | all / geometry |
| Streets and roads (no outline) | `#FFFFFF` | road / geometry (fill and stroke) |
| Motorways and ramps | `#9CA9D4` | road.highway / geometry (includes controlled_access) |
| Railway | `#BECAD1` | transit.line / geometry |
| Parks and forest | `#B6DEBB` | poi.park, landscape.natural.landcover / geometry |
| Hospital / school / campus | `#F1E1E1` | poi.medical, poi.school / geometry |
| Water | `#BBD9FB` | water / geometry |
| Water labels | `#4A6C9B` | water / labels.text.fill (readable blue, not sampled) |
| Town names | `#596171` | administrative.locality / labels.text.fill |
| District names | `#8FA2D3` | administrative.neighborhood / labels.text.fill |
| Street names / road numbers | `#444444` on `#FFFFFF` halo | road / labels.text.fill, all / labels.text.stroke |
| Park names | `#478660` | poi.park / labels.text.fill (icon: Google's own green) |
| Restaurants and other businesses | `#576167`, greyscale icons | poi.business labels on, labels.icon saturation -100 |

Other POI labels (attractions, government, worship, medical, school,
sports) stay off. Administrative boundary lines stay off.

Not expressible in Google JSON styles:

- Restaurants cannot be isolated: `poi.business` also shows shops, hotels
  and other businesses.
- Motorway shields (E20 green `#509E85`, white text) are Google's own
  icons; a style can hide or desaturate them but not set their colour.
- Tunnels / closed roads (`#D5D8DB` in the references) have no feature type.
- The reference's thinner city-zoom motorway shade (`#8998CC`) needs a
  zoom-dependent style; JSON styles are zoom-independent.

The web style string is about 510 characters, well inside the Maps
JavaScript 1000-character limit guarded by `test/core/reference_map_style_test.dart`.

## Separate overlay colors observed

Traffic red/orange, incident symbols, road-number shields, location markers,
accuracy circles and navigation routes are not base-map geometry. They must not
be painted onto every road to imitate a screenshot. Live operational maps now enable the provider traffic layer. Historical ride maps
keep traffic disabled because present traffic does not describe a past ride. The green road shields also contain `#118742`; their appearance
is controlled by the provider, not the park-label rule.

## Limits of matching

Screenshots do not reveal the source provider's layer metadata. Google Maps
can classify polygons differently and use different geometry, label placement,
zoom-dependent detail and antialiasing. Exact sampled RGB values do not prove
pixel-identical rendering. Roads in these references have textured gradients;
the chosen road values represent common shades, not every road pixel.

## Orange road segments — follow-up correction

The previous base-map change omitted the visible orange road segments. Two road-only
crops in IMG_7404(2).png contain dominant orange samples `#FEB87F` (light) and
`#FE9F60` (deeper). These are measured screenshot pixels, not confirmed road-class
metadata. Red and orange segments changing along grey roads are consistent with
a traffic overlay; this assignment remains an inference from the screenshots.

Both apps previously passed `trafficEnabled: false` on their operational maps.
Those call sites now enable Google's real-time traffic layer. Google chooses its
traffic colors and coverage; this flag does not apply the sampled orange RGB
values or reproduce the reference provider's shaded strokes. Do not replace all
arterial or highway fills with orange, and do not fabricate congestion polylines.

Official provider layer documentation:
https://developers.google.com/maps/documentation/javascript/trafficlayer

Boundaries and separate local/main-road edges still lack confirmed samples.
Passing CI does not establish an exact visual match.
