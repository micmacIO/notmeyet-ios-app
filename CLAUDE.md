# CLAUDE.md

The project's engineering guidelines live in `AGENTS.md`, shared with the other
AI tools configured for this repo. They are imported below — edit `AGENTS.md`,
not this file, for anything that should apply to every tool.

@AGENTS.md

## Claude Code specifics

- Spec-driven work runs through OpenSpec. Use `/opsx:propose`, `/opsx:explore`,
  `/opsx:apply`, `/opsx:update`, `/opsx:sync`, `/opsx:archive`, `/opsx:verify`.
  Specs live in `openspec/specs/`, in-flight changes in `openspec/changes/`.
- Swift/SwiftUI skills in `.claude/skills/` (architecture, navigation, layout,
  animation, testing, API design, simulator) load on demand — prefer them over
  re-deriving conventions.
