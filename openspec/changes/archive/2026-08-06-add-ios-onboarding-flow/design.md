## Context

The repository contains an Xcode-generated SwiftUI/SwiftData sample with no product architecture or third-party packages. Its project currently targets iOS 26.2 for iPhone and iPad, while this change must support iOS 17+ on portrait-only iPhone. The visual source is `Design/notmeyet-ios-flow.html`; the agreed written flow is authoritative wherever the prototype's selected states, links, or dismissible paywall conflict with it.

The onboarding is a branching 13-screen journey with authentication, sensitive image handling, two asynchronous backend operations, and entitlement-gated completion. The Looksmaxxing OpenAPI contract and a successful end-to-end trace are now available for `https://api.micmac.io`; Firebase, Google, RevenueCat, legal URLs, backend failure/refund semantics, and production retention/deletion terms remain externally configured or deferred. The implementation therefore needs a concrete live Looks adapter alongside deterministic mocks, without allowing placeholder configuration or unapproved facial-data handling to contact a service.

## Goals / Non-Goals

**Goals:**

- Deliver the complete native onboarding journey and an empty Main App destination with deterministic routing.
- Match the supplied phone design at compact, standard, and large iPhone sizes while retaining native accessibility behavior.
- Make authentication, analysis, generation, and purchase effects replaceable and independently testable.
- Complete the live Looksmaxxing happy path using Firebase bearer authentication, bounded selfie upload, cancellable polling, ranked hairstyle selection, and ephemeral result-image loading.
- Keep questionnaire answers, photos, analysis, and generated looks in memory only.
- Make the active RevenueCat entitlement the sole authority for Main App access.
- Allow developers and UI tests to exercise every success and failure state before external configuration arrives.

**Non-Goals:**

- Implement any of the six Main App screens shown after onboarding in the HTML.
- Support iPad, landscape orientation, a newly invented dark theme, localization, analytics, or deep links.
- Define backend failure/refund/idempotency semantics, result retention or deletion policy, Main App analysis-detail presentation, or legal text.
- Persist questionnaire answers, photos, harmony results, generated images, or exact in-progress screens.
- Perform local face detection, liveness, or photo-quality validation; screen 07 is review UI, not a verified quality claim.
- Build a custom production paywall or custom camera capture pipeline.

## Decisions

### 1. Use one explicit observable flow state

A `@MainActor` Observation model owns the app access phase, `OnboardingStep`, ephemeral `OnboardingDraft`, async operation phases, and injected clients. The app root owns this model with `@State`; focused child views receive only the values and actions they need. The model is the sole mutation path for route changes and effects.

Conceptual state:

```text
AppAccessPhase
  bootstrapping
  onboarding(OnboardingStep)
  main
  configurationUnavailable

OnboardingDraft
  primaryGoal?             in memory
  painPoints               in memory
  direction?               in memory
  preparedPhoto?           in memory
  harmonyResult?           in memory
  generatedLook?           in memory
```

An enum-driven content switch is preferable to a free-form `NavigationStack` path because skips, processing screens, and the hard paywall permit only an explicit transition set. It also prevents interactive back gestures from escaping screen 12 or revisiting an invalid processing state. This is simpler than TCA, MVI, or a coordinator for one self-contained SwiftUI feature, while remaining testable through injected clients.

The complete transition table is:

| From | Event | To |
|---|---|---|
| bootstrap | no Firebase user | 01 Welcome |
| bootstrap | Firebase user, identity synchronized, active entitlement | Main |
| bootstrap | Firebase user, no entitlement, stored gate is paywall | 12 Paywall |
| bootstrap | Firebase user, no entitlement, stored gate is photo | 06 Photo preparation |
| bootstrap | Firebase user, no entitlement, gate is start, missing, corrupt, or from a future version | Clear unsupported value and show 01 Welcome |
| bootstrap | unresolved configuration/access error | Configuration unavailable or retry state; never Main |
| 01 | `Discover my next look` | 02 |
| 01 | `Already have an account? Sign in` | 13 |
| 02 | back / `Build my preview` | 01 / 03 |
| 03 | back / `That sounds like me` | 02 / 04 |
| 04 | back / `Choose my direction` | 03 / 05 |
| 05 | back / successful Apple or Google auth | 04 / 06 |
| 06 | camera or library returns one photo | 07 |
| 06 | picker cancellation or permission interruption | 06 |
| 06 | `Skip harmony check` | 12 |
| 07 | back or `Retake` / `Use this photo` | 06 / 08 |
| 08 | analysis success / failure | 09 / 08 retry state |
| 09 | `Show me a matching hairstyle` / `Skip look` | 10 / 12 |
| 10 | generation success / failure | 11 / 10 retry state |
| 11 | `Try more` | 12 |
| 12 | active entitlement confirmed after purchase or restore | Main |
| 12 | cancellation, failure, or no active entitlement | 12 |
| 13 | back or `Start onboarding` | 01 |
| 13 | auth plus active entitlement / auth without entitlement | Main / 12 |

Starting a new photo selection or retake cancels any in-flight request and clears prior photo-derived results. The model owns one structured task handle for analysis and one for generation, cancels and replaces them on retry or route reset, and treats `CancellationError` as a silent non-result. Clients must propagate cooperative cancellation. Each invocation also has one request identity as a second guard, so stale or out-of-order completions cannot advance the route.

### 2. Represent choices as stable domain values

Choices are typed values rather than display strings so later REST mapping does not leak into views. Copy remains centralized and exact:

| Screen | Cardinality | Values |
|---|---|---|
| 02 | zero or one; initially empty; selected value can be cleared | `Find a haircut that actually suits me`; `Look sharper and more put-together`; `Break out of my current style`; `Feel more confident about my appearance`; `Avoid regretting my next haircut`; `Just see what else could work` |
| 03 | zero through six; initially empty; each value toggles independently | `I don't know what suits my face`; `Haircuts look different on me than on the model`; `I can't picture a new style before committing`; `I don't know what to ask my barber for`; `I've regretted a haircut before`; `I keep choosing the same safe style` |
| 04 | zero or one; initially empty; selected value can be cleared | `Subtle` / `A cleaner version of my current look`; `Noticeable` / `Clearly different, but still easy to wear`; `Bold` / `Show me something I wouldn't normally try` |

All three continuation buttons remain enabled when nothing is selected. Backward navigation retains current in-memory answers. The delivered generation contract defines only `selfieId` and `transformationIds`, so questionnaire answers are never serialized or transmitted by onboarding.

### 3. Extract a small fixed design system from the HTML

The implementation uses reusable design tokens and focused screen components rather than reproducing web phone chrome. Inter is not bundled by the handoff and the CSS already falls back to `-apple-system`, so native San Francisco text styles preserve the intended typography while supporting Dynamic Type.

| Token | Value |
|---|---|
| Background | `#FAFAFA` |
| Surface | `#FFFFFF` |
| Foreground | `#111111` |
| Muted/meta | `#6B6B6B` |
| Border | `#E5E5E5` |
| Accent | `#2F6FEB` |
| Accent foreground | `#FFFFFF` |
| Success | `#17A34A` |
| Warning | `#EAB308` |
| Danger | `#DC2626` |
| Corner radii | 8, 12, and 16 points; pills use a capsule |
| Primary control | At least 52 points tall; all controls retain at least a 44x44-point hit target |
| Standard horizontal inset | 20 points, reduced only when required to fit 360-point screens |
| Progress track | 4 points tall |
| Motion | 150 ms fast and 200 ms base equivalents, replaced or removed under Reduce Motion |

The root uses the fixed light palette; screen 01 alone places white foreground content over darkened video. Scrollable screens use a bottom safe-area inset for CTAs so content remains reachable at Dynamic Type sizes. Validation covers 360x800, 390x844, and 430x932 points against the 393x852 reference frames, including keyboard-free safe areas and accessibility text sizes.

### 4. Ship an optimized local welcome loop

The 21.84-second, silent H.264 source is 2160x3840 and approximately 33.5 MB. It stays in `Design/` and is not added directly to the application target. Implementation produces a silent portrait derivative no larger than 1080x1920, with final bitrate chosen after visual and bundle-size comparison.

An `AVQueuePlayer` plus `AVPlayerLooper` renders the derivative aspect-fill, muted, without controls. Playback starts only while screen 01 is visible and the scene is active, and pauses when either condition ends. Reduce Motion substitutes a bundled poster image and never autoplays the loop. A native media component is preferred to embedding HTML or a web view because it provides predictable lifecycle, offline behavior, and accessibility.

### 5. Use native system acquisition and ephemeral image preparation

Screen 06 launches `UIImagePickerController` in camera mode with the front camera preferred when available. Camera authorization is checked before presentation; denial provides an explanation and Settings action, unavailability provides a library fallback, and cancellation leaves the user on screen 06. `NSCameraUsageDescription` is required.

Library selection uses SwiftUI `PhotosPicker` with a one-image limit, avoiding broad photo-library access. Selection cancellation and decoding failures remain on screen 06 with recoverable feedback. The preparation screen's guide is instructional and is not a custom live camera overlay.

The selected asset is normalized for orientation, stripped of metadata, and downsampled according to an `ImagePreparationPolicy`. A dedicated photo-processing actor performs normalization, downsampling, JPEG encoding, and thumbnail work away from the main actor and returns a `Sendable` value containing immutable data. The current policy caps the long edge at 2048 pixels and encodes JPEG at 0.85 quality; live upload additionally rejects prepared bytes above the backend-configured 10,485,760-byte (10 MiB) ceiling before constructing a request. A `PreparedPhoto` holds display and upload bytes only in memory. Retake, returning to the start, a received memory warning, or process termination cancels photo-derived work and discards it; an in-process memory warning atomically returns screens 07-11 to screen 06 with recoverable feedback.

### 6. Keep the concrete REST workflow behind presentation-ready results

The UI depends on a `LooksClient`, not wire DTOs. Its two operations remain conceptually:

```text
analyze(preparedPhoto) -> HarmonyResult
generateLook(preparedPhoto, availableAnalysisContext) -> GeneratedLook
```

`HarmonyResult` supplies downloaded annotated-mesh image bytes, the display-normalized `shape.primaryShape`, and `symmetry.overallScore`. Screen 09 formats a finite score in the inclusive `0...100` range with one decimal place as `<score> / 100` and exposes an equivalent “out of 100” accessibility value. Other analysis ratios and details are outside onboarding. `GeneratedLook` supplies bounded decoded generated-image bytes, `TransformationResponse.displayName`, and its static `description`; screen 11 labels that copy `About this look`. `personalizedReason`, when present, is ignored until a future capability defines its behavior. Remote image URLs remain private transport values and never enter screen state.

`LiveLooksService` is an actor and owns one non-persistent remote session for the current `PreparedPhoto.id`. The session retains only the exact decimal-string selfie ID, whether analysis was accepted, the completed response needed for mapping, the selected transformation, and the generation ID. Re-entering the same high-level operation resumes known polling or image-download work; starting with another photo replaces the session. This private correlation keeps wire values out of screen state while avoiding duplicate POSTs after a response has supplied its remote ID.

Every remote identifier is represented internally as a nonempty ASCII decimal string. A checked conversion requires a positive `Int64` before writing the numeric `selfieId` and `transformationIds` fields still declared by the request contract; URL path and query components use the exact decimal string. String response IDs are never parsed through floating-point storage, and the migrated analysis acknowledgement uses a string `selfieId`.

The analysis operation performs this sequence:

1. Obtain the current Firebase user's ID token through an injected async token provider and send it as `Authorization: Bearer <token>`.
2. Validate the prepared JPEG is no larger than 10,485,760 bytes and upload it as a sanitized `selfie.jpg` `file` part to `POST /api/v1/selfies`.
3. Retain the exact string `SelfieResponse.id`, trigger `POST /api/v1/selfies/{id}/analysis`, and do not derive correlation from a precision-losing numeric acknowledgement.
4. Poll `GET /api/v1/selfies/{id}` every three seconds for at most 40 attempts. Explicit `null` analysis values are incomplete; completion requires non-null `deepface`, `symmetry`, `shape`, `mesh`, and `ratio` blocks.
5. Validate nonempty `shape.primaryShape`, a finite `symmetry.overallScore` in `0...100`, and an HTTPS `mesh.imageUrl`; download and decode the annotated mesh through the same non-persistent sensitive-image policy before returning `HarmonyResult`.

The generation operation begins only after the user requests a matching hairstyle:

1. Call `GET /api/v1/transformations/search` with the retained `selfieId` and `categories=HAIRSTYLE`; do not call the diagnostic `/users/me` endpoint.
2. Select the first ranked response, which the backend guarantees costs one credit, and require a valid ID, `category == HAIRSTYLE`, `creditPrice == 1`, nonempty `displayName`, and nonempty static `description`. A malformed first response fails closed; the app does not skip to a lower-ranked result.
3. Send `POST /api/v1/generations` with exactly that selfie ID and one transformation ID. The JSON request contains no questionnaire values.
4. Poll `GET /api/v1/generations/{id}` every three seconds for at most 40 attempts. `PENDING`, `SUBMITTING`, `AWAITING_RESULT`, and `PROCESSING` continue; `FAILED` and `PARTIALLY_COMPLETED` fail the one-item onboarding request; `COMPLETED` succeeds only when the item matching the selected `transformationId` is also complete with a valid HTTPS `resultImageUrl`. Item array order is not significant.
5. Download and validate the selected generated image through the non-persistent sensitive-image loader before returning a presentation-ready `GeneratedLook`.

Retry behavior depends on the furthest confirmed remote stage:

| Failure point | Retry behavior |
|---|---|
| Token acquisition, validation, search, or an explicitly rejected request | A user Retry starts that safe stage again. |
| Analysis polling timeout or mesh download failure after a known selfie ID | Retain the selfie ID; a user Retry receives a fresh 40-poll budget or retries only the mesh download without re-uploading or re-triggering accepted analysis. |
| Generation polling timeout or generated-image download failure after a known generation ID | Retain the generation ID; a user Retry receives a fresh 40-poll budget or retries only the image download without creating or charging another order. |
| Ambiguous `POST /generations` outcome without a generation ID | Never replay the create request automatically or through the generic Retry action; show non-retryable safe feedback because duplicate charging cannot be excluded. |
| Terminal `FAILED` or `PARTIALLY_COMPLETED` generation | Show non-retryable safe feedback and do not create a replacement order while refund semantics remain undefined. |

Each invocation owns at most 40 polls. Cooperative cancellation stops its timer immediately but retains confirmed remote IDs in the actor; an explicit safe Retry starts a new 40-poll budget. Entering screen 12, entering Main, clearing the flow, a memory warning, or starting another photo clears all local session correlation and every photo-derived draft value, including prepared display/upload bytes, annotated-mesh bytes, generated-image bytes, and mapped results. No polling continues while its structured task is cancelled.

Screens 08 and 10 initiate one cancellable async operation on entry and expose loading, recoverable failure, and non-retryable failure phases. Raw transport and backend `errorMessage` values are mapped to safe user-facing messages. Screen 09 renders the downloaded annotated mesh, face shape, and harmony score. Screen 11 compares the generated bytes already returned by `LooksClient` to the source photo with a split constrained to 12-88 percent; it performs no network request and does not use `AsyncImage`. Looks upload and image-download sessions use ephemeral configurations with no `URLCache`, background transfer, cookie persistence, or sensitive URL/body logging. Mesh and generated-image responses accept only HTTPS redirects whose final URL is also HTTPS, an `image/*` content type, at most 12 MiB of encoded bytes, a decodable raster image, positive dimensions no greater than 8192 pixels on either axis, and no more than 40 million decoded pixels. Downloaded bytes remain in the draft and are released on cancellation, retake, screen-12/Main entry, reset, memory warning, or termination. The comparison exposes a native adjustable value and drag interaction; VoiceOver and keyboard users can increment or decrement it without relying on the drag gesture.

The mock client returns deterministic annotated-image, shape, score, style-name, static-description, and generated-image byte fixtures and can inject delay or each documented failure for previews, unit tests, and UI tests. The live client remains fail-closed until the base URL, Firebase user, image policy, legal URLs, and facial-data disclosures are complete.

### 7. Authenticate first, then bind purchases to the Firebase UID

`AuthenticationClient` exposes current identity and Apple/Google sign-in operations. The Apple adapter uses AuthenticationServices, a per-request random nonce, and SHA-256 nonce verification before exchanging the credential with Firebase. The Google adapter obtains Google tokens through Google Sign-In and exchanges a Firebase credential. The app root forwards Google OAuth callback URLs to Google Sign-In through `.onOpenURL`; this provider callback is not product deep-link routing. User cancellation stays on the current auth screen without an error banner; provider or Firebase failures show recoverable inline feedback.

Screen 05 uses the same providers for account creation or sign-in. It binds the resulting Firebase UID to RevenueCat, records the per-user photo gate, and always continues to screen 06 even if that account already has an active entitlement. It does not show the HTML's `Already have an account? Sign in` link. Screen 13 is reachable only from screen 01; after authentication it binds the UID and performs the entitlement decision instead of continuing the new-user flow.

Every authentication result binds the stable Firebase UID to RevenueCat before any later paywall operation. The Main/paywall access branch below runs at launch, after screen-13 authentication, and after screen-12 purchase or restore; screen-05 authentication stops after identity binding and follows its required screen-06 route.

```text
Firebase current user / auth result
             |
             v
      stable Firebase UID
             |
             v
RevenueCat configure-or-logIn(UID)
             |
             v
refresh CustomerInfo for configured entitlement
             |
        +----+----+
        |         |
      active    inactive/error
        |         |
      Main     gate-derived onboarding route or retry
```

No view, persisted flag, successful transaction callback, or production setting can bypass the access branch. A transaction is considered successful for navigation only after returned or refreshed customer information reports the configured entitlement active.

### 8. Embed RevenueCatUI as a hard root destination

Configured production mode embeds RevenueCatUI's paywall as screen 12 rather than presenting it as a dismissible sheet. The app does not supply a close control or `Not now` action and does not permit interactive dismissal or back navigation. RevenueCatUI owns offering presentation and transaction UI; the app owns entitlement verification, error feedback, restore completion, and the transition to Main. Remote configuration must retain visible restore and legal actions and must not introduce a dismiss path.

The HTML paywall is used only to understand intent. A custom SwiftUI hard paywall exists only in explicit mock mode so previews and tests can simulate purchase, cancellation, failure, restore, and entitlement activation without RevenueCat configuration. A custom production paywall was rejected because it would duplicate remote product and disclosure logic.

### 9. Make service mode explicit and fail closed outside development

`AppConfiguration` validates Firebase/Google, RevenueCat, legal URL, and Looks settings before constructing dependencies. Looks authentication is the current Firebase user's ID token obtained at request time; no static Looks credential is stored in app configuration:

| Mode | Selection | Behavior |
|---|---|---|
| Mock | Compile-time `DEBUG` code plus an explicit Debug setting, preview environment, or UI-test launch argument | Uses deterministic auth, looks, and purchase clients; never initializes or contacts production services |
| Live | Explicit setting and complete non-placeholder configuration | Initializes the real SDK/client adapters |
| Invalid live | Release/non-mock execution with missing or placeholder values, or any mock selector in a non-Debug build | Shows configuration-unavailable/retry diagnostics; never grants Main access or silently enables mock purchasing |

Mock dependency constructors and launch-argument parsing are compiled only under `#if DEBUG`; Release dependency construction has no branch capable of producing mock auth or entitlement clients. Checked-in files contain placeholders or examples only. Real Firebase plist, URL schemes, keys, identifiers, endpoints, and legal URLs are supplied through ignored/local or CI configuration. Placeholder legal actions show an unavailable-in-this-build message instead of opening a fake URL. Explicit mode selection is preferable to detecting arbitrary string patterns throughout the feature and prevents a release build from simulating paid access. Live Looks mode additionally requires approved legal URLs and facial-image retention/deletion disclosures before upload can be enabled.

### 10. Persist only per-user routing gates

A small versioned `OnboardingGateStore` uses UserDefaults for `start`, `photo`, or `paywall`, scoped to Firebase UID after authentication. Missing, corrupt, or unsupported-version values are cleared and resolve to `start`. Firebase and RevenueCat retain their own SDK session data. Questionnaire choices and facial data never enter UserDefaults, SwiftData, URL caches, logs, state restoration, or UI-test attachments.

The gate chooses where an authenticated, non-entitled user resumes; it is not an authorization signal. An entitlement-active user always enters Main, and entitlement errors fail closed. A user terminated during screens 07-11 resumes at screen 06 because the photo was deliberately not persisted. Reaching screen 12 records `paywall`, so relaunch does not force the user through the photo path again.

SwiftData and the generated `Item` model are removed because this scope has no durable domain data. Per-user keys avoid one Firebase account inheriting another account's onboarding checkpoint.

### 11. Treat accessibility and verification as architecture constraints

Every screen exposes one heading as initial accessibility focus after a route change. Choice buttons expose selected state and combine title/description without making color the only indicator. Processing completion and errors are announced without repeatedly interrupting VoiceOver. Decorative movie, guides, and status imagery are hidden or given concise context as appropriate.

The comparison control provides label, percentage value, and adjustable actions. All flows remain operable with VoiceOver, Voice Control, Switch Control, and Full Keyboard Access. Dynamic Type can scroll without covering CTAs; Reduce Motion replaces video and spatial transitions; Reduce Transparency keeps surfaces solid; increased contrast does not erase selection borders.

Unit tests drive the state model with deterministic clients, controllable suspended operations, and a temporary gate store. They cover cancelled and out-of-order completions, retry replacement, retake, route reset, memory warning, corrupt gates, and access ordering. UI tests select mock mode through Debug-only launch arguments and cover the new-user happy path, both skips, returning-user entitlement branches, service retries, hard-paywall persistence, and Main authorization. A Release configuration test verifies that mock launch arguments cannot construct mock clients or activate access. Previews cover default, selected, loading, error, and success states without live SDK initialization.

## Risks / Trade-offs

- **[Deferred backend edge semantics]** Ambiguous POST outcomes, failed paid generations, and refunds are not yet defined -> never automatically replay an ambiguous side-effecting POST, retain known remote IDs in memory, and map unsupported outcomes to safe failure until the backend contract expands.
- **[Snowflake identifier precision]** Numeric JSON consumers can round remote IDs -> retain response identifiers as decimal strings, require the analysis acknowledgement to migrate to a string, and convert only validated request fields that the current API still declares as `int64`.
- **[Placeholder configuration reaches production]** Test credentials or simulated purchases could leak into Release -> require explicit mode selection, validate all live settings centrally, and never fall back to mock mode outside explicit development/test execution.
- **[Wrong RevenueCat identity or stale local access]** A user could be incorrectly admitted or blocked -> serialize Firebase UID binding before customer-info evaluation and treat only the active entitlement as authorization.
- **[RevenueCat remote paywall adds dismissal]** Remote changes could violate the hard-paywall contract -> embed rather than present, disable app-owned dismissal, and add configured-paywall acceptance checks before release.
- **[Sensitive image persistence or metadata disclosure]** Photos could remain beyond the session or upload location metadata -> normalize and strip metadata, keep bytes in memory, avoid logs/state restoration, and clear derived data on retake or termination.
- **[Generated image caching]** Shared image loaders can write returned facial images to disk -> use an injected ephemeral loader with no URL cache and clear its in-memory bytes with the onboarding draft.
- **[Large images exhaust memory]** Modern camera assets can be tens of megapixels -> downsample before retaining upload/display representations and keep one prepared photo per flow.
- **[Main-actor stalls]** Image conversion or decoding can block interaction under the project's actor defaults -> isolate photo and transport processing in worker actors and cross back with `Sendable` values.
- **[Welcome movie harms launch size or motion accessibility]** The source is 4K and 33.5 MB -> ship only an optimized derivative, lazy-start playback, pause off-screen, and use a still poster for Reduce Motion.
- **[Visual fidelity conflicts with accessibility sizes]** Fixed reference frames can clip enlarged text -> preserve tokens and proportions at standard sizes but prioritize scrolling, safe-area CTAs, and system text scaling.
- **[Screen 07 copy implies validation]** Static `Ready` copy could be mistaken for face-quality analysis -> treat it as photo selection readiness only and avoid claiming Vision/backend validation until such a requirement exists.
- **[Mock/live behavior drifts]** A polished mock may hide integration mismatches -> share domain results and state transitions, then add adapter contract tests when Firebase, RevenueCat, and OpenAPI configuration arrives.

## Migration Plan

1. Lower all app/test deployment targets to iOS 17, limit the app to portrait iPhone, add packages/configuration examples, and introduce optimized assets without adding the 4K source to the target.
2. Replace the template SwiftData root with the state model, gate store, dependency construction, mock clients, and empty Main shell.
3. Build screens and native media/photo bridges against mock clients, then add real Firebase/Google and RevenueCat adapters behind validated live configuration.
4. Replace the fail-closed Looks shell with the Firebase-authenticated upload, analysis polling, hairstyle search, generation polling, and response-mapping workflow while preserving the mock boundary.
5. Verify unit, UI, accessibility, device-size, lifecycle, and package-build behavior before enabling live mode.

There is no user-data migration because the existing `Item` model is template data. Routing keys are versioned and may be cleared safely during development. Before live upload is enabled, rollback removes the new root, packages, configuration, and assets and restores the prior template target with no facial-data cleanup. After live upload is enabled, rollback and cleanup must follow the approved backend retention/deletion contract and disclosures; live release remains blocked until those inputs exist.

## Open Questions

- What Firebase plist, Google client ID/URL scheme, Apple team/capability setup, and provider-console configuration will be supplied?
- What RevenueCat public SDK key, Firebase UID identity policy, entitlement identifier, offering, products, and remote paywall configuration define access?
- What final failure/refund/idempotency behavior, result lifetime, and deletion mechanism apply after the implemented Looks happy path?
- What final Terms of Use and Privacy Policy URLs and facial-image retention/deletion disclosures must ship?
- What measured bitrate/codec settings should the optimized welcome derivative use, and what final app icon or brand assets replace placeholders?
