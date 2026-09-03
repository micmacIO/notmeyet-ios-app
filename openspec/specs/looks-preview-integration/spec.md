# looks-preview-integration Specification

## Purpose
Defines facial analysis, hairstyle generation, result presentation, and sensitive transport behavior for the onboarding preview.

## Requirements

### Requirement: Facial analysis processing
Accepting a reviewed photo on screen 07 SHALL advance to screen 08 and initiate one cancellable live-or-mock facial-analysis workflow for the current prepared photo.

#### Scenario: Analysis starts
- **WHEN** the user activates `Use this photo` on screen 07
- **THEN** screen 08 presents analysis progress and one analysis request begins for the current photo

#### Scenario: Analysis succeeds
- **WHEN** the current analysis workflow returns a valid annotated image, face shape, and harmony score
- **THEN** the app stores that presentation-ready result in memory and advances to screen 09

#### Scenario: Analysis fails
- **WHEN** analysis returns a transport, server, decoding, or domain error
- **THEN** screen 08 presents safe feedback without exposing raw response or credential details and offers Retry only when the failed stage can be repeated safely

#### Scenario: Safe analysis retry
- **WHEN** the user retries a polling timeout or annotated-image download failure after the remote selfie ID is known
- **THEN** any prior local operation is cancelled and the replacement resumes from the known selfie without uploading another photo or repeating accepted analysis

#### Scenario: Safe pre-upload retry
- **WHEN** token acquisition fails before upload or a request is explicitly rejected without an ambiguous remote outcome
- **THEN** Retry repeats only that safe stage and does not duplicate confirmed upload or accepted analysis work

#### Scenario: Known-selfie polling failure
- **WHEN** a polling request or response decoding fails after the exact selfie ID is known
- **THEN** screen 08 presents recoverable feedback and Retry resumes polling that selfie without repeating upload or analysis triggering

#### Scenario: Stale analysis completion
- **WHEN** a cancelled or superseded analysis completes after the current request identity has changed
- **THEN** its result is ignored and it does not change the current route or result

### Requirement: Live selfie analysis transport
Configured live mode SHALL authenticate with the current Firebase user's ID token, upload one bounded prepared JPEG, trigger analysis for the returned exact selfie ID, and poll the owned selfie until the five analysis blocks are populated or the bounded attempt limit is reached.

#### Scenario: Authenticated selfie upload
- **WHEN** a current Firebase user accepts a prepared JPEG no larger than 10,485,760 bytes and live facial-data gates are approved
- **THEN** the client sends `POST /api/v1/selfies` with `Authorization: Bearer <Firebase ID token>` and a sanitized `selfie.jpg` multipart `file` part

#### Scenario: Missing Firebase user or oversized image
- **WHEN** no Firebase user can supply an ID token or the prepared upload exceeds 10,485,760 bytes
- **THEN** the workflow fails safely before sending selfie bytes

#### Scenario: Ambiguous selfie upload
- **WHEN** selfie upload may have reached the backend but returns no authoritative selfie ID
- **THEN** the workflow presents non-retryable safe feedback and does not repeat the sensitive upload

#### Scenario: Exact selfie correlation
- **WHEN** upload succeeds with a decimal-string selfie ID
- **THEN** the client retains that exact ID, triggers `POST /api/v1/selfies/{id}/analysis`, and does not replace it with a precision-losing numeric acknowledgement

#### Scenario: Ambiguous analysis trigger
- **WHEN** analysis triggering has an ambiguous response after the selfie ID is known
- **THEN** the client does not repeat the trigger and instead polls the known selfie within the normal bounded attempt budget

#### Scenario: Partial analysis response
- **WHEN** a polled `GET /api/v1/selfies/{id}` response has explicit `null` for any of `deepface`, `symmetry`, `shape`, `mesh`, or `ratio`
- **THEN** the workflow remains incomplete and polls again after three seconds

#### Scenario: Omitted analysis block
- **WHEN** a polled selfie response omits any of `deepface`, `symmetry`, `shape`, `mesh`, or `ratio`
- **THEN** the omitted block is treated as incomplete and the workflow polls again after three seconds

#### Scenario: Complete analysis response
- **WHEN** all five analysis blocks are non-null within 40 polling attempts
- **THEN** the client validates a nonempty `shape.primaryShape`, a finite `symmetry.overallScore` in `0...100`, and a valid HTTPS `mesh.imageUrl` before mapping the result

#### Scenario: Analysis polling timeout
- **WHEN** any analysis block remains null after 40 polling attempts
- **THEN** screen 08 presents safe recoverable timeout feedback and a retry can resume polling with a new bounded attempt budget

#### Scenario: Analysis polling cancellation
- **WHEN** the active analysis workflow is cancelled
- **THEN** no later poll or image completion advances the route and no polling continues until an explicit safe retry

#### Scenario: Questionnaire values are absent
- **WHEN** the live client serializes upload, analysis, transformation-search, or generation requests
- **THEN** no primary-goal, pain-point, direction, or other questionnaire field is present

### Requirement: Harmony snapshot presentation
Screen 09 SHALL render the downloaded response-derived annotated mesh image, the display-normalized face shape, the harmony score, `Show me a matching hairstyle`, and `Skip look` without presenting the deferred detailed ratios.

#### Scenario: Render valid harmony result
- **WHEN** screen 09 receives a valid harmony result
- **THEN** it renders the mesh image, `shape.primaryShape` such as `Oval`, and `symmetry.overallScore` with one decimal place as `<score> / 100`

#### Scenario: Harmony-score accessibility value
- **WHEN** assistive technology focuses the overall harmony result
- **THEN** it receives the score as `<score> out of 100` rather than relying on the visual slash notation

#### Scenario: Request a matching style
- **WHEN** the user activates `Show me a matching hairstyle`
- **THEN** the app advances to screen 10 with the prepared photo and available analysis context retained in memory

#### Scenario: Skip generation
- **WHEN** the user activates `Skip look`
- **THEN** the app clears no required access state and advances directly to screen 12

### Requirement: Personalized look processing
Entering screen 10 from the harmony snapshot SHALL search ranked hairstyle transformations for the current remote selfie, select the backend-guaranteed first one-credit result, create one generation item, poll it to completion, and download the generated image before screen 11.

#### Scenario: Generation starts
- **WHEN** the app advances from screen 09 to screen 10
- **THEN** screen 10 presents generation progress and requests `/api/v1/transformations/search` with the current `selfieId` and `categories=HAIRSTYLE`

#### Scenario: First ranked hairstyle
- **WHEN** transformation search returns a nonempty ranked list whose first item has category `HAIRSTYLE`, costs one credit, and contains valid `id`, `displayName`, and static `description`
- **THEN** the client creates one generation using exactly that first transformation ID and does not call `/api/v1/users/me`

#### Scenario: Invalid ranked hairstyle result
- **WHEN** transformation search is empty or its first item violates any required field, category, or one-credit constraint
- **THEN** screen 10 presents safe failure feedback and no generation order is created

#### Scenario: Safe pre-generation retry
- **WHEN** token acquisition, transformation search, local response validation, or an explicitly rejected generation request fails without an ambiguous charged outcome
- **THEN** Retry repeats only that safe stage and does not duplicate a confirmed generation order

#### Scenario: Generation succeeds
- **WHEN** the one-item order and its item matching the selected transformation ID complete with a valid generated image
- **THEN** the app retains the downloaded image bytes, display name, and static description in memory and advances to screen 11

#### Scenario: Generation fails
- **WHEN** generation returns a transport, server, decoding, or domain error
- **THEN** screen 10 presents safe failure feedback and offers Retry only when the failed stage can be repeated safely

#### Scenario: Generation status polling
- **WHEN** the order reports `PENDING`, `SUBMITTING`, `AWAITING_RESULT`, or `PROCESSING`
- **THEN** the client polls again after three seconds, for no more than 40 attempts per invocation

#### Scenario: Reordered generation items
- **WHEN** a polled order returns items in another array order
- **THEN** the client correlates the result by the selected `transformationId` rather than array position

#### Scenario: Safe generation retry
- **WHEN** polling times out or generated-image download fails after a generation ID is known
- **THEN** Retry resumes the known order with a new bounded polling budget or retries only the image download and does not create another charged order

#### Scenario: Known-generation polling failure
- **WHEN** a polling request or response decoding fails after the exact generation ID is known
- **THEN** screen 10 presents recoverable feedback and Retry resumes polling that order without creating another charged order

#### Scenario: Unsafe generation retry
- **WHEN** generation creation has an ambiguous outcome without an order ID or the known order becomes `FAILED` or `PARTIALLY_COMPLETED`
- **THEN** screen 10 presents non-retryable safe feedback and does not create a replacement order while idempotency and refund behavior remain undefined

#### Scenario: Stale generation completion
- **WHEN** an older cancelled generation workflow completes after the current request identity changes
- **THEN** its result is ignored and it does not change the current route or result

### Requirement: Sensitive result-image loading
The Looks workflow SHALL download annotated-mesh and generated-result images without persistent caching and SHALL return only validated presentation-ready bytes to screen state.

#### Scenario: Result image loads
- **WHEN** an HTTPS mesh or generated-result URL returns at most 12 MiB with an `image/*` content type, a final HTTPS redirect target, positive dimensions no greater than 8192 pixels per axis, no more than 40 million decoded pixels, and decodable image content
- **THEN** the bounded bytes remain in memory and the corresponding result becomes available

#### Scenario: Result image fails validation
- **WHEN** a mesh or generated-result URL is invalid, insecure, unavailable, oversized, redirects to a non-HTTPS target, or returns unsupported dimensions, content type, or bytes
- **THEN** the active processing screen presents safe failure feedback and does not expose invalid bytes as a result

#### Scenario: Retry known result image
- **WHEN** the user retries image loading after its remote selfie or generation ID is known
- **THEN** one new ephemeral image request begins without repeating completed backend work or reusing a persistent response cache

#### Scenario: Clear photo-derived bytes
- **WHEN** the flow resets, the photo is retaken, screen 12 or Main is entered, a memory warning occurs, or the process terminates
- **THEN** prepared photo bytes, downloaded mesh/generated bytes, remote correlation, and mapped results are released and are not restored

### Requirement: Before-and-after comparison
Screen 11 SHALL compare the original prepared photo and generated image with a user-adjustable split, SHALL identify Before and After, and SHALL present the response-derived style display name and static description under `About this look`.

#### Scenario: Initial comparison
- **WHEN** both source and generated images are available
- **THEN** the comparison starts at 46 percent, constrains adjustment to the inclusive 12-88 percent range, and performs no network request on screen 11

#### Scenario: Static style copy
- **WHEN** a generated look includes `displayName`, static `description`, and an optional `personalizedReason`
- **THEN** screen 11 presents `displayName` and `description` under `About this look` and ignores `personalizedReason`

#### Scenario: Touch adjustment
- **WHEN** the user drags the comparison handle, taps a point on the comparison, or adjusts the split control beneath it
- **THEN** the visible split updates within the allowed range, continuously while the handle is being dragged

#### Scenario: Scrolling over the comparison
- **WHEN** the user drags vertically across the comparison
- **THEN** the page scrolls and the split does not change

#### Scenario: Assistive adjustment
- **WHEN** VoiceOver, Switch Control, or keyboard input increments or decrements the comparison
- **THEN** the split changes in bounded steps and exposes its current percentage value

#### Scenario: Continue from first result
- **WHEN** the user activates `Try more`
- **THEN** the app advances to screen 12

### Requirement: REST contract isolation
The app SHALL keep Looksmaxxing wire requests, responses, remote IDs, and URLs outside screen state and SHALL NOT contact `api.micmac.io` in live mode until endpoint configuration, Firebase authentication, image policy, legal URLs, and facial-image retention and deletion disclosures are complete and approved for release.

#### Scenario: Complete live contract
- **WHEN** live Looksmaxxing configuration and mappings are complete
- **THEN** the client maps the configured selfie, analysis, transformation-search, generation, and result-image workflow into transport-independent harmony and generated-look values

#### Scenario: Missing live contract
- **WHEN** live mode lacks any required Looksmaxxing contract or configuration value
- **THEN** the app fails closed with configuration-unavailable feedback and sends no placeholder request

#### Scenario: Facial-data disclosures are not approved
- **WHEN** technical endpoint configuration exists but facial-image retention or deletion disclosures are missing or unapproved
- **THEN** live photo upload remains disabled and no Looks request is sent

#### Scenario: Questionnaire mapping is undefined
- **WHEN** the backend contract does not define questionnaire fields
- **THEN** the app SHALL NOT invent or transmit questionnaire values

### Requirement: Deterministic mock processing
Explicit development and test mode SHALL provide deterministic analysis, generation, image-loading, delay, and failure outcomes without contacting production services.

#### Scenario: Mock happy path
- **WHEN** the mock client is configured for success
- **THEN** screens 08 through 11 can complete using bundled fixtures and the supplied sample image

#### Scenario: Mock failure path
- **WHEN** a specific mock failure is selected
- **THEN** only the selected analysis, generation, or image-loading operation fails in a repeatable manner

### Requirement: Sensitive Looks transport
Photo uploads, API calls, and result-image downloads SHALL use ephemeral network behavior and SHALL NOT write request bodies, response bytes, sensitive URLs, remote IDs, or credentials to persistent caches, background transfers, cookies, logs, or test attachments.

#### Scenario: Upload and download session
- **WHEN** a live analysis, generation, or generated-image request runs
- **THEN** it uses non-persistent transfer behavior and retains sensitive bytes only for the current in-memory flow

#### Scenario: Operation cancellation
- **WHEN** an analysis, generation, or image-loading operation is cancelled
- **THEN** transport cancellation propagates, partial bytes are discarded, and no completion advances the route

#### Scenario: Heavy photo processing
- **WHEN** any camera or library image is normalized, stripped of metadata, downsampled, encoded, or decoded
- **THEN** the work completes without blocking main-thread interaction and returns only bounded, metadata-free immutable in-memory data to the UI flow

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
