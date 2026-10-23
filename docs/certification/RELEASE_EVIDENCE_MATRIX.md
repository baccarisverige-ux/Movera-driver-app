# Release evidence matrix

Fill one row per check on the **exact** release commit. A row may say PASS
only when `artifact` points at a log, screenshot, or workflow run for that
same SHA. This file does not certify a device, browser, or performance run
by itself.

| id | surface | device_or_browser | os | viewport | text_scale | reduced_motion | result | artifact |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| web-ci | Flutter web release build | GitHub ubuntu | ubuntu-latest | n/a | 100% | n/a | PASS | https://github.com/baccarisverige-ux/Movera-driver-app/actions/runs/39843117314 (Drider CI on b8bd860, job verify) |
| lifecycle | Launch to Home via offer | Flutter test | host | 375x812 | 100% | false | PASS | https://github.com/baccarisverige-ux/Movera-driver-app/actions/runs/39843117314 (driver_lifecycle_test in job verify) |
| chrome | Deployed web (local release build of the same SHA; Pages not reachable from the test machine) | Chromium 1194 headless | Linux | 390x844 | 100% | false | PASS | docs/frontend-completion/evidence/browser-b8bd860/REPORT.md, 390x844-*.jpg |
| safari | Deployed web | Safari | pending | 390x844 | 100% | false | PENDING | no WebKit binary reachable from the test machine (23 Oct) |
| edge | Deployed web | Edge | pending | 1440x900 | 100% | false | PENDING | Chromium 1440x900 reference only: docs/frontend-completion/evidence/browser-b8bd860/1440x900-*.jpg |
| visual-390 | Home, offer, active ride, wallet | screenshot | Chromium 1194 | 390x844 | 100% | false | PASS | docs/frontend-completion/evidence/browser-b8bd860/390x844-01..05 |
| visual-320 | Same surfaces, narrow | screenshot | Chromium 1194 | 320x700 | 100% | false | PASS | docs/frontend-completion/evidence/browser-b8bd860/320x700-01..05 |
| text-200 | Same surfaces, large text | screenshot | Chromium 1194 | 390x844 | 200% | false | FAIL | docs/frontend-completion/evidence/browser-b8bd860/390x844-text200-01..05; findings F1-F3 in REPORT.md (orb hint clipped, Accept cut, mid-word wrap) |
| iphone | Sheet, map, lock/resume | physical iPhone | pending | device | 100% | false | PENDING | |
| android | Sheet, map, lock/resume | physical Android | pending | device | 100% | false | PENDING | |
| refresh-120 | High refresh sheet drag | physical | pending | device | 100% | false | PENDING | |
| a11y | VoiceOver and TalkBack | physical | pending | device | 100% | false | PENDING | |
| perf-startup | Cold start | trace | pending | n/a | 100% | false | PENDING | |
| perf-soak | 30 minute online idle | trace | pending | n/a | 100% | false | PENDING | |
| pwa | Install, reload, lock | browser | Chromium 1194 | 390x844 | 100% | false | PENDING | reload restores the trip and manifest answers 200 (docs/frontend-completion/evidence/browser-b8bd860/*-05-after-reload.jpg); no service worker (F5); lock needs a phone |

Physical, browser, visual, and performance rows stay PENDING until a human
records the artifact for the candidate being shipped. Do not copy an older
workflow run onto a newer SHA.
