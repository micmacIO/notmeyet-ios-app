## proposal Round 1 — 2026-08-04 21:15

### 🔴 Fixed

- Written-flow precedence and intentional departures from the HTML were implicit -> made behavior precedence, empty/clearable choices, screen-05 link removal, and the illustrative paywall explicit.
- Launch access authority was ambiguous -> required Firebase-to-RevenueCat identity synchronization before evaluation and made the active entitlement the only Main authorization source.

### 🟡 Addressed

- Visual dimensions and media handling were incomplete -> added the complete phone matrix, reference frame, palette exception, optimized derivative, and source preservation.
- Cross-module ownership was too generic -> added the observable in-memory flow and transport-independent result boundary.
- Deferred external inputs were under-enumerated -> added the full production configuration, contract, privacy, media, and branding inventory.

### 🔴 Outstanding

- None.

## proposal Round 2 — 2026-08-04 21:17

### 🔴 Fixed

- Confirmed the source-precedence, launch-authorization, visual, media, module-boundary, and deferred-input fixes from Round 1.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## design Round 1 — 2026-08-04 21:32

### 🔴 Fixed

- Screen-05 routing conflicted with a global post-auth entitlement branch -> separated identity binding from route-specific access evaluation so screen 05 always continues to screen 06.
- Runtime mock selection could have admitted Release users -> made mock construction and selector parsing Debug-only and added a Release invariant test.
- Generated-image loading could have persisted facial bytes in shared caches -> required injected ephemeral upload/download sessions with no disk cache or sensitive logging.

### 🟡 Addressed

- Gate and memory-pressure fallback paths were incomplete -> mapped start/missing/corrupt/future gates and made memory warnings cancel work, clear derived state, and return to screen 06.
- Cancellation and out-of-order behavior lacked a concrete contract -> added model-owned task handles, cooperative cancellation, request identities, and deterministic tests.
- Image and decoding work could inherit MainActor -> assigned photo and transport work to actors with `Sendable` boundaries.
- Google OAuth callback handling was absent -> added app-root URL forwarding distinct from product deep links.
- Rollback assumed uploads never became live -> made legal/retention inputs live release gates and qualified post-live cleanup.

### 🔴 Outstanding

- None.

## design Round 2 — 2026-08-04 21:35

### 🔴 Fixed

- Confirmed all Round 1 routing, Release-mode, memory-only networking, fallback, cancellation, actor-isolation, OAuth callback, and rollback fixes.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## specs Round 1 — 2026-08-04 21:44

### 🔴 Fixed

- RevenueCat binding/evaluation failures after screen-05 and screen-13 Firebase authentication were undefined -> required fail-closed retry behavior with no gate write or route advancement.
- Photo preparation did not require privacy and memory controls -> required orientation normalization, complete metadata removal, bounded pixels/encoding, and mock policy limits for every acquired photo.
- Technical REST readiness could enable facial upload before legal approval -> made approved legal URLs and retention/deletion disclosures mandatory live-upload gates.

### 🟡 Addressed

- iPhone-only scope was not explicit -> required exclusion of native iPad support.
- Screen-05 Back was absent -> mapped it to screen 04 with choices retained.
- Optimized welcome packaging was vague -> required the bounded derivative, target exclusion, and source preservation.
- Accessibility details were incomplete -> added status announcements, decorative-media semantics, transparency, and contrast behavior.
- Mock paywall legal actions were absent -> added Terms/Privacy actions with safe placeholder behavior.

### 🔴 Outstanding

- None.

## specs Round 2 — 2026-08-04 21:47

### 🔴 Fixed

- Confirmed all Round 1 identity-binding, photo-preparation, legal-upload-gate, platform, routing, media, accessibility, and mock-legal fixes.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## tasks Round 1 — 2026-08-04 21:55

### 🔴 Fixed

- Many implementation and verification items exceeded the two-hour task cap -> decomposed state, UI, provider, photo, transport, paywall, test, visual, and privacy work into focused units.
- Authentication and bootstrap depended on later purchase/access work -> moved Firebase identity, RevenueCat UID binding, entitlement evaluation, and access mocks ahead of flow and auth-screen work.
- Configured remote-paywall verification required unavailable production inputs -> replaced it with a completable future acceptance-checklist task and explicit blocked-live documentation.

### 🟡 Addressed

- Rollback coverage was missing -> added pre-live source rollback and post-live retention/deletion cleanup documentation.
- Questionnaire non-transmission had no focused evidence -> added an explicit transport serialization test.
- Visual verification was open-ended -> split it into bounded screen/state groups across the required dimensions.

### 🔴 Outstanding

- None.

## tasks Round 2 — 2026-08-04 21:59

### 🔴 Fixed

- End-to-end error and visual/accessibility tasks still exceeded two hours -> split Retake and each service error path, separated visual capture from correction per screen, and divided audits by preference, assistive technology, and screen group.
- Entitlement revocation had tests but no implementation -> added authoritative customer-info update handling from Main before the revocation test.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## tasks Round 3 — 2026-08-04 22:02

### 🔴 Fixed

- Confirmed the final visual, correction, service-error, and assistive-technology task decomposition satisfies the two-hour cap.
- Confirmed authoritative Main-state entitlement update implementation precedes revocation tests.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## proposal Round 3 — 2026-08-05 15:06

### 🔴 Fixed

- None in this round.

### 🟡 Addressed

- None in this round.

### 🔴 Outstanding

- Live facial-data upload and production release were not explicitly blocked on approved retention/deletion terms, disclosures, and legal URLs.
- The concrete transformation flow omitted the approved `HAIRSTYLE` filter and first-ranked one-credit constraint.

## proposal Round 4 — 2026-08-05 15:06

### 🔴 Fixed

- Made approved retention/deletion terms, disclosures, and legal URLs explicit live-upload and production-release gates.
- Required `HAIRSTYLE` search filtering and selection of the first ranked one-credit transformation.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## design Round 3 — 2026-08-05 15:19

### 🔴 Fixed

- None in this round.

### 🟡 Addressed

- None in this round.

### 🔴 Outstanding

- Generation retry behavior did not distinguish resumable polling/download failures from ambiguous charged POST outcomes or terminal failures.
- First-ranked one-credit selection was ambiguous about whether a malformed first response could be skipped.
- Generated-image URLs crossed the presentation boundary instead of returning bounded presentation-ready bytes.
- Poll-budget ownership, sensitive cleanup, image/redirect bounds, and lossless ID conversion needed explicit design rules.

## design Round 4 — 2026-08-05 15:19

### 🔴 Fixed

- Added a stage-specific retry matrix that never replays ambiguous charged generation creation and does not retry terminal failed orders.
- Required the backend-guaranteed first ranked result and fail-closed validation rather than skipping to a lower-ranked item.
- Moved generated-image download and validation inside `LooksClient`, returning presentation-ready bytes.

### 🟡 Addressed

- Defined per-invocation polling budgets, cancellation/resume behavior, redirect and resource limits, and checked decimal-string/`Int64` conversion.

### 🔴 Outstanding

- Screen-12/Main cleanup did not explicitly clear prepared display and upload bytes from `OnboardingDraft`.

## design Round 5 — 2026-08-05 15:19

### 🔴 Fixed

- Required screen-12/Main entry and other resets to clear prepared display/upload bytes and every other photo-derived draft value.

### 🟡 Addressed

- None.

### 🔴 Outstanding

- None.

## specs Round 3 — 2026-08-05 15:32

### 🔴 Fixed

- None in this round.

### 🟡 Addressed

- None in this round.

### 🔴 Outstanding

- Ambiguous upload and analysis-trigger outcomes could have replayed sensitive side-effecting requests.
- The 2048-pixel/0.85 JPEG preparation policy applied only to mock mode despite the frozen design applying it to live upload too.
- Safe-stage retry categories, omitted analysis blocks, and the exact 10 MB byte ceiling were underspecified.

## specs Round 4 — 2026-08-05 15:32

### 🔴 Fixed

- Made ambiguous upload non-retryable and made an ambiguous analysis trigger poll the known selfie without replaying the trigger.
- Applied the 2048-pixel/0.85 JPEG preparation policy to mock and live paths.

### 🟡 Addressed

- Treated omitted analysis blocks as incomplete and fixed the live ceiling at 10,485,760 bytes.

### 🔴 Outstanding

- Safe retries did not fully enumerate analysis polling/decoding and generation token/search/validation/explicit-rejection stages.

## specs Round 5 — 2026-08-05 15:32

### 🔴 Fixed

- None.

### 🟡 Addressed

- Added explicit safe-stage scenarios for known-selfie and known-generation polling/decoding failures plus pre-generation token, search, validation, and explicit-rejection failures.

### 🔴 Outstanding

- None.

## tasks Round 4 — 2026-08-05 15:48

### 🔴 Fixed

- None in this round.

### 🟡 Addressed

- None in this round.

### 🔴 Outstanding

- Completed screen-11 loading and normalized-guide tasks were not explicitly replaced by the new presentation boundary.
- Privacy audits predated live transport, remote correlation cleanup omitted several reset routes, and multiple implementation/test tasks exceeded two hours.
- Revised visual checks lacked correction pairs, and verification omitted several auth, mapping, error-suppression, ignored-field, and actor-isolation cases.

## tasks Round 5 — 2026-08-05 15:48

### 🔴 Fixed

- Added explicit replacement tasks for screen-11 loading and normalized guides, post-transport privacy audits, every cleanup route, and visual capture/correction pairs.

### 🟡 Addressed

- Added focused token, mapping, raw-error, `personalizedReason`, and non-main-thread image-work verification.

### 🔴 Outstanding

- DTO/domain/image/lifecycle tasks remained too broad, and generation retry wording did not clearly separate safe known-order resume from ambiguous or terminal failures.

## tasks Round 6 — 2026-08-05 15:48

### 🔴 Fixed

- None.

### 🟡 Addressed

- Split DTO, domain, image, and lifecycle work into bounded tasks and separated safe known-order resume from non-retryable ambiguous/terminal generation behavior.

### 🔴 Outstanding

- None.
