## proposal Round 1 - 2026-08-12 18:26

### Red Fixed

- None in this round; findings are being addressed before the next review.

### Yellow Addressed

- None in this round; findings are being addressed before the next review.

### Red Outstanding

- Declare `looks-preview-integration` because screen-09 and screen-11 route requirements change.
- Preserve the exceptional routing outcomes and PATCH failure/cancellation behavior at proposal scope.
- Explicitly prohibit RevenueCat work for incomplete accounts and define bind-then-evaluate for completed accounts.

### Yellow Outstanding

- Include production backend-contract confirmation as a live-mode activation prerequisite.

## proposal Round 2 - 2026-08-12 18:27

### Red Fixed

- Added `looks-preview-integration` to the modified capabilities.
- Made screen-13 `201 + false`, invalid `201 + true`, and PATCH failure/cancellation outcomes explicit.
- Prohibited RevenueCat work for incomplete accounts and required bind-then-evaluate for completed accounts.

### Yellow Addressed

- Added production endpoint, status, and response-shape confirmation as a fail-closed live-mode prerequisite.

### Red Outstanding

- None.

## tasks Round 1 - 2026-08-12 19:02

### Red Fixed

- None in this round; migration gating, RevenueCat safeguards, dependency ordering, task granularity, and workflow staging are being corrected before re-review.

### Yellow Addressed

- None in this round; Back contexts, evidence location, and no-request fail-closed verification are being clarified.

### Red Outstanding

- Add a conditional retained-user migration execution and validation gate.
- Include SDK configured-state corroboration and strong delegate-retention verification for the lazy RevenueCat proxy.
- Move incomplete-route absence tests after coordinator and routing implementation.
- Split oversized routing, async-state, UI, accessibility, gate-removal, and visual-verification tasks below two hours.
- Remove `/opsx-verify` completion from the apply checklist while retaining OpenSpec validation and handoff.

### Yellow Outstanding

- Limit Back cancellation coverage to screens 05 and 13.
- Use one named `release-readiness.md` evidence destination.
- Verify unconfirmed lifecycle configuration sends no PUT/PATCH request.

## tasks Round 2 - 2026-08-12 19:05

### Red Fixed

- None in this round; the remaining compound tasks are being split and the SDK-already-configured proxy path is being added to test coverage.

### Yellow Addressed

- Converted external migration execution into a bounded evidence gate requiring the backend owner's procedure, attestation, and validation counts.

### Red Outstanding

- Add explicit proxy coverage proving SDK configured state prevents a second configure call.
- Split the remaining migration, incomplete-route, completion-control, access-outcome, UI, accessibility, gate-removal, and verification matrices into independently checkable work below two hours.

## tasks Round 3 - 2026-08-12 19:12

### Red Fixed

- None in this round; remaining compound tasks and external waits are being converted into bounded implementation or evidence-check units.

### Yellow Addressed

- Replaced open-ended transport combinations with complete finite PUT and PATCH fixture matrices.

### Red Outstanding

- Split operation-state, per-screen completion, access-monitoring, gate-removal, and unbounded test-remediation work below two hours.
- Make external migration and deployment dependencies bounded release-status checks rather than waits.
- Add explicit account-resolution announcement, Voice Control, and Reduce Transparency verification.

## tasks Round 4 - 2026-08-12 19:29

### Red Fixed

- None in this round; final executable-order, bounded-verification, finite-matrix, and launch-announcement corrections are being applied before Round 5.

### Yellow Addressed

- Added a bounded unavailable-OpenAPI release-blocker path and an explicit `release-readiness.md` creation task.

### Red Outstanding

- Remove gate references before deleting local-gate types.
- Split resolving/completing/access-pending stage work and remaining full route matrices.
- Make all focused and complete test runs bounded evidence checks without dynamic remediation-task cycles.
- Bind PUT/PATCH response tests to exact finite fixture lists.
- Cover one-time authenticated-launch resolution success and error announcements.

## tasks Round 5 - 2026-08-12 19:32

### Red Fixed

- Ordered local-gate caller and dependency removal before deleting gate types.
- Split operation stages and route matrices into bounded implementation units.
- Converted test execution into bounded pass/fail evidence without dynamic remediation cycles.
- Enumerated exact finite PUT and PATCH response-test fixtures.

### Yellow Addressed

- Added bounded unavailable-contract and external-evidence blocker outcomes.

### Red Outstanding

- Move `release-readiness.md` creation before tasks 1.1 and 1.2 write to it.
- Add explicit implementation tasks for one-time resolution success/error announcements on authenticated launch and success announcements on screens 05 and 13.

## tasks Round 6 - 2026-08-12 19:47

### Red Fixed

- Moved `release-readiness.md` creation before every evidence write.
- Added explicit implementation tasks for one-time resolution progress, success, and actionable-error announcements on launch and screens 05/13 before verification.

### Yellow Addressed

- Required visual and accessibility viewport results to be recorded in `release-readiness.md`.

### Red Outstanding

- Require results from the non-viewport accessibility checks in tasks 6.16-6.28 to be recorded in `release-readiness.md`.

## tasks Round 7 - 2026-08-12 19:49

### Red Fixed

- Added a bounded task that records all accessibility checks 6.16-6.28 in `release-readiness.md`.

### Yellow Addressed

- None.

### Red Outstanding

- None.

### Post-Freeze Declarative Correction

- Updated the validation command to the installed CLI's item-name syntax; no requirement, design decision, or task scope changed.

## specs Round 2 - 2026-08-12 18:58

### Red Fixed

- Aligned access retries with the irreversible RevenueCat lifecycle: configure once after prevalidation, then retry only UID binding and entitlement evaluation.

### Yellow Addressed

- Added PATCH request-time token acquisition and pre-transport authentication failure scenarios.
- Required checked OpenAPI, passing iOS fixtures, and backend-owned deployment contract evidence before live release.

### Red Outstanding

- None.

## specs Round 1 - 2026-08-12 18:51

### Red Fixed

- None in this round; design and specs are unfrozen to resolve RevenueCat initialization retry semantics.

### Yellow Addressed

- None in this round; PATCH token behavior and objective contract activation evidence are being added before re-review.

### Red Outstanding

- Define whether and how post-onboarding access retry recovers from lazy RevenueCat initialization failure.

### Yellow Outstanding

- Specify request-time Firebase token acquisition and pre-transport failure for PATCH.
- Define checked OpenAPI plus production-shaped adapter fixtures as lifecycle activation evidence.

## design Round 3 - 2026-08-12 18:54

### Red Fixed

- None in this round; the design is being revised to respect RevenueCat's irreversible process-global configuration lifecycle.

### Yellow Addressed

- None in this round; deployed backend contract evidence is being added before re-review.

### Red Outstanding

- Move all throwable validation before RevenueCat configuration, then configure nonthrowingly exactly once and strongly retain the service instead of claiming transactional initialization retry.

### Yellow Outstanding

- Require backend-owned deployment contract evidence in addition to checked OpenAPI and iOS fixtures.

## design Round 4 - 2026-08-12 18:56

### Red Fixed

- Moved RevenueCat input validation before access, then made process-global configuration nonthrowing, exactly once, and immediately strongly retained.

### Yellow Addressed

- Added checked OpenAPI, iOS fixtures, and backend-owned release-environment contract results as live-release evidence.
- Clarified that exactly-once configuration uses a process-global main-actor guard rather than only per-proxy state.

### Red Outstanding

- None.

## design Round 1 - 2026-08-12 18:45

### Red Fixed

- None in this round; the post-PATCH access retry-state gap is being addressed before the next review.

### Yellow Addressed

- None in this round; access-stage tracking, API configuration ownership, lazy purchase ownership, and rollback consequences are being clarified before the next review.

### Red Outstanding

- Define a stable route and retry behavior when PATCH succeeds but RevenueCat access evaluation fails, especially after screens 09 and 11 release image state.

### Yellow Outstanding

- Define explicit operation-stage tracking and stage-specific retry dispatch.
- Clarify shared API URL and global versus lifecycle-specific configuration gates.
- Assign lazy RevenueCat construction to a concrete dependency boundary.
- Document rollback behavior for accounts that have only backend completion state.

## design Round 2 - 2026-08-12 18:47

### Red Fixed

- Added a stable post-onboarding access state that clears photo data only after PATCH acknowledgement and retries RevenueCat without repeating PATCH.

### Yellow Addressed

- Defined resolution, completion, and access-pending stages with stage-specific retries.
- Kept one shared API base URL while separating lifecycle transport from photo-policy checks.
- Assigned at-most-once lazy RevenueCat construction to the dependency-owned purchase proxy.
- Documented the emergency rollback limitation for backend-only completion state.

### Red Outstanding

- None.
