## Context

The repository contains an Xcode-generated SwiftUI/SwiftData sample with no product architecture or third-party packages. Its project currently targets iOS 26.2 for iPhone and iPad, while this change must support iOS 17+ on portrait-only iPhone. The visual source is `Design/notmeyet-ios-flow.html`; the agreed written flow is authoritative wherever the prototype's selected states, links, or dismissible paywall conflict with it.

The onboarding is a branching 13-screen journey with authentication, sensitive image handling, two asynchronous backend operations, and entitlement-gated completion. Firebase, Google, RevenueCat, legal URLs, and REST contracts are not available yet. The implementation therefore needs production integration seams and deterministic mocks without inventing a production contract or allowing placeholder configuration to contact a service.

## Goals / Non-Goals

**Goals:**

- Deliver the complete native onboarding journey and an empty Main App destination with deterministic routing.
- Match the supplied phone design at compact, standard, and large iPhone sizes while retaining native accessibility behavior.
- Make authentication, analysis, generation, and purchase effects replaceable and independently testable.
- Keep questionnaire answers, photos, analysis, and generated looks in memory only.
- Make the active RevenueCat entitlement the sole authority for Main App access.
- Allow developers and UI tests to exercise every success and failure state before external configuration arrives.

**Non-Goals:**

- Implement any of the six Main App screens shown after onboarding in the HTML.
- Support iPad, landscape orientation, a newly invented dark theme, localization, analytics, or deep links.
- Define the missing Looksmaxxing wire contracts, product catalog, credit semantics, or legal text.
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

All three continuation buttons remain enabled when nothing is selected. Backward navigation retains current in-memory answers. Answers are not sent to either endpoint until a delivered contract explicitly maps them.

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

The selected asset is normalized for orientation, stripped of metadata, and downsampled according to an `ImagePreparationPolicy`. A dedicated photo-processing actor performs normalization, downsampling, JPEG encoding, and thumbnail work away from the main actor and returns a `Sendable` value containing immutable data. Mock defaults cap the long edge at 2048 pixels and encode JPEG at 0.85 quality; the live values remain configurable until backend limits arrive. A `PreparedPhoto` holds display and upload bytes only in memory. Retake, returning to the start, a received memory warning, or process termination cancels photo-derived work and discards it; an in-process memory warning atomically returns screens 07-11 to screen 06 with recoverable feedback.

### 6. Isolate unfinished REST transport behind presentation-ready results

The UI depends on a `LooksClient`, not wire DTOs. Its two operations are conceptually:

```text
analyze(preparedPhoto) -> HarmonyResult
generateLook(preparedPhoto, availableAnalysisContext) -> GeneratedLook
```

`HarmonyResult` supplies face-shape title and description, harmony title and description, and presentation-ready guide geometry. Mock guides use normalized `0...1` image coordinates so they scale with aspect-fit image bounds. `GeneratedLook` supplies an HTTPS image URL, style name, and explanation. The final adapters will map delivered `/analysis` and `/selfie` DTOs into these domain values; no speculative production request body is committed before the OpenAPI contract arrives. A transport actor performs request construction, JSON decoding, and response validation away from the main actor and returns `Sendable` domain values.

Screens 08 and 10 initiate one cancellable async operation on entry and expose loading, failure, and retry phases. Raw transport errors are mapped to safe user-facing messages. Screen 09 renders the source photo, response guides, and response copy. Screen 11 uses an injected generated-image loader with loading and retry feedback, then compares the downloaded bytes to the source photo with a split constrained to 12-88 percent. It does not use `AsyncImage` or a shared cached session. Looks upload and image-download sessions use ephemeral configurations with no `URLCache`, background transfer, cookie persistence, or sensitive URL/body logging; downloaded bytes remain in the draft and are released on cancellation, retake, reset, memory warning, or termination. The comparison exposes a native adjustable value and drag interaction; VoiceOver and keyboard users can increment or decrement it without relying on the drag gesture.

The mock client returns deterministic fixtures based on the supplied sample image and can inject delay or each documented failure for previews, unit tests, and UI tests. The live client remains fail-closed until base URL, authentication, image policy, and DTO mappings are complete.

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

`AppConfiguration` validates Firebase/Google, RevenueCat, legal URL, and Looks settings before constructing dependencies:

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

- **[Unknown REST contracts]** A guessed request or guide model could require rework -> keep wire DTOs out of views, make mock results presentation-ready, and leave live transport fail-closed until OpenAPI arrives.
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
4. Add the fail-closed Looks transport shell; complete its DTO mapping only when the OpenAPI contracts arrive.
5. Verify unit, UI, accessibility, device-size, lifecycle, and package-build behavior before enabling live mode.

There is no user-data migration because the existing `Item` model is template data. Routing keys are versioned and may be cleared safely during development. Before live upload is enabled, rollback removes the new root, packages, configuration, and assets and restores the prior template target with no facial-data cleanup. After live upload is enabled, rollback and cleanup must follow the approved backend retention/deletion contract and disclosures; live release remains blocked until those inputs exist.

## Open Questions

- What Firebase plist, Google client ID/URL scheme, Apple team/capability setup, and provider-console configuration will be supplied?
- What RevenueCat public SDK key, Firebase UID identity policy, entitlement identifier, offering, products, and remote paywall configuration define access?
- What base URL, authentication, image limits, request fields, response DTOs, guide-coordinate system, and generated-image lifetime apply to `/analysis` and `/selfie`?
- What final Terms of Use and Privacy Policy URLs and facial-image retention/deletion disclosures must ship?
- What measured bitrate/codec settings should the optimized welcome derivative use, and what final app icon or brand assets replace placeholders?
