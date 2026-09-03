## Context

See proposal.md — Why. Three screens render a 3:4 prepared photo inside rectangles of unrelated proportions and let `.scaledToFill()` centre-crop the difference.

Two facts discovered while investigating shape the approach:

- `OnboardingPage` puts content in a `ScrollView` with the actions pinned by `safeAreaInset(edge: .bottom)` whenever `pinsActions` is true. Screen 07 uses that default, so a taller image simply scrolls and the actions stay on screen. No height cap is needed.
- Capture is already correct. `CameraSession` uses `sessionPreset = .photo` and the preview layer uses `.resizeAspectFill` inside a `3/4` rectangle, so the capture matches what the user framed, and `PhotoProcessor` only downscales the long edge. Nothing upstream of display needs to change.

## Goals / Non-Goals

**Goals:**

- Each of the three rectangles derives its proportions from the image it shows.
- Delete the geometry that existed only to compute the old fixed heights.

**Non-Goals:**

- Changing capture, preparation, upload bytes, or the image policy.
- Touching the screen 06 framing guide, the processing-screen capsule, or the paywall image. Those crop deliberately or decoratively and are out of scope.
- Re-cutting the design mock. The divergence from `object-position: 50% 27%` is recorded in the proposal for the design owner.

## Decisions

**Rectangle follows the image, not the reverse.** Alternative considered: keep the mock's rectangles and move the crop anchor to the top 27% to match `Design/notmeyet-ios-flow.html`. That preserves the visual composition but still discards a fifth of the photo, which is what the user reported. A third alternative — cropping to a canonical aspect during preparation — was rejected because it would change the bytes uploaded to the Looks API, turning a display fix into a contract change.

**Screen 07 loses its `GeometryReader`.** It existed solely to feed `reviewImageHeight(in:)`. With the height derived from the photo, both go away. This also settles the repo guidance against `GeometryReader` where a plain modifier works.

**Screen 09 loses its fixed 260pt height.** `.scaledToFit()` inside the content width already produces a rectangle with the image's proportions.

**Screen 11 keeps its `GeometryReader`** — the split maths needs the container width — but takes its aspect ratio from `before.size` instead of the literal `353 / 380`.

**Both comparison layers are pinned to the container size explicitly.** The before layer is narrowed to the split width and clipped. If the image were left flexible under `.scaledToFit()`, that narrowing would shrink the image instead of clipping it, and the split would smear rather than wipe. Giving each layer `.frame(width: size.width, height: size.height)` before the narrowing frame keeps the wipe behaviour that `.scaledToFill()` provided incidentally, without its crop.

**The generated look is fitted, not filled.** The Looks API does expose `FalAiImage.width`/`height`, but the client does not decode them and does not need to: the decoded `UIImage` carries its own size at render time. If the generated image does not share the prepared photo's proportions it is fitted inside the shared rectangle, so it stays whole and centred rather than being cropped to match.

## Risks / Trade-offs

- **A generated look with proportions different from the input letterboxes inside the comparison rectangle** → The two images then no longer map face regions to identical screen points, but that misalignment exists today and is currently hidden by a crop. Fitting makes it visible instead of silently wrong. A task verifies a real generation response so we know whether this case occurs at all.
- **Screens get taller; a 3:4 photo occupies 471pt of a 353pt-wide content column where screen 11 previously used 380pt** → The page scrolls and the actions are pinned, so nothing becomes unreachable. Visual verification screenshots will differ from the current baselines and need re-approval.
- **Very tall library photos produce a very tall rectangle** → Acceptable for the MVP: the page scrolls, and the alternative is reintroducing the crop this change removes.
