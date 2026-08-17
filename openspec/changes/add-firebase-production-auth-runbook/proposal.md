## Why

The production Firebase Authentication guidance developed during exploration exists only in conversation, so it is not discoverable or durable for release work. A repository-local runbook is needed to preserve the complete Apple, Google, Firebase, backend, secret-handling, and verification procedure without implying that any production configuration has already been applied.

## What Changes

- Add `docs/firebase-production-auth-runbook.md` containing the complete explored production-readiness instructions for Firebase Sign in with Apple and Google Sign-In.
- Ground the runbook in the repository's checked bundle identifier, entitlement, authentication implementation, placeholder configuration, and recorded release blockers.
- Document exact responsibility boundaries for public client configuration, mobile CI inputs, Apple private keys, Google OAuth configuration, and backend Admin credentials.
- Record the unresolved implementation requirements for provider linking, account deletion and revocation, provider branding, backend data deletion, and signed-release verification.
- Include the production verification matrix, key-rotation guidance, and official Firebase, Google, and Apple references.
- Make no application-code, Xcode-project, credential, external-console, backend, or production-readiness-state changes.

The runbook SHALL preserve this complete numbered structure; the detailed content inventory in `explore-brief.md` is the transcription baseline:

| # | Required heading |
|---:|---|
| 1 | Freeze the production identifiers before creating credentials |
| 2 | Use a dedicated Firebase production project |
| 3 | Secure Firebase and Google Cloud administrative access |
| 4 | Register the iOS app in Firebase |
| 5 | Enable Sign in with Apple for the Apple App ID |
| 6 | Create an Apple Services ID for Firebase |
| 7 | Create the Apple private key |
| 8 | Enable Apple in Firebase Authentication |
| 9 | Configure Apple private email relay if email is sent |
| 10 | Enable Google in Firebase Authentication |
| 11 | Publish the Google OAuth application |
| 12 | Place the Firebase client configuration in the app |
| 13 | Populate the Google build settings from the same plist |
| 14 | Fix the current `.xcconfig` wiring before relying on it |
| 15 | Remember the app's global live-configuration gate |
| 16 | Use the documented secret-placement rules |
| 17 | Harden Firebase Authentication |
| 18 | Configure the production backend trust boundary |
| 19 | Make an explicit provider-linking decision |
| 20 | Implement in-app account deletion before release |
| 21 | Review provider button branding and legal presentation |
| 22 | Run a signed production verification matrix |
| 23 | Plan key rotation and incident response |

The document SHALL state that Firebase has no single production switch; record `io.micmac.notmeyet`, checked team `H36U63R3Y7` subject to portal verification, the existing Apple entitlement and provider exchanges, missing production plist, placeholders, unwired configuration, global live gate, and missing account lifecycle operations; and preserve these mappings:

```text
Apple AuthenticationServices --\
                                +--> Firebase Auth --> Firebase ID token --> production API/Admin verification
Google Sign-In SDK ------------/

GoogleService-Info.plist --> FirebaseApp.configure()
CLIENT_ID -----------------> Google Sign-In configuration
REVERSED_CLIENT_ID --------> app callback URL scheme

Apple .p8 ------------> Firebase provider only
Admin credential/ADC -> backend only
Server secrets -------> never the iOS app, repository, or mobile artifact
```

The runbook SHALL also preserve every row in the exploration brief's secret-classification and verification inventories, Apple anonymized-identity consent constraints, and official references for Firebase setup, both providers, environment separation, API keys, Admin token verification, Apple Services IDs/keys/relay/deletion, Google OAuth readiness/disconnect, and App Review account deletion.

## Capabilities

### New Capabilities

None. This is a documentation-only change and `.openspec.yaml` opts out of specification deltas.

### Modified Capabilities

None. No application requirement or runtime behavior changes.

## Impact

The change adds one standalone Markdown file under `docs/`. It does not affect compiled targets, APIs, package dependencies, build settings, authentication behavior, external services, or deployed environments. Future production-authentication work may use the runbook as an operational baseline but requires separate proposals and verification evidence.
