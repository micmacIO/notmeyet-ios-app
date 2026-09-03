## ADDED Requirements

### Requirement: Harmony snapshot image geometry
Screen 09 SHALL present the annotated mesh image in a rectangle whose proportions follow that image, so the image spans the available content width, is shown in full, and leaves no empty area beside it.

#### Scenario: Annotated image fills the width
- **WHEN** screen 09 renders a valid harmony result
- **THEN** the annotated image spans the full content width and no empty area appears to the left or right of it

#### Scenario: Annotation markers stay inside the image
- **WHEN** the annotated mesh image is displayed
- **THEN** every part of the returned image is visible, including markers near its edges

### Requirement: Before-and-after comparison geometry
Screen 11 SHALL present the comparison in a single rectangle whose proportions follow the prepared photo, so the whole prepared photo is visible with no part cropped away. Both compared images SHALL occupy that same rectangle at the same size and position, so that the split at a given horizontal position reveals the corresponding region of each image.

#### Scenario: Comparison shows both photos whole
- **WHEN** screen 11 renders a prepared photo and a generated look of the same proportions
- **THEN** both images are shown in full within one rectangle spanning the content width, and neither is cropped

#### Scenario: Split stays aligned across the two images
- **WHEN** the user moves the split to any position in the allowed range
- **THEN** the region revealed on the before side and the region hidden on the after side correspond to the same part of the face

#### Scenario: Generated look of different proportions
- **WHEN** the generated look does not share the prepared photo's proportions
- **THEN** the app shows the generated image in full inside the comparison rectangle rather than cropping it
