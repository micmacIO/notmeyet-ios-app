## ADDED Requirements

### Requirement: Whole-photo review geometry
Screen 07 SHALL present the prepared photo in a rectangle whose proportions follow the photo, so the entire photo is visible, the rectangle spans the available content width, and no part of the photo is cropped away and no empty area appears beside it. The screen's actions SHALL remain reachable for a photo of any proportions.

#### Scenario: Camera photo is shown whole
- **WHEN** screen 07 displays a photo captured by the in-app camera
- **THEN** the rendered image spans the full content width, shows the photo's full height including the top of the hair and the chin, and leaves no empty area beside the photo

#### Scenario: Library photo of unusual proportions
- **WHEN** screen 07 displays a library photo that is much taller or much wider than a camera photo
- **THEN** the entire photo remains visible and `Use this photo` and `Retake` remain reachable

#### Scenario: No centre crop
- **WHEN** any prepared photo is displayed on screen 07
- **THEN** no region of the photo is removed from view in order to fill the rectangle
