# Explore Brief: Firebase Production Auth Runbook

## Final Approach

Create `docs/firebase-production-auth-runbook.md` as the durable, repository-local version of the completed exploration for production Firebase Authentication with Sign in with Apple and Google Sign-In. The document will be operational guidance only: it will describe current repository state, Firebase/Google/Apple console setup, Xcode and CI placement, secret classification, backend trust, provider-linking and deletion gaps, release verification, rotation, and official references. It will not change application code, build configuration, credentials, external provider settings, or release-readiness claims.

## Rejected Alternatives

| Alternative | Reason rejected |
|---|---|
| Put the runbook in `README.md` | The detailed production procedure would overwhelm the repository landing page. |
| Keep the guidance only in OpenSpec artifacts | Change artifacts describe planned work and may be archived; the user requested a durable standalone document. |
| Store it at the repository root | A `docs/` location gives operational documentation a clear home without adding unrelated README content. |
| Add real identifiers or credential values | The runbook must explain placement without recording production secrets or unknown external values. |
| Implement the setup while documenting it | The request is to preserve the explored instructions, not to configure Firebase, alter code, or claim production readiness. |

## Complete Content Mapping

| Runbook section | Required content |
|---|---|
| Purpose and current verdict | Explain that Firebase has no single production switch and distinguish existing native flows from production-readiness blockers. |
| Current repository state | Record the checked bundle ID, development team, entitlement, Apple and Google exchanges, URL callback, dependencies, missing plist, placeholders, and unwired configuration. |
| Authentication flow | Apple/Google provider credential to Firebase Auth to Firebase ID token to backend verification. |
| Production setup | Preserve all 23 numbered steps from identifier selection through incident response. |
| Secret handling | Classify Firebase plist/API key/project IDs, Google IDs and secrets, Apple IDs/key/JWT, Admin credentials, tokens, authorization codes, and nonce data. |
| Product and App Review gaps | Cover provider linking, Apple consent constraints, in-app account deletion, provider revocation, backend data deletion, and button/legal review. |
| Verification | Preserve the physical-device/TestFlight, cross-provider, deletion, backend-token, signed-archive, and secret-audit matrix. |
| References | Include the official Firebase, Google, Apple, token-verification, API-key, and App Review links cited during exploration. |

## Checked Repository Facts

| Fact | Checked value and source |
|---|---|
| Production bundle identifier | `io.micmac.notmeyet` in `notmeyet.xcodeproj/project.pbxproj` |
| Checked development team | `H36U63R3Y7` in `notmeyet.xcodeproj/project.pbxproj`; the runbook must require portal verification |
| Apple entitlement | `com.apple.developer.applesignin = Default` in `notmeyet/notmeyet.entitlements` |
| Apple exchange | Nonce-backed native credential exchange in `notmeyet/Services/LiveAuthenticationClient.swift` |
| Google exchange | `GoogleSignIn` credential exchange in `notmeyet/Services/LiveAuthenticationClient.swift` |
| URL callback | `.onOpenURL` forwarding in `notmeyet/App/AppRootView.swift` and `NMY_GOOGLE_REVERSED_CLIENT_ID` in `notmeyet/Info.plist` |
| Firebase startup | `FirebaseApp.configure()` requires `GoogleService-Info.plist` |
| Release inputs | Google values are placeholders, the Firebase plist is absent, and no `.xcconfig` is assigned through `baseConfigurationReference` |
| Global live gate | Google, Firebase, RevenueCat, API, legal, facial-data, and backend-lifecycle settings must all validate |
| Missing account lifecycle | `AuthenticationClient` has no sign-out, provider-linking, revocation, or account-deletion operations |

## Required Numbered Runbook

| # | Exact step label | Required coverage |
|---:|---|---|
| 1 | Freeze the production identifiers before creating credentials | Bundle ID, checked team, explicit Apple App ID, immutable Firebase project ID, and a distinct Apple Services ID. |
| 2 | Use a dedicated Firebase production project | Environment separation and the requirement that the iOS app and backend trust the same project. |
| 3 | Secure Firebase and Google Cloud administrative access | Least privilege, administrator MFA, recovery ownership, billing, quotas, and alerts. |
| 4 | Register the iOS app in Firebase | Exact bundle ID, optional metadata, and the fact that Android SHA fingerprints do not apply. |
| 5 | Enable Sign in with Apple for the Apple App ID | Portal capability, primary App ID, refreshed profiles, and signed entitlement verification. |
| 6 | Create an Apple Services ID for Firebase | Primary-App-ID association, Firebase domain, exact callback, and revocation rationale. |
| 7 | Create the Apple private key | Sign in with Apple key, one-time `.p8` download, secret storage, and two-key rotation constraint. |
| 8 | Enable Apple in Firebase Authentication | Services ID, Team ID, Key ID, private key, and Firebase-owned client-secret generation. |
| 9 | Configure Apple private email relay if email is sent | Conditional sender registration, custom domains, SPF/DKIM, and relay delivery. |
| 10 | Enable Google in Firebase Authentication | Provider activation, support email, refreshed plist, and required plist keys. |
| 11 | Publish the Google OAuth application | Branding, External audience, In production status, basic scopes, exact iOS client, and verification warnings. |
| 12 | Place the Firebase client configuration in the app | Exact plist path, current ignore policy, CI materialization, target membership, and archive inclusion. |
| 13 | Populate the Google build settings from the same plist | Exact `CLIENT_ID` and `REVERSED_CLIENT_ID` mappings and prohibition on cross-project mixing. |
| 14 | Fix the current `.xcconfig` wiring before relying on it | Missing base configuration, stronger target placeholders, recommended Release configuration change, and proposal requirement. |
| 15 | Remember the app's global live-configuration gate | Complete list of non-authentication values that also prevent `.live` activation and truthful confirmation handling. |
| 16 | Use the documented secret-placement rules | Complete public, secret, and transient-value matrix below. |
| 17 | Harden Firebase Authentication | Unused providers, authorized domains, localhost removal, email enumeration, API allowlist, quotas, and sanitized telemetry. |
| 18 | Configure the production backend trust boundary | Admin SDK project match, verified UID, ADC/workload identity, secret-manager fallback, and token rejection tests. |
| 19 | Make an explicit provider-linking decision | Duplicate UID risk, backend and RevenueCat consequences, no email-only merge, Apple consent, and support behavior. |
| 20 | Implement in-app account deletion before release | App Review requirement, recent reauthentication, Apple authorization-code revocation, Google disconnect, backend/Firebase deletion, and all data owners. |
| 21 | Review provider button branding and legal presentation | Apple and Google branding plus live Terms and Privacy URLs shared with OAuth configuration. |
| 22 | Run a signed production verification matrix | All test rows in the verification inventory below, using TestFlight and physical devices. |
| 23 | Plan key rotation and incident response | Apple overlap rotation, native Google non-secret handling, installed-client constraints, and credential ownership. |

## Complete Secret Classification

| Value | Classification | Required location or handling |
|---|---|---|
| `GoogleService-Info.plist` | Public client configuration | App bundle; optionally controlled through CI to prevent environment mix-ups |
| Firebase `API_KEY` | Public project identifier | Inside the plist with Firebase-recommended API restrictions |
| Firebase project and app IDs | Public identifiers | Client configuration |
| Google iOS client ID | Public identifier | App configuration |
| Google reversed client ID | Public callback scheme | App `Info.plist` URL scheme |
| Apple Team ID, Services ID, and Key ID | Public identifiers | Firebase provider configuration and operational inventory |
| Apple `.p8` | Secret | Secret manager and Firebase provider only; never mobile source, bundle, or CI artifact |
| Apple client-secret JWT | Secret bearer credential | Generated and used by Firebase, never by the iOS app |
| Google web-client secret | Secret | Firebase or server configuration only |
| Firebase Admin service-account key | Secret | Backend secret manager only; prefer ADC or workload identity |
| Firebase, Apple, and Google ID/access/refresh tokens | Secret bearer credentials | Transient use; never logs or fixtures |
| OAuth authorization code | Short-lived secret | Revoke or exchange immediately; never log |
| Raw Apple nonce | Transient security-sensitive value | Memory only; never persist or log |

## Complete Verification Inventory

| Test | Required expectation |
|---|---|
| Apple Share My Email | One Firebase user with Apple provider |
| Apple Hide My Email | Relay address accepted and backend account created |
| Returning Apple user | Sign-in works without repeated name/email data |
| Revoked Apple authorization | Reauthentication recovery works |
| New Google user | No test-user or unverified-app restriction |
| Returning Google user | Stable Firebase UID |
| Provider cancellation | No Firebase or backend mutation |
| Apple then Google | Behavior matches the explicit linking policy |
| Account deletion | Provider grant and all application data are removed |
| Sign-in after deletion | Deleted application data is not restored |
| Backend token validation | Production accepted; staging, expired, malformed, and tampered tokens rejected |
| Signed archive | Production plist, callback scheme, and Apple entitlement present |
| Secret audit | No `.p8`, Admin JSON, OAuth secret, token, or test credential bundled |

## Official Reference Inventory

| Subject | URL |
|---|---|
| Firebase Apple-platform setup | `https://firebase.google.com/docs/ios/setup` |
| Firebase Google Sign-In for iOS | `https://firebase.google.com/docs/auth/ios/google-signin` |
| Firebase Sign in with Apple for iOS and token revocation | `https://firebase.google.com/docs/auth/ios/apple` |
| Firebase environment separation | `https://firebase.google.com/docs/projects/dev-workflows/general-best-practices` |
| Firebase API-key handling | `https://firebase.google.com/docs/projects/api-keys` |
| Firebase Admin ID-token verification | `https://firebase.google.com/docs/auth/admin/verify-id-tokens` |
| Apple Services ID/web configuration | `https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/` |
| Apple Sign in with Apple key creation | `https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key/` |
| Apple private email relay | `https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/` |
| Apple account deletion and token revocation | `https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple.md` |
| Google OAuth production readiness | `https://developers.google.com/identity/protocols/oauth2/production-readiness/overview` |
| Google iOS disconnect | `https://developers.google.com/identity/sign-in/ios/disconnect` |
| App Review Guidelines | `https://developer.apple.com/app-store/review/guidelines/#5.1.1` |

## Cross-System Flows To Preserve

```text
Apple AuthenticationServices --\
                                +--> Firebase Auth --> Firebase ID token --> production API/Admin verification
Google Sign-In SDK ------------/

Production GoogleService-Info.plist --> FirebaseApp.configure()
CLIENT_ID ---------------------------> Google Sign-In configuration
REVERSED_CLIENT_ID ------------------> app callback URL scheme

Apple .p8 --> Firebase Apple provider only
Admin credential/ADC --> backend only
No server secret --> iOS app, repository, or mobile build artifact
```

## Known Open Questions

- No question blocks the documentation change.
- Actual Firebase project ID, Apple Services ID, final legal URLs, credentials, provider-linking policy, and deletion design remain intentionally unresolved operational or future-change inputs.
- Any future implementation should use a separate OpenSpec change and update this runbook only after the signed production behavior has been verified.
