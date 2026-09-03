## ADDED Requirements

### Requirement: Front-photo capture screen
The screen 06 front-photo capture SHALL be presented by an in-app camera screen rather than the system image picker, so the capture surface can light the subject and guide framing. While that screen is presented, the app SHALL set the device screen to maximum brightness, and SHALL restore the brightness that was in effect before presentation once the screen is dismissed.

#### Scenario: Brightness rises with the camera
- **WHEN** the user activates `Take my front photo`, camera access is authorized, and the capture screen is presented
- **THEN** the app records the current screen brightness and sets the screen to maximum brightness

#### Scenario: Brightness is restored after capture
- **WHEN** the user captures a photo and the capture screen is dismissed
- **THEN** the app restores the screen brightness recorded before the screen was presented

#### Scenario: Brightness is restored after cancellation
- **WHEN** the user cancels the capture screen without capturing
- **THEN** the app restores the screen brightness recorded before the screen was presented

#### Scenario: Library path leaves brightness untouched
- **WHEN** the user acquires a photo through `Choose from library` instead of the camera
- **THEN** the screen brightness is left unchanged

#### Scenario: The capture surround lights the face
- **WHEN** the capture screen is presented
- **THEN** the area surrounding the camera preview is white, so the display adds light to the subject

#### Scenario: Framing guide
- **WHEN** the capture screen is presented
- **THEN** a dashed oval is drawn over the preview, matching the guide shown on the preparation screen, so the user can centre their face

#### Scenario: The captured photo is not mirrored
- **WHEN** the user captures a photo with the front camera
- **THEN** the preview remains mirrored for framing, and the photo handed to preparation is not mirrored
