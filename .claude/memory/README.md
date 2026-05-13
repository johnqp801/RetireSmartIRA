# Project Memory Index

**Claude: ALWAYS read this file at the start of any session before claiming you have no prior context.**

This directory is the persistent memory for the RetireSmartIRA project. It survives across sessions, worktrees, and machine changes. If the user references prior work — a LinkedIn draft, a screenshot pick, a roadmap decision, a release plan — check here first.

---

## Active context

- **Current release status:** see `roadmap/current.md`
- **Most recent session:** see newest file in `sessions/`
- **Recent decisions:** see `decisions/log.md` (newest entries at top)

## When you need…

| Need | Location |
|---|---|
| Marketing copy / App Store text | `drafts/marketing/` |
| Release notes for any version | `drafts/release-notes/` |
| LinkedIn posts | `drafts/linkedin/` |
| Tester emails (Ron, Tim, Fred) | `drafts/emails/` |
| Product/UX decisions and rationale | `decisions/log.md` |
| Roadmap and scope for upcoming versions | `roadmap/` |
| Session-by-session work history | `sessions/` |

## File naming conventions

- **Sessions:** `sessions/YYYY-MM-DD-<topic>.md`
- **Drafts:** `drafts/<category>/YYYY-MM-DD-<title>.md`
- **Decisions:** appended to `decisions/log.md` with `## YYYY-MM-DD: <Title>` headers, newest at top
- **Roadmap:** `roadmap/current.md` (active), `roadmap/v<N>-plan.md` (per release)

## Maintenance rules

- **Never delete drafts** — archive them. Old marketing copy and emails are evidence of what was tried and rejected.
- **Decisions are append-only** — if a decision is reversed, add a new entry referencing the prior one. Don't edit history.
- **Commit memory to git** alongside code. This file is worthless if it lives only on one laptop.
