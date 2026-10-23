# Release evidence matrix

Fill one row per check on the **exact** release commit. A row may say PASS
only when `artifact` points at a log, screenshot, or workflow run for that
same SHA. This file does not certify a device, browser, or performance run
by itself.

| id | surface | device_or_browser | os | viewport | text_scale | reduced_motion | result | artifact |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| web-ci | Flutter web release build | GitHub ubuntu | ubuntu-latest | n/a | 100% | n/a | PENDING | |
| lifecycle | Launch to Home via offer | Flutter test | host | 375x812 | 100% | false | PENDING | |
| chrome | Deployed web | Chrome | pending | 390x844 | 100% | false | PENDING | |
| safari | Deployed web | Safari | pending | 390x844 | 100% | false | PENDING | |
| edge | Deployed web | Edge | pending | 1440x900 | 100% | false | PENDING | |
| visual-390 | Home, offer, active ride, wallet | screenshot | pending | 390x844 | 100% | false | PENDING | |
| visual-320 | Same surfaces, narrow | screenshot | pending | 320x700 | 100% | false | PENDING | |
| text-200 | Same surfaces, large text | screenshot | pending | 390x844 | 200% | false | PENDING | |
| iphone | Sheet, map, lock/resume | physical iPhone | pending | device | 100% | false | PENDING | |
| android | Sheet, map, lock/resume | physical Android | pending | device | 100% | false | PENDING | |
| refresh-120 | High refresh sheet drag | physical | pending | device | 100% | false | PENDING | |
| a11y | VoiceOver and TalkBack | physical | pending | device | 100% | false | PENDING | |
| perf-startup | Cold start | trace | pending | n/a | 100% | false | PENDING | |
| perf-soak | 30 minute online idle | trace | pending | n/a | 100% | false | PENDING | |
| pwa | Install, reload, lock | browser | pending | 390x844 | 100% | false | PENDING | |

Physical, browser, visual, and performance rows stay PENDING until a human
records the artifact for the candidate being shipped. Do not copy an older
workflow run onto a newer SHA.
