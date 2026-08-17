## 1. Backend Contract Prerequisites

- [x] 1.1 Create `release-readiness.md` with sections for migration, contract evidence, test runs, visual and accessibility evidence, release blockers, and rollback.
- [x] 1.2 Evaluate the available production-state inventory for retained users and record either the migration decision or an explicit unresolved release blocker in `release-readiness.md` without waiting on another team.
- [x] 1.3 Check for a backend-owned OpenAPI contract defining required `onboardingCompleted`, idempotent PUT, monotonic PATCH, exact statuses, and response shape; replace `Design/openapi.json` if supplied or record an explicit live-release blocker in `release-readiness.md` without waiting.
- [x] 1.4 Add production-shaped PUT fixtures for `201 + false`, `200 + false`, `200 + true`, invalid `201 + true`, missing, null, string, malformed, and representative `400`, `401`, and `500` responses without real identifiers or tokens.
- [x] 1.5 Add production-shaped PATCH fixtures for accepted `200 + true`, invalid `200 + false`, missing, null, string, malformed, and representative `400`, `401`, and `500` responses without real identifiers or tokens.

## 2. Backend User Domain And Transport

- [x] 2.1 Define the transport-independent backend-user origin, resolution, completion request, and injected `BackendUserClient` APIs.
- [x] 2.2 Implement an ephemeral `LiveBackendUserService` using `NMYLooksAPIBaseURL` and request-time Firebase ID tokens without photo-policy or photo-data dependencies.
- [x] 2.3 Implement strict PUT mapping for `201 + false`, `200 + false`, and `200 + true`, rejecting `201 + true`, missing/non-Boolean fields, malformed bodies, and all other statuses.
- [x] 2.4 Implement exact PATCH `{ "onboardingCompleted": true }` encoding and accept only `200 + true` acknowledgement, with no client operation capable of writing `false`.
- [x] 2.5 Add Swift Testing contract tests for PUT method, path, body absence, and fresh bearer acquisition.
- [x] 2.6 Add parameterized PUT response tests for exactly these fixtures: `201 + false`, `200 + false`, `200 + true`, invalid `201 + true`, missing, null, string, malformed, `204`, `302`, `400`, `401`, and `500`.
- [x] 2.7 Add PUT tests for token failure before transport, ambiguous transport retry safety, and cancellation.
- [x] 2.8 Add Swift Testing contract tests for PATCH method, path, exact JSON, and fresh bearer acquisition.
- [x] 2.9 Add parameterized PATCH response tests for exactly these fixtures: accepted `200 + true`, invalid `200 + false`, missing, null, string, malformed, `204`, `302`, `400`, `401`, and `500`.
- [x] 2.10 Add PATCH tests for token failure before transport, idempotent ambiguous retry safety, and cancellation.
- [x] 2.11 Verify lifecycle transport uses no cache, cookies, credential storage, background session, persistent response state, sensitive logs, or test attachments.

## 3. Dependency And RevenueCat Lifecycle

- [x] 3.1 Add `BackendUserClient` to live, mock, test, preview, and unavailable `AppDependencies` construction.
- [x] 3.2 Extend deterministic mock state so Firebase identity, backend origin/completion, and entitlement are independently selectable, and reset clears identity plus backend lifecycle state.
- [x] 3.3 Move all throwable RevenueCat key and entitlement validation before live dependency construction completes.
- [x] 3.4 Add a main-actor lazy purchase proxy and move the first `LivePurchaseService` construction out of eager dependency assembly.
- [x] 3.5 Add an app-owned process-global guard corroborated by SDK configured state so the lazy proxy configures RevenueCat exactly once.
- [x] 3.6 Strongly retain the live purchase delegate service for the configured SDK lifetime and make subsequent proxy operations reuse that retained service.
- [x] 3.7 Add proxy tests proving repeated operations on one proxy configure RevenueCat once and reuse the retained service.
- [x] 3.8 Add a proxy test in which SDK state already reports configuration and verify another proxy does not call configure again.
- [x] 3.9 Add a lifetime test proving the proxy strongly retains the delegate service through access monitoring.
- [x] 3.10 Refocus `AccessCoordinator` on serialized UID binding and entitlement evaluation without reading Firebase launch identity or owning SDK construction.

## 4. Account Resolution State Machine

- [x] 4.1 Add the resolving operation stage and make its retry repeat only PUT.
- [x] 4.2 Add the completing operation stage and make its retry repeat only PATCH.
- [x] 4.3 Add the access-pending operation stage and make its retry repeat only RevenueCat bind/evaluate.
- [x] 4.4 Add the post-onboarding access-verification app phase and route it from the app root.
- [x] 4.5 Add request identities and expected entry/initiating contexts that reject stale account-operation results.
- [x] 4.6 Change bootstrap so signed-out launch shows screen 01 without backend or RevenueCat work, while authenticated launch resolves PUT before any access decision.
- [x] 4.7 Implement authenticated-launch incomplete and completed routing.
- [x] 4.8 Implement authenticated-launch invalid-response and backend-failure retry behavior.
- [x] 4.9 Implement screen-05 incomplete and completed routing after provider authentication.
- [x] 4.10 Implement screen-05 invalid-response, backend-failure, and PUT-only retry behavior.
- [x] 4.11 Implement screen-13 created-incomplete and existing-incomplete routing.
- [x] 4.12 Implement screen-13 completed, invalid-response, and backend-failure routing.
- [x] 4.13 Make screen-13 `Start onboarding` clear transient returning-state feedback, preserve backend completion as false, and return to screen 01.
- [x] 4.14 Add parameterized Swift Testing coverage for every authenticated-launch status/Boolean route and exact backend-before-purchase event ordering.
- [x] 4.15 Add parameterized Swift Testing coverage for every screen-05 status/Boolean route, provider-versus-PUT retry behavior, and absence of incomplete-user purchase events.
- [x] 4.16 Add parameterized Swift Testing coverage for every screen-13 status/Boolean route, created-incomplete choice behavior, and absence of incomplete-user purchase events.
- [x] 4.17 Add controlled-operation tests proving screen-05 and screen-13 Back or provider cancellation invalidates pending resolution without later routing.
- [x] 4.18 Add controlled-operation tests proving overlapping resolution requests discard stale results and cannot invoke a later service stage.
- [x] 4.19 Add an incomplete authenticated-launch test proving no RevenueCat construction/configuration, bind, refresh, or monitoring occurs.
- [x] 4.20 Add an incomplete screen-05 test proving no RevenueCat construction/configuration, bind, refresh, purchase, restore, or monitoring occurs.
- [x] 4.21 Add an incomplete screen-13 test proving no RevenueCat construction/configuration, bind, refresh, purchase, restore, or monitoring occurs.

## 5. Completion And Access Handoff

- [x] 5.1 Replace direct paywall entry from screen-06 `Skip harmony check` with guarded asynchronous PATCH completion.
- [x] 5.2 Replace direct paywall entry from screen-09 `Skip look` with guarded asynchronous PATCH completion.
- [x] 5.3 Replace direct paywall entry from screen-11 `Try more` with guarded asynchronous PATCH completion.
- [x] 5.4 Preserve screen 06 and its in-memory state through PATCH failure/cancellation, disable duplicate completion, and retry only PATCH.
- [x] 5.5 Preserve screen 09 and its result state through PATCH failure/cancellation, disable duplicate completion, and retry only PATCH.
- [x] 5.6 Preserve screen 11 and its comparison state through PATCH failure/cancellation, disable duplicate completion, and retry only PATCH.
- [x] 5.7 On PATCH acknowledgement, record access pending before clearing photo-derived state once and route to the unnumbered post-onboarding access surface.
- [x] 5.8 Implement access-pending sequencing as RevenueCat UID bind then entitlement refresh, routing active access to Main and inactive access to screen 12.
- [x] 5.9 On UID binding or entitlement failure, remain in access pending and retry only bind/evaluate without provider auth, PUT, PATCH, or RevenueCat reconfiguration.
- [x] 5.10 Start entitlement-update monitoring only after successful access evaluation.
- [x] 5.11 Preserve later Main-access revocation after monitoring starts.
- [x] 5.12 Preserve hard-paywall purchase behavior after acknowledged backend completion.
- [x] 5.13 Preserve hard-paywall restore behavior after acknowledged backend completion.
- [x] 5.14 Add parameterized Swift Testing coverage that each screen-06, screen-09, and screen-11 initiator sends one completion request and cannot enter access before acknowledgement.
- [x] 5.15 Add parameterized PATCH failure tests proving each initiating route and its required in-memory content remain available for retry.
- [x] 5.16 Add controlled PATCH cancellation tests proving cancellation preserves the initiating route and content without starting access.
- [x] 5.17 Add controlled stale-completion tests proving an invalidated PATCH result cannot clear content, route, or start access.
- [x] 5.18 Add tests proving photo-derived cleanup occurs once only after acknowledgement and the access-pending surface replaces the numbered screen.
- [x] 5.19 Add tests for UID-binding failure recovery and assert retry repeats only bind then entitlement refresh.
- [x] 5.20 Add tests for entitlement-refresh failure recovery and assert retry never repeats provider auth, PUT, PATCH, or RevenueCat configuration.
- [x] 5.21 Add tests for active and inactive entitlement outcomes after backend completion.
- [x] 5.22 Add tests proving monitoring starts only after successful evaluation and later revocation removes Main access.
- [x] 5.23 Update hard-paywall purchase tests to begin from acknowledged backend completion and preserve existing authorization behavior.
- [x] 5.24 Update hard-paywall restore tests to begin from acknowledged backend completion and preserve existing authorization behavior.

## 6. User Interface And Accessibility

- [x] 6.1 Build the non-dismissible `PostOnboardingAccessView` with verification progress, safe recoverable feedback, `Try again`, no Back action, and a stable accessibility identifier.
- [x] 6.2 Present neutral created-incomplete feedback on screen 13 while retaining the existing `Start onboarding` action and preventing premature RevenueCat work.
- [x] 6.3 Add completion progress, duplicate-action disabling, retry feedback, and announcements to screen 06.
- [x] 6.4 Add completion progress, duplicate-action disabling, retry feedback, and announcements to screen 09 while retaining its result content.
- [x] 6.5 Add completion progress, duplicate-action disabling, retry feedback, and announcements to screen 11 while retaining its comparison content.
- [x] 6.6 Add isolated previews and Debug UI-test presentations for backend resolving and screen-13 created-incomplete states.
- [x] 6.7 Add isolated previews and Debug UI-test presentations for completion progress, access-pending progress, and access failure.
- [x] 6.8 Add a UI test for the screen-13 created-incomplete `Start onboarding` choice.
- [x] 6.9 Add a UI test for existing-incomplete screen-13 authentication resuming at screen 06.
- [x] 6.10 Add a UI test for a completed account with active access reaching Main.
- [x] 6.11 Add a UI test for a completed account with inactive access reaching screen 12.
- [x] 6.12 Add a UI test for completion failure retaining its initiating screen and successful PATCH retry reaching access pending.
- [x] 6.13 Add a UI test for post-completion RevenueCat failure and access-only retry without a Back or dismissal path.
- [x] 6.14 Implement one-time account-resolution progress, success, and actionable-error announcements for authenticated launch.
- [x] 6.15 Implement one-time account-resolution progress, success, and actionable-error announcements on screens 05 and 13.
- [x] 6.16 Verify VoiceOver focus and neutral created-incomplete feedback on screen 13.
- [x] 6.17 Verify one-time VoiceOver progress/error announcements for completion actions on screens 06, 09, and 11.
- [x] 6.18 Verify VoiceOver focus and one-time progress/error announcements on post-onboarding access.
- [x] 6.19 Verify one-time account-resolution progress, success, and actionable-error announcements on authenticated launch.
- [x] 6.20 Verify one-time account-resolution progress, success, and actionable-error announcements on screens 05 and 13.
- [x] 6.21 Audit unique labels and 44-point targets for screen-13 and completion actions.
- [x] 6.22 MVP waiver: keyboard and Switch Control activation verification for screen-13 and completion actions was explicitly removed from scope; no assistive-technology pass is claimed.
- [x] 6.23 MVP waiver: Voice Control activation verification for screen-13, completion, retry, and post-onboarding access actions was explicitly removed from scope; no Voice Control pass is claimed.
- [x] 6.24 MVP waiver: unique-label and 44-point target audits are complete, while keyboard and Switch Control operation on post-onboarding access was explicitly removed from scope; no assistive-technology pass is claimed.
- [x] 6.25 Verify Dynamic Type reflow and action reachability on screens 06, 09, and 11 at accessibility sizes.
- [x] 6.26 Verify Dynamic Type reflow and action reachability on screens 05, 13, and post-onboarding access at accessibility sizes.
- [x] 6.27 Verify increased-contrast presentation and non-dismissible behavior for the post-onboarding access surface.
- [x] 6.28 Verify Reduce Transparency produces a legible solid post-onboarding access surface.

## 7. Remove Local Routing Authority

- [x] 7.1 Remove gate reads and writes from bootstrap and screen-05 authentication after backend-routed tests pass.
- [x] 7.2 Remove gate writes from completion and paywall entry.
- [x] 7.3 Remove gate behavior from Main revocation.
- [x] 7.4 Replace `--mock-gate` setup with independent backend `onboardingCompleted` selectors.
- [x] 7.5 Replace gate-based launch tests and test-harness event expectations with backend lifecycle expectations.
- [x] 7.6 Remove routing-gate dependency fields and constructor arguments from app and test dependency assembly.
- [x] 7.7 Remove `OnboardingGateStore` after no caller remains.
- [x] 7.8 Remove `RoutingGate` and `RoutingGateClient` after no caller or dependency field remains.
- [x] 7.9 Add a regression test proving legacy `notmeyet.onboarding.gate.*` UserDefaults values do not affect backend-based routing or authorize Main.
- [x] 7.10 Re-audit source, tests, and app configuration to confirm no second durable onboarding authority or exact checkpoint persistence remains.

## 8. Verification And Release Evidence

- [x] 8.1 Run the focused backend-user transport and configuration suites and record pass/fail plus failing test names in `release-readiness.md` without open-ended remediation.
- [x] 8.2 Run the focused access-coordinator and onboarding-flow suites and record pass/fail plus failing test names in `release-readiness.md` without open-ended remediation.
- [x] 8.3 Run the complete unit-test target on a supported iPhone Simulator and record pass/fail plus failing test names in `release-readiness.md`.
- [x] 8.4 Run the serial mock-mode onboarding UI-test suite on a supported iPhone Simulator and record pass/fail plus failing test names in `release-readiness.md`.
- [x] 8.5 Re-run visual verification for changed screens 05, 06, and 13 at the required phone sizes and record the result in `release-readiness.md`.
- [x] 8.6 Re-run visual verification for changed screens 09, 11, and post-onboarding access at the required phone sizes and record the result in `release-readiness.md`.
- [x] 8.7 Re-run accessibility text-size viewport verification for screens 05, 06, and 13 and record the result in `release-readiness.md`.
- [x] 8.8 Re-run accessibility text-size viewport verification for screens 09, 11, and post-onboarding access and record the result in `release-readiness.md`.
- [x] 8.9 Inspect a Release build to confirm mock lifecycle selectors cannot execute and no credentials or production user fixtures are bundled.
- [x] 8.10 Verify invalid or unconfirmed live lifecycle configuration fails closed and sends no PUT or PATCH request.
- [x] 8.11 Check `release-readiness.md` for the backend owner's migration procedure, completion attestation, and pre/post counts when migration is required; record pass or an explicit release blocker without waiting for external work.
- [x] 8.12 Check `release-readiness.md` for a passing backend-owned release-environment deployment/contract result matching OpenAPI and iOS fixtures; record pass or an explicit release blocker without waiting for external work.
- [x] 8.13 Record checked OpenAPI validation, iOS fixture results, rollout status, and rollback limitation in `release-readiness.md`.
- [x] 8.14 Record the results of accessibility checks 6.16-6.28, including assistive-technology, target-size, contrast, transparency, and non-dismissible behavior evidence, in `release-readiness.md`.
- [x] 8.15 Run `openspec validate add-backend-onboarding-completion --type change --strict --no-interactive`; record any validation failure as an apply blocker and hand a clean apply stage to `/opsx-verify`.
