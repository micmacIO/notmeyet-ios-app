## Context

See `proposal.md` — Why. The two fixes touch different files and share nothing, but each has one non-obvious technical choice that is cheaper to settle here than to discover mid-implementation.

Current state:

- `notmeyet/Media/CameraPicker.swift` is a thin `UIViewControllerRepresentable` over `UIImagePickerController`; it has no lifecycle hooks beyond `makeUIViewController`. `PhotoPreparationScreen` presents it in a `fullScreenCover` bound to `showsCamera` and clears that flag in both the capture and cancel callbacks.
- `notmeyet/Screens/LooksScreens.swift` — `BeforeAfterComparison` draws both images inside a `GeometryReader`/`ZStack`, sized by an outer `.aspectRatio(353 / 380, contentMode: .fit)`, and reveals the before image by narrowing its frame and clipping. The split value itself (`OnboardingFlowModel.comparisonSplit`, `setComparisonSplit`) is correct and clamped to 12–88 percent, and the existing UI test at `notmeyetUITests/OnboardingUITests.swift:266` proves the `Slider` moves it. What is missing is any gesture: the handle is drawn with `.allowsHitTesting(false)`, so dragging it scrolls the page instead.

Constraint from the SDK: `UIScreen.main` is deprecated as of iOS 26 (`API_DEPRECATED(..., ios(2.0, 26.0))`), while `UIScreen.brightness` itself is not deprecated and is documented as *"Only supported by main screen."* `UIWindowScene.screen` is not deprecated.

## Goals / Non-Goals

**Goals:**

- Reach the screen's brightness without touching deprecated API, and guarantee restore on every dismissal path by construction rather than by remembering to call it.
- Make the on-image handle do what it looks like it does, without the enclosing `ScrollView` losing vertical scrolling over the comparison.

**Non-Goals:**

- Brightness continuity across app backgrounding, incoming calls, or Low Power Mode. If the process dies while the camera is open the user keeps a bright screen; that is accepted for the MVP.
- Any change to the split's initial value, bounds, step, or the `Slider` control itself.
- Any change to how the comparison images are laid out — see *The image layout was already correct* below.
- Animating the split, adding haptics, or changing the comparison's aspect ratio or corner treatment.

## Decisions

### Brightness lives in the capture screen, not in `PhotoPreparationScreen`

Save-and-set in the capture screen's `onAppear`, restore in its `onDisappear`.

Rationale: binding restore to the screen's own lifecycle means there is exactly one restore site and no dismissal path — capture, cancel, or anything added later — can skip it. Driving it from `PhotoPreparationScreen` around the `showsCamera` state would need the restore repeated in both the `onCapture` and `onCancel` closures.

### The capture screen is ours, not `UIImagePickerController`

The brightness fix shipped first against `UIImagePickerController` and worked, but the picker draws its own black chrome above and below the preview — surface that could be adding light instead of absorbing it — and it owns the framing and the mirroring of the result.

Styling that chrome means `showsCameraControls = false` plus a hand-built `cameraOverlayView`, which then has to guess the picker's undocumented preview geometry to know which regions to paint. That is the same volume of code as owning the session outright, with none of the control.

Decision: a small `AVCaptureSession` front-camera screen — `CameraSession` (session, JPEG photo output, async capture), `CameraPreview` (preview layer), `CameraCaptureView` (white surround, dashed oval, shutter, cancel). The preview keeps AVFoundation's default front-camera mirroring so framing feels like a mirror; the photo output connection sets `automaticallyAdjustsVideoMirroring = false` and `isVideoMirrored = false`, so the saved photo shows the face the way other people see it.

Trade-off taken: the session is configured and started on the main actor rather than a background queue. Marked with a `ponytail:` comment in `CameraSession.start()`; move it off if opening the camera ever feels janky.

### Reach the screen through the active window scene

```
UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .first { $0.activationState == .foregroundActive }?
    .screen
```

Rationale: `UIScreen.main` is the obvious call and is deprecated in iOS 26; the project targets iOS 17+ and builds against the current SDK, so it would warn. `UIWindowScene.screen` is the documented replacement and is not deprecated. The app is single-scene, so the foreground-active scene is unambiguous.

Alternative considered: `view.window?.windowScene?.screen` from inside the picker's view hierarchy. Rejected — the value is needed in `makeUIViewController`, before the controller's view is in a window.

If no active scene is found the code does nothing and records no saved value, so restore also does nothing. That is the correct degenerate behavior and needs no special handling.

### The image layout was already correct

An earlier draft of this design claimed the before image was re-laid out inside its narrowed frame, giving it a different `scaledToFill` scale and horizontal centre than the after image, and proposed replacing the frame-and-clip with a full-size frame plus a leading mask.

That claim was tested and is false. Rendering the same screen under both the frame-and-clip and the mask implementation, at a 0.85 split with the 1200×1800 fixtures, produced the before region with a best-fit horizontal shift of **0 px**, a best-fit scale of **1.00**, and a mean absolute pixel difference of **0.0002**. The mask version is correct by construction — both images receive the same full-size frame — and the existing code renders identically to it, so the existing code is in register too.

Decision: leave the image layout alone. The rewrite fixed nothing user-visible, and an MVP change should not carry a no-op refactor.

### The handle is draggable; the comparison is tappable

Attach `DragGesture(minimumDistance: 0, coordinateSpace: .named(...))` to the handle, and a `SpatialTapGesture` in the same named coordinate space to the comparison `ZStack`, both routing through `model.setComparisonSplit`, which already clamps. The named coordinate space is what makes the handle's drag report positions in the comparison's frame rather than its own 40×40 frame.

Rationale: a `DragGesture` attached to the whole comparison starves the enclosing `ScrollView`. This was measured, not assumed — with a full-area drag, `testCompletionFailureRetainsFirstResultAndRetrySucceeds` fails at `XCTAssertTrue(retry.isHittable)` because every `app.swipeUp()` is swallowed and the retry button never scrolls into view. Isolation runs: layout change alone passes, tap gesture alone passes, full-area drag fails, and it still fails as `.simultaneousGesture` with `minimumDistance: 10` and a horizontal-dominance guard. SwiftUI does not arbitrate this conflict by direction the way an earlier draft of this design assumed.

Scoping the drag to the 40×40 handle keeps the scroll view's pan intact everywhere else, and the handle is the affordance a user actually reaches for. Tap-to-jump on the whole comparison restores coarse adjustment across the full width, and a tap needs no movement so it never competes with the pan.

The Before/After labels keep `.allowsHitTesting(false)` so taps that land on them still reach the comparison's tap gesture.

## Risks / Trade-offs

- **Brightness is not restored if the app is killed while the camera is open** → Accepted for MVP. The write is to a persistent system setting, so the user would keep a bright screen, but the window is narrow (the camera is a short-lived modal) and handling backgrounding is explicitly out of scope.
- **`UIScreen.brightness` is a no-op on the Simulator** → The brightness behavior cannot be verified there at all. A device check is a required task, not optional polish; without it this ships unverified.
- **Dragging anywhere other than the handle does not adjust the split** → Deliberate, and the price of keeping vertical scrolling. Tap-to-jump covers the rest of the comparison area, and the `Slider` beneath remains the precise control.
- **A 40×40 drag target is small** → Acceptable for MVP; it matches the drawn affordance, and once the drag starts it tracks the finger anywhere on screen.
