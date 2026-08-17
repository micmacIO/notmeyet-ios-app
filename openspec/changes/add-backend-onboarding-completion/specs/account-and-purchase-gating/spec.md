## ADDED Requirements

### Requirement: Separated post-onboarding access handoff
The app SHALL perform no RevenueCat SDK configuration, UID binding, entitlement refresh, or access-update monitoring while the resolved backend account is incomplete, and SHALL begin those operations only in a post-onboarding access handoff for a completed account.

#### Scenario: Incomplete account avoids RevenueCat
- **WHEN** current-user resolution returns `onboardingCompleted: false`
- **THEN** the app selects the applicable incomplete onboarding route without configuring RevenueCat, binding a UID, refreshing entitlement, or starting access monitoring

#### Scenario: Completed account evaluates access
- **WHEN** current-user resolution or acknowledged completion reports `onboardingCompleted: true`
- **THEN** the handoff lazily initializes RevenueCat, binds the stable Firebase UID, and only then refreshes the configured entitlement

#### Scenario: Completed account has active access
- **WHEN** the ordered handoff returns the configured active entitlement
- **THEN** the app starts access-update monitoring and advances to Main

#### Scenario: Completed account has inactive access
- **WHEN** the ordered handoff returns no configured active entitlement
- **THEN** the app starts access-update monitoring and advances to the non-dismissible screen-12 paywall

#### Scenario: Post-onboarding access evaluation fails
- **WHEN** RevenueCat UID binding or entitlement refresh fails after backend completion is known
- **THEN** the app remains outside Main on the non-dismissible post-onboarding access view and offers a retry that repeats only UID binding and entitlement evaluation against the retained once-configured service

#### Scenario: Lazy RevenueCat configuration
- **WHEN** the first post-onboarding purchase operation begins after configuration inputs were validated during dependency construction
- **THEN** the main-actor purchase proxy configures RevenueCat nonthrowingly exactly once, strongly retains its delegate service, and never repeats process-global configuration

## MODIFIED Requirements

### Requirement: Explicit service execution mode
The app SHALL select service dependencies through an explicit build-safe mode and SHALL prevent placeholder or mock service behavior from authorizing production access.

#### Scenario: Explicit Debug mock mode
- **WHEN** a Debug build, preview, or Debug UI test explicitly selects mock mode
- **THEN** the app uses deterministic authentication, backend-user, Looks, and purchase clients and initializes no production service

#### Scenario: Valid live mode
- **WHEN** live mode is selected and every required Firebase, Google, backend-user lifecycle, RevenueCat, legal, and Looks setting and contract is complete and non-placeholder
- **THEN** the app constructs the configured live dependency boundaries, with RevenueCat SDK construction deferred until the post-onboarding access handoff

#### Scenario: Invalid live configuration
- **WHEN** a non-mock build is missing or contains a placeholder required setting or an unconfirmed backend-user lifecycle contract
- **THEN** the app shows configuration-unavailable feedback, contacts no incomplete service, and grants no Main access

#### Scenario: Mock selector supplied to Release
- **WHEN** a Release build receives a mock launch argument, environment value, or placeholder lifecycle or purchase result
- **THEN** the selector cannot construct mock clients, complete onboarding, or activate an entitlement and the app fails closed

### Requirement: New-user authentication screen
Screen 05 SHALL offer `Continue with Apple` and `Continue with Google`, SHALL expose configured Terms of Use and Privacy Policy actions, and SHALL NOT show the HTML's `Already have an account? Sign in` link.

#### Scenario: New-user Apple or Google authentication succeeds
- **WHEN** either provider returns a Firebase user on screen 05
- **THEN** the app resolves that account through PUT before any RevenueCat work and applies the incomplete or completed route below

#### Scenario: New-user authentication resolves an incomplete account
- **WHEN** either provider returns a Firebase user on screen 05 and PUT resolves a created or existing account with `onboardingCompleted: false`
- **THEN** the app advances to screen 06 without performing RevenueCat work

#### Scenario: New-user authentication resolves a completed account
- **WHEN** either provider returns a Firebase user on screen 05 and PUT resolves an existing account with `onboardingCompleted: true`
- **THEN** the app enters the separate post-onboarding access handoff

#### Scenario: New-user resolution is invalid or fails
- **WHEN** Firebase authentication succeeds on screen 05 but current-user resolution fails or returns the invalid `201 Created` plus `onboardingCompleted: true` combination
- **THEN** the app remains on screen 05 with safe recoverable feedback, performs no RevenueCat work, and Retry repeats PUT without repeating provider authentication

#### Scenario: New-user RevenueCat binding fails
- **WHEN** screen-05 resolution confirms a completed account but RevenueCat UID binding fails in the post-onboarding access handoff
- **THEN** the app remains outside Main on the non-dismissible access retry view and Retry repeats only UID binding and entitlement evaluation

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

#### Scenario: Returning authentication creates an incomplete account
- **WHEN** Apple or Google authentication succeeds on screen 13 and PUT returns `201 Created` with `onboardingCompleted: false`
- **THEN** the app remains on screen 13, explains neutrally that the account has not completed onboarding, performs no RevenueCat work, and continues to offer `Start onboarding`

#### Scenario: Start onboarding after account creation
- **WHEN** the user activates `Start onboarding` after the screen-13 created-incomplete result
- **THEN** the app clears transient returning-screen feedback, keeps backend completion false, and returns to screen 01

#### Scenario: Returning authentication resolves an existing incomplete account
- **WHEN** authentication succeeds on screen 13 and PUT returns `200 OK` with `onboardingCompleted: false`
- **THEN** the app advances to screen 06 without performing RevenueCat work

#### Scenario: Returning authentication resolves an existing completed account
- **WHEN** authentication succeeds on screen 13 and PUT returns `200 OK` with `onboardingCompleted: true`
- **THEN** the app enters the separate post-onboarding access handoff

#### Scenario: Returning authentication with active entitlement
- **WHEN** screen-13 resolution confirms a completed account and the ordered access handoff reports the configured entitlement active
- **THEN** the app advances to Main

#### Scenario: Returning authentication without active entitlement
- **WHEN** screen-13 resolution confirms a completed account and the ordered access handoff reports no configured active entitlement
- **THEN** the app advances to screen 12

#### Scenario: Returning identity or entitlement evaluation fails
- **WHEN** screen-13 resolution confirms a completed account but RevenueCat UID binding or entitlement refresh fails
- **THEN** the app shows the non-dismissible post-onboarding access retry state and does not enter Main

#### Scenario: Returning-user resolution is invalid or fails
- **WHEN** Firebase authentication succeeds on screen 13 but current-user resolution fails or returns the invalid `201 Created` plus `onboardingCompleted: true` combination
- **THEN** the app remains on screen 13 with safe recoverable feedback, performs no RevenueCat work, and Retry repeats PUT without repeating provider authentication

#### Scenario: Returning authentication is cancelled or fails
- **WHEN** returning authentication is cancelled or fails
- **THEN** cancellation leaves screen 13 unchanged without an error, while failure leaves it unchanged with recoverable feedback

### Requirement: Authoritative launch access evaluation
At launch, the app SHALL resolve Firebase identity and backend onboarding completion before selecting an onboarding route or beginning the separately owned RevenueCat access handoff.

#### Scenario: Launch without Firebase user
- **WHEN** no Firebase user is present
- **THEN** the app shows screen 01 without contacting the backend-user or RevenueCat clients

#### Scenario: Authenticated launch with incomplete onboarding
- **WHEN** PUT returns `200 OK` or `201 Created` with `onboardingCompleted: false`
- **THEN** the app shows screen 06 without restoring ephemeral content and performs no RevenueCat work

#### Scenario: Authenticated launch with active entitlement
- **WHEN** PUT returns `200 OK` with `onboardingCompleted: true`, the UID is bound, and refreshed customer information reports the configured entitlement active
- **THEN** the app shows Main

#### Scenario: Authenticated completed launch without active entitlement
- **WHEN** PUT returns `200 OK` with `onboardingCompleted: true` and the ordered access handoff reports no configured active entitlement
- **THEN** the app shows screen 12

#### Scenario: Authenticated launch at photo gate
- **WHEN** a legacy local `photo` gate exists and PUT reports `onboardingCompleted: false`
- **THEN** the app ignores the local gate, shows screen 06 from backend state, and performs no RevenueCat work

#### Scenario: Authenticated launch at paywall gate
- **WHEN** a legacy local `paywall` gate exists and PUT reports `onboardingCompleted: false`
- **THEN** the app ignores the local gate, shows screen 06 from backend state, and performs no RevenueCat work

#### Scenario: Authenticated launch at default gate
- **WHEN** a legacy local gate is `start`, missing, corrupt, or unsupported and PUT reports `onboardingCompleted: false`
- **THEN** the app ignores the local gate and shows screen 06 from backend state

#### Scenario: Current-user resolution fails at launch
- **WHEN** backend resolution fails, is malformed, or returns `201 Created` with `onboardingCompleted: true`
- **THEN** the app presents fail-closed retry feedback, performs no RevenueCat work, and does not show Main

#### Scenario: Entitlement evaluation fails
- **WHEN** backend completion is true but RevenueCat UID binding or entitlement refresh fails
- **THEN** the app shows the non-dismissible post-onboarding access retry state and does not show Main

## REMOVED Requirements

### Requirement: Non-authoritative per-user routing gates
**Reason**: Device-local `start`/`photo`/`paywall` checkpoints conflict with the backend Boolean as the sole cross-launch onboarding authority.

**Migration**: Ignore existing local gate values and resolve `onboardingCompleted` from the authenticated backend user; incomplete accounts resume at screen 06 and completed accounts enter the access handoff.
