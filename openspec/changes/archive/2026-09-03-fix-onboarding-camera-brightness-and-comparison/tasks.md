## 1. Screen 06 — camera fill light

- [x] 1.1 Add a screen lookup helper that resolves the foreground-active `UIWindowScene`'s `screen` (per design.md — *Reach the screen through the active window scene*) and verify the project builds with no deprecation warning for `UIScreen.main`
- [x] 1.2 Raise the screen to maximum brightness when the capture screen appears, recording the previous level
- [x] 1.3 Restore the recorded brightness when the capture screen disappears, so capture and cancellation share one restore site
- [x] 1.4 Verify on a physical device that brightness rises when the camera opens and returns to its prior level after both capturing and cancelling, and that `Choose from library` never changes brightness

## 2. Screen 11 — direct touch on the comparison

- [x] 2.1 Attach `DragGesture(minimumDistance: 0, coordinateSpace:)` to the comparison handle in a named coordinate space, routing through `model.setComparisonSplit`, and verify dragging the handle moves the split continuously
- [x] 2.2 Attach a `SpatialTapGesture` in the same coordinate space to the comparison area so a tap jumps the split to the touched point within the 12–88 percent bounds
- [x] 2.3 Verify a vertical drag over the comparison still scrolls the page, via `OnboardingUITests.testCompletionFailureRetainsFirstResultAndRetrySucceeds`, which swipes up from the comparison to reach the retry button

## 3. Screen 06 — capture surface

- [x] 3.1 Replace `UIImagePickerController` with an in-app `AVCaptureSession` front-camera screen, so the capture surface can be styled
- [x] 3.2 Surround the preview with white and draw the dashed framing oval over it
- [x] 3.3 Leave the preview mirrored and hand back an unmirrored photo, by disabling mirroring on the photo output connection

## 4. Verification

- [x] 4.1 Run the unit test suite and confirm the `OnboardingFlowModelTests` comparison-split tests still pass
- [x] 4.2 Run `OnboardingUITests` and confirm all cases pass, including the `result.slider` adjustment test and the screen-11 navigation tests
- [x] 4.3 Run the full screen 06 → 11 onboarding flow once on a physical device — camera brightness rises and is restored, the capture screen lights and guides framing, the photo is not mirrored, and the comparison responds to the handle drag, a tap, and the slider
