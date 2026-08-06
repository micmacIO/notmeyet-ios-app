# Exploration Brief: iOS Onboarding Flow

## Final approach

Build a native SwiftUI onboarding flow for iOS 17+ on portrait-only iPhone layouts. Use the supplied fixed light palette, except for the dark cinematic welcome. Validate the mobile layouts at 360x800, 390x844, and 430x932 points, using the 393x852 HTML frames as the visual reference. The written screen behavior overrides prototype interactions; the HTML remains the visual and copy source. A single observable flow state owns routing and ephemeral onboarding data, while injected authentication, looks, and purchase clients isolate external SDKs and REST transport. Real Firebase Auth, Google Sign-In, RevenueCat, and RevenueCatUI adapters coexist with deterministic mock adapters until configuration and contracts arrive.

| Screen | Inputs and labels | Exit mapping |
|---|---|---|
| 01 Welcome | Looping supplied movie; `Discover my next look`; `Already have an account? Sign in` | Discover -> 02; sign in -> 13 |
| 02 Primary goal | Zero or one, initially empty and clearable: `Find a haircut that actually suits me`; `Look sharper and more put-together`; `Break out of my current style`; `Feel more confident about my appearance`; `Avoid regretting my next haircut`; `Just see what else could work` | `Build my preview` -> 03, including with no selection |
| 03 Pain points | Zero through six, initially empty: `I don't know what suits my face`; `Haircuts look different on me than on the model`; `I can't picture a new style before committing`; `I don't know what to ask my barber for`; `I've regretted a haircut before`; `I keep choosing the same safe style` | `That sounds like me` -> 04, including with no selection |
| 04 Direction | Zero or one, initially empty and clearable: `Subtle` / `A cleaner version of my current look`; `Noticeable` / `Clearly different, but still easy to wear`; `Bold` / `Show me something I wouldn't normally try` | `Choose my direction` -> 05, including with no selection |
| 05 Account | `Continue with Apple`; `Continue with Google`; Terms of Use; Privacy Policy. Omit the HTML's second returning-user link. | Successful Firebase authentication -> 06 |
| 06 Photo preparation | `Take my front photo`; `Choose from library`; `Skip harmony check` | Camera or one selected photo -> 07; cancellation stays on 06; skip -> 12 |
| 07 Photo review | `Use this photo`; `Retake` | Use -> 08; retake/back -> 06 |
| 08 Harmony processing | Automatic `POST /analysis` through the looks client | Success -> 09; failure stays with retry |
| 09 Harmony snapshot | Response-driven image guides, face shape, harmony label, and descriptions; `Show me a matching hairstyle`; `Skip look` | Show -> 10; skip -> 12 |
| 10 Look processing | Automatic `POST /selfie` through the looks client | Success -> 11; failure stays with retry |
| 11 First result | Original and generated image URL in an adjustable before/after comparison; `Try more` | Try more -> 12 |
| 12 Hard paywall | Production RevenueCatUI offering; purchase; restore; legal links. No close, dismiss, or `Not now` action. | Confirmed purchase or restored entitlement -> Main skeleton; failure/cancellation stays on 12 |
| 13 Returning sign-in | `Continue with Apple`; `Continue with Google`; `Start onboarding`/back | Auth -> RevenueCat identity and entitlement check; entitled -> Main skeleton; not entitled -> 12; start/back -> 01 |

Persist only non-sensitive gates needed to avoid losing authentication/paywall/completion routing. Keep questionnaire answers, selected photo, analysis, and generated result in memory. On launch, synchronize Firebase identity to RevenueCat before evaluating access. Main App is an empty skeleton; all six designed Main App screens are outside this change.

## Cross-module data flow

1. Auth view sends provider intent -> authentication client exchanges Apple/Google credentials with Firebase -> returns Firebase UID -> purchase client logs in that UID -> new-user route continues to 06; returning route checks entitlement and selects Main or 12.
2. Camera or PhotosPicker returns one image -> flow model holds normalized image data in memory -> analysis client accepts that image -> live adapter will map the future `/analysis` contract while mock adapter returns deterministic guides and harmony fields -> screen 09 renders the domain result.
3. Screen 09 action -> generation client accepts the in-memory source image and future contract fields -> live adapter will map `/selfie` while mock adapter returns a deterministic generated-image result -> screen 11 compares source and result.
4. Screen 12 embeds a non-dismissible RevenueCatUI paywall in configured production mode -> purchase or restore refreshes customer info -> only the configured active entitlement commits Main access. Placeholder mode uses a hard mock paywall and simulated entitlement without contacting production.

## Rejected alternatives

- iPad and landscape support: rejected because the supplied contract is phone portrait and this change prioritizes fidelity.
- Dark-mode invention: rejected because no dark visual contract exists.
- Mocks without real integration seams, or visible placeholder-configuration failures: rejected; include real SDK adapters plus safe mocks.
- Custom production paywall matching the HTML: rejected in favor of remotely configured RevenueCatUI; the HTML paywall is illustrative only.
- Dismissible paywall, HTML preselected answers, sticky single selections, and a screen-05 route to screen 13: rejected because they contradict the written flow.
- Exact resume with persisted facial data, or unconditional onboarding restart: rejected in favor of persisted gates and ephemeral sensitive content.
- Shipping the 2160x3840, 33.5 MB movie unchanged: rejected; create an optimized silent portrait derivative while preserving the source under `Design/`.

## Known open questions

- Firebase project plist, Google client and URL scheme, Apple capability/team configuration, and production provider setup.
- RevenueCat public SDK key, app user identity policy details, entitlement identifier, offering, products, and remote paywall configuration.
- Looksmaxxing base URL, authentication, `/analysis` and `/selfie` request/response contracts, image encoding limits, overlay coordinate model, and generated-image lifetime.
- Final Terms of Use and Privacy Policy URLs/content, plus production facial-image retention and deletion disclosures.
- Final optimized welcome-video encoding settings and any production-specific app icon/brand assets.
