## MODIFIED Requirements

### Requirement: Before-and-after comparison
Screen 11 SHALL compare the original prepared photo and generated image with a user-adjustable split, SHALL identify Before and After, and SHALL present the response-derived style display name and static description under `About this look`.

#### Scenario: Initial comparison
- **WHEN** both source and generated images are available
- **THEN** the comparison starts at 46 percent, constrains adjustment to the inclusive 12-88 percent range, and performs no network request on screen 11

#### Scenario: Static style copy
- **WHEN** a generated look includes `displayName`, static `description`, and an optional `personalizedReason`
- **THEN** screen 11 presents `displayName` and `description` under `About this look` and ignores `personalizedReason`

#### Scenario: Touch adjustment
- **WHEN** the user drags the comparison handle, taps a point on the comparison, or adjusts the split control beneath it
- **THEN** the visible split updates within the allowed range, continuously while the handle is being dragged

#### Scenario: Scrolling over the comparison
- **WHEN** the user drags vertically across the comparison
- **THEN** the page scrolls and the split does not change

#### Scenario: Assistive adjustment
- **WHEN** VoiceOver, Switch Control, or keyboard input increments or decrements the comparison
- **THEN** the split changes in bounded steps and exposes its current percentage value

#### Scenario: Continue from first result
- **WHEN** the user activates `Try more`
- **THEN** the app advances to screen 12
