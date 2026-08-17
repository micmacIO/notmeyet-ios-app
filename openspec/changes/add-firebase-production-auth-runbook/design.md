## Context

See `proposal.md` for motivation. The conversation produced a detailed, repository-specific production-authentication runbook, while the repository currently has no `docs/` directory and its `README.md` contains only the project title. The checked app contains native Apple and Google Firebase exchanges but intentionally lacks production Firebase configuration, and the existing release-readiness artifact records that absence as a blocker.

This change is pure documentation and skips specification deltas. Its primary implementation risk is incomplete or misleading transcription, not runtime behavior.

## Goals / Non-Goals

**Goals:**

- Produce one durable runbook whose contents can be checked mechanically against the frozen 23-step inventory and supporting tables.
- Clearly distinguish checked repository facts, actions an operator must perform, security boundaries, unresolved product work, and evidence required before release.
- Preserve exact paths, identifiers already present in source, placeholder forms for unknown external values, and official source URLs.
- Keep the document useful to both an engineer preparing the Xcode archive and an operator configuring Firebase, Google Cloud, Apple Developer, and the backend.

**Non-Goals:**

- Configure Firebase, Google Cloud, Apple Developer, App Store Connect, CI, code signing, the backend, or a production environment.
- Add or alter credentials, app code, Xcode build settings, entitlements, tests, OpenAPI contracts, or release-readiness evidence.
- Resolve provider linking, account deletion sequencing, legal copy, production identifiers, or other future implementation decisions.
- Claim that any checklist item has passed merely because its instructions are documented.

## Decisions

### 1. Use one standalone operational document

Create `docs/firebase-production-auth-runbook.md`. The document will not be folded into `README.md`, copied into an existing change's release-readiness record, or left solely in OpenSpec artifacts. A dedicated file remains discoverable after this planning change is archived and avoids presenting a long external-console procedure as repository onboarding.

### 2. Preserve the explored structure instead of rewriting it as a shorter checklist

The final document will retain the introductory verdict, current-state table, authentication diagram, all 23 numbered headings in their frozen order, secret-placement matrix, signed-production verification matrix, conclusion, and official references. Each heading must contain every coverage item mapped in `explore-brief.md`; equivalent paraphrasing is allowed, omission or consolidation is not.

This is preferred over a concise summary because the user asked to save the whole instruction and because details such as Apple Services ID requirements, `.xcconfig` precedence, and account-deletion revocation are easy to lose in condensation.

### 3. Separate observed state from future operator action

Checked statements will cite repository paths and use present-tense wording such as “the app contains” or “the Release build currently lacks.” External setup will use imperative or conditional wording and placeholders such as `YOUR_FIREBASE_PROJECT_ID`. Unverified external values will never be presented as established facts.

The document will state that `H36U63R3Y7` is the team selected in the project and still requires Apple-portal verification. It will also state that documenting a blocker does not clear it.

### 4. Encode security boundaries through a complete classification table

Every value in the frozen secret inventory will be present with its public, secret, or transient classification and placement rule. No real Firebase project ID, Services ID, private key, service-account document, OAuth secret, token, authorization code, or nonce will be added.

The runbook will explicitly explain that client configuration remains extractable even when delivered through a CI secret mechanism, and that the Apple `.p8` and Firebase Admin credentials never belong in the mobile build pipeline.

### 5. Preserve responsibility and data flow visually

The document will include the frozen flow showing Apple and Google credentials entering Firebase Auth, Firebase ID tokens entering the production API, and the Admin SDK verifying identity. It will separately map `GoogleService-Info.plist`, `CLIENT_ID`, and `REVERSED_CLIENT_ID` to their runtime consumers and show that Apple and backend secrets terminate outside the app.

This avoids conflating provider credentials, Firebase client configuration, and server authorization.

### 6. Treat unresolved application work as release blockers, not setup instructions already fulfilled

Provider linking, in-app account deletion, Apple token revocation, Google disconnect, backend data deletion, provider branding, legal URLs, and signed-device verification will remain explicitly unresolved. The runbook may describe the required outcome and high-level flow but must direct repository implementation into separate OpenSpec changes.

Future implementation may update the runbook's current-state or readiness claims only after the corresponding signed production behavior has been verified; planned or partially configured behavior must remain labeled required or unverified.

### 7. Verify by inventory comparison rather than prose review alone

Implementation verification will compare the final document row-for-row against:

- the 23 required headings and coverage statements;
- the checked repository-fact table;
- all secret-classification rows;
- all signed-production verification rows;
- all official-reference URLs;
- the cross-system and configuration mappings.

Validation will also confirm that only the intended documentation file is added outside the change directory, all links are well-formed HTTPS URLs, no placeholder is presented as a completed production value, and no credential-like private material is introduced.

## Risks / Trade-offs

- **[External console labels drift]** Firebase, Google, or Apple may rename navigation elements while the underlying setup remains valid. → Link authoritative pages, use stable concepts as headings, and date future substantive reviews rather than claiming perpetual currency.
- **[Repository facts drift]** Bundle settings or authentication code may change after publication. → Cite paths, keep claims narrow, and require future auth changes to update the runbook.
- **[Documentation mistaken for readiness evidence]** A reader may infer that described steps have been completed. → Use explicit current, required, conditional, and blocker language; preserve the final warning that console and implementation work remain separate.
- **[Secret leakage during future edits]** Operators may paste real values into examples. → Use named placeholders, preserve the full classification table, and verify the diff for private-key, service-account, token, and credential material.
- **[Large document becomes harder to scan]** Preserving the whole instruction is longer than a minimal checklist. → Keep the numbered sequence, concise paragraphs, tables, and diagrams so operators can navigate without removing required detail.

## Migration Plan

1. Create the `docs/` directory and add the runbook as the only implementation deliverable.
2. Transcribe the frozen content inventory without changing application or operational state.
3. Compare the document against every required heading, table row, flow, and reference.
4. Validate the OpenSpec change and inspect the final diff for scope and secret safety.

Rollback is deletion of the standalone runbook. No runtime, data, credential, or external-service rollback is required.
