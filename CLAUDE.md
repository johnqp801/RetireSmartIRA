# RetireSmartIRA — Project Instructions for Claude

## Project Memory

This repo maintains persistent memory in `.claude/memory/`.

**At session start:** Read `.claude/memory/README.md` and the most recent file in `.claude/memory/sessions/` BEFORE claiming you lack context on prior work. If the user references a prior LinkedIn draft, screenshot decision, roadmap discussion, release plan, or rejected idea, check `.claude/memory/` first.

**At session end:** Offer to write a session summary to `.claude/memory/sessions/YYYY-MM-DD-<topic>.md` capturing decisions made, drafts produced (full text), open questions, and next steps.

**When user makes a notable decision** (product direction, naming, rejecting an approach, scope change): append to `.claude/memory/decisions/log.md` with date header, the decision, and one-sentence rationale.

**When user approves marketing/release/email copy:** save the final version to the appropriate `.claude/memory/drafts/` subfolder. Don't ask permission first — just do it and tell the user where it went.

## Release Notes & Marketing Copy

- Never frame changes as "Honesty Improvements," "Bug Fixes for Misleading...," or any wording that implies prior dishonesty or undermines user trust. Rejected on v1.7.
- Prefer neutral, forward-looking language: "Accuracy Improvements," "Refinements," "Enhanced Calculations."
- Always offer 2-3 wording options for user-facing release notes before committing to one.

## iOS Release Workflow

- Before stating whether a new build is required for App Store submission, verify by checking: (1) current `CURRENT_PROJECT_VERSION` in `RetireSmartIRA.xcodeproj/project.pbxproj`, (2) whether the prior build has been accepted/uploaded to App Store Connect, (3) whether binary changes exist since the last upload.
- Don't conflate `MARKETING_VERSION` (1.8.1) with `CURRENT_PROJECT_VERSION` (37 etc.).
- After modifying retirement/tax engine code, run the test suite before claiming work is done. Tests are the source of truth — 951+ tests run on this project.

## Code Search Conventions

- Default to scoping searches under `RetireSmartIRA/` and `RetireSmartIRATests/`.
- Never grep `node_modules`, `.build`, `DerivedData`, `.git`, or `Pods/`.

## Platform Target

Native macOS (NOT Catalyst) + iOS/iPadOS. Universal binary. Designed for iOS 18 and macOS 15.

## Worktree Convention

Active development branches use git worktrees at `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/<branch>/`. The main repo at the project root is the canonical home for `.claude/memory/` and `CLAUDE.md` — these should be readable from any worktree once merged.
