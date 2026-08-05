## Why

The current project is an untouched Xcode template and does not provide the product's required first-run journey. A production-shaped onboarding vertical slice is needed now so the approved design and routing can be validated while Firebase, RevenueCat, and Looksmaxxing configuration remains safely replaceable.

## What Changes

- Replace the sample SwiftData item interface with a native SwiftUI onboarding experience for screens 01-13. The agreed written flow controls behavior when it conflicts with `Design/notmeyet-ios-flow.html`, which remains the visual and copy source.
- Target iOS 17+ on portrait-only iPhone layouts using the supplied fixed light palette and dark cinematic welcome, with accessible controls and motion behavior. Validate 360x800, 390x844, and 430x932 layouts against the 393x852 design frames.
- Capture optional onboarding goal, pain-point, and direction answers, all initially empty; single answers are clearable and every questionnaire can advance with no selection. Support native camera capture or one Photos library selection and keep sensitive photo/result data ephemeral.
- Add Apple and Google authentication through Firebase-backed adapters, including the separate new-user and returning-user routes.
- Add replaceable Looksmaxxing clients for `/analysis` and `/selfie`, deterministic mock results, processing/error states, response-driven harmony presentation, and an accessible before/after comparison.
- Add Firebase-to-RevenueCat identity synchronization, returning-user entitlement checks, and a non-dismissible RevenueCatUI paywall with purchase and restore handling. The HTML paywall is illustrative; it contributes no close or `Not now` action, and screen 05 contributes no returning-user link.
- Persist only non-sensitive access-routing gates. On launch, synchronize the Firebase UID to RevenueCat before evaluating access; local gates never authorize Main, and only the configured active entitlement routes to an empty Main App skeleton. Keep the six designed Main App screens outside this change.
- Add safe placeholder configuration and mock execution paths so no placeholder secret or incomplete endpoint is contacted.
- Pass the selected image through one observable in-memory flow boundary into mockable analysis and generation clients, then expose transport-independent harmony and generated-look results to the UI.

## Capabilities

### New Capabilities

- `ios-onboarding-experience`: The iPhone onboarding presentation, questionnaire behavior, photo acquisition and review, route transitions, ephemeral data policy, accessibility, and Main App handoff.
- `looks-preview-integration`: Mockable facial analysis and look-generation processing, result rendering, failures and retries, and before/after comparison behavior.
- `account-and-purchase-gating`: Firebase Apple/Google authentication, RevenueCat identity and entitlement synchronization, hard-paywall behavior, purchase/restore handling, and placeholder-mode safety.

### Modified Capabilities

None.

## Impact

- Replaces the generated app entry UI and removes the sample `Item`/SwiftData dependency from the application flow.
- Changes project support to iOS 17+ and portrait iPhone, adds camera usage configuration, and adds onboarding media and image assets. The app ships an optimized silent portrait derivative while preserving the 2160x3840 source under `Design/`.
- Adds Swift Package dependencies for Firebase Authentication, Google Sign-In, RevenueCat Purchases, and RevenueCatUI, plus native AuthenticationServices, PhotosUI, and Apple media frameworks.
- Defers Firebase project configuration, Google client/URL scheme, Apple capability/team setup, RevenueCat SDK key/identity policy/entitlement/offering/products/paywall, Looksmaxxing base URL/auth/contracts/image limits/overlay coordinates/result lifetime, final legal URLs and facial-image disclosures, optimized-video encoding, and production icon/brand assets behind explicit configuration or adapter boundaries.
- Adds unit and UI coverage for state transitions, skips, permission and service failures, entitlement gates, mock happy paths, accessibility identifiers, and relaunch routing.
