## 1. Create The Runbook

- [x] 1.1 Recheck the repository paths and checked values listed in `explore-brief.md`, then create `docs/firebase-production-auth-runbook.md` with the production-mode verdict, current-state table, and authentication/configuration flow diagrams.
- [x] 1.2 Transcribe numbered steps 1-8 with the complete identifier, Firebase project, administrative access, iOS registration, Apple App ID, Services ID, private-key, and Firebase Apple-provider guidance.
- [x] 1.3 Transcribe numbered steps 9-11 with the complete Apple relay, Firebase Google-provider, and Google OAuth publishing guidance.
- [x] 1.4 Transcribe numbered steps 12-15 with the complete plist placement, client-ID mapping, `.xcconfig`, and global live-gate guidance.
- [x] 1.5 Transcribe numbered steps 16-18 with the complete secret matrix, Firebase hardening, and backend trust-boundary guidance.
- [x] 1.6 Transcribe numbered steps 19-21 with the complete provider-linking, account-deletion/revocation, backend-data-deletion, branding, and legal guidance.
- [x] 1.7 Transcribe numbered steps 22-23 with the complete signed-production verification matrix, key-rotation, and incident-response guidance.
- [x] 1.8 Add the conclusion and every official reference URL from `explore-brief.md`, preserving placeholders for unknown production values and explicit blocker language for unverified work.

## 2. Verify Documentation Completeness And Safety

- [x] 2.1 Compare the runbook row-for-row against all 23 required headings and every per-step coverage statement, checked repository fact, secret classification, verification case, official reference, and cross-system/configuration mapping in `explore-brief.md`; correct every omission or unsupported readiness claim.
- [x] 2.2 Verify every external reference is a well-formed authoritative HTTPS URL and that provider-console wording remains clearly distinguishable from checked repository facts.
- [x] 2.3 Inspect the final diff to confirm `docs/firebase-production-auth-runbook.md` is the only implementation file, no app/build/configuration/readiness file changed, and no private key, service-account document, OAuth secret, token, authorization code, nonce, or real unknown production value was introduced.
- [x] 2.4 Confirm the conclusion directs future implementation into a separate OpenSpec change and permits current-state or readiness updates only after signed production behavior is verified; record every unavailable external check as unverified rather than complete.
- [x] 2.5 Run strict OpenSpec validation for `add-firebase-production-auth-runbook`.
