## ADDED Requirements

### Requirement: Controlled onboarding completion transition
The app SHALL acknowledge backend onboarding completion before leaving screens 06, 09, or 11 for post-onboarding access, and SHALL provide stable, accessible progress and retry states across backend completion and RevenueCat access stages.

#### Scenario: Completion update is in progress
- **WHEN** a completion action begins on screen 06, 09, or 11 and PATCH has not been acknowledged
- **THEN** the initiating screen remains visible, duplicate completion actions are disabled, and an accessible completion-progress status is presented

#### Scenario: Completion update fails
- **WHEN** PATCH fails, is rejected, or is cancelled before acknowledgement
- **THEN** the initiating screen and its required in-memory presentation state remain available, no access handoff begins, and a safe retry repeats only PATCH

#### Scenario: Completion update becomes stale
- **WHEN** an older completion request finishes after its route or request identity is invalidated
- **THEN** that result neither clears current content nor changes the route nor invokes RevenueCat

#### Scenario: Completion is acknowledged
- **WHEN** PATCH returns acknowledged `onboardingCompleted: true`
- **THEN** the app records access-pending state, clears photo-derived content once, and replaces the numbered onboarding screen with the unnumbered non-dismissible post-onboarding access view

#### Scenario: Access handoff fails after completion
- **WHEN** RevenueCat UID binding or entitlement evaluation fails after backend completion was acknowledged
- **THEN** the post-onboarding access view remains visible with safe feedback and a retry that repeats only UID binding and entitlement evaluation without repeating process-global RevenueCat configuration

#### Scenario: Access handoff completes
- **WHEN** the post-onboarding access handoff returns an authoritative entitlement result
- **THEN** active access advances to Main and inactive access advances to screen 12 without repeating backend completion

## MODIFIED Requirements

### Requirement: Photo preparation and acquisition
Screen 06 SHALL explain front-photo guidance, offer `Take my front photo`, `Choose from library`, and `Skip harmony check`, and accept at most one photo for the current onboarding session. Before screen 07, every acquired photo SHALL have its orientation normalized, all source metadata removed, and its pixel and encoding size bounded by the active image policy.

#### Scenario: Take a front photo
- **WHEN** the user activates `Take my front photo`, camera access is authorized, and a camera is available
- **THEN** the system camera opens with the front camera preferred and a captured photo advances the app to screen 07

#### Scenario: Camera permission is undetermined
- **WHEN** the user requests the camera before authorization has been decided
- **THEN** iOS requests camera permission before capture begins

#### Scenario: Camera permission is denied
- **WHEN** camera access is denied or restricted
- **THEN** the app remains on screen 06 and offers an explanation, a Settings action when applicable, and the library alternative

#### Scenario: Camera is unavailable
- **WHEN** the current device environment has no usable camera
- **THEN** the app remains on screen 06 and offers the library alternative

#### Scenario: Camera capture is cancelled
- **WHEN** the user cancels the system camera without capturing
- **THEN** the app remains on screen 06 without creating a photo

#### Scenario: Choose one library photo
- **WHEN** the user activates `Choose from library` and selects one decodable image
- **THEN** the app prepares that image and advances to screen 07

#### Scenario: Prepare an acquired photo
- **WHEN** a camera or library image is accepted
- **THEN** the photo used for display or upload contains no source metadata, has normalized orientation, and does not exceed the active policy's dimensions or encoding limits

#### Scenario: Current image policy
- **WHEN** an image is prepared for mock display or live upload
- **THEN** its long edge is at most 2048 pixels and its JPEG quality is 0.85

#### Scenario: Live upload byte limit
- **WHEN** a prepared image is accepted for live Looks upload
- **THEN** its metadata-free JPEG upload representation is no larger than the configured 10,485,760-byte backend ceiling

#### Scenario: Library selection is cancelled or invalid
- **WHEN** the user cancels the picker or the selected image cannot be decoded
- **THEN** the app remains on screen 06 and, for a decoding failure, provides recoverable feedback

#### Scenario: Skip the harmony path
- **WHEN** the user activates `Skip harmony check`
- **THEN** the app begins the controlled onboarding-completion transition and advances to post-onboarding access only after backend acknowledgement

### Requirement: Ephemeral onboarding content
The app SHALL keep questionnaire answers, selected photos, harmony results, and generated looks in memory only and SHALL NOT write them to SwiftData, UserDefaults, state restoration, persistent URL caches, or application logs.

#### Scenario: Navigate backward in the same process
- **WHEN** the user moves backward among screens 02 through 04 without terminating the app
- **THEN** current questionnaire selections remain available in memory

#### Scenario: Process terminates after photo acquisition
- **WHEN** the process terminates during screens 07 through 11 and backend `onboardingCompleted` remains false
- **THEN** no photo or result is restored and the authenticated user resumes at screen 06

#### Scenario: Process terminates after completion acknowledgement
- **WHEN** backend completion was acknowledged before the process terminated
- **THEN** no photo or result is restored and the next authenticated launch enters post-onboarding access rather than a numbered onboarding screen

#### Scenario: Memory warning during a photo-derived step
- **WHEN** the app receives a memory warning during screens 07 through 11
- **THEN** it cancels photo-derived work, clears photo and result bytes, returns to screen 06, and presents recoverable feedback

### Requirement: Accessible onboarding operation
The onboarding SHALL remain operable with Dynamic Type, VoiceOver, Voice Control, Switch Control, Full Keyboard Access, Reduce Motion, Reduce Transparency, and increased contrast.

#### Scenario: Route changes with VoiceOver
- **WHEN** an onboarding or post-onboarding access route changes while VoiceOver is active
- **THEN** accessibility focus moves to the new screen's primary heading in logical reading order

#### Scenario: Choice semantics
- **WHEN** assistive technology focuses a questionnaire choice
- **THEN** it receives the complete visible label, description where present, button role, and selected state

#### Scenario: Processing status announcement
- **WHEN** account resolution, onboarding completion, access verification, analysis, generation, purchase, restore, or image loading completes or enters an actionable error while VoiceOver is active
- **THEN** the app announces the status once without repeatedly interrupting navigation

#### Scenario: Decorative media semantics
- **WHEN** assistive technology traverses an onboarding screen
- **THEN** decorative movie, guide, and status imagery creates no redundant focus stop, while informative imagery receives concise context

#### Scenario: Accessibility text size
- **WHEN** the user selects an accessibility Dynamic Type size
- **THEN** text can reflow or scroll and no primary action becomes unreachable or obscured by a fixed overlay

#### Scenario: Non-touch operation
- **WHEN** the user navigates with Voice Control, Switch Control, or Full Keyboard Access
- **THEN** every visible action has a unique speakable label, at least a 44x44-point target, visible focus, and a non-gesture activation path

#### Scenario: Transparency and contrast preferences
- **WHEN** Reduce Transparency or increased contrast is enabled
- **THEN** surfaces remain legible and solid as needed, and selections remain distinguishable without color alone
