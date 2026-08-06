# Onboarding Release Readiness

Recorded through 2026-08-06 with Xcode 26.3 and the iOS 26.2 Simulator runtime. The app and test targets compile with an iOS 17.0 deployment target. A physical iPhone 14 Plus running iOS 26.4.2 is connected for device verification, but an iOS 17 runtime or device remains unavailable.

## Build And Fail-Closed Evidence

- Debug and Release simulator builds pass with `SWIFT_STRICT_CONCURRENCY=complete` after the live Looks integration and accessibility corrections. The final Release build completed for arm64 and x86_64 simulator architectures with the iOS 17.0 deployment target.
- The final strict Debug scheme regression in `Accessibility-Final-Regression.xcresult` passes 109 tests with zero failures or skips (134 executions including dynamic arguments). It includes the exact-viewport XCTest; expanded Looks transport, DTO, image-policy, retry, cancellation, and lifecycle assertions; the restricted-camera regression; and all accessibility assertions. Focused `LiveLooksServiceTests`, `GeneratedImageLoaderTests`, and `OnboardingFlowModelTests` runs also pass.
- The final serial mock-mode XCUITest run passes all 15 tests: 14 onboarding tests plus the 16-state native visual-capture test. Coverage includes welcome background/return routing, questionnaire labels and selection semantics, fixture-photo processing, analysis and generation retries, persisted paywall skips, Retake cleanup, returning-user branches, revised screen-09/11 values, comparison adjustment, paywall dismissal assertions, and Main handoff.
- Focused mock and production-shell checks pass 2 of 2 and assert that screen 12 has no Back, close, `Dismiss`, `Not now`, sheet, or other app-owned dismissal surface.
- Targeted new-user skip and full fixture-preview UI flows also pass at `accessibility-extra-extra-extra-large` with Increase Contrast enabled. These smoke runs support the shared reflow implementation but do not replace the manual assistive-technology verification in section 12 of the task plan.
- The Release bundle contains `NMYServiceMode=live`, placeholder Google and RevenueCat values, no Looks API URL or legal URLs, no static Looks token, and unapproved facial-data disclosures.
- Launching that Release bundle with `--mock-services --mock-entitled` shows `Configuration unavailable` with `Mock services are unavailable in Release builds.` It does not show Main.
- `AppDependencies` compiles mock dependency construction only under `#if DEBUG`. Invalid and incomplete Release configurations construct unavailable clients that cannot authorize Main.

## Visual Matrix Evidence

- Thirteen authoritative 393x852 frames were rendered from `Design/notmeyet-ios-flow.html` for screens 01 through 13. The written-flow overrides remain authoritative for selected state, omitted links, and hard-paywall behavior.
- `VisualViewportRenderTests.testRenderAtExact360x800Viewport` passes and exports all 16 current deterministic states through an exact 360x800 host with synthetic 59-point top and 34-point bottom safe areas.
- `VisualVerificationUITests.testCaptureDeterministicVisualStates` passes at native 390x844 and 430x932 viewports and exports the same 16 current states. The prior complete matrix also includes the 393x852 reference-sized capture.
- Revised screens 09 and 11 were recaptured and inspected at 360x800, 390x844, and 430x932. The annotated image, score cards, disclaimer, comparison, static style copy, slider, and CTAs remain visible without material clipping, overlap, or unsafe-area collisions; no correction was required.
- Corrections covered typography scale, adaptive choice/card sizing, navigation and inline-action placement, welcome width and overlay treatment, photo-guide and review media, harmony/result media and cards, loading/error states, and mock-paywall spacing and image clipping.
- Current revised-screen evidence is in `LooksIntegration-Visual-360.xcresult`, `Test-notmeyet-2026.08.05_17-21-30-+0200.xcresult` for 390x844, and `LooksIntegration-Visual-430.xcresult`. Earlier complete-matrix bundles remain `VisualCapture-390x844-Final2.xcresult`, `VisualCapture-393x852-Final2.xcresult`, and `VisualCapture-430x932-Final2.xcresult`.

## Accessibility Preference Evidence

- All 16 deterministic states were captured and inspected at `accessibility-extra-extra-extra-large` on native 390x844 and 430x932 viewports. Final bundles are `Accessibility-DynamicType-390-AX5-Corrected.xcresult` and `Accessibility-DynamicType-430-AX5-Corrected.xcresult`.
- The review found and corrected four issues: the welcome viewport compressed multiline CTA labels, screen-11 comparison labels lacked reliable image contrast, enlarged mock-paywall badges obscured the previews, and the Main subtitle missed large-text contrast. Accessibility-size welcome content now uses its intrinsic scroll height, shared CTA labels expand vertically, comparison labels use adaptive dark surfaces, mock-paywall captions move below images at accessibility sizes, and Main uses the contrast-aware muted color.
- Two AX5 end-to-end flows and all three recoverable analysis/generation/image-error flows pass on the 390x844 simulator. XCTest explicitly scrolled below-fold questionnaire, photo, result, retry, paywall purchase, and restore controls into view before activation, confirming that no primary action is obscured or unreachable.
- With Reduce Motion enabled, the live welcome route rendered the poster and two screenshots taken two seconds apart were byte-identical. The implementation has no spatial route transition; the remaining button press animation is disabled by the same preference.
- With Reduce Transparency enabled, the welcome gradient and representative photo-review, comparison, and paywall badges remained legible and their adaptive surfaces rendered solid. Evidence is in `Accessibility-ReduceTransparency-01.png`, `Accessibility-ReduceTransparency-07.png`, `Accessibility-ReduceTransparency-11.png`, and `Accessibility-ReduceTransparency-12.png`.
- With Increase Contrast enabled, the photo guide, error panel, paywall/card borders, and secondary controls remained distinct in `Accessibility-IncreaseContrast-06.png`, `Accessibility-IncreaseContrast-08-Error.png`, and `Accessibility-IncreaseContrast-12.png`. `testChoicesClearAndRemainSelectedThroughBackNavigation` also passed while repeatedly checking selected-state semantics.
- The correction pass additionally fixed semantic grouping, heading traits, image traits, adjustable-control exposure, traversal order, restricted-camera guidance, stale asynchronous photo errors, and 44-point legal/navigation/settings targets. The corrected build passed the corresponding focused UI flows, full serial regression, final 16-state 390x844 visual inspection, and physical VoiceOver, Voice Control, Switch Control, and Full Keyboard Access reruns.

## Looks Integration Status

- The implemented happy path acquires a Firebase ID token per request, uploads one bounded prepared JPEG, triggers and polls analysis, downloads the annotated mesh, selects the first valid one-credit `HAIRSTYLE` transformation, creates and polls one generation, and returns bounded presentation-ready generated bytes plus static style copy.
- Remote IDs remain exact positive decimal strings for paths and query values. Checked `Int64` conversion occurs only where the current generation request schema requires numeric IDs. The onboarding client never calls `/api/v1/users/me`.
- Polling is bounded to 40 attempts at three-second intervals. Known selfie/generation IDs resume safely; ambiguous side-effecting POSTs and terminal paid-generation failures are not replayed and expose safe nonretryable feedback.
- The implementation is verified against deterministic protocol stubs and mock UI fixtures only. No production facial image, Firebase token, paid generation, or live provider request was used for this evidence.
- Live enablement remains blocked on production Firebase and provider configuration, approved legal URLs and facial-data retention/deletion disclosures, backend idempotency and failure/refund semantics, generated-result URL lifetime, and an updated backend contract for string analysis acknowledgement and transformation presentation fields.

## Built Resource Audit

- The shipped first-party movie is `welcome-loop.mp4`, the optimized silent portrait derivative.
- `Design/10330484-uhd_2160_3840_25fps.mp4` is absent from the Release bundle.
- `GoogleService-Info.plist` and real provider credentials are absent from the Release bundle and checked-in configuration. Checked-in provider values are explicit placeholders.
- `WelcomePoster`, `SamplePortrait`, and `GeneratedLook` are the three intentional first-party asset-catalog resources. The latter two are deterministic mock/design fixtures required by the change.
- Other images and localized resources observed in the bundle belong to resolved GoogleSignIn and RevenueCatUI packages.

## Storage And Cache Audit

- Production app code writes only versioned `start`, `photo`, or `paywall` routing gates through `OnboardingGateStore`. Debug mock mode additionally stores only `notmeyet.mock.userID`.
- Questionnaire answers, prepared display/upload bytes, annotated-mesh bytes, harmony results, generated-look bytes, and style copy exist only in `OnboardingFlowModel.draft`. Remote IDs, transport responses, and sensitive URLs remain private to the in-memory `LiveLooksService` actor. Draft content and remote correlation clear on the specified retake, replacement, reset, memory-warning, paywall, Main, and process-lifetime boundaries; ordinary retry cancellation may retain only confirmed remote IDs in memory so a known operation can resume safely without replaying a side-effecting POST.
- Current app source contains no SwiftData, file writes, state-restoration payloads, or other application persistence APIs for onboarding content.
- `LiveLooksService` and `GeneratedImageLoader` use ephemeral URL sessions with no URL cache, no cookie storage, and reload-ignoring-cache policies. Loader tests repeat a cacheable same-URL response and observe fresh transport on every request.
- A clean post-integration Release install and fail-closed launch left Documents, Library/Caches, Library/Preferences, and tmp empty. Only OS-managed scene state was present.
- An older simulator install contained a stale `notmeyet.onboarding.durable-state` key from a prior development build. That key is absent from current source and was absent after uninstalling and clean-installing the current build.
- Firebase and RevenueCat may retain their own authentication and SDK session state when live mode is enabled; that provider-owned state is intentionally outside the ephemeral onboarding draft.

## Log And Test-Attachment Audit

- App and test sources contain no `print`, `debugPrint`, `Logger`, `os_log`, or `NSLog` calls.
- Request-contract tests inspect Firebase authorization, request bodies, remote IDs, URLs, and backend errors only in process and do not attach them. Raw `ProblemDetail` and backend error text are mapped to fixed safe messages.
- The visual-verification tests intentionally attach deterministic screenshots for the 16 current presentation states. Those attachments contain only bundled fixtures and static mock data.
- UI tests acquire no user image. The full preview path uses only the bundled deterministic `SamplePortrait` fixture; visual captures and failed local XCUITest diagnostics may therefore contain that non-user fixture and must still be handled as development artifacts.
- Live-provider framework logs and remote-provider diagnostics must be reviewed again with production configuration before release because those services cannot be exercised yet.

## Physical-Device And Live Checks

A development-signed Debug build has been built, installed, and launched in mock mode on the connected iPhone 14 Plus. The following checks still must be completed before live enablement:

- VoiceOver verification on screens 01 through 04 passed on the physical device: route headings received initial focus, traversal followed logical order, welcome/navigation actions had unique labels, questionnaire choices spoke complete labels and selected state, and selection changes did not cause repeated focus or announcements.
- VoiceOver verification on screens 05 through 07 passed: heading focus, authentication and legal labels, one-shot connection status, instructional image semantics, photo actions, and the reordered screen-07 heading/image/instructions/action traversal all behaved as intended.
- VoiceOver verification on screens 08 through 10 passed: processing headings and images, one-shot failure announcements, error traversal, retries, harmony image/value speech, and completion focus transitions all behaved as intended.
- VoiceOver verification on screens 11 through 13 and Main passed: the comparison exposed one image plus one bounded adjustable slider, `About this look` appeared in the Headings rotor, the mock hard paywall could not be dismissed, purchase moved focus to the independent Main heading, and returning-sign-in traversal omitted decorative content.
- Voice Control `Show Names` and `Show Numbers` verification passed on screens 01 through 06; every visible action received one unique target and could be activated by name or number. A normal launch also confirmed the cinematic welcome loop; the static poster seen in the direct screen-01 harness was its intentional deterministic test behavior.
- Voice Control verification passed on screens 07 through 13 and Main, including the fixture flow and stable screen-08/screen-10 error states. All actions received unique usable name/number targets, while decorative processing and authentication content received none.
- Switch Control verification passed on screens 01 through 06 in Item Mode: scan order, one-stop-per-action behavior, automatic scrolling, selection state, and activation all worked without decorative stops or traps.
- Switch Control verification passed on screens 07 through 13 and Main: fixture-flow scanning, retry activation, comparison Increment/Decrement actions, paywall lock, automatic scrolling, and returning-sign-in controls all worked without traps.
- Full Keyboard Access verification passed on screens 01 through 06: Tab/Shift-Tab order, visible system focus, automatic scrolling, choice state, and Space/Return activation worked across dark and light surfaces.
- Full Keyboard Access verification passed on screens 07 through 13 and Main: logical forward/reverse focus, visible focus rings, automatic scrolling, slider arrow adjustment, retry activation, Escape-resistant paywall behavior, and Main/screen-13 traversal all worked without traps.

- Verify camera permission prompts, denied/restricted recovery, front-camera preference, capture cancellation, image orientation, memory behavior, and Settings return on a physical iPhone.
- Run the supported flow on an iPhone with iOS 17 because no iOS 17 Simulator runtime is installed here.
- Verify Sign in with Apple and Google callback behavior against the production Firebase project and provider-console configuration.
- Verify RevenueCat UID binding, customer-info refresh, purchase, restore, cancellation, billing failure, and later entitlement revocation against the production project.
- Verify the concrete selfie, analysis, transformation-search, generation, and result-image flow only after production Firebase authentication, approved legal and retention/deletion disclosures, backend contract updates, and failure/refund decisions are supplied.

## Remaining OpenSpec Verification

- The change is at 239 of 239 tasks complete.
- All implementation, automated regression, revised visual, privacy-audit, simulator build, physical assistive-technology, and correction tasks are complete.
- Dynamic Type and adaptive-preference tasks 12.29 through 12.35 are complete with the evidence above.
- Physical-device VoiceOver, Voice Control, Switch Control, and Full Keyboard Access tasks 12.36 through 12.45 are complete with the evidence above.
- Accessibility correction tasks 12.46 through 12.49 are complete: all in-scope findings were corrected in behavior, practical regression coverage was added or updated, affected scenarios were rerun on the corrected build, the final strict scheme regression and Release build passed, and no accessibility release blocker remains open.

## RevenueCat Remote Paywall Acceptance

Before enabling the production offering, confirm every item against the remotely configured paywall:

- Screen 12 is embedded as a root destination, not presented as a dismissible sheet.
- No close, Back, `Not now`, swipe-dismiss, or other bypass is present.
- Restore purchases is visible and completes through authoritative refreshed customer information.
- Terms of Use and Privacy Policy actions are visible and open the approved production URLs.
- Purchase and restore route to Main only when the configured entitlement is active.
- Completed transactions without the configured entitlement remain on screen 12 with safe feedback.
- Cancellation and failures remain on screen 12; cancellation is not shown as an error.
- A later inactive entitlement update removes Main access and returns the user to screen 12.

## Deferred Production Inputs

- Firebase: production `GoogleService-Info.plist`, project identifiers, authorized bundle ID, and provider enablement.
- Google and Apple: Google client ID and reversed callback scheme, Apple team/signing capability, nonce exchange validation, and provider-console settings.
- RevenueCat: public SDK key, entitlement identifier, Firebase UID identity policy, offering, products, remote paywall, restore behavior, and legal links.
- Looksmaxxing: production Firebase authentication, backend contract updates for string analysis acknowledgement and transformation presentation fields, generated-image lifetime, idempotency, paid-generation failure/refund semantics, and production operational acceptance.
- Legal and privacy: final Terms and Privacy URLs plus approved facial-image retention, deletion, subprocessors, and user-request disclosures.
- Product assets: measured final welcome-video bitrate decision and production app icon/brand assets.

## Rollback And Cleanup

### Before Live Upload Is Enabled

- Keep Release fail closed by retaining placeholder or incomplete live configuration.
- Roll back the onboarding root, packages, configuration, and bundled assets through normal source control if the feature is withdrawn.
- No backend facial-data cleanup is required for this evidence because production configuration remains fail closed and no production upload was enabled or executed.
- Remove development-only simulator/app data by uninstalling the development build; no shipped-user migration is required before first release.

### After Live Upload Is Enabled

- Disable the Looks feature or endpoint configuration first so no new facial data is uploaded.
- Revoke or rotate exposed service credentials and disable affected provider offerings when applicable.
- Execute backend deletion according to the approved retention/deletion contract, including queued jobs, object storage, derived images, logs, backups, subprocessors, and generated-image URLs.
- Preserve an auditable deletion record without retaining request bodies, facial bytes, credentials, or sensitive URLs in application logs.
- Confirm the app still uses ephemeral sessions and clears in-memory source and generated bytes on reset, memory warning, and termination.
- Coordinate user notice, support handling, and regulatory reporting with the approved privacy and incident-response owners before declaring cleanup complete.
