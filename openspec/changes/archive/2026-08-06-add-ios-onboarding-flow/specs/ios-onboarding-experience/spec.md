## ADDED Requirements

### Requirement: Supported onboarding surface
The app SHALL support the onboarding experience on iPhones running iOS 17 or newer, SHALL exclude iPad from the targeted device family, SHALL expose only portrait orientation, and SHALL use the fixed supplied light palette except for the dark cinematic welcome.

#### Scenario: Supported iPhone launch
- **WHEN** the app launches on a supported iPhone in portrait orientation
- **THEN** the onboarding or authorized Main destination fills the available safe area without web-preview phone chrome

#### Scenario: Required phone dimensions
- **WHEN** an onboarding screen is rendered at 360x800, 390x844, or 430x932 points
- **THEN** all required content and actions remain reachable, using the 393x852 design frame as the standard visual reference

#### Scenario: System dark appearance
- **WHEN** the device uses dark appearance
- **THEN** onboarding retains the supplied fixed palette rather than inventing an unsupported dark theme

#### Scenario: Target device family
- **WHEN** the application target is inspected or installed from a compatible distribution
- **THEN** it is offered as an iPhone app and does not declare native iPad support

### Requirement: Cinematic welcome behavior
Screen 01 SHALL show the supplied cinematic asset as a silent looping background while the screen is active, together with `Discover my next look` and `Already have an account? Sign in` actions.

#### Scenario: Welcome loop is active
- **WHEN** screen 01 is visible, the scene is active, and Reduce Motion is off
- **THEN** the optimized local welcome movie plays muted, without controls, and loops continuously behind the welcome content

#### Scenario: Welcome loop leaves the foreground
- **WHEN** screen 01 disappears or the app scene becomes inactive
- **THEN** movie playback pauses and consumes no continuing foreground presentation work

#### Scenario: Reduce Motion welcome
- **WHEN** Reduce Motion is enabled
- **THEN** screen 01 shows a still poster and does not autoplay the movie

#### Scenario: Welcome media packaging
- **WHEN** application resources are built
- **THEN** they include a silent portrait derivative no larger than 1080x1920 and exclude the 2160x3840 source, while the source remains preserved under `Design/`

#### Scenario: Start new-user onboarding
- **WHEN** the user activates `Discover my next look`
- **THEN** the app advances to screen 02

#### Scenario: Start returning-user authentication
- **WHEN** the user activates `Already have an account? Sign in`
- **THEN** the app advances to screen 13

### Requirement: Primary-goal selection
Screen 02 SHALL present exactly the following initially unselected choices and SHALL allow zero or one selection: `Find a haircut that actually suits me`; `Look sharper and more put-together`; `Break out of my current style`; `Feel more confident about my appearance`; `Avoid regretting my next haircut`; `Just see what else could work`.

#### Scenario: Select one primary goal
- **WHEN** the user activates an unselected primary-goal choice
- **THEN** that choice becomes the only selected primary goal

#### Scenario: Clear the primary goal
- **WHEN** the user activates the currently selected primary-goal choice
- **THEN** the selection returns to empty

#### Scenario: Continue without a primary goal
- **WHEN** no primary goal is selected and the user activates `Build my preview`
- **THEN** the app advances to screen 03

#### Scenario: Return from primary goal
- **WHEN** the user activates Back on screen 02
- **THEN** the app returns to screen 01

### Requirement: Pain-point selection
Screen 03 SHALL present exactly the following initially unselected choices and SHALL allow any number from zero through six: `I don't know what suits my face`; `Haircuts look different on me than on the model`; `I can't picture a new style before committing`; `I don't know what to ask my barber for`; `I've regretted a haircut before`; `I keep choosing the same safe style`.

#### Scenario: Toggle pain points independently
- **WHEN** the user activates any pain-point choice
- **THEN** that choice toggles without clearing other selected pain points

#### Scenario: Continue without pain points
- **WHEN** no pain point is selected and the user activates `That sounds like me`
- **THEN** the app advances to screen 04

#### Scenario: Return from pain points
- **WHEN** the user activates Back on screen 03
- **THEN** the app returns to screen 02 with the current in-memory primary-goal selection unchanged

### Requirement: Direction selection
Screen 04 SHALL present exactly these initially unselected choices and SHALL allow zero or one selection: `Subtle` with `A cleaner version of my current look`; `Noticeable` with `Clearly different, but still easy to wear`; `Bold` with `Show me something I wouldn't normally try`.

#### Scenario: Select one direction
- **WHEN** the user activates an unselected direction
- **THEN** that direction becomes the only selected direction

#### Scenario: Clear the direction
- **WHEN** the user activates the currently selected direction
- **THEN** the direction selection returns to empty

#### Scenario: Continue without a direction
- **WHEN** no direction is selected and the user activates `Choose my direction`
- **THEN** the app advances to screen 05

#### Scenario: Return from direction
- **WHEN** the user activates Back on screen 04
- **THEN** the app returns to screen 03 with current in-memory choices unchanged

### Requirement: Onboarding progress and controlled navigation
The app SHALL expose the visual onboarding progress and only the back routes defined for the current step.

#### Scenario: Progress values
- **WHEN** the user views screens 02 through 11
- **THEN** the progress indicator reports 10, 20, 30, 40, 50, 60, 70, 80, 90, and 100 percent respectively

#### Scenario: Screens outside measured progress
- **WHEN** the user views screen 01, screen 12, or screen 13
- **THEN** no measured onboarding progress indicator is shown

#### Scenario: Processing and result routes are controlled
- **WHEN** the user is on screen 06, 08, 09, 10, 11, or 12
- **THEN** the app SHALL NOT expose an interactive back gesture or an unspecified back action

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
- **THEN** the app discards photo-derived in-memory state and advances directly to screen 12

### Requirement: Photo review and retake
Screen 07 SHALL display the acquired photo and provide `Use this photo` and `Retake` actions without claiming that face quality, liveness, or suitability has been technically validated.

#### Scenario: Accept reviewed photo
- **WHEN** the user activates `Use this photo`
- **THEN** the app advances to screen 08 with that prepared photo as the sole analysis input

#### Scenario: Retake reviewed photo
- **WHEN** the user activates `Retake` or Back
- **THEN** the app clears the current photo and derived results and returns to screen 06

### Requirement: Ephemeral onboarding content
The app SHALL keep questionnaire answers, selected photos, harmony results, and generated looks in memory only and SHALL NOT write them to SwiftData, UserDefaults, state restoration, persistent URL caches, or application logs.

#### Scenario: Navigate backward in the same process
- **WHEN** the user moves backward among screens 02 through 04 without terminating the app
- **THEN** current questionnaire selections remain available in memory

#### Scenario: Process terminates after photo acquisition
- **WHEN** the process terminates during screens 07 through 11 and the authenticated user later relaunches without access
- **THEN** no photo or result is restored and the user resumes at screen 06

#### Scenario: Memory warning during a photo-derived step
- **WHEN** the app receives a memory warning during screens 07 through 11
- **THEN** it cancels photo-derived work, clears photo and result bytes, returns to screen 06, and presents recoverable feedback

### Requirement: Accessible onboarding operation
The onboarding SHALL remain operable with Dynamic Type, VoiceOver, Voice Control, Switch Control, Full Keyboard Access, Reduce Motion, Reduce Transparency, and increased contrast.

#### Scenario: Route changes with VoiceOver
- **WHEN** an onboarding route changes while VoiceOver is active
- **THEN** accessibility focus moves to the new screen's primary heading in logical reading order

#### Scenario: Choice semantics
- **WHEN** assistive technology focuses a questionnaire choice
- **THEN** it receives the complete visible label, description where present, button role, and selected state

#### Scenario: Processing status announcement
- **WHEN** an analysis, generation, purchase, restore, or image-loading operation completes or enters an actionable error while VoiceOver is active
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

### Requirement: Main App placeholder
The change SHALL provide an empty Main App skeleton as the authorized onboarding destination and SHALL NOT implement the six Main App feature screens shown in the design handoff.

#### Scenario: Authorized handoff
- **WHEN** the account-and-purchase gate confirms Main access
- **THEN** the onboarding is replaced by the Main App skeleton
