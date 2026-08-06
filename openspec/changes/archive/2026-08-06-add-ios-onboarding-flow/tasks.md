## 1. Project Baseline and Dependencies

- [x] 1.1 Set the app deployment target to iOS 17.0 and update test targets to match.
- [x] 1.2 Limit the app target to iPhone portrait and add the camera usage description.
- [x] 1.3 Add and resolve FirebaseCore, FirebaseAuth, and GoogleSignIn Swift Package products.
- [x] 1.4 Add and resolve RevenueCat Purchases and RevenueCatUI Swift Package products.
- [x] 1.5 Add checked-in placeholder/example configuration and ignore real local or CI Firebase, Google, RevenueCat, legal, and Looksmaxxing values.
- [x] 1.6 Add the Sign in with Apple entitlement scaffold and placeholder Google callback URL-scheme configuration.
- [x] 1.7 Remove the generated `Item` and SwiftData root wiring and add a minimal app root plus empty Main App skeleton.
- [x] 1.8 Create a silent welcome-video derivative no larger than 1080x1920 and a poster image, excluding the 4K source from the target.
- [x] 1.9 Add the supplied sample portrait and deterministic generated-look fixture resources to the app target.

## 2. Domain, Gates, Configuration, and Mocks

- [x] 2.1 Define onboarding-step, app-access-phase, operation-phase, and routing-gate values.
- [x] 2.2 Define typed screen 02-04 choice values with all labels, descriptions, and cardinality metadata.
- [x] 2.3 Define `Sendable` prepared-photo, harmony-result, guide-geometry, and generated-look values without REST DTO dependencies.
- [x] 2.4 Define authentication, purchase/access, and routing-gate client boundaries.
- [x] 2.5 Define Looks, generated-image-loading, and photo-processing client boundaries.
- [x] 2.6 Implement per-Firebase-UID `start`/`photo`/`paywall` gate reads and writes.
- [x] 2.7 Add routing-gate tests for versioning, missing/corrupt values, unsupported versions, and account isolation.
- [x] 2.8 Implement centralized explicit mock, live, and invalid-live configuration validation.
- [x] 2.9 Compile mock dependency construction and launch-selector parsing only in Debug.
- [x] 2.10 Add configuration tests for valid mock/live modes, missing placeholders, and Release rejection of mock selectors.
- [x] 2.11 Implement deterministic mock authentication identity, success, cancellation, and failure outcomes.
- [x] 2.12 Implement deterministic mock UID binding, entitlement refresh, purchase, restore, revocation, cancellation, and failure outcomes.

## 3. Identity and Access Foundation

- [x] 3.1 Implement guarded Firebase initialization and current-user lookup for validated live mode.
- [x] 3.2 Implement guarded RevenueCat configure-or-log-in behavior using the Firebase UID.
- [x] 3.3 Implement configured-entitlement extraction from RevenueCat customer information.
- [x] 3.4 Implement serialized UID binding followed by entitlement evaluation for launch and returning-user access checks.
- [x] 3.5 Add access-coordinator tests for no Firebase user, active entitlement, and inactive entitlement.
- [x] 3.6 Add access-coordinator tests for UID-binding failure, entitlement-refresh failure, cancellation, and stale results.
- [x] 3.7 Add a Release invariant test proving mock selectors and simulated entitlement values cannot construct access-granting clients.

## 4. Observable Flow State

- [x] 4.1 Create the `@MainActor` observable flow model, in-memory onboarding draft, and injected dependency initializer.
- [x] 4.2 Implement screen 01-05 forward and Back transitions.
- [x] 4.3 Implement screen 06-13 forward, skip, Retake, Back, and hard-paywall transitions.
- [x] 4.4 Implement empty, single-clearable, and independent-multi choice mutations with in-process Back retention.
- [x] 4.5 Implement photo and paywall gate writes at their specified transition points.
- [x] 4.6 Implement model-owned analysis task start, retry replacement, cancellation, and request-identity checks.
- [x] 4.7 Implement model-owned generation and generated-image task start, retry replacement, cancellation, and request-identity checks.
- [x] 4.8 Implement memory-warning and route-reset cleanup for photo-derived state.
- [x] 4.9 Implement bootstrap selection for no user, active access, photo/paywall/default gates, invalid configuration, and retry.
- [x] 4.10 Add state tests for screen 01-05 routes, zero-selection continuation, clearing, and Back retention.
- [x] 4.11 Add state tests for screen 06-13 routes, both skips, Retake, hard-paywall lock, and gate writes.
- [x] 4.12 Add controllable-operation tests for cancellation, retry replacement, and out-of-order analysis/generation completions.
- [x] 4.13 Add state tests for memory warning, termination-style photo loss, corrupt gate fallback, and bootstrap failures.

## 5. Design System and Shared Accessibility

- [x] 5.1 Add fixed palette and native typography tokens from the HTML design.
- [x] 5.2 Add spacing, radius, control-height, progress, and motion tokens from the HTML design.
- [x] 5.3 Build the shared safe-area screen and scroll containers with pinned bottom-action support.
- [x] 5.4 Build shared progress and Back controls with the screen 02-11 percentage mapping.
- [x] 5.5 Build shared primary/secondary buttons and loading/error presentation.
- [x] 5.6 Build the clearable single-choice control with selected semantics and non-color indication.
- [x] 5.7 Build the independent multi-choice control with selected semantics and non-color indication.
- [x] 5.8 Add route-heading accessibility focus and one-shot status/error announcements.
- [x] 5.9 Add Dynamic Type reflow and scrolling behavior to shared containers and controls.
- [x] 5.10 Add shared Reduce Motion, Reduce Transparency, and increased-contrast adaptations.
- [x] 5.11 Add stable accessibility identifiers, speakable input labels, visible keyboard focus, and 44x44-point targets to shared controls.
- [x] 5.12 Add deterministic shared-component previews for default, selected, loading, error, and accessibility-size states.

## 6. Welcome and Questionnaire Screens

- [x] 6.1 Build the muted `AVQueuePlayer`/`AVPlayerLooper` component with visible-screen and scene-activity lifecycle control.
- [x] 6.2 Add the Reduce Motion poster path and decorative accessibility semantics to the welcome media.
- [x] 6.3 Implement screen 01 copy, cinematic styling, and both entry actions.
- [x] 6.4 Implement screen 02 with all six primary-goal choices and its 10-percent progress state.
- [x] 6.5 Implement screen 03 with all six pain-point choices and its 20-percent progress state.
- [x] 6.6 Implement screen 04 with all three titled/described direction choices and its 30-percent progress state.
- [x] 6.7 Add focused UI tests for welcome lifecycle routing and questionnaire empty/clearable/multi-select behavior.

## 7. Firebase Provider Flows and Auth Screens

- [x] 7.1 Implement and unit-test the random nonce and SHA-256 helpers for Sign in with Apple.
- [x] 7.2 Implement Sign in with Apple to Firebase exchange with cancellation and safe error mapping.
- [x] 7.3 Implement Google Sign-In to Firebase credential exchange with cancellation and safe error mapping.
- [x] 7.4 Forward configured Google OAuth callback URLs from the app root and add a callback-routing test.
- [x] 7.5 Build shared Apple/Google authentication controls, legal actions, loading, and inline error states.
- [x] 7.6 Implement screen 05 copy, 40-percent progress, omitted returning-user link, and Back to screen 04.
- [x] 7.7 Connect screen-05 auth to UID binding, binding retry, photo-gate recording, and unconditional screen-06 continuation after successful binding.
- [x] 7.8 Implement screen 13 copy, Back, and `Start onboarding` route.
- [x] 7.9 Connect screen-13 auth to UID binding and active, inactive, binding-failure, and entitlement-failure outcomes.
- [x] 7.10 Add screen-05 tests for provider cancellation/failure, binding failure, gate ordering, and successful routing.
- [x] 7.11 Add screen-13 tests for Back/start, active access, inactive access, and recoverable access-evaluation failure.

## 8. Camera, Library, and Photo Review

- [x] 8.1 Implement worker-isolated orientation normalization and immutable prepared-photo output.
- [x] 8.2 Implement metadata removal, configurable downsampling, and JPEG encoding in the photo processor.
- [x] 8.3 Add photo-processor tests for orientation normalization and complete source-metadata removal.
- [x] 8.4 Add photo-processor tests for mock 2048-pixel/0.85-JPEG limits, malformed input, cancellation, and main-thread responsiveness.
- [x] 8.5 Implement camera authorization states, permission request, denied/restricted explanation, and Settings action.
- [x] 8.6 Build the system camera picker bridge with front-camera preference and successful capture handling.
- [x] 8.7 Add camera-picker handling for unavailable hardware and user cancellation.
- [x] 8.8 Integrate one-image `PhotosPicker` selection with cancellation and decoding-failure handling.
- [x] 8.9 Implement screen 06 guidance, instructional guide, and 50-percent progress presentation.
- [x] 8.10 Connect screen-06 camera, library, legal, and `Skip harmony check` actions.
- [x] 8.11 Implement screen 07 prepared-photo preview, non-validated wording, and 60-percent progress presentation.
- [x] 8.12 Connect screen-07 `Use this photo`, Back, and `Retake` cleanup actions.
- [x] 8.13 Add flow tests for camera/library success and picker cancellation.
- [x] 8.14 Add flow tests for permission denial, unavailable camera, and invalid library images.
- [x] 8.15 Add flow tests for Retake cleanup, screen-06 skip, memory-warning reset, and relaunch without photo restoration.

## 9. Looks Transport and Screens

- [x] 9.1 Implement deterministic mock harmony fields and normalized guide fixtures.
- [x] 9.2 Implement deterministic mock generated-look/image fixtures, delays, and independent failure selection.
- [x] 9.3 Implement the live Looks configuration and approved-disclosure gates without inventing request DTOs.
- [x] 9.4 Build an ephemeral Looks session factory with no disk cache, cookies, background transfer, or sensitive logging.
- [x] 9.5 Implement the worker-isolated fail-closed Looks transport shell and safe error mapping.
- [x] 9.6 Add tests proving placeholder contracts and unapproved retention/deletion disclosures send no request.
- [x] 9.8 Implement screen 08 analysis loading and 70-percent progress presentation.
- [x] 9.9 Add screen-08 safe error, retry, cancellation, and automatic success routing.
- [x] 9.10 Build normalized harmony-guide rendering against aspect-fitted image bounds.
- [x] 9.11 Implement screen 09 response-derived image, face-shape, harmony, disclaimer, and 80-percent progress presentation.
- [x] 9.12 Connect screen-09 matching-hairstyle and `Skip look` actions.
- [x] 9.13 Implement screen 10 generation loading and 90-percent progress presentation.
- [x] 9.14 Add screen-10 safe error, retry, cancellation, and automatic success routing.
- [x] 9.15 Implement an ephemeral generated-image loader with HTTPS, content-type, byte-limit, and decoding validation.
- [x] 9.16 Add generated-image loader tests for success, insecure URL, unsupported/oversized response, retry, cancellation, and no cache.
- [x] 9.17 Build the before/after image composition with a 46-percent initial split and 12-88-percent bounds.
- [x] 9.18 Add drag, native adjustable actions, percentage value, and keyboard operation to the comparison control.
- [x] 9.19 Implement screen 11 response-derived style copy, Before/After labels, 100-percent progress, and `Try more` action.
- [x] 9.20 Add analysis tests for exactly-once execution, retry replacement, cancellation, stale completion, and result routing.
- [x] 9.21 Add generation tests for exactly-once execution, retry replacement, cancellation, stale completion, and result routing.
- [x] 9.22 Add generated-image cleanup tests for Retake, reset, memory warning, and route replacement.
- [x] 9.23 Replace static Looks authentication configuration with an injected current-Firebase-ID-token provider and update configuration tests.
- [x] 9.24 Define private nullable OpenAPI request/response DTOs and tolerant generation-status decoding.
- [x] 9.25 Define checked decimal-string remote IDs and safe `ProblemDetail` response mapping.
- [x] 9.26 Replace normalized-guide harmony values and mock fixtures with annotated image bytes and harmony score.
- [x] 9.27 Replace URL/explanation generated-look values and mock fixtures with generated bytes, display name, and static style description.
- [x] 9.28 Apply the 2048-pixel/0.85-JPEG preparation policy to live mode and reject prepared uploads above 10,485,760 bytes.
- [x] 9.29 Implement the authenticated sanitized multipart request builder and selfie-upload response validation.
- [x] 9.30 Implement exact selfie-ID session correlation and one-time analysis triggering for the current prepared photo.
- [x] 9.31 Implement three-second/40-attempt analysis polling with explicit-null and omitted-block completion handling.
- [x] 9.32 Implement face-shape/score validation and bounded annotated-mesh download into a presentation-ready harmony result.
- [x] 9.33 Implement `HAIRSTYLE` transformation-search request construction and exclude `/api/v1/users/me` from onboarding.
- [x] 9.34 Implement first-ranked transformation validation for ID, category, one-credit price, display name, and static description while ignoring `personalizedReason`.
- [x] 9.35 Implement exact one-item generation request serialization with no questionnaire fields.
- [x] 9.36 Implement generation status polling and transformation-ID item correlation independent of array order.
- [x] 9.37 Implement bounded generated-image download and map presentation-ready bytes plus static style copy.
- [x] 9.38 Implement resumable analysis polling/mesh retries and non-retryable ambiguous selfie-upload behavior.
- [x] 9.39 Implement safe known-order generation polling and image-download resume without creating another charged order.
- [x] 9.40 Implement non-retryable feedback for ambiguous generation creation and terminal `FAILED` or `PARTIALLY_COMPLETED` orders.
- [x] 9.41 Clear remote correlation on Retake, reset, memory warning, replacement photo, screen-12 entry, and Main entry.
- [x] 9.42 Replace normalized-guide screen-09 rendering with the annotated mesh, normalized face-shape title, and one-decimal harmony score plus accessible out-of-100 value.
- [x] 9.43 Remove screen-11 network-loading state and render presentation-ready generated bytes with static description under `About this look`.
- [x] 9.44 Add token/configuration tests for request-time Firebase token acquisition, absent static Looks credentials, and pre-upload authentication failure.
- [x] 9.45 Add request-contract tests for bearer headers, sanitized bounded multipart upload, lossless IDs, exact generation JSON, and absent questionnaire fields.
- [x] 9.46 Add DTO and error-mapping tests for explicit nulls, omitted fields, malformed IDs/statuses, and suppression of raw backend details.
- [x] 9.47 Add analysis polling tests for partial/complete responses, three-second scheduling, 40-attempt timeout, cancellation, and safe known-selfie resume.
- [x] 9.48 Add analysis mapping tests for invalid face shape, score, mesh URL/image, bounded decoding, and non-main-thread image work.
- [x] 9.49 Add transformation-search tests for category query encoding, empty/malformed lists, first-ranked validation, ignored `personalizedReason`, and no `/users/me` call.
- [x] 9.50 Add generation serialization/status tests for one item, every status class, reordered items, bounded polling, and completed-result validation.
- [x] 9.51 Add generation tests for safe known-order resume without a duplicate charged request.
- [x] 9.52 Add generation tests for ambiguous creation, terminal failure, non-retryable feedback, and no replacement order.
- [x] 9.53 Add sensitive-image tests for final-HTTPS redirects plus MIME and encoded-byte limits.
- [x] 9.54 Add sensitive-image tests for dimensions, decoded-pixel limits, decoding, cancellation, and ephemeral sessions.
- [x] 9.55 Update flow-model and mock tests to replace guide and screen-11 image-loading expectations with presentation-ready Looks results.
- [x] 9.56 Update UI and accessibility assertions for annotated analysis, harmony-score speech, removed screen-11 loading, and `About this look` copy.
- [x] 9.57 Add lifecycle tests proving remote transport correlation clears on every specified exit and reset.
- [x] 9.58 Add lifecycle tests proving prepared, annotated-mesh, and generated byte values clear on every specified exit and reset.

## 10. RevenueCatUI and Paywall Outcomes

- [x] 10.1 Embed RevenueCatUI as screen 12 at the app root without app-owned close, Back, `Not now`, or sheet dismissal.
- [x] 10.2 Connect purchase completion to refreshed active-entitlement evaluation.
- [x] 10.3 Add purchase cancellation, failure, and completed-without-entitlement states that remain on screen 12.
- [x] 10.4 Connect restore completion to refreshed active-entitlement evaluation.
- [x] 10.5 Add restore failure and no-active-entitlement states that remain on screen 12.
- [x] 10.6 Build the Debug-only hard mock paywall with Terms/Privacy unavailable-in-this-build behavior.
- [x] 10.7 Add deterministic mock purchase and restore active, inactive, cancellation, and failure outcomes.
- [x] 10.8 Verify and test paywall-gate writes from screen 06, screen 09, screen 11, and screen 13.
- [x] 10.9 Add tests proving no local gate or transaction callback can bypass active-entitlement authorization.
- [x] 10.10 Wire authoritative customer-info updates while Main is visible so an inactive entitlement routes to the hard paywall.
- [x] 10.11 Add tests for later entitlement revocation returning Main users to the hard-paywall route.
- [x] 10.12 Add UI assertions that production and mock screen 12 expose no app-owned dismissal control.

## 11. End-to-End UI Tests

- [x] 11.1 Add a Debug-only UI-test launch harness for deterministic initial identity, gates, service outcomes, and entitlement state.
- [x] 11.2 Test screen 01 through screen 05 with empty questionnaire continuation and successful mock authentication.
- [x] 11.3 Test screen 06 through screen 12 with a fixture photo, analysis, generation, purchase, and Main handoff.
- [x] 11.4 Test screen-06 skip, hard-paywall gate persistence, and relaunch to screen 12.
- [x] 11.5 Test screen-09 skip and its hard-paywall gate persistence.
- [x] 11.6 Test screen-13 active-entitlement routing to Main.
- [x] 11.7 Test screen-13 inactive-entitlement routing to the hard paywall.
- [x] 11.8 Test clearable choices, multi-select choices, and retained values through Back navigation.
- [x] 11.9 Test Retake and return to screen 06 with photo-derived state cleared.
- [x] 11.10 Test analysis failure, retry, and successful continuation.
- [x] 11.11 Test generation failure, retry, and successful continuation.
- [x] 11.12 Test generated-image loading failure, retry, and successful comparison.
- [x] 11.13 Add UI assertions for labels, selected states, stable identifiers, and initial heading focus where observable.
- [x] 11.14 Add UI assertions for comparison percentage adjustment and keyboard/non-drag operation.

## 12. Visual and Assistive-Technology Verification

- [x] 12.1 Capture and compare screen 01 at 360x800, 390x844/393x852, and 430x932.
- [x] 12.2 Correct material screen-01 drift found by task 12.1 and recapture its affected sizes.
- [x] 12.3 Capture and compare screen 02 at the three required phone sizes.
- [x] 12.4 Correct material screen-02 drift found by task 12.3 and recapture its affected sizes.
- [x] 12.5 Capture and compare screen 03 at the three required phone sizes.
- [x] 12.6 Correct material screen-03 drift found by task 12.5 and recapture its affected sizes.
- [x] 12.7 Capture and compare screen 04 at the three required phone sizes.
- [x] 12.8 Correct material screen-04 drift found by task 12.7 and recapture its affected sizes.
- [x] 12.9 Capture and compare screen 05 at the three required phone sizes.
- [x] 12.10 Correct material screen-05 drift found by task 12.9 and recapture its affected sizes.
- [x] 12.11 Capture and compare screen 06 at the three required phone sizes.
- [x] 12.12 Correct material screen-06 drift found by task 12.11 and recapture its affected sizes.
- [x] 12.13 Capture and compare screen 07 at the three required phone sizes.
- [x] 12.14 Correct material screen-07 drift found by task 12.13 and recapture its affected sizes.
- [x] 12.15 Capture and compare screen-08 loading and error states at the three required phone sizes.
- [x] 12.16 Correct material screen-08 drift found by task 12.15 and recapture its affected states and sizes.
- [x] 12.17 Capture and compare screen 09 at the three required phone sizes.
- [x] 12.18 Correct material screen-09 drift found by task 12.17 and recapture its affected sizes.
- [x] 12.19 Capture and compare screen-10 loading and error states at the three required phone sizes.
- [x] 12.20 Correct material screen-10 drift found by task 12.19 and recapture its affected states and sizes.
- [x] 12.21 Capture and compare screen-11 loading, error, and success states at the three required phone sizes.
- [x] 12.22 Correct material screen-11 drift found by task 12.21 and recapture its affected states and sizes.
- [x] 12.23 Capture and compare mock screen 12 at the three required phone sizes.
- [x] 12.24 Correct material mock-screen-12 drift found by task 12.23 and recapture its affected sizes.
- [x] 12.25 Capture and compare screen 13 at the three required phone sizes.
- [x] 12.26 Correct material screen-13 drift found by task 12.25 and recapture its affected sizes.
- [x] 12.27 Capture and review the Main skeleton at the three required phone sizes.
- [x] 12.28 Correct material Main-skeleton layout issues found by task 12.27 and recapture affected sizes.
- [x] 12.29 Verify accessibility Dynamic Type on screens 01-04 and record findings.
- [x] 12.30 Verify accessibility Dynamic Type on screens 05-07 and 13 and record findings.
- [x] 12.31 Verify accessibility Dynamic Type on screens 08-10 and record findings.
- [x] 12.32 Verify accessibility Dynamic Type on screens 11-12 and Main and record findings.
- [x] 12.33 Verify Reduce Motion welcome/media and route-transition behavior.
- [x] 12.34 Verify Reduce Transparency surface behavior on representative light and cinematic screens.
- [x] 12.35 Verify increased-contrast selection, error, guide, and paywall indicators.
- [x] 12.36 Verify VoiceOver labels, order, focus, and announcements on screens 01-04.
- [x] 12.37 Verify VoiceOver labels, order, focus, and announcements on screens 05-07.
- [x] 12.38 Verify VoiceOver labels, order, focus, and announcements on screens 08-10.
- [x] 12.39 Verify VoiceOver comparison adjustment, paywall lock, and screen-13/Main traversal.
- [x] 12.40 Verify Voice Control `Show Names` and `Show Numbers` targetability on screens 01-06.
- [x] 12.41 Verify Voice Control `Show Names` and `Show Numbers` targetability on screens 07-13 and Main.
- [x] 12.42 Verify Switch Control scanning and operation on screens 01-06.
- [x] 12.43 Verify Switch Control scanning and operation on screens 07-13 and Main.
- [x] 12.44 Verify Full Keyboard Access focus and operation on screens 01-06.
- [x] 12.45 Verify Full Keyboard Access focus and operation on screens 07-13 and Main.
- [x] 12.46 Correct recorded accessibility findings on screens 01-04 and rerun affected checks.
- [x] 12.47 Correct recorded accessibility findings on screens 05-07 and 13 and rerun affected checks.
- [x] 12.48 Correct recorded accessibility findings on screens 08-10 and rerun affected checks.
- [x] 12.49 Correct recorded accessibility findings on screens 11-12 and Main and rerun affected checks.
- [x] 12.50 Recapture and inspect the revised screen 09 at 360x800, 390x844/393x852, and 430x932.
- [x] 12.51 Correct material revised-screen-09 drift and recapture affected sizes.
- [x] 12.52 Recapture and inspect the revised screen 11 at the three required phone sizes.
- [x] 12.53 Correct material revised-screen-11 drift and recapture affected sizes.

## 13. Build, Privacy, Rollback, and Release Gates

- [x] 13.1 Build app and test targets in Debug for an iOS 17-compatible iPhone simulator and resolve availability diagnostics.
- [x] 13.2 Resolve strict-concurrency and actor-isolation diagnostics in the Debug build.
- [x] 13.3 Run the Swift Testing suite in mock mode and resolve failures.
- [x] 13.4 Run the XCUITest suite in mock mode and resolve failures.
- [x] 13.5 Build Release with placeholder configuration and verify it fails closed without mock-only access paths.
- [x] 13.6 Audit built resources for the excluded 4K source, accidental real secrets, and unintended fixture inclusion.
- [x] 13.7 Audit runtime storage and URL caches for questionnaire answers, source metadata, photo bytes, and generated-image bytes.
- [x] 13.8 Audit runtime logs and test attachments for sensitive URLs, credentials, request bodies, and facial data.
- [x] 13.9 Record physical-device-only camera and live-provider checks that remain blocked by hardware or missing provider configuration.
- [x] 13.10 Create the future RevenueCat remote-paywall acceptance checklist for restore, legal links, active-entitlement navigation, and absence of dismissal.
- [x] 13.11 Document deferred Firebase/Google setup, RevenueCat identifiers/offering, Looksmaxxing contracts, legal disclosures, video bitrate, and production brand assets that block live enablement.
- [x] 13.12 Document pre-live source rollback and post-live backend retention/deletion cleanup procedures.
- [x] 13.13 Run strict-concurrency Debug builds and focused/full Swift Testing after the live Looks integration.
- [x] 13.14 Run the serial mock XCUITest suite and a standard Release simulator build after the transport and UI changes.
- [x] 13.15 Update release-readiness evidence to distinguish the implemented Looks happy path from deferred live credentials, legal approval, retention/deletion, idempotency, and failure/refund semantics.
- [x] 13.16 Re-audit runtime storage and URL caches for prepared photos, mesh/generated bytes, remote IDs, sensitive URLs, and transport responses.
- [x] 13.17 Re-audit logs and test attachments for Firebase tokens, request bodies, remote IDs, URLs, backend errors, and facial data after live transport tests.
