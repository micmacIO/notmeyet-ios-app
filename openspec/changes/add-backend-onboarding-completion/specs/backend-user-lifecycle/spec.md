## ADDED Requirements

### Requirement: Authenticated current-user resolution
The app SHALL resolve the current Looksmaxxing user through a Firebase-authenticated, idempotent `PUT /api/v1/users/me` request and SHALL expose only a validated creation origin and required `onboardingCompleted` Boolean to routing state.

#### Scenario: Resolve a newly created incomplete user
- **WHEN** request-time Firebase token acquisition succeeds and PUT returns `201 Created` with `onboardingCompleted: false`
- **THEN** the client returns a created, incomplete user resolution

#### Scenario: Resolve an existing incomplete user
- **WHEN** PUT returns `200 OK` with `onboardingCompleted: false`
- **THEN** the client returns an existing, incomplete user resolution

#### Scenario: Resolve an existing completed user
- **WHEN** PUT returns `200 OK` with `onboardingCompleted: true`
- **THEN** the client returns an existing, completed user resolution

#### Scenario: Reject an impossible created-completed user
- **WHEN** PUT returns `201 Created` with `onboardingCompleted: true`
- **THEN** the client reports a safe contract failure and returns no routable user resolution

#### Scenario: Reject an invalid resolution response
- **WHEN** PUT returns a non-`200`/`201` status or a missing, null, non-Boolean, or malformed `onboardingCompleted` value
- **THEN** the client reports safe recoverable feedback and does not infer completion from status, Firebase identity, local state, wallet data, or entitlement

#### Scenario: Authenticate the resolution request
- **WHEN** current-user resolution begins
- **THEN** the client obtains the current Firebase ID token at request time, sends it as `Authorization: Bearer <token>`, and sends no domain request payload

#### Scenario: Firebase token acquisition fails
- **WHEN** no current Firebase user or usable ID token is available
- **THEN** no current-user request is sent and the app fails closed with safe authentication feedback

#### Scenario: Retry an ambiguous resolution
- **WHEN** the PUT outcome is unknown because transport ends before a valid response is received
- **THEN** Retry repeats the idempotent PUT without repeating Apple or Google provider authentication

### Requirement: Monotonic onboarding completion update
The app SHALL mark onboarding complete only through an authenticated `PATCH /api/v1/users/me` request with the exact domain body `{ "onboardingCompleted": true }`, and the backend contract SHALL make this update monotonic and idempotent.

#### Scenario: Complete an incomplete account
- **WHEN** PATCH changes `onboardingCompleted` from `false` to `true` and returns `200 OK` with `onboardingCompleted: true`
- **THEN** the client acknowledges completion and permits the separate post-onboarding access handoff

#### Scenario: Repeat an acknowledged completion
- **WHEN** PATCH is repeated for an account whose `onboardingCompleted` value is already `true`
- **THEN** the backend returns successful `200 OK` with `onboardingCompleted: true` without resetting or duplicating lifecycle effects

#### Scenario: Reject an unacknowledged completion
- **WHEN** PATCH returns a non-`200` status, malformed current-user representation, or any `onboardingCompleted` value other than `true`
- **THEN** the client does not acknowledge completion and does not enter the access handoff

#### Scenario: Authenticate the completion request
- **WHEN** onboarding completion begins
- **THEN** the client obtains the current Firebase ID token at request time and sends it as `Authorization: Bearer <token>` with the exact completion body

#### Scenario: Completion token acquisition fails
- **WHEN** no current Firebase user or usable ID token is available before PATCH
- **THEN** no completion request is sent, completion is not acknowledged, and the initiating screen presents safe authentication feedback

#### Scenario: Retry an ambiguous completion
- **WHEN** PATCH may have committed but no valid response reaches the app
- **THEN** Retry repeats only the same idempotent `true` update and never sends `false`

#### Scenario: Cancel completion
- **WHEN** completion is cancelled before acknowledgement or its initiating route becomes stale
- **THEN** no later completion changes the route or invokes the access handoff

#### Scenario: No reset operation
- **WHEN** the iOS client constructs backend-user lifecycle operations
- **THEN** it exposes no request capable of changing `onboardingCompleted` from `true` to `false`

### Requirement: Backend-owned routing authority
The app SHALL use backend `onboardingCompleted` as the sole durable authority for completed versus incomplete onboarding, while treating it as routing metadata that grants no subscription, credit, trial, protected-operation, or Main access.

#### Scenario: Incomplete account resumes
- **WHEN** a validated current-user response reports `onboardingCompleted: false`
- **THEN** the authenticated MVP flow resumes at screen 06 unless the screen-13 newly-created exception applies

#### Scenario: Completed account enters access handoff
- **WHEN** a validated current-user response reports `onboardingCompleted: true`
- **THEN** the app enters the separate access handoff and requires an authoritative entitlement result before Main

#### Scenario: Legacy local gate exists
- **WHEN** UserDefaults contains a prior `start`, `photo`, `paywall`, corrupt, or unsupported routing value
- **THEN** that value neither changes backend completion nor controls launch, authentication, paywall, or Main routing

#### Scenario: Process or device changes
- **WHEN** the authenticated user relaunches, reinstalls, or uses another device
- **THEN** the app resolves backend completion again and does not restore an exact questionnaire, photo, analysis, generation, or onboarding checkpoint

### Requirement: Isolated backend-user transport
Backend-user lifecycle requests SHALL use the configured HTTPS Looksmaxxing API base URL with ephemeral transport and SHALL NOT persist or log Firebase tokens, user responses, request bodies, backend identifiers, or raw backend errors.

#### Scenario: Send a lifecycle request
- **WHEN** PUT or PATCH is issued in configured live mode
- **THEN** the request uses non-persistent network behavior without URL caching, cookies, credential storage, background transfer, or sensitive logging

#### Scenario: Lifecycle contract is unavailable
- **WHEN** the production endpoint URL, accepted statuses, required Boolean, PATCH shape, or Firebase authentication contract has not been confirmed
- **THEN** live mode remains fail closed and no placeholder lifecycle request is sent

#### Scenario: Lifecycle contract activation evidence
- **WHEN** the lifecycle path is considered ready for live release
- **THEN** the checked production OpenAPI document and iOS adapter fixtures define and pass the agreed PUT and PATCH cases, and a backend-owned deployment contract test confirms the release environment implements the same contract before live release is enabled

#### Scenario: Facial-data policy boundary
- **WHEN** the backend-user client resolves or completes lifecycle state
- **THEN** it sends no photo data and does not itself require or inspect facial-image disclosure approval

### Requirement: Deterministic backend-user lifecycle mocks
Explicit Debug mock mode SHALL model Firebase identity, backend user creation, backend onboarding completion, and RevenueCat entitlement as independently configurable state.

#### Scenario: Mock lifecycle outcomes
- **WHEN** a test selects created-incomplete, existing-incomplete, existing-complete, invalid-response, resolution-failure, or completion-failure behavior
- **THEN** the backend-user client returns that deterministic outcome without contacting a production service

#### Scenario: Reset mock lifecycle
- **WHEN** a test requests onboarding reset
- **THEN** mock Firebase identity and backend-user lifecycle state are reset without deriving either state from mock entitlement
