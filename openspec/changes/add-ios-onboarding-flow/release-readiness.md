# Onboarding Release Readiness

Recorded on 2026-08-05 with Xcode 26.3 and the iOS 26.2 Simulator runtime. The app and test targets compile with an iOS 17.0 deployment target, but an iOS 17 runtime and physical-device verification remain unavailable on this machine.

## Build And Fail-Closed Evidence

- Debug and Release simulator builds pass with `SWIFT_STRICT_CONCURRENCY=complete`.
- The final strict Debug run passes 72 Swift Testing cases plus the exact-viewport XCTest. The isolated testable-Release run passes 67 of 67 tests, including the Release-only mock-access invariant. `ENABLE_TESTABILITY=YES` was supplied only to the isolated Release test action and is not part of the shipped Release build.
- The final serial mock-mode XCUITest run passes all 15 tests: 14 onboarding tests plus the 18-state native visual-capture test. Coverage includes welcome background/return routing, questionnaire labels and selection semantics, fixture-photo processing, service and image retries, persisted paywall skips, Retake cleanup, returning-user branches, comparison adjustment, paywall dismissal assertions, and Main handoff.
- Focused mock and production-shell checks pass 2 of 2 and assert that screen 12 has no Back, close, `Dismiss`, `Not now`, sheet, or other app-owned dismissal surface.
- Targeted new-user skip and full fixture-preview UI flows also pass at `accessibility-extra-extra-extra-large` with Increase Contrast enabled. These smoke runs support the shared reflow implementation but do not replace the manual assistive-technology verification in section 12 of the task plan.
- The Release bundle contains `NMYServiceMode=live`, placeholder Google and RevenueCat values, no Looks API URL, and unapproved facial-data disclosures.
- Launching that Release bundle with `--mock-services --mock-entitled` shows `Configuration unavailable` with `Mock services are unavailable in Release builds.` It does not show Main.
- `AppDependencies` compiles mock dependency construction only under `#if DEBUG`. Invalid and incomplete Release configurations construct unavailable clients that cannot authorize Main.

## Visual Matrix Evidence

- Thirteen authoritative 393x852 frames were rendered from `Design/notmeyet-ios-flow.html` for screens 01 through 13. The written-flow overrides remain authoritative for selected state, omitted links, and hard-paywall behavior.
- `VisualViewportRenderTests.testRenderAtExact360x800Viewport` passes and exports all 18 deterministic states through an exact 360x800 host with synthetic 59-point top and 34-point bottom safe areas.
- `VisualVerificationUITests.testCaptureDeterministicVisualStates` passes at native 390x844, 393x852, and 430x932 viewports and exports the same 18 states at each size.
- The resulting 72 viewport/state captures were reviewed across the correction and final recapture rounds. Required content and actions remain visible or reachable, and the final captures have no material clipping, overlap, empty navigation rows, or unsafe-area collisions.
- Corrections covered typography scale, adaptive choice/card sizing, navigation and inline-action placement, welcome width and overlay treatment, photo-guide and review media, harmony/result media and cards, loading/error states, and mock-paywall spacing and image clipping.
- Final result bundles are `VisualCapture-360x800-Synthetic-Final4.xcresult`, `VisualCapture-390x844-Final2.xcresult`, `VisualCapture-393x852-Final2.xcresult`, and `VisualCapture-430x932-Final2.xcresult`. Regression bundles are `Regression-PaywallDismissal.xcresult`, `Regression-Debug-Unit.xcresult`, `Regression-Debug-UI.xcresult`, and `Regression-Release-Unit-Testable.xcresult`.

## Built Resource Audit

- The shipped first-party movie is `welcome-loop.mp4`, the optimized silent portrait derivative.
- `Design/10330484-uhd_2160_3840_25fps.mp4` is absent from the Release bundle.
- `GoogleService-Info.plist` and real provider credentials are absent from the Release bundle and checked-in configuration. Checked-in provider values are explicit placeholders.
- `WelcomePoster`, `SamplePortrait`, and `GeneratedLook` are the three intentional first-party asset-catalog resources. The latter two are deterministic mock/design fixtures required by the change.
- Other images and localized resources observed in the bundle belong to resolved GoogleSignIn and RevenueCatUI packages.

## Storage And Cache Audit

- Production app code writes only versioned `start`, `photo`, or `paywall` routing gates through `OnboardingGateStore`. Debug mock mode additionally stores only `notmeyet.mock.userID`.
- Questionnaire answers, prepared-photo bytes, harmony results, generated-look values, and downloaded generated-image bytes exist only in `OnboardingFlowModel.draft` and are cleared by retake, reset, memory warning, or process termination.
- Current app source contains no SwiftData, file writes, state-restoration payloads, or other application persistence APIs for onboarding content.
- `LiveLooksService` and `GeneratedImageLoader` use ephemeral URL sessions with no URL cache, no cookie storage, and reload-ignoring-cache policies. Loader tests repeat a cacheable same-URL response and observe fresh transport on every request.
- A clean Release install and fail-closed launch left Documents, Library/Caches, and tmp empty and created no app preference plist.
- An older simulator install contained a stale `notmeyet.onboarding.durable-state` key from a prior development build. That key is absent from current source and was absent after uninstalling and clean-installing the current build.
- Firebase and RevenueCat may retain their own authentication and SDK session state when live mode is enabled; that provider-owned state is intentionally outside the ephemeral onboarding draft.

## Log And Test-Attachment Audit

- App and test sources contain no `print`, `debugPrint`, `Logger`, `os_log`, or `NSLog` calls.
- The visual-verification tests intentionally attach deterministic screenshots for the 18 declared presentation states. Those attachments contain only bundled fixtures and static mock data.
- UI tests acquire no user image. The full preview path uses only the bundled deterministic `SamplePortrait` fixture; visual captures and failed local XCUITest diagnostics may therefore contain that non-user fixture and must still be handled as development artifacts.
- Live-provider framework logs and remote-provider diagnostics must be reviewed again with production configuration before release because those services cannot be exercised yet.

## Physical-Device And Live Checks

The following checks remain blocked and must be completed before live enablement:

- Verify camera permission prompts, denied/restricted recovery, front-camera preference, capture cancellation, image orientation, memory behavior, and Settings return on a physical iPhone.
- Run the supported flow on an iPhone with iOS 17 because no iOS 17 Simulator runtime is installed here.
- Verify Sign in with Apple and Google callback behavior against the production Firebase project and provider-console configuration.
- Verify RevenueCat UID binding, customer-info refresh, purchase, restore, cancellation, billing failure, and later entitlement revocation against the production project.
- Verify `/analysis`, `/selfie`, and generated-image behavior only after the approved OpenAPI contract, authentication, image policy, and retention/deletion disclosures are supplied.

## Remaining OpenSpec Verification

- The change is at 173 of 195 tasks complete.
- Task 9.7 remains blocked because no Looks request DTO or approved questionnaire mapping exists; inventing a serializer would violate the contract-isolation decision.
- Tasks 12.29 through 12.35 and 12.44 through 12.45 require recorded manual Dynamic Type, adaptive-preference, and Full Keyboard Access review.
- Tasks 12.36 through 12.43 require physical-device VoiceOver, Voice Control, and Switch Control verification.
- Tasks 12.46 through 12.49 remain pending until the corresponding manual and physical-device findings can be corrected and rerun.

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
- Looksmaxxing: HTTPS base URL, authentication method, OpenAPI request and response DTOs, questionnaire mapping, image dimension/encoding limits, guide-coordinate contract, generated-image lifetime, and error schema.
- Legal and privacy: final Terms and Privacy URLs plus approved facial-image retention, deletion, subprocessors, and user-request disclosures.
- Product assets: measured final welcome-video bitrate decision and production app icon/brand assets.

## Rollback And Cleanup

### Before Live Upload Is Enabled

- Keep Release fail closed by retaining placeholder or incomplete live configuration.
- Roll back the onboarding root, packages, configuration, and bundled assets through normal source control if the feature is withdrawn.
- No backend facial-data cleanup is required because the current live Looks transport sends no request and no production upload has been enabled.
- Remove development-only simulator/app data by uninstalling the development build; no shipped-user migration is required before first release.

### After Live Upload Is Enabled

- Disable the Looks feature or endpoint configuration first so no new facial data is uploaded.
- Revoke or rotate exposed service credentials and disable affected provider offerings when applicable.
- Execute backend deletion according to the approved retention/deletion contract, including queued jobs, object storage, derived images, logs, backups, subprocessors, and generated-image URLs.
- Preserve an auditable deletion record without retaining request bodies, facial bytes, credentials, or sensitive URLs in application logs.
- Confirm the app still uses ephemeral sessions and clears in-memory source and generated bytes on reset, memory warning, and termination.
- Coordinate user notice, support handling, and regulatory reporting with the approved privacy and incident-response owners before declaring cleanup complete.
