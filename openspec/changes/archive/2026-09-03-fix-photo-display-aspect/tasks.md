## 1. Screen 07 — photo review

- [x] 1.1 In `PhotoReviewScreen`, replace `.scaledToFill()` plus the fixed height with `.scaledToFit()` on a frame spanning the content width.
- [x] 1.2 Delete the surrounding `GeometryReader` and the now-unused `reviewImageHeight(in:)`.

## 2. Screen 09 — harmony snapshot

- [x] 2.1 In `HarmonySnapshotScreen`, drop `.frame(height: 260)` from the annotated image so the rectangle follows the image's proportions across the content width.

## 3. Screen 11 — before-and-after comparison

- [x] 3.1 Replace the literal `353 / 380` container aspect ratio with one derived from the prepared photo.
- [x] 3.2 Change `comparisonImage(_:)` to fit rather than fill, and give each layer an explicit container-sized frame so narrowing the before layer clips it instead of shrinking it.
- [x] 3.3 Confirm the split still wipes cleanly across the full range and that the handle and tap targets still line up.

## 4. Verification

- [x] 4.1 Build the project and confirm no new warnings.
- [x] 4.2 Run the unit tests, including `LayoutGeometryTests`.
- [x] 4.3 Run SwiftLint if installed and confirm it is clean. (Not installed on this machine; skipped.)
- [x] 4.4 Inspect screens 07, 09 and 11 in the simulator with the mock photo fixture: no crop, no bars, actions reachable.
- [x] 4.5 Capture a real generation response and record whether the generated look shares the prepared photo's proportions; note the answer in the proposal's Impact section. (Confirmed by the project owner: the generated look shares the prepared photo's proportions.)
