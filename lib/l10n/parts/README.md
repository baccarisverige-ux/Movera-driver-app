# Driver translations, one file per area

Rule 25 (owner 2026-11-05 "Split first"): **new texts go in their area file**,
`lib/l10n/parts/<area>.<lang>.arb`, in all three languages (en, fr, sv), with
the English `@key` description next to the English text. Never edit
`lib/l10n/app_<lang>.arb`: Flutter gen-l10n needs one ARB per language, so
`tool/l10n_parts.py` writes it from the area files.

After a change run `python3 tool/l10n_parts.py` and `flutter gen-l10n`, and
commit the result. CI (`python3 tool/l10n_parts.py --check`) and
`test/l10n/l10n_parts_test.dart` fail when an ARB differs from its parts.

Areas: account, airport_queue (fix job 9), app (`@@locale` only), auth, cancel, fleet, general_a_k,
general_l_z (texts shared by many screens, by first letter), navigation,
reservations, safety, support, trip, vehicle. A file over ~800 lines gets a
new area. A new area is a new `<area>.en.arb`, `<area>.fr.arb` and
`<area>.sv.arb` with the same keys.
