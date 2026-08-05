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

## Code Review & Git

- Always verify the current git branch and pull latest before reviewing or assessing code. Do not assume `main` is current — check `git branch` and `git log` first.
- When reconciling external AI reviews (Perplexity, etc.), cite actual source code and git history before agreeing or rejecting any finding. Do not dismiss a finding without code evidence.

## Accuracy & Verification

- Before stating which features or calculations are live in the app, perform a code audit rather than answering from assumption. Verify against the actual source files and confirm with file/line references.
- Do not give confident answers about implementation status without reading the relevant code first.

## Testing

**Run the suite with `tools/run-tests.sh`. Do not call `xcodebuild` directly.**

```bash
tools/run-tests.sh                              # full suite, about five to six minutes
tools/run-tests.sh GoldenScenarioSingleYearTests # one or more suites by name
tools/run-tests.sh --raw                        # unfiltered xcodebuild output
```

**RUN IT IN THE FOREGROUND.** If your tool has a timeout parameter, set it to 600000 milliseconds. Do NOT background it and do not poll it. Five separate agents lost a full turn each by backgrounding a build after hitting a 120 second default; the wrapper prints about six lines instead of tens of thousands, so there is no reason to.

The wrapper exists because two mistakes kept recurring and a louder instruction never fixed either:

- **Omitting `-project`.** This repo uses git worktrees, so several checkouts of different branches sit side by side. `xcodebuild` with no `-project` picks one by scanning the working directory, and a shell whose cwd resets between calls once silently built a DIFFERENT worktree on a DIFFERENT branch and printed BUILD SUCCEEDED for code nobody had written. The wrapper derives the project from its own location and cannot target another checkout.
- **Backgrounding the run**, as above.

It also refuses to report a false green: a run where zero tests executed exits non-zero and tells you the suite name was probably mistyped. And when the only failing suite is the known `MultiYearPerfTests` wall-clock flake, it re-runs that suite in isolation to CHECK the claim rather than waving it through, then tells you to say so explicitly in any report.

- After any edits to retirement, tax, or calculation engine code, run the full suite and confirm it passes before considering the change complete.
- Tests are the source of truth. The suite is currently about 2,366 tests (1,857 Swift Testing in 293 suites plus 509 XCTest). A change is not done until it is green.

## Code Search Conventions

- Default to scoping searches under `RetireSmartIRA/` and `RetireSmartIRATests/`.
- Never grep `node_modules`, `.build`, `DerivedData`, `.git`, or `Pods/`.

## Platform Target

Native macOS (NOT Catalyst) + iOS/iPadOS. Universal binary. Designed for iOS 18 and macOS 15.

## Worktree Convention

Active development branches use git worktrees at `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/<branch>/`. The main repo at the project root is the canonical home for `.claude/memory/` and `CLAUDE.md` — these should be readable from any worktree once merged.
