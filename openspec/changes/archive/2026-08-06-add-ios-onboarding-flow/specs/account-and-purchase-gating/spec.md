## ADDED Requirements

### Requirement: Explicit service execution mode
The app SHALL select service dependencies through an explicit build-safe mode and SHALL prevent placeholder or mock service behavior from authorizing production access.

#### Scenario: Explicit Debug mock mode
- **WHEN** a Debug build, preview, or Debug UI test explicitly selects mock mode
- **THEN** the app uses deterministic authentication, Looks, and purchase clients and initializes no production service

#### Scenario: Valid live mode
- **WHEN** live mode is selected and every required Firebase, Google, RevenueCat, legal, and Looks setting is complete and non-placeholder
- **THEN** the app constructs the configured live adapters

#### Scenario: Invalid live configuration
- **WHEN** a non-mock build is missing or contains a placeholder required setting
- **THEN** the app shows configuration-unavailable feedback, contacts no incomplete service, and grants no Main access

#### Scenario: Mock selector supplied to Release
- **WHEN** a Release build receives a mock launch argument, environment value, or placeholder purchase result
- **THEN** the selector cannot construct mock clients or activate an entitlement and the app fails closed

### Requirement: New-user authentication screen
Screen 05 SHALL offer `Continue with Apple` and `Continue with Google`, SHALL expose configured Terms of Use and Privacy Policy actions, and SHALL NOT show the HTML's `Already have an account? Sign in` link.

#### Scenario: New-user Apple or Google authentication succeeds
- **WHEN** either provider returns a Firebase user on screen 05 and that UID is successfully bound to RevenueCat
- **THEN** the per-user photo gate is recorded and the app advances to screen 06 even if the account already has an active entitlement

#### Scenario: New-user RevenueCat binding fails
- **WHEN** Firebase authentication succeeds on screen 05 but binding that UID to RevenueCat fails
- **THEN** the app remains on screen 05 with a recoverable binding retry, records no photo gate, and does not advance or grant access

#### Scenario: New-user authentication is cancelled
- **WHEN** the user cancels Apple or Google authentication
- **THEN** the app remains on screen 05 without presenting cancellation as an error

#### Scenario: New-user authentication fails
- **WHEN** the provider or Firebase exchange fails
- **THEN** the app remains on screen 05 and presents safe recoverable feedback

#### Scenario: Return from new-user authentication
- **WHEN** the user activates Back on screen 05
- **THEN** the app returns to screen 04 with current in-memory questionnaire choices unchanged

#### Scenario: Legal URL is not configured
- **WHEN** the user activates a legal action in placeholder mode
- **THEN** the app reports that the content is unavailable in this build instead of opening a fake URL

### Requirement: Returning-user authentication screen
Screen 13 SHALL be reachable only from screen 01 and SHALL offer Apple, Google, Back, and `Start onboarding` actions.

#### Scenario: Return to onboarding start
- **WHEN** the user activates Back or `Start onboarding` on screen 13
- **THEN** the app returns to screen 01

#### Scenario: Returning authentication with active entitlement
- **WHEN** Apple or Google authentication succeeds, the Firebase UID is bound to RevenueCat, and the configured entitlement is active
- **THEN** the app advances directly to the Main App skeleton

#### Scenario: Returning authentication without active entitlement
- **WHEN** authentication succeeds and refreshed customer information does not contain the configured active entitlement
- **THEN** the app records the per-user paywall gate and advances to screen 12

#### Scenario: Returning identity or entitlement evaluation fails
- **WHEN** Firebase authentication succeeds on screen 13 but RevenueCat UID binding or entitlement refresh fails
- **THEN** the app remains on screen 13 with a recoverable retry, records no paywall gate, and does not enter Main

#### Scenario: Returning authentication is cancelled or fails
- **WHEN** returning authentication is cancelled or fails
- **THEN** cancellation leaves screen 13 unchanged without an error, while failure leaves it unchanged with recoverable feedback

### Requirement: Firebase provider security and callback handling
Apple and Google credentials SHALL be exchanged for Firebase identity using their required security and callback mechanisms.

#### Scenario: Apple credential exchange
- **WHEN** Sign in with Apple begins
- **THEN** the app uses a fresh cryptographic nonce and verifies the corresponding value during Firebase credential exchange

#### Scenario: Google redirect callback
- **WHEN** iOS opens the configured Google OAuth callback URL
- **THEN** the app forwards it to Google Sign-In without treating it as a product deep link

### Requirement: Authoritative launch access evaluation
At launch, the app SHALL evaluate Firebase identity, bind any Firebase UID to RevenueCat, and refresh the configured entitlement in that order before selecting Main or a gated onboarding destination.

#### Scenario: Launch without Firebase user
- **WHEN** no Firebase user is present
- **THEN** the app shows screen 01

#### Scenario: Authenticated launch with active entitlement
- **WHEN** the Firebase UID has been bound and refreshed customer information reports the configured entitlement active
- **THEN** the app shows the Main App skeleton

#### Scenario: Authenticated launch at photo gate
- **WHEN** the entitlement is inactive and the current UID's gate is `photo`
- **THEN** the app shows screen 06 without restoring a photo

#### Scenario: Authenticated launch at paywall gate
- **WHEN** the entitlement is inactive and the current UID's gate is `paywall`
- **THEN** the app shows screen 12

#### Scenario: Authenticated launch at default gate
- **WHEN** the entitlement is inactive and the current UID's gate is `start`, missing, corrupt, or unsupported
- **THEN** the app clears any unsupported value and shows screen 01

#### Scenario: Entitlement evaluation fails
- **WHEN** identity binding or entitlement evaluation cannot produce a trustworthy access result
- **THEN** the app presents retry or configuration-unavailable feedback and does not show Main

### Requirement: Non-authoritative per-user routing gates
The app SHALL persist only a versioned `start`, `photo`, or `paywall` checkpoint per Firebase UID, and that checkpoint SHALL influence resume routing but SHALL NOT grant Main access.

#### Scenario: Record photo gate
- **WHEN** screen-05 authentication succeeds
- **THEN** `photo` is stored for that Firebase UID without questionnaire or facial data

#### Scenario: Record paywall gate
- **WHEN** the user reaches screen 12 from screen 06, 09, 11, or 13
- **THEN** `paywall` is stored for that Firebase UID

#### Scenario: Different Firebase account
- **WHEN** another Firebase UID authenticates on the same installation
- **THEN** the first UID's checkpoint does not control the second UID's route

#### Scenario: Local gate claims completion
- **WHEN** any local value implies completion but the configured RevenueCat entitlement is not active
- **THEN** the app SHALL NOT show Main

### Requirement: Hard production paywall
Screen 12 in configured live mode SHALL embed the remotely configured RevenueCatUI paywall as a non-dismissible root destination with purchase, restore, Terms of Use, and Privacy Policy access.

#### Scenario: Paywall cannot be dismissed
- **WHEN** screen 12 is visible
- **THEN** no close, Back, `Not now`, swipe-dismiss, or other bypass action is available

#### Scenario: Purchase activates entitlement
- **WHEN** a purchase completes and returned or refreshed customer information reports the configured entitlement active
- **THEN** the app advances to the Main App skeleton

#### Scenario: Transaction completes without entitlement
- **WHEN** a transaction callback succeeds but the configured entitlement is not active
- **THEN** the app remains on screen 12 and does not authorize Main

#### Scenario: Purchase is cancelled or fails
- **WHEN** the user cancels purchasing or a purchase fails
- **THEN** the app remains on screen 12, presenting recoverable feedback for failures but not treating cancellation as an error

#### Scenario: Restore activates entitlement
- **WHEN** restore completes and refreshed customer information reports the configured entitlement active
- **THEN** the app advances to the Main App skeleton

#### Scenario: Restore finds no entitlement or fails
- **WHEN** restore finds no active configured entitlement or returns an error
- **THEN** the app remains on screen 12 and presents an appropriate no-access or retry state

#### Scenario: Remote paywall configuration
- **WHEN** the production offering is prepared for release
- **THEN** it exposes restore and valid legal actions and introduces no dismiss path

### Requirement: Mock hard paywall
Explicit Debug mock mode SHALL provide a non-dismissible local screen-12 substitute with Terms of Use and Privacy Policy actions and deterministic purchase and restore outcomes without contacting RevenueCat.

#### Scenario: Simulated entitlement activation
- **WHEN** the mock purchase or restore outcome activates its configured test entitlement
- **THEN** the same access-evaluation path used by live mode advances to Main

#### Scenario: Simulated cancellation or failure
- **WHEN** the selected mock outcome is cancellation, failure, or inactive entitlement
- **THEN** the app remains on the mock hard paywall with the corresponding deterministic state

#### Scenario: Mock paywall legal actions
- **WHEN** the user activates Terms of Use or Privacy Policy on the mock paywall before a valid URL is configured
- **THEN** the app reports that the content is unavailable in this build instead of opening a fake URL

### Requirement: Entitlement-only Main authorization
Only customer information reporting the configured active RevenueCat entitlement, or its explicit Debug mock equivalent, SHALL authorize the Main App skeleton.

#### Scenario: Persisted state cannot bypass access
- **WHEN** local onboarding state, Firebase authentication alone, or a transaction callback exists without the active entitlement
- **THEN** the app does not show Main

#### Scenario: Access is revoked
- **WHEN** a later authoritative access evaluation reports the configured entitlement inactive
- **THEN** the app leaves or does not enter Main and returns to the applicable hard-paywall route
