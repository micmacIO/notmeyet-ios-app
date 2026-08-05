## ADDED Requirements

### Requirement: Facial analysis processing
Accepting a reviewed photo on screen 07 SHALL advance to screen 08 and initiate exactly one facial-analysis operation for the current prepared photo.

#### Scenario: Analysis starts
- **WHEN** the user activates `Use this photo` on screen 07
- **THEN** screen 08 presents analysis progress and one analysis request begins for the current photo

#### Scenario: Analysis succeeds
- **WHEN** the current analysis request returns a valid harmony result
- **THEN** the app stores that result in memory and advances to screen 09

#### Scenario: Analysis fails
- **WHEN** analysis returns a transport, server, decoding, or domain error
- **THEN** screen 08 presents safe failure feedback and a retry action without exposing raw response or credential details

#### Scenario: Analysis retry
- **WHEN** the user retries a failed analysis
- **THEN** any prior operation is cancelled and exactly one replacement request begins for the same current photo

#### Scenario: Stale analysis completion
- **WHEN** a cancelled or superseded analysis completes after the current request identity has changed
- **THEN** its result is ignored and it does not change the current route or result

### Requirement: Harmony snapshot presentation
Screen 09 SHALL render the current photo together with response-derived guide geometry, face-shape title and description, harmony title and description, `Show me a matching hairstyle`, and `Skip look`.

#### Scenario: Render valid harmony result
- **WHEN** screen 09 receives a valid harmony result
- **THEN** all supplied titles, descriptions, and guides are rendered against the displayed photo without substituting hard-coded production values

#### Scenario: Request a matching style
- **WHEN** the user activates `Show me a matching hairstyle`
- **THEN** the app advances to screen 10 with the prepared photo and available analysis context retained in memory

#### Scenario: Skip generation
- **WHEN** the user activates `Skip look`
- **THEN** the app clears no required access state and advances directly to screen 12

### Requirement: Personalized look processing
Entering screen 10 from the harmony snapshot SHALL initiate exactly one look-generation operation for the current prepared photo and available analysis context.

#### Scenario: Generation starts
- **WHEN** the app advances from screen 09 to screen 10
- **THEN** screen 10 presents generation progress and one generation request begins

#### Scenario: Generation succeeds
- **WHEN** the current generation request returns a valid generated-look result
- **THEN** the app retains the result in memory and advances to screen 11

#### Scenario: Generation fails
- **WHEN** generation returns a transport, server, decoding, or domain error
- **THEN** screen 10 presents safe failure feedback and a retry action

#### Scenario: Generation retry or stale completion
- **WHEN** generation is retried or an older generation completes after replacement
- **THEN** the previous operation is cancelled, one replacement begins, and any stale result is ignored

### Requirement: Generated image loading
Screen 11 SHALL load the generated result from its response URL without persistently caching facial-image bytes and SHALL expose loading, success, and recoverable failure states.

#### Scenario: Generated image loads
- **WHEN** the generated HTTPS URL returns a valid supported image
- **THEN** the bytes remain in memory and the before/after comparison becomes available

#### Scenario: Generated image fails to load
- **WHEN** the URL is invalid, insecure, unavailable, oversized, or returns unsupported content
- **THEN** screen 11 presents recoverable failure feedback and does not present invalid bytes as a result

#### Scenario: Retry generated image
- **WHEN** the user retries image loading
- **THEN** one new ephemeral request begins without reusing a persistent response cache

#### Scenario: Clear generated image bytes
- **WHEN** the flow resets, the photo is retaken, a memory warning occurs, or the process terminates
- **THEN** downloaded generated-image bytes are released and are not restored

### Requirement: Before-and-after comparison
Screen 11 SHALL compare the original prepared photo and generated image with a user-adjustable split, SHALL identify Before and After, and SHALL present the response-derived style name and explanation.

#### Scenario: Initial comparison
- **WHEN** both source and generated images are available
- **THEN** the comparison starts at 46 percent and constrains adjustment to the inclusive 12-88 percent range

#### Scenario: Touch adjustment
- **WHEN** the user drags or adjusts the comparison control
- **THEN** the visible split updates continuously within the allowed range

#### Scenario: Assistive adjustment
- **WHEN** VoiceOver, Switch Control, or keyboard input increments or decrements the comparison
- **THEN** the split changes in bounded steps and exposes its current percentage value

#### Scenario: Continue from first result
- **WHEN** the user activates `Try more`
- **THEN** the app advances to screen 12

### Requirement: REST contract isolation
The app SHALL keep Looksmaxxing wire requests and responses outside screen state and SHALL NOT contact `/analysis` or `/selfie` in live mode until the required endpoint, authentication, image policy, DTO configuration, legal URLs, and facial-image retention and deletion disclosures are complete and approved for release.

#### Scenario: Complete live contract
- **WHEN** live Looksmaxxing configuration and mappings are complete
- **THEN** the client maps `/analysis` and `/selfie` results into transport-independent harmony and generated-look values

#### Scenario: Missing live contract
- **WHEN** live mode lacks any required Looksmaxxing contract or configuration value
- **THEN** the app fails closed with configuration-unavailable feedback and sends no placeholder request

#### Scenario: Facial-data disclosures are not approved
- **WHEN** technical endpoint configuration exists but facial-image retention or deletion disclosures are missing or unapproved
- **THEN** live photo upload remains disabled and no `/analysis` or `/selfie` request is sent

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
Photo uploads and generated-image downloads SHALL use ephemeral network behavior and SHALL NOT write request bodies, response bytes, sensitive URLs, or credentials to persistent caches, background transfers, cookies, logs, or test attachments.

#### Scenario: Upload and download session
- **WHEN** a live analysis, generation, or generated-image request runs
- **THEN** it uses non-persistent transfer behavior and retains sensitive bytes only for the current in-memory flow

#### Scenario: Operation cancellation
- **WHEN** an analysis, generation, or image-loading operation is cancelled
- **THEN** transport cancellation propagates, partial bytes are discarded, and no completion advances the route

#### Scenario: Heavy photo processing
- **WHEN** any camera or library image is normalized, stripped of metadata, downsampled, encoded, or decoded
- **THEN** the work completes without blocking main-thread interaction and returns only bounded, metadata-free immutable in-memory data to the UI flow
