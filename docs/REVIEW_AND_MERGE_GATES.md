# Driver post-audit review and merge gates

## Safe merge rule

Post-audit phases are merged one at a time only after their own exact-head CI succeeds. Descendants are retargeted to the updated `main` before merge. A planning document or a green ancestor does not validate a newer implementation head.

## Post-audit sequence

| Phase | PR | Scope | Final handling |
| --- | --- | --- | --- |
| 32 | #48 | Post-audit baseline | merged |
| 33 | #49 | Active-surface ownership | merged |
| 34 | #50 | Driver session / on-trip lifecycle | merged |
| 35 | #51 | Real-device sheet evidence record | merged; no defect reproduced |
| 36 | #52 | Active Ride sheet rewrite | intentionally unmerged; no reproduced defect |
| 37 | #53 | Home sheet rewrite | intentionally unmerged; no reproduced defect |
| 38 | #54 | Rider contact truth | merged |
| 39 | #55 | Cancellation integrity | merged |
| 40 | #56 | History truth | merged |
| 41 | #57 | Operational/demo data truth | merged |
| 42 | #58 | Local storage hardening | merged |
| 43 | #59 | Realtime ordering/idempotency | merged |
| 44 | #60 | Terminal marker retention | merged |
| 45 | #61 | Conservative dead-code cleanup | merged |
| 46 | #62 | Final verification/docs | historical only; not the current gate |

## Automated gate

The workflow on main is `.github/workflows/drider-ci.yml` (`Drider CI`). A green ancestor does not certify a descendant. Squash merge only after the pull-request head's own run is green. The squash commit is a different SHA; cite a main push run only when that run's `head_sha` is the squash commit.

Jobs on a commit whose workflow file contains them:

- `verify`: `flutter pub get --enforce-lockfile`, `flutter analyze --fatal-infos`, `flutter test`, `flutter test integration_test/driver_lifecycle_test.dart -d flutter-tester`, `flutter build web --release`, artifact upload.
- `android-release`: production `flutter build apk --release` must fail closed with `Production Android release refuses debug signing` when upload signing secrets are absent; a required-but-blank `GOOGLE_MAPS_API_KEY` must fail with `Native release requires GOOGLE_MAPS_API_KEY`; an explicit preview build uses `MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW=true`.
- `ios-release-preflight`: `flutter build ios --release --no-codesign`.

The native jobs were added in F04 (pull request #76). The lifecycle step was added in F05 (pull request #85). Earlier exact-head runs that list only "Analyze, test and build web" did not execute those later jobs. See [FRONTEND_16_POINT_RECORD.md](FRONTEND_16_POINT_RECORD.md) for the recorded run IDs. Do not copy those IDs onto a newer SHA.

## Runtime/device evidence

The product owner reported a real-device sheet smoke test on 2026-09-30 with no problem observed. The device model, platform/browser build, 10-repeat gesture matrix and video traces were not captured. Therefore this evidence supports **no speculative sheet change**, but it is not a full iPhone+Android certification.

## Product truth gate

The repository remains a frontend/demo. Dispatch, reservations, payments, support transport, rider chat delivery, document review, OTP, safety recording/sharing and production authentication are not connected services. UI must not claim those actions succeeded when only local state changed.

## 16-point frontend record

Findings F01–F12 and F14–F16 are merged. F13 is documentation of that work and is not a certification. [docs/certification/RELEASE_EVIDENCE_MATRIX.md](certification/RELEASE_EVIDENCE_MATRIX.md) stays PENDING. Device, browser, visual, accessibility, and performance PASS is not claimed. The headless lifecycle test does not certify native Google Maps.
