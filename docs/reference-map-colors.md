# Reference map palette — October 6, 2026

The same JSON is used in Rider and Driver. Rider Home shares its fallback
constant. These values come from original map references, not the Map Color Lab
editor screenshots (those display the previous palette and an edited background).

| Layer | Applied color | Evidence / confidence |
| --- | --- | --- |
| Land / background | `#FAFCFA` | Exact dominant PNG fill |
| General labels | `#565C61` | Dark text core in IMG_7405 |
| Label halo | `#FFFFFF` | White outline pixels; antialiasing adds intermediate shades |
| Administrative boundaries | `#D2DBE1` | Retained previous value; unconfirmed, not newly sampled |
| Built areas / buildings | `#E1E4E5` | Exact urban fill in IMG_7405 and IMG_7406 |
| POI areas | `#E1E4E5` | Exact station and parking-area fill in close-ups |
| POI labels | `#8E9496` | Text core at Spånga Station / parking |
| Parks | `#BEF2C9` | Exact green fill in PNGs |
| Park labels | `#118742` | Most frequent green text core in IMG_7395 and IMG_7404 |
| Natural areas | `#DDF7E3` | Exact pale green fill in wider IMG_7390/IMG_7393; feature assignment inferred |
| Local roads | `#D1D6DA` | Frequent road pixel in close-up; textured rather than uniform |
| Local road edges | `#D1D6DA` | Separate border not distinguishable; reuse fill, not an independently detected edge |
| Main roads | `#B6BBC0` | Frequent road pixel in close-ups; wider views include `#C0C5CB` |
| Main road edges | `#B6BBC0` | Separate border not distinguishable; reuse fill |
| Highway fill | `#8E9496` | Frequent dark highway pixel in wider PNG |
| Highway edge | `#8C939A` | Frequent adjacent grey highway shade; edge assignment inferred |
| Road labels | `#565C61` | Same dark text core, white halo |
| Transit areas | `#E1E4E5` | Exact Spånga Station area fill |
| Railway lines | `#D2CECC` | Exact track/tie pixels in IMG_7405 |
| Transit labels | `#8E9496` | Spånga Station text core |
| Water | `#9EE4FF` | Exact dominant PNG water fill |
| Water labels | `#1360A7` | Most frequent blue text core in IMG_7395 |

## Separate overlay colors observed

Traffic red/orange, incident symbols, road-number shields, location markers,
accuracy circles and navigation routes are not base-map geometry. They must not
be painted onto every road to imitate a screenshot. Live operational maps now enable the provider traffic layer. Historical ride maps
keep traffic disabled because present traffic does not describe a past ride. The green road shields also contain `#118742`; their appearance
is controlled by the provider, not the park-label rule.

## Limits of matching

The previous palette missed the close-up built-area, transit, railway and label
samples. This revision corrects those and adds explicit road and transit labels.
The 16 Map Color Lab categories are mapped in code, but detection remains incomplete for
boundaries and undistinguished edges. Additional park, road and transit labels
and railway rules prevent those elements from inheriting the generic color.

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
