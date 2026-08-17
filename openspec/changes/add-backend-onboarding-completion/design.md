## Context

The app currently treats Firebase authentication plus local `start`/`photo`/`paywall` values as onboarding routing state. Screen 05 binds every authenticated UID to RevenueCat and always enters screen 06, while screen 13 binds the UID and immediately evaluates entitlement. Launch also evaluates RevenueCat before consulting the local gate. This makes onboarding state device-local and couples authentication to purchase identity before the app knows whether onboarding is complete.

The Looksmaxxing API already authenticates Firebase ID tokens and has a current-user representation. The backend will add a required `onboardingCompleted` Boolean and a monotonic update operation. The iOS app remains a single SwiftUI MV flow with one `@MainActor` observable model and injected service clients; this change does not justify introducing another state architecture.

The accepted MVP intentionally stores no exact server-side onboarding checkpoint. An authenticated incomplete account always resumes at screen 06, and questionnaire, photo, analysis, and generated-look state remains ephemeral.

## Goals / Non-Goals

**Goals:**

- Make the backend Boolean the sole durable authority for completed versus incomplete onboarding.
- Resolve backend user state after Firebase authentication and before any RevenueCat work.
- Keep RevenueCat identity binding and entitlement evaluation in a separate post-onboarding access handoff.
- Make completion monotonic, idempotent, retryable, and required before paywall or Main routing.
- Preserve safe cancellation, stale-result rejection, accessibility feedback, deterministic mocks, and test seams.

**Non-Goals:**

- Persist or restore an exact onboarding checkpoint, questionnaire answer, photo, analysis, or generated result.
- Use onboarding completion as subscription, credit, trial, or Main authorization.
- Change Apple/Google credential exchange, RevenueCat entitlement semantics, purchase/restore behavior, or backend benefit enforcement.
- Add provider linking, account switching, account deletion, or a general-purpose networking framework.
- Implement the backend in this iOS repository; the backend contract must be deployed before live iOS enablement.

## Decisions

### 1. Add a focused backend-user service boundary

Add an injected `BackendUserClient` beside `AuthenticationClient`, `PurchaseClient`, and `LooksClient` with two asynchronous operations:

```swift
resolveCurrentUser() async throws -> BackendUserResolution
completeOnboarding() async throws
```

`BackendUserResolution` contains an origin (`created` or `existing`) and `onboardingCompleted`. The service, rather than the flow model, translates HTTP statuses and validates impossible wire combinations. The flow model consumes transport-independent values and retains route ownership.

The live implementation is a small dedicated service rather than an extension of `LiveLooksService`. `NMYLooksAPIBaseURL` remains the one base-URL setting for both user lifecycle and facial processing; no second URL is added. The service shares that validated HTTPS URL and the request-time Firebase ID-token provider, but it does not inspect facial-image disclosure approval and cannot access photo bytes. Global live-mode validation remains unchanged for this release, so the app as a whole still fails closed when any existing live prerequisite, including facial disclosures, is missing; the lifecycle adapter itself has no photo-policy coupling. It uses an ephemeral `URLSession`, no URL cache, cookies, credential storage, background transfer, request/response logging, or new external dependency.

This keeps user lifecycle separate from facial processing and avoids refactoring the larger Looks transport solely to share a few request helpers.

### 2. Use one strict, additive HTTP contract

Every request obtains a current Firebase ID token immediately before transport and sends `Authorization: Bearer <token>`.

`PUT /api/v1/users/me` has no domain request body and atomically gets or creates the current user. It accepts only:

| Status | Required body value | Domain result |
|---|---|---|
| `201 Created` | `onboardingCompleted: false` | `created`, incomplete |
| `200 OK` | `onboardingCompleted: false` | `existing`, incomplete |
| `200 OK` | `onboardingCompleted: true` | `existing`, complete |
| `201 Created` | `onboardingCompleted: true` | Invalid contract response |

The response may retain its existing user and wallet properties, but `onboardingCompleted` is required. Missing, null, non-Boolean, malformed, unauthenticated, non-`200`/`201`, or impossible responses fail closed with a safe domain error.

`PATCH /api/v1/users/me` sends exactly:

```json
{
  "onboardingCompleted": true
}
```

The backend accepts only the monotonic `false -> true` transition and repeated `true` writes as successful no-ops. A successful PATCH returns `200 OK` with the current-user representation and `onboardingCompleted: true`; the client rejects a missing or false value. The iOS client exposes no operation that writes `false`.

Reusing the current-user response avoids a second lifecycle representation and lets the client confirm the acknowledged state. A strict contract is preferred to guessing from local state or accepting arbitrary success responses.

### 3. Resolve onboarding before access, with no incomplete-user RevenueCat work

Account resolution and access evaluation are sequential phases:

```text
Firebase identity
      |
      v
PUT current user
      |
      +-- incomplete --> onboarding route
      |                   no RevenueCat bind, refresh, or monitoring
      |
      +-- complete ----> post-onboarding access handoff
                              |
                              v
                        bind Firebase UID
                              |
                              v
                        refresh entitlement
                         |             |
                      active       inactive
                         |             |
                        Main        screen 12
```

`AccessCoordinator` remains the serialized owner of RevenueCat UID binding and entitlement refresh, but its launch entry point no longer reads Firebase identity itself. `OnboardingFlowModel` obtains the UID from `AuthenticationClient`, resolves backend state, and invokes access coordination only for a complete account or after acknowledged completion.

Dependency construction validates the RevenueCat API key and entitlement identifier before live mode begins, so no throwable configuration work remains in the access flow. `PurchaseClient` becomes a `@MainActor` lazy proxy whose first operation performs the irreversible, non-throwing `Purchases.configure` step exactly once, creates and strongly retains `LivePurchaseService` for its delegate lifetime, and immediately forwards the operation. A process-global main-actor guard, corroborated by the SDK's configured state, prevents a second configuration even if dependency assembly accidentally creates another proxy instance. `AccessCoordinator` continues to depend only on `PurchaseClient`; it does not own SDK construction. Mock and unavailable clients retain the same interface. Access-update monitoring begins only after a successful bind/evaluation. This prevents RevenueCat SDK configuration or network work merely because an incomplete Firebase session exists. Once access coordination has begun, existing entitlement revocation, purchase, restore, and hard-paywall rules remain unchanged.

### 4. Apply the complete entry-context routing table

The flow model retains whether resolution began at screen 05, screen 13, or launch and applies this table:

| Context | Resolution | Route |
|---|---|---|
| Screen 05 | created or existing, incomplete | Screen 06 |
| Screen 05 | existing, complete | Post-onboarding access handoff |
| Screen 13 | created, incomplete | Remain on screen 13 with a neutral incomplete-account message and the existing `Start onboarding` action |
| Screen 13 | existing, incomplete | Screen 06 |
| Screen 13 | existing, complete | Post-onboarding access handoff |
| Authenticated launch | created or existing, incomplete | Screen 06 |
| Authenticated launch | existing, complete | Post-onboarding access handoff |
| Any context | created, complete or invalid response | Remain/fail closed with safe retry feedback and no RevenueCat work |

An unauthenticated launch continues to screen 01 without a backend or RevenueCat request. `Start onboarding` from the screen-13 created/incomplete state keeps the backend account incomplete, clears transient returning-screen messaging, and follows the existing route to screen 01. A lost `201` response can become `200 + false` on retry; the accepted MVP then treats the account as existing and routes it to screen 06.

### 5. Complete onboarding at the paywall/access boundary

The only completion initiators are the existing actions that leave the optional preview journey:

| Initiating screen | Action |
|---|---|
| 06 | `Skip harmony check` |
| 09 | `Skip look` |
| 11 | `Try more` |

Each action starts one guarded asynchronous transition:

```text
initiating screen
      |
      v
PATCH onboardingCompleted=true
      |
      +-- failure/cancel --> same screen, no access handoff
      |
      +-- success --------> post-onboarding access state
                                  |
                                  +-- clear photo-derived state once
                                  |
                                  v
                            RevenueCat handoff
                             |       |        |
                           Main  screen 12  retry state
```

The initiating screen remains rendered while PATCH is in progress. Its completion actions are disabled, an accessible progress state is exposed, and safe recoverable feedback appears on failure. Photo-derived state is not cleared until PATCH succeeds, so a failed transition does not destroy the screen the user must retry from. A cancelled or stale operation cannot route or invoke later access work.

After PATCH acknowledgement, the flow records an explicit `.accessPending(userID)` state, clears photo-derived data once, and replaces the numbered onboarding screen with an unnumbered, non-dismissible `PostOnboardingAccessView`. That view shows access-verification progress or safe recoverable feedback and a `Try again` action. It has no Back action and never repeats PATCH because the backend acknowledgement is already represented in the state. Successful access evaluation replaces it with Main or screen 12. This stable surface also handles completed-account access failures from screen 05, screen 13, and launch, so those routes do not need to retain authentication or image screens as RevenueCat retry UIs.

The flow records the authenticated UID and one explicit account-operation stage: resolving from an entry context, completing from an initiating step, or access pending after acknowledged completion. Retry dispatches solely from that stage: resolution repeats PUT without provider authentication, completion repeats PATCH, and access pending repeats only RevenueCat UID binding and entitlement evaluation against the retained, once-configured service. It never repeats Firebase provider authentication, backend PUT/PATCH, or process-global RevenueCat configuration. Repeating PUT or PATCH after an ambiguous transport outcome is safe by contract; after backend acknowledgement, an access failure cannot change completion back to false or return to a numbered onboarding step.

### 6. Remove local gates instead of reconciling two authorities

Remove `RoutingGateClient`, `RoutingGate`, and `OnboardingGateStore` from dependency construction and routing. Existing `UserDefaults` keys are ignored; they are not mapped to backend completion because `photo` and `paywall` values are neither authoritative nor reliably portable.

There is no shipped production-state migration assumed for this pre-release app. Existing development installs may resume at screen 06 if their backend user defaults to incomplete. If production users exist before rollout, their backend field requires an explicit server migration decision before this client is released.

Mock mode models backend user existence and completion independently from Firebase authentication and entitlement. Reset arguments clear both mock identity and backend lifecycle state; deterministic selectors cover created/incomplete, existing/incomplete, existing/complete, malformed, resolution failure, and completion failure. Existing gate-based UI fixtures move to backend-completion fixtures.

### 7. Keep one observable flow owner and explicit operation identity

`OnboardingFlowModel` remains the owner of route, transient operation state, and cross-service sequencing. `AppAccessPhase` gains a post-onboarding access-verification case, and the model tracks the account-operation stage described above rather than introducing a forwarding view model or coordinator hierarchy. Each asynchronous account operation carries a request identity plus expected route/context, matching the existing authentication and Looks stale-result protections.

Unit tests use injected clients and event logs to prove ordering and absence as well as destinations. Transport contract tests use `URLProtocol` interception to verify methods, paths, bearer acquisition, exact PATCH JSON, status/body mapping, malformed responses, cancellation, and no persistence. XCUITests remain XCTest-based and verify visible route/error behavior; new unit tests continue using Swift Testing.

## Risks / Trade-offs

- **[No exact checkpoint]** An incomplete account on another device or after termination restarts at screen 06 and loses in-memory work. -> Accept for MVP and add a server checkpoint only when product requirements justify it.
- **[Ambiguous PUT creation response]** A created account whose response is lost appears existing on retry, changing screen-13 behavior. -> Accept the documented idempotency trade-off; both outcomes remain safe and incomplete.
- **[Ambiguous PATCH response]** The backend may commit completion before transport fails. -> Retry the same monotonic `true` PATCH; never write `false`.
- **[Backend/iOS rollout skew]** The released contract may lack the field, PATCH operation, or agreed status. -> Deploy and validate the additive backend contract first; keep live iOS mode fail closed until the checked contract and adapter tests agree.
- **[Two remote systems after completion]** Backend completion can succeed while RevenueCat is unavailable. -> Preserve completion, fail closed outside Main, and retry only the post-onboarding access handoff.
- **[Lazy purchase configuration changes timing]** Process-global RevenueCat configuration moves from app construction to the first post-onboarding operation. -> Validate all throwable inputs during dependency construction, configure nonthrowingly exactly once in the main-actor proxy, strongly retain the delegate service, and test that incomplete routes perform no purchase work or configuration.
- **[Legacy local state ignored]** Development users can repeat onboarding after upgrade. -> Accept for pre-release data; require a backend migration decision if real users are discovered.
- **[iOS rollback loses new routing knowledge]** An older client cannot read backend completion and a new-device or reinstalled user may return to its default local route after rollback. -> Treat rollback as an emergency access-safe fallback, retain the additive backend value, communicate the onboarding-repeat limitation, and ship a forward fix rather than trying to reconstruct local gates remotely.
- **[Client can mark completion early]** A modified client can skip onboarding. -> Treat the Boolean only as routing metadata; backend credits, trials, subscriptions, and protected operations remain independently enforced.

## Migration Plan

1. Deploy a non-null backend `onboardingCompleted` field defaulting to `false`, idempotent PUT get-or-create behavior, and monotonic PATCH behavior without removing compatibility needed by older clients.
2. Publish an updated OpenAPI contract with the production HTTPS base URL, exact statuses, required Boolean, PATCH request, and response representation. Validate that document and production-shaped PUT/PATCH fixtures with iOS adapter contract tests, and require a backend-owned deployment/contract test result from the release environment confirming the deployed endpoint implements the same cases. Both evidence sets are required to enable the lifecycle path in live release.
3. Add the iOS backend-user adapter, strict contract tests, mock lifecycle state, and dependency wiring while local gates still exist but are no longer consulted by new routing tests.
4. Switch authentication, launch, and completion routing to backend resolution; make purchase initialization/monitoring conditional on the post-onboarding handoff.
5. Remove local gate types, wiring, launch selectors, and obsolete tests, then run unit, UI, configuration, and production-shaped contract verification.
6. Release only after backend compatibility is confirmed. An emergency rollback can restore the prior access-safe iOS code, but older clients may repeat onboarding because they cannot consume backend completion; retain the additive backend field and prefer a forward client fix.

## Open Questions

- Has any production or externally retained user state been created that needs a one-time backend value migration instead of the default `false`?
- When will the generated OpenAPI document confirming PUT/PATCH statuses and the required response field be supplied to this repository?
- What final product copy should the neutral screen-13 created/incomplete message use? The behavior and available `Start onboarding` action are fixed by this design.
