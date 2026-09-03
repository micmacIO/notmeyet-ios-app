## Why

The onboarding photo is captured at 3:4 but displayed inside three hardcoded rectangles whose aspect ratios do not match it, so the app silently crops or letterboxes the user's face. On screen 07 roughly 13% of the photo height is cut, on screen 11 roughly 19% is cut (45pt off the top and 45pt off the bottom of a 380pt frame), and on screen 09 the annotated image is letterboxed into a fixed 260pt height that leaves about 45% of the available width empty. Because SwiftUI's `.scaledToFill()` anchors the crop at the centre, the part removed on screens 07 and 11 includes the top of the hair — the single feature this product exists to show.

## What Changes

- Screen 07, screen 09, and screen 11 SHALL size their image rectangle from the aspect ratio of the image being displayed, so the full image is visible and fills the rectangle with no crop and no letterbox bars.
- Screen 07 drops its fixed review height; the page already scrolls under pinned actions, so a tall photo needs no height cap.
- Screen 09 replaces the fixed 260pt height with a photo-driven rectangle spanning the content width.
- Screen 11 replaces the fixed `353 / 380` comparison rectangle with one derived from the prepared photo, keeping both halves of the comparison in a single shared rectangle so the split line stays meaningful.
- No change to capture, preparation, upload bytes, or the image policy. This is a display-geometry change only.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `ios-onboarding-experience`: the screen 07 photo review requirement gains a rule that the review rectangle shows the whole prepared photo rather than a centre crop.
- `looks-preview-integration`: the harmony snapshot requirement (screen 09) and the before-and-after comparison requirement (screen 11) gain rules that their image rectangles follow the displayed image's aspect ratio.

## Impact

- `notmeyet/Screens/PhotoScreens.swift` — `PhotoReviewScreen` image frame and `reviewImageHeight(in:)`.
- `notmeyet/Screens/LooksScreens.swift` — `HarmonySnapshotScreen` annotated image frame, `BeforeAfterComparison` container aspect ratio and `comparisonImage(_:)`.
- `notmeyetTests/LayoutGeometryTests.swift` — extends the existing `aspectFitRect` coverage with the new rectangle-sizing logic.
- Design reference `Design/notmeyet-ios-flow.html` uses `object-fit: cover` with `object-position: 50% 27%` for the comparison, i.e. a deliberate top-biased crop. This proposal departs from that mock in favour of showing the whole photo; the visual handoff should be updated to match.
- Open risk: the generated look returned by the Looks API may not share the prepared photo's aspect ratio. If it does not, the before/after split is already misaligned today and a shared rectangle will make that visible. Confirmed by the project owner that the generated look shares the prepared photo's proportions, so the shared rectangle fits both images exactly. The API also exposes `FalAiImage.width`/`height` should this ever need re-checking.
