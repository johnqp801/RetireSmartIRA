# Git Topology & `main` Reconciliation Plan

**Captured:** 2026-06-04. **Status:** ✅ EXECUTED 2026-06-04 — `main` reconciled. The plan
below is now history; current truth is in "Post-reconciliation state."

---

## ✅ Post-reconciliation state (2026-06-04 — CURRENT)

- **`main` (`c45327f`, on origin) IS the shipped app now** = the `v1.8.5-build50` tree
  (MARKETING_VERSION 1.8.5 / build 49) + latest `.claude/memory/` synced on top. `main` is
  trustworthy again — clone it, branch from it, feed it to reviewers.
- **`feature/multi-year-planning` — DELETED** (was the confusing 1.1/build-14 experiment).
- **`archive/v2.0-planning` (`1f43de2`, local + origin)** — preserves old main's 10 V2.0
  planning-doc commits. Roadmap links resolve here.
- **`backup/feature-myp` (`e004b54`, local only)** — old feature-branch tip with all memory,
  kept as insurance.
- Shipped tag `v1.8.5-build50` (commit `6a6e110`) is unchanged/immutable.
- Undo, if ever needed: `git checkout -B main archive/v2.0-planning && git push --force-with-lease origin main`.

---

## The one-line truth (historical — pre-reconciliation)

**The real App Store app WAS only on the tag `v1.8.5-build50` (`6a6e110`)**, not `main`.
Releases shipped from worktree branches/tags and were never merged back, so the normal
branches were misleading. **This is now fixed — `main` carries the shipped code.**

## What each thing actually is

Everything diverged at `1335329` (2026-05-01, "Ignore .worktrees/ directory").

| Ref | Reports version | Reality |
|---|---|---|
| **tag `v1.8.5-build50`** (`6a6e110`) | **1.8.5 / build 49–50** | ✅ The live App Store code (iOS + macOS). Full test suites. HAS `.claude/memory/` (through ~2026-05-28). Worktree branch: `1.8.5/state-tax-refresh`. |
| **`main`** (`1f43de2`, 2026-05-04) | 1.8.0 / build 32 | Orphaned fork: 10 commits of **V2.0 *planning docs*** only (Plan A/B specs+plans under `docs/superpowers/`). No app release. **No `.claude/memory/` at all.** Local `main` was ahead of `origin/main`. |
| **`feature/multi-year-planning`** (`da8c9f3`) | **1.1 / build 14** | ❌ NOT release work. Ancient multi-year-Roth experiment, missing ~37k lines vs shipped (whole test files/features absent). Its ONLY value: the **newest `.claude/memory/` commits** (2026-06-01 session, roadmap-through-1.8.5). **Unpushed to origin — exists only locally.** |

`main`'s 10 unique commits (vs shipped tag) are all V2.0 spec/plan docs:
Plan B UI design spec, optimizer-correctness specs/plans, multi-year engine plan (Plan A),
multi-year design spec. The roadmap (`roadmap/current.md`) links to these — preserve them.

## Reconciliation plan (when user gives the go-ahead)

1. **Rescue memory first.** The newest `.claude/memory/` lives only on
   `feature/multi-year-planning` and is unpushed. Salvage it before deleting anything.
2. **Make `main` = shipped truth.** Point `main` at the `v1.8.5-build50` tree, then layer the
   rescued memory on top.
3. **Archive `main`'s V2.0 planning docs** to `archive/v2.0-planning` (preserve, don't delete —
   roadmap links to them).
4. **Force-push `main`** to origin (safe — solo dev) and **delete `feature/multi-year-planning`**.

## ⚠️ Safety rules until reconciled

- **Never build/tag/submit from `feature/multi-year-planning`** (1.1/build-14 tree). Release
  ONLY from worktree branches or the shipped tag.
- **Never feed `main` to code reviewers** — it's stale and missing all 1.8.x. Use the shipped
  tag / active worktree (or `RetireSmartIRA-1.8.5-shipped-6a6e110.zip`). See decision log
  2026-06-01.
- Active dev happens on worktrees: `1.9/features-bundle`, `2.0/multi-year-engine`,
  `2.0/plan-b-ui`. Not on `main`.

## How to re-verify (paste-able)

```
git log -1 --format="%h %ci %s" v1.8.5-build50
git log -1 --format="%h %ci %s" main
git merge-base --is-ancestor v1.8.5-build50 main && echo "main HAS shipped" || echo "main MISSING shipped"
git branch --contains da8c9f3   # which branch holds newest memory
```
