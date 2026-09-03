## Why

Two onboarding defects break the happy path. On screen 06 the front camera opens at whatever screen brightness the device happens to be at, so selfies taken indoors are under-lit and feed a poor image into the harmony and look pipeline. On screen 11 the before/after comparison draws a drag handle that does nothing: it is rendered with hit testing disabled and no drag gesture exists, so dragging it scrolls the page and the comparison reads as broken.

## What Changes

- **Screen 06 — camera fill light and a capture surface we control.** `Take my front photo` now opens an in-app camera screen instead of the system image picker. While it is presented, the app raises screen brightness to maximum so the display acts as a fill light, and restores the user's previous brightness when the screen is dismissed by capture or cancel. Restoration is mandatory, not optional polish: writing screen brightness mutates a persistent system setting. The surround is white so it adds light rather than absorbing it, a dashed oval shows where the face belongs, and the captured photo is handed back unmirrored while the preview stays mirrored for framing.
- **Screen 11 — the comparison responds to direct touch.** The `Touch adjustment` scenario already requires that dragging the comparison control updates the split, but no gesture exists today. Dragging the handle will adjust the split, and a tap anywhere on the comparison will move the split to that point, both within the existing 12-88 percent bounds.

Out of scope for this MVP change: accessibility behavior, camera hardware torch, brightness handling across backgrounding or interruptions, and any change to the split's initial value, bounds, or the `Slider` control itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ios-onboarding-experience`: Gains a new `Front-photo capture screen` requirement covering the screen 06 camera path — an in-app capture screen, maximum brightness while it is presented, prior brightness restored on dismissal, library path untouched, a white surround, a dashed framing oval, and an unmirrored captured photo. No existing requirement changes.
- `looks-preview-integration`: The `Before-and-after comparison` requirement's `Touch adjustment` scenario is sharpened to state which touches adjust the split — dragging the handle, tapping the comparison, or the slider beneath it — and that the page still scrolls over the comparison. That scenario already required drag adjustment and is currently unimplemented; this change satisfies it.

## Impact

- `notmeyet/Media/CameraPicker.swift` is removed, replaced by `CameraSession.swift` (front-camera `AVCaptureSession` and JPEG photo output), `CameraPreview.swift` (preview layer), and `CameraCaptureView.swift` (white surround, framing oval, shutter and cancel). A new `notmeyet/Media/ScreenBrightness.swift` saves and sets brightness when the capture screen appears and restores it when it disappears, reading the screen through the active `UIWindowScene.screen` rather than the iOS 26-deprecated `UIScreen.main`.
- `notmeyet/Screens/LooksScreens.swift` — `BeforeAfterComparison` gains a drag gesture on the handle and a spatial tap gesture on the comparison area. Its image layout is unchanged.
- `notmeyetTests/PhotoAcquisitionFlowTests.swift` — the two cases that drove the removed picker coordinator now exercise the model's capture and cancellation paths directly.
- No API, dependency, persistence, or navigation changes. AVFoundation is a system framework; no new third-party frameworks.
- Verification requires a physical device for the brightness behavior: `UIScreen.brightness` is a no-op on the Simulator. The gesture work is verifiable in the Simulator and by the existing `OnboardingUITests` suite.
