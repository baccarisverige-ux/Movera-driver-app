# Browser evidence · candidate b8bd8603dd7692edaf1e8fa621baedf7ab3679f9 (main, 22 Oct 2026)

Recorded 23 Oct 2026 by the design session, on the owner's request, for the
rows of the release evidence matrix a browser can answer. The repository's
templates (`docs/certification/RELEASE_EVIDENCE_MATRIX.md`,
`docs/frontend-completion/09-release-candidate.json`) stay PENDING by rule;
the filled copies for this candidate are `RELEASE_EVIDENCE_MATRIX-b8bd860.md`
and `release-candidate-b8bd860.json` in this folder
(`python3 tool/check_frontend_release.py docs/frontend-completion/evidence/browser-b8bd860/release-candidate-b8bd860.json`).
Phones, screen readers, performance and the real Google map are not covered
here and their rows stay PENDING.

## How it was run

- Build: `flutter build web --release --no-web-resources-cdn --dart-define=MOVERA_DEMO_ARRIVAL=true`
  of commit `b8bd860` (the Pages deploy uses the same flags plus `--base-href`;
  `--no-web-resources-cdn` was needed because the test machine cannot reach
  gstatic.com, and the deployed site on github.io was not reachable from it
  either, so the local build of the same commit was served on localhost).
- Browser: Playwright 1.63, Chromium 1194 headless (the Chrome engine),
  touch input through the DevTools protocol, Flutter's semantics tree turned
  on to find the controls by their labels. The app ran in Swedish (its default).
- No Google Maps key on the test machine: the map shows no tiles and Google's
  "InvalidKey" overlay was hidden by CSS for the screenshots. Map content,
  route lines and markers are therefore **not** covered (row `real-maps`).
- 200 % text: the document root font size set to 32 px after load (Flutter
  web reads its text scale from it).

## Flow, identical in every configuration

Home (demo mode) → Wallet → back → Radar (go online) → the demo's account
hold ("Skip demo") → reservation requests hidden → the Exclusive offer
(Movera · Prioriterad, 129,40 kr, Tegnérgatan 8 → Hammarby sjöstad) → Accept
→ trip screen ("Navigera till upphämtningen", "Hämta Karim") → browser
reload → the trip screen comes back.

| Configuration | Viewport · DPR · text | Flow completed | Trip restored after reload | Uncaught page errors | Files |
| --- | --- | --- | --- | --- | --- |
| Phone | 390x844 · 3 · 100 % | yes | yes | 2 (F4) | `390x844-*.jpg`, `390x844-log.json` |
| Narrow phone | 320x700 · 2 · 100 % | yes | yes | 2 (F4) | `320x700-*.jpg`, `320x700-log.json` |
| Phone, large text | 390x844 · 3 · 200 % | yes | yes | 2 (F4) | `390x844-text200-*.jpg`, `390x844-text200-log.json` |
| Desktop window | 1440x900 · 1 · 100 % | yes | yes | 2 (F4) | `1440x900-*.jpg`, `1440x900-log.json` |

`manifest.json` answered 200 in every run. No service worker was registered
(F5). The logs keep the console messages other than WebGL driver notices.

## Findings

- **F1 (200 % text)** Home: the radar orb's hint line under "Radar / AV"
  ("Tryck för att söka") is clipped by the orb. `390x844-text200-01-home.jpg`.
- **F2 (200 % text)** Offer: the accept orb's word is cut to "Acce…" above
  "TA". `390x844-text200-03-offer.jpg`.
- **F3 (200 % text)** Wallet: "Utbetalningsdatum saknas" wraps in the middle
  of the word ("Utbetalningsd / atum saknas"). `390x844-text200-02-wallet.jpg`.
- **F4 (all runs)** Two uncaught `TypeError: Failed to execute 'observe' on
  'IntersectionObserver': parameter 1 is not of type 'Element'` per run. Not
  in `driver_map_camera.js` or `index.html`; it appears while the Maps script
  is in its InvalidKey state. Re-check with a real key before treating it as
  an app bug.
- **F5 (all runs)** `navigator.serviceWorker.getRegistration()` is empty:
  Flutter's current loader does not register `flutter_service_worker.js` by
  itself. Install relies on the manifest alone; decide whether the PWA needs a
  worker (offline shell, update prompt).
- **F6 (expected)** The trip screen shows "Demoerbjudanden — liveposition
  saknas eller är gammal": the demo's follow-up offers need a live GPS fix,
  which a headless browser has none of.

At 100 % text no clipping, overflow or mid-word break was seen on Home,
Wallet, the offer, the trip screen or after reload, at 390, 320 and 1440 px.

## Not covered here

Safari/WebKit and Edge (no binary reachable from the test machine; the
1440x900 run is Chromium, kept as a reference only), iPhone and Android,
lock/resume, 120 Hz drag, VoiceOver/TalkBack, cold start and soak
performance, the deployed Pages site itself, and the real Google map.
