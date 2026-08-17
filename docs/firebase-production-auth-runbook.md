# Firebase Production Authentication Runbook

Last source review: 2026-08-17

Firebase Authentication has no single production switch. For NotMeYet, production readiness means using a dedicated Firebase project, publishing and configuring both identity providers, supplying the correct Release client configuration, verifying Firebase ID tokens in the production backend, supporting account deletion and provider revocation, and validating the final signed build.

This document is operational guidance, not evidence that any external setup or release check has been completed. Values written as placeholders remain unknown, and all external configuration and signed-device checks remain unverified until recorded by a separate implementation change.

## Current Repository State

The app already contains most of the native credential-exchange implementation:

| Existing element | Checked location |
|---|---|
| Bundle ID `io.micmac.notmeyet` | `notmeyet.xcodeproj/project.pbxproj` |
| Selected Apple development team `H36U63R3Y7` | `notmeyet.xcodeproj/project.pbxproj`; verify it in Apple Developer before use |
| Sign in with Apple entitlement with value `Default` | `notmeyet/notmeyet.entitlements` |
| Nonce-backed Apple credential and Firebase exchange | `notmeyet/Services/LiveAuthenticationClient.swift` |
| Google Sign-In and Firebase credential exchange | `notmeyet/Services/LiveAuthenticationClient.swift` |
| Google callback URL forwarding | `notmeyet/App/AppRootView.swift` |
| Google callback URL scheme setting | `notmeyet/Info.plist` |
| FirebaseCore, FirebaseAuth, and GoogleSignIn dependencies | `notmeyet.xcodeproj/project.pbxproj` |
| Firebase startup through `FirebaseApp.configure()` | `notmeyet/Services/LiveAuthenticationClient.swift` |

The checked Release configuration is intentionally not operational:

| Current blocker | Checked state |
|---|---|
| Google client ID | `PLACEHOLDER_GOOGLE_CLIENT_ID` |
| Google reversed client ID | `com.googleusercontent.apps.PLACEHOLDER` |
| Firebase client configuration | No `GoogleService-Info.plist` is present |
| `.xcconfig` assignment | No `baseConfigurationReference` is configured |
| Global live prerequisites | Firebase, Google, RevenueCat, API, legal, facial-data, and backend-lifecycle values must all validate |
| Account lifecycle | `AuthenticationClient` has no sign-out, provider-linking, revocation, or account-deletion operations |

The existing backend-onboarding release record also lists production Firebase and Google configuration as an unresolved blocker. Adding this document does not clear that blocker.

## Authentication And Configuration Flows

```text
Apple AuthenticationServices --\
                                +--> Firebase Auth --> Firebase ID token --> production API
Google Sign-In SDK ------------/                                      |
                                                                      v
                                                             Firebase Admin verification

Production GoogleService-Info.plist --> FirebaseApp.configure()
CLIENT_ID ---------------------------> Google Sign-In configuration
REVERSED_CLIENT_ID ------------------> app callback URL scheme

Apple .p8 ---------------------------> Firebase Apple provider only
Admin credential or ADC ------------> backend only
No server secret --------------------> iOS app, repository, or mobile build artifact
```

## Production Runbook

1. **Freeze the production identifiers before creating credentials.**

   Confirm the following identifiers are final before configuring external systems:

   | Identifier | Required value or action |
   |---|---|
   | Bundle ID | `io.micmac.notmeyet` |
   | Apple Team ID | The project currently selects `H36U63R3Y7`; verify ownership in Apple Developer |
   | Apple App ID | An explicit App ID for `io.micmac.notmeyet` |
   | Firebase project ID | Choose the immutable production project ID |
   | Apple Services ID | Create a distinct identifier such as `io.micmac.notmeyet.firebase-auth` |

   Changing the bundle ID later requires new or updated Apple, Firebase, and Google OAuth registrations. Do not replace placeholders in this runbook with production secrets.

2. **Use a dedicated Firebase production project.**

   In [Firebase Console](https://console.firebase.google.com/), create or select the project that the production backend will trust. Do not reuse an emulator, personal development, or staging project for App Store users.

   Firebase Auth users, OAuth clients, quotas, provider settings, ID-token issuer, and ID-token audience are project-specific. The production iOS app and production backend must use the same Firebase project; otherwise, Admin SDK verification will reject the app's tokens.

   If a production backend is already tied to a Firebase project, confirm that project before creating another one. Follow Firebase's [environment separation guidance](https://firebase.google.com/docs/projects/dev-workflows/general-best-practices).

3. **Secure Firebase and Google Cloud administrative access.**

   Restrict Firebase and Google Cloud IAM to people who operate production, require MFA for administrators, apply least-privilege roles, and keep at least two controlled recovery administrators. Record ownership for OAuth branding, provider credentials, quotas, billing, and incident response.

   Configure billing and quota alerts appropriate to the production traffic plan. Enabling Google Analytics is optional and is not required for Firebase Authentication.

4. **Register the iOS app in Firebase.**

   Open Firebase Console, select the production project, then use Project settings > General > Your apps > Add app > Apple. Console group names may change; use the linked official setup documentation if navigation differs.

   Enter the exact, case-sensitive bundle ID:

   ```text
   io.micmac.notmeyet
   ```

   The App Store ID and internal nickname are optional. Android SHA certificate fingerprints do not apply to this iOS registration.

5. **Enable Sign in with Apple for the Apple App ID.**

   Open [Apple Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), select the explicit App ID for `io.micmac.notmeyet`, and enable Sign in with Apple. Make it the primary App ID if Apple prompts for that relationship.

   The repository entitlement only requests the capability; it does not prove that the Apple portal or distribution profile grants it. Refresh or regenerate development and App Store distribution profiles after enabling the capability.

   Inspect the final signed archive and confirm it contains:

   ```text
   com.apple.developer.applesignin = ["Default"]
   ```

6. **Create an Apple Services ID for Firebase.**

   In Apple Developer > Identifiers > Services IDs, create the Services ID selected in step 1. Configure Sign in with Apple for it and associate it with the primary App ID.

   For the standard Firebase auth domain, register:

   ```text
   Domain:
   YOUR_FIREBASE_PROJECT_ID.firebaseapp.com

   Return URL:
   https://YOUR_FIREBASE_PROJECT_ID.firebaseapp.com/__/auth/handler
   ```

   If Firebase displays a different handler because a custom auth domain is used, copy the exact handler shown by Firebase rather than constructing it manually.

   Native Apple authorization may appear to work without the Services ID fields, but Firebase's supported `revokeToken(withAuthorizationCode:)` production path uses the complete Services ID configuration. Token revocation is part of the account-deletion requirement.

7. **Create the Apple private key.**

   In Apple Developer > Keys, create a key with Sign in with Apple enabled and configure it for the primary App ID. Record the Key ID and download the `.p8` file immediately; Apple permits downloading it only once.

   Store the `.p8` in an approved secret manager or password vault and supply it only to Firebase's Apple provider configuration. Never add it to Xcode, an `.xcconfig`, this repository, the iOS bundle, a test fixture, mobile CI output, email, or chat.

   Apple permits two Sign in with Apple keys for each primary App ID. Preserve a free slot where possible so a replacement key can be created and validated before an old or compromised key is revoked.

8. **Enable Apple in Firebase Authentication.**

   Open Firebase Console > Authentication > Sign-in method > Apple and supply:

   | Firebase field | Source |
   |---|---|
   | Services ID | Apple Services ID from step 6 |
   | Apple Team ID | Verified Apple team identifier |
   | Key ID | Apple key from step 7 |
   | Private key | Contents of the downloaded `.p8` |

   Firebase stores the key and generates Apple client-secret JWTs. The iOS app does not need the `.p8` or an Apple client secret.

9. **Configure Apple private email relay if email is sent.**

   This step is conditional. Complete it if Firebase or the backend sends email to users who may select Hide My Email.

   Register the actual Firebase or custom sender in Apple's private email relay configuration. A default Firebase sender commonly has this form:

   ```text
   noreply@YOUR_FIREBASE_PROJECT_ID.firebaseapp.com
   ```

   Register any custom sender domain, validate SPF and DKIM, and test delivery to `privaterelay.appleid.com` addresses. If the product never sends email, record that decision rather than claiming relay delivery was tested.

10. **Enable Google in Firebase Authentication.**

    Open Firebase Console > Authentication > Sign-in method > Google. Enable the provider, select the correct public support email, and save.

    Download a fresh production `GoogleService-Info.plist` after Google is enabled. Confirm it contains the production values for:

    ```text
    CLIENT_ID
    REVERSED_CLIENT_ID
    API_KEY
    GOOGLE_APP_ID
    PROJECT_ID
    BUNDLE_ID
    ```

    The iOS OAuth client is a public client and has no client secret. A Google web-client secret, if present for Firebase or a server flow, must never enter the app.

11. **Publish the Google OAuth application.**

    Open [Google Auth Platform](https://console.cloud.google.com/auth/overview) in the Google Cloud project associated with the production Firebase project.

    | Area | Required state |
    |---|---|
    | Branding | Correct app name, logo, support email, homepage, privacy policy, terms, owned domains, and developer contacts |
    | Audience | `External` for a public consumer app |
    | Publishing status | `In production`, not `Testing` |
    | Data Access | Only `openid`, `email`, and `profile` unless additional access is explicitly required |
    | Clients | The iOS client uses bundle ID `io.micmac.notmeyet` |

    Basic identity scopes normally do not require sensitive-scope verification, but complete any brand or verification warnings shown in Google Auth Platform. If the app remains in Testing, ordinary production users may be unable to sign in.

12. **Place the Firebase client configuration in the app.**

    The current app expects the production file at:

    ```text
    notmeyet/GoogleService-Info.plist
    ```

    The path is currently ignored by `.gitignore`. If that repository policy remains, the release CI system must materialize the production file at that exact path before compilation. The file contains public client configuration rather than a server secret, but controlled delivery can prevent accidental project mixing.

    Verify target membership, Copy Bundle Resources behavior, and presence in the final archive. `FirebaseApp.configure()` requires the default filename and the app fails closed when it is absent.

13. **Populate the Google build settings from the same plist.**

    The Release build must receive values from that same production plist:

    ```xcconfig
    NMY_GOOGLE_CLIENT_ID = <CLIENT_ID from production GoogleService-Info.plist>
    NMY_GOOGLE_REVERSED_CLIENT_ID = <REVERSED_CLIENT_ID from the same plist>
    ```

    `NMY_GOOGLE_REVERSED_CLIENT_ID` becomes the callback URL scheme through `notmeyet/Info.plist`. Do not combine a client ID from one Firebase project with a plist from another. The current configuration validation requires the callback scheme to be the exact reversal of the configured Google client ID.

14. **Fix the current `.xcconfig` wiring before relying on it.**

    `Configuration/AppConfig.example.xcconfig` suggests creating `Configuration/Secrets.xcconfig`, but the checked Xcode project has no `baseConfigurationReference`. It also defines placeholder `NMY_*` values directly in the target configuration, which take precedence over a base configuration file.

    Merely creating `Secrets.xcconfig` will therefore not activate the values. A future repository implementation should move environment-specific values out of stronger target-level placeholders, assign an appropriate Release `.xcconfig`, and keep local or CI-controlled values out of committed secret material.

    This runbook does not make that Xcode project change. It requires a separate OpenSpec implementation and signed-build verification.

15. **Remember the app's global live-configuration gate.**

    Correct Firebase settings alone will not activate the live app. `AppConfiguration` currently requires all of these values before accepting `.live`:

    | Required Release setting | Checked state |
    |---|---|
    | Google client ID and callback | Placeholder |
    | `GoogleService-Info.plist` | Missing |
    | RevenueCat API key and entitlement | Placeholder or otherwise unverified |
    | Production API URL | Missing or unverified |
    | Terms URL | Missing or unverified |
    | Privacy URL | Missing or unverified |
    | Facial-data disclosure approval | `NO` in the checked configuration |
    | Backend lifecycle contract confirmation | `NO` in the checked configuration |

    Set confirmation flags to `YES` only after the corresponding policy, deployment, and contract have actually been approved and verified. Do not use them to bypass the fail-closed gate for testing.

16. **Use the documented secret-placement rules.**

    | Value | Classification | Correct location or handling |
    |---|---|---|
    | `GoogleService-Info.plist` | Public client configuration | App bundle; optionally CI-controlled to prevent environment mix-ups |
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

    Anything embedded in an iOS application must be considered publicly extractable. Delivering a public client identifier through a CI secret variable can reduce environment mistakes, but it does not make the value secret.

17. **Harden Firebase Authentication.**

    Disable every unused Firebase Auth provider. Review Authentication > Settings > Authorized domains and remove accidental entries such as `localhost`; retain the Firebase handler domain and only intentional custom domains.

    Keep email-enumeration protection enabled, review the account-linking setting deliberately, and verify that the Firebase API key remains restricted to the Firebase-related API allowlist. Do not attach unrelated billable Google APIs to the client key, and do not add application restrictions without checking Firebase compatibility.

    Monitor Identity Toolkit and Secure Token API failures, latency, and quotas. Product telemetry may record sanitized provider and error categories, but it must never log tokens, emails, authorization codes, provider responses, or nonce values.

    App Check can provide additional abuse resistance for supported Firebase resources, but it does not replace authentication, backend authorization, Security Rules, or provider security.

18. **Configure the production backend trust boundary.**

    The app already obtains Firebase ID tokens and sends them to the backend. The production backend must initialize Firebase Admin for the same production project and verify each bearer token with the Admin SDK's `verifyIdToken` operation.

    Trust the UID from the verified Firebase token. Do not trust a UID or email sent separately by the app, and do not treat successful authentication as authorization to every resource.

    Prefer Application Default Credentials, an attached cloud service account, or workload identity. If a service-account JSON key is unavoidable, mount it from a backend secret manager and keep it out of this repository and the iOS build pipeline.

    Verify that production tokens are accepted and that staging-project, expired, malformed, tampered, and revoked tokens are rejected according to the endpoint's security requirements. Provider access tokens should not be sent to the custom API when a Firebase ID token is the defined trust boundary.

19. **Make an explicit provider-linking decision.**

    The current app does not link providers, while the returning-user screen offers both Apple and Google. One person can therefore create separate Firebase UIDs by choosing different providers, especially when Apple Hide My Email is used.

    This affects both the custom backend and RevenueCat because they use the Firebase UID as identity. Decide before production whether Apple and Google remain separate accounts or can be explicitly linked.

    Do not merge accounts solely by matching email addresses. A linking flow must authenticate both credentials and obtain explicit user consent. Apple requires consent before an anonymized Apple identity is associated with directly identifying information from another provider.

    If linking remains outside the MVP, tell users to return with their original provider and define a support recovery process. Test the expected Firebase error behavior rather than leaving users with only a generic failure.

20. **Implement in-app account deletion before release.**

    This is an unresolved production blocker, not a Firebase console setting. The app creates accounts, so App Review Guideline 5.1.1 requires users to initiate account deletion from inside the app.

    The current `AuthenticationClient` supports only current-user lookup, sign-in, and URL handling. A future account-lifecycle change must cover recent provider reauthentication, provider revocation, custom-backend deletion, Firebase Auth deletion, local cleanup, and all other data owners.

    ```text
    Recent provider reauthentication
              |
              v
    Idempotent custom-backend data deletion
              |
              +--> Apple: obtain a fresh authorization code
              |           call Firebase revokeToken(...)
              |
              +--> Google: disconnect and revoke Google access
              |
              v
    Delete Firebase Auth user
              |
              v
    Clear provider session and local state
    ```

    Apple deletion needs `ASAuthorizationAppleIDCredential.authorizationCode` and Firebase `revokeToken(withAuthorizationCode:)`. The checked Apple sign-in implementation uses the identity token and full name but does not consume the authorization code.

    Google deletion should disconnect or revoke the app's Google grant rather than merely signing out locally. Firebase Auth user deletion does not automatically delete custom API records, images, RevenueCat customer data, Firestore documents, Storage objects, or other retained data. Each owner needs an explicit, retry-safe deletion policy.

21. **Review provider button branding and legal presentation.**

    The current authentication screen uses custom Apple and Google buttons. Validate both against the current provider branding rules. Apple's supplied `SignInWithAppleButton(.continue)` is the lowest-risk Apple presentation. The current custom Google action does not display the Google mark and requires branding review.

    Production Terms and Privacy Policy URLs must be live, public, and consistent across the app, Google OAuth branding, Firebase email templates where applicable, and App Store metadata. The privacy documentation must accurately describe Firebase, Apple, Google, backend identity, account linking, and account deletion behavior.

22. **Run a signed production verification matrix.**

    Perform these checks through TestFlight on physical devices. Simulator success alone is not production evidence.

    | Test | Required expectation |
    |---|---|
    | Apple Share My Email | One Firebase user with Apple provider |
    | Apple Hide My Email | Relay address accepted and backend account created |
    | Returning Apple user | Sign-in works when Apple no longer returns name or email |
    | Revoked Apple authorization | Reauthentication recovery works |
    | New Google user | No test-user or unverified-app restriction |
    | Returning Google user | The same Firebase UID is restored |
    | Provider cancellation | No Firebase or backend account mutation |
    | Apple then Google | Behavior matches the explicit linking or separate-account policy |
    | Account deletion | Provider grant and all application data are removed |
    | Sign-in after deletion | Deleted application data is not restored |
    | Backend token validation | Production accepted; staging, expired, malformed, and tampered tokens rejected |
    | Signed archive | Production plist, callback scheme, and Apple entitlement are present |
    | Secret audit | No `.p8`, Admin JSON, OAuth secret, token, or test credential is bundled |

    Inspect Firebase Authentication users and backend records during controlled testing, but do not place retained production credentials or tokens in repository fixtures or logs. Record unavailable external checks as unverified, not passed.

23. **Plan key rotation and incident response.**

    For Apple, create a replacement key, update Firebase with the new Key ID and `.p8`, validate new sign-in and token revocation through TestFlight, monitor failures while the old key remains available for rollback, and only then revoke the old key.

    A native Google iOS OAuth client has no secret to rotate. Do not casually replace Firebase API keys or OAuth client IDs because installed older app versions continue using embedded client configuration.

    Avoid long-lived Firebase Admin keys by using ADC or workload identity. If a server key exists, create and deploy a replacement before disabling the old one. Document owners, emergency contacts, credential locations, rotation procedure, rollback window, and the evidence required to close an incident.

## Conclusion

The native Apple and Google Firebase credential exchanges are largely present, but the app is not production-ready. Release configuration is unwired, external providers are unverified, provider-linking behavior is unresolved, account deletion and provider revocation are absent, and no signed physical-device production evidence exists.

Each repository implementation described as future or unresolved must use a separate OpenSpec change. Update this runbook's current-state or readiness claims only after the corresponding signed production behavior has been verified. Until then, external console actions, credentials, backend behavior, and release checks remain required or unverified.

## Official References

| Subject | Official reference |
|---|---|
| Firebase Apple-platform setup | [Add Firebase to an Apple project](https://firebase.google.com/docs/ios/setup) |
| Firebase Google Sign-In for iOS | [Authenticate using Google](https://firebase.google.com/docs/auth/ios/google-signin) |
| Firebase Sign in with Apple and token revocation | [Authenticate using Apple](https://firebase.google.com/docs/auth/ios/apple) |
| Firebase environment separation | [General development workflow best practices](https://firebase.google.com/docs/projects/dev-workflows/general-best-practices) |
| Firebase API-key handling | [Learn about using and managing API keys](https://firebase.google.com/docs/projects/api-keys) |
| Firebase Admin ID-token verification | [Verify ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens) |
| Apple Services ID and web callback configuration | [Configure Sign in with Apple for the web](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web/) |
| Apple Sign in with Apple key creation | [Create a Sign in with Apple private key](https://developer.apple.com/help/account/capabilities/create-a-sign-in-with-apple-private-key/) |
| Apple private email relay | [Configure private email relay](https://developer.apple.com/help/account/capabilities/configure-private-email-relay-service/) |
| Apple account deletion and token revocation | [TN3194: Handling account deletions and revoking tokens](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple.md) |
| Google OAuth production readiness | [OAuth 2.0 production readiness](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview) |
| Google iOS disconnect | [Disconnecting accounts](https://developers.google.com/identity/sign-in/ios/disconnect) |
| App Review account deletion requirement | [App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#5.1.1) |
