## Why

Firebase authentication proves identity but does not say whether that account finished NotMeYet onboarding, while the current local routing gates cannot follow a user across reinstalls or devices. The app needs one backend-owned completion signal so screens 05 and 13, launch restoration, and the paywall handoff route consistently without using RevenueCat as part of authentication.

## What Changes

- Resolve the authenticated Looksmaxxing user after Firebase authentication and at authenticated launch through `PUT /api/v1/users/me`, accepting `200 OK` or `201 Created` and requiring an `onboardingCompleted` Boolean.
- Route incomplete users to screen 06 without contacting RevenueCat and route completed users to a separate post-onboarding access handoff that first binds the Firebase UID and then evaluates entitlement. A newly created incomplete account on screen 13 instead remains there with a Start onboarding choice.
- Reject the impossible `201 Created` plus `onboardingCompleted: true` combination and fail closed on malformed or unsuccessful account resolution.
- Mark onboarding complete through idempotent `PATCH /api/v1/users/me` before every legitimate transition from screens 06, 09, or 11 into the paywall/access stage; a failed or cancelled PATCH keeps the initiating screen visible.
- Keep `onboardingCompleted` monotonic and limited to routing; only the later RevenueCat handoff authorizes Main or selects the paywall.
- Replace device-local onboarding routing gates with the backend Boolean as the cross-launch authority. Exact checkpoint resume remains outside the MVP, so incomplete authenticated users resume at screen 06.
- Fail closed on backend resolution or completion errors, with retry behavior that neither advances the route nor repeats provider authentication unnecessarily.

## Capabilities

### New Capabilities
- `backend-user-lifecycle`: Firebase-authenticated current-user resolution, the backend onboarding-completion contract, monotonic completion updates, validation, and failure semantics.

### Modified Capabilities
- `account-and-purchase-gating`: Route screen-05, screen-13, launch, and post-onboarding access from backend completion before performing the separately owned RevenueCat access decision.
- `ios-onboarding-experience`: Complete onboarding through the backend before transitions from screens 06, 09, or 11 reach the paywall/access stage.
- `looks-preview-integration`: Gate the existing screen-09 `Skip look` and screen-11 `Try more` transitions on successful backend completion.

## Impact

- Adds a backend-user client and response models beside the existing authentication, purchase, and Looks service boundaries.
- Changes `OnboardingFlowModel`, app bootstrap, dependency construction, mocks, and tests; removes `OnboardingGateStore` from routing authority and may remove it entirely once unused.
- Requires the Looksmaxxing API to return `onboardingCompleted` from `PUT /api/v1/users/me` and support authenticated, idempotent `PATCH /api/v1/users/me` with `{ "onboardingCompleted": true }`.
- Keeps live mode fail closed until the configured production API contract confirms the endpoint URL, success statuses, and required response shape.
- Does not change Firebase provider authentication, RevenueCat entitlement semantics, backend credit enforcement, questionnaire persistence, or facial-data handling.
