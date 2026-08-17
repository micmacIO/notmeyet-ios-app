# Exploration Brief: Backend Onboarding Completion

## Final Approach

Use the authenticated Looksmaxxing user record as the durable authority for whether onboarding is complete. After Apple or Google authentication, the iOS app obtains a fresh Firebase ID token and calls `PUT /api/v1/users/me`. Both `200 OK` and `201 Created` return a required `onboardingCompleted` Boolean. An incomplete account routes to onboarding without contacting RevenueCat; a completed account enters a separate post-onboarding access handoff that binds the Firebase UID to RevenueCat and evaluates entitlement. Every legitimate transition from screens 06, 09, or 11 into the paywall first sends the idempotent, monotonic `PATCH /api/v1/users/me` body `{ "onboardingCompleted": true }`. Only a successful completion response permits the access handoff.

The backend Boolean replaces the local `start`/`photo`/`paywall` routing gates as the cross-launch authority. Exact cross-device checkpoint resume is deliberately outside the MVP: every authenticated incomplete account resumes at screen 06. Questionnaire and facial data remain ephemeral.

## Complete Routing Matrix

| Context | Backend result | Route |
|---|---|---|
| Screen 05 | `201` + `onboardingCompleted: false` | Screen 06 |
| Screen 05 | `200` + `onboardingCompleted: false` | Screen 06 |
| Screen 05 | `200` + `onboardingCompleted: true` | Post-onboarding access handoff |
| Screen 05 | `201` + `onboardingCompleted: true` | Treat as an invalid contract response; remain on screen 05 with retry feedback |
| Screen 13 | `201` + `onboardingCompleted: false` | Remain on screen 13, explain that this account has not completed onboarding, and offer `Start onboarding` |
| Screen 13 | `200` + `onboardingCompleted: false` | Screen 06 |
| Screen 13 | `200` + `onboardingCompleted: true` | Post-onboarding access handoff |
| Screen 13 | `201` + `onboardingCompleted: true` | Treat as an invalid contract response; remain on screen 13 with retry feedback |
| Authenticated launch | `200` or `201` + `onboardingCompleted: false` | Screen 06 |
| Authenticated launch | `200` + `onboardingCompleted: true` | Post-onboarding access handoff |
| Authenticated launch | `201` + `onboardingCompleted: true` | Fail closed with retry feedback |
| Any context | Transport, authentication, non-`200`/`201`, missing Boolean, or malformed response | Do not route forward; expose safe retry behavior |
| Completion from screen 06, 09, or 11 | PATCH succeeds | Enter post-onboarding access handoff |
| Completion from screen 06, 09, or 11 | PATCH fails or is cancelled | Remain at the initiating onboarding step; do not show paywall or Main; allow retry |

`onboardingCompleted` starts as `false`, may transition only from `false` to `true`, and repeated PATCH requests with `true` are successful no-ops. It controls onboarding routing only and never grants subscription access, credits, or authorization to Main.

## Cross-Module Data Flow

1. Screen 05, screen 13, or launch obtains the current Firebase identity.
2. A backend-user client obtains the current Firebase ID token at request time and sends `PUT /api/v1/users/me`.
3. The client maps HTTP creation status plus the required Boolean into a typed account-resolution result.
4. `OnboardingFlowModel` applies the table above using the entry context; no purchase method is called for `false`.
5. A completed result is handed to the access coordinator, which then binds the Firebase UID to RevenueCat and evaluates entitlement to select Main or screen 12.
6. Screen 06 `Skip harmony check`, screen 09 `Skip look`, and screen 11 `Try more` call the backend-user client with `{ "onboardingCompleted": true }` before invoking the same access handoff.
7. Launch repeats backend resolution, so reinstall and another device agree on completed versus incomplete onboarding without local routing state.

## Rejected Alternatives

- Infer account lifecycle from `200` versus `201` alone: rejected because retries can turn a just-created account into `200`, and existence does not prove completion.
- Use RevenueCat entitlement to classify authentication results: rejected because onboarding state and paid access are separate concerns.
- Keep local routing gates as a second durable authority: rejected because reinstall, another device, or divergent writes can disagree with the backend Boolean.
- Add a server-side checkpoint enum now: rejected as unnecessary for the MVP; exact resume can be added later.
- Mark onboarding complete only after purchase: rejected because users who reach but do not purchase from the paywall have still completed onboarding.
- Allow the client to PATCH `false`: rejected to prevent accidental onboarding resets and repeated free-flow entry.

## Known Open Questions

- The backend deployment must confirm the production base URL and that `PUT` and `PATCH /api/v1/users/me` return the documented success statuses and response shape before live mode is enabled.
- A request that creates a user but loses its `201` response can return `200 + false` on retry; the MVP accepts routing that account to screen 06.
- A new account created from screen 13 and relaunched before `Start onboarding` is selected resumes at screen 06 because the MVP stores no server-side intent or exact checkpoint.
- Provider linking, selecting a different Firebase account, and account deletion remain separate future changes.
