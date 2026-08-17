# Release Readiness: Backend Onboarding Completion

## Migration

- The app has not been released to production and has no production or externally retained users.
- No existing-user `onboardingCompleted` migration or backfill is required. New users can begin with the backend default of `false` and complete onboarding through the monotonic PATCH flow.
- Migration does not block rollout.

## Contract Evidence

- The checked `Design/openapi.json` currently documents `GET /api/v1/users/me` as get-or-create, does not require `onboardingCompleted`, and does not define `PATCH /api/v1/users/me`.
- Production-shaped iOS fixtures cover all accepted and rejected PUT/PATCH combinations without real identifiers or tokens in `notmeyetTests/LiveBackendUserServiceTests.swift`.
- The focused backend/configuration run passed 22 logical tests (52 parameterized executions) with zero failures on an iPhone 17 Pro simulator running iOS 26.2. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-focused-backend-config-v2.xcresult`.
- Invalid or unconfirmed lifecycle configuration is tested fail closed before Firebase token acquisition or transport, so no PUT or PATCH is sent.
- **Release blocker:** replace the checked OpenAPI document with the backend-owned PUT/PATCH contract and attach a passing backend-owned deployment/contract result from the release environment.

## Test Runs

- Focused access-coordinator and onboarding-flow suites: **passed**, 71 logical tests (99 parameterized executions), zero failures. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-focused-flow-access-v2.xcresult`.
- Complete unit-test target: **passed**, 147 logical tests (225 parameterized executions), zero failures. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-full-unit-v2.xcresult`.
- Serial mock-mode `OnboardingUITests`: **passed**, 23 of 23 tests, zero failures. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-serial-onboarding-ui-v2.xcresult`.
- Release-only configuration assertions built with `ENABLE_TESTABILITY=YES`: **passed**, 8 logical tests (9 parameterized executions), zero failures. This testability override was used only to inspect Release configuration behavior. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-release-tests-v2.xcresult`.
- Strict change validation: **passed** with `openspec validate add-backend-onboarding-completion --type change --strict --no-interactive` on 2026-08-13.
- No failing test names were recorded in those final runs.

## Visual And Accessibility Evidence

- Deterministic visual UI captures passed at 390x844 and 430x932, producing 23 non-failure screenshots per size. They include screens 05, 06, 09, 11, screen-13 created-incomplete, access-pending progress, and access failure. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/current-visual-390.xcresult`, `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/current-visual-430.xcresult`, and their exported attachment manifests.
- The focused accessibility suite passed 53 logical tests (74 parameterized executions) with zero failures. Its AX5 viewport renders cover screens 05, 06, 09, 11, 13, and post-onboarding access at 390x844 and 430x932; synthetic renders also cover increased contrast and Reduce Transparency seams. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/focused-accessibility-tests.xcresult`.
- AX5 UI action-reachability runs passed at both required sizes: 3 tests at 390x844 and 2 tests at 430x932. They use `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/ax5-actions-final-390.xcresult` and `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/ax5-actions-final-430.xcresult`.
- Source and UI-test audit confirms unique visible action labels, at least 44-point targets, and no Back or dismissal control on post-onboarding access. Dynamic Type reflow and action reachability are substantiated by automation.
- VoiceOver checks 6.16-6.20 passed on the dedicated `NMY Accessibility Probe` iOS 26.5 Simulator with the actual `com.apple.VoiceOverTouch` service and Caption Panel. The authentic screen-13 created-incomplete transition moved focus to the inserted neutral notice; completion actions on screens 06, 09, and 11, post-onboarding access, authenticated launch, and screens 05/13 emitted their progress, success, and actionable-error announcements. Direct `vot` logs contain the exact `Announcement` payloads, queued `OutputRequest` values, synthesized speech, and `finished speaking` events. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/manual-a11y-evidence/voiceover-evidence.logarchive`, `voiceover-screen13-dynamic.xcresult`, `voiceover-completion-errors.xcresult`, and `voiceover-access-dynamic.xcresult` in the same directory.
- Increase Contrast check 6.27 passed with the actual Simulator system preference enabled. The access-failure surface retained its `Try again` action, contained no Back/dismissal control or sheet, and rendered stronger black secondary text plus thicker card and button boundaries. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/manual-a11y-evidence/access-increase-contrast.xcresult` and its retained screenshots.
- Reduce Transparency check 6.28 passed with the actual accessibility preference enabled through the Simulator accessibility setting API. The post-onboarding access card, error panel, and retry action remained solid and legible, with no dismissal path. Evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/manual-a11y-evidence/access-reduce-transparency.xcresult` and its retained screenshots.
- Tasks 6.22-6.24 are complete by explicit MVP-scope waiver, not by passing physical assistive-technology verification. Full Keyboard Access had no attached hardware keyboard; authentic Switch Control activation was attempted but not established; Voice Control activation was not run. No Full Keyboard Access, Switch Control, or Voice Control support claim is substantiated by this change. The temporary physical-device Switch Control service, Full Screen switch source, and Accessibility Shortcut were restored off/removed; evidence: `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/manual-a11y-evidence/physical-accessibility-final-restoration.xcresult`.

## Release Blockers

- Backend-owned OpenAPI contract matching the implemented PUT/PATCH adapter.
- Backend-owned deployment/contract result from the release environment.
- Production Firebase, Google, RevenueCat, API URL, legal URLs, lifecycle confirmation, and facial-data configuration. The checked Release configuration remains live but intentionally fail closed with placeholder/empty values, `NMY_BACKEND_USER_LIFECYCLE_CONTRACT_CONFIRMED = NO`, and `NMY_FACIAL_DATA_DISCLOSURES_APPROVED = NO`.
- A retained production user and credential fixture for authenticated live PUT/PATCH integration testing.
- Source and licensing provenance for the production-bundled `SamplePortrait` and `GeneratedLook` assets.
- Inspection of the final signed shipping archive and physical-device runtime; the current artifact evidence is an unsigned Release simulator build.

## Release Artifact Audit

- A normal unsigned Release simulator app built successfully and was inspected at `/var/folders/jc/hlwy75dj5dlcw9y32pmpq06w0000gn/T/opencode/final-release-app-v2-derived/Build/Products/Release-iphonesimulator/notmeyet.app`.
- The app contains no `GoogleService-Info.plist`, signing credential files, production-user fixtures, fixture identifiers/tokens, fixture-named files, or legacy gate symbols.
- Specific Debug mock lifecycle selectors and implementations are absent from the Release binary. Generic Release argument-rejection strings such as `--reset-onboarding` and `--ui-test-presentation=` remain intentionally present so Release can reject those inputs and fail closed.
- The Release `Info.plist` confirms live service mode, placeholder Google and RevenueCat values, empty API/legal URLs, facial approval `NO`, and lifecycle confirmation `NO`; the default artifact therefore cannot contact lifecycle services or authorize Main.
- This audit does not substantiate code signing, provisioning, production entitlements, device-only behavior, or the contents of a future App Store archive.

## Rollback

The backend field and idempotent PATCH are additive. An emergency rollback to the prior iOS client remains access-safe, but older clients cannot consume backend completion and may repeat onboarding after reinstall or on another device. Preserve backend completion data and prefer a forward client fix. No rollback exercise can be completed until the backend contract and release environment exist.
