# Current Release Roadmap

**Last updated:** 2026-05-13

---

## In review at Apple: V1.8.1 build 37

**Status:** Submitted to App Store Connect, awaiting Apple review.

**Marketing version:** 1.8.1
**Build:** 37
**Platforms:** iOS/iPadOS + Native macOS

**What shipped:**
- 5 correctness bugs (F1-F5) from Ron Park's May 11 feedback
- 6 UX improvements (U1-U6) from Ron's feedback
- 4 test fixes for Phase 1 / Phase 2 changes
- Build bump 36 → 37
- Updated App Store description, screenshots, promotional text
- Email to Ron explaining changes

**Plan reference:** `docs/superpowers/plans/2026-05-12-1.8.1-final-fixes.md`

---

## Next: V1.8.2

**Status:** Scoped, not yet started. Awaits 1.8.1 Apple approval before kickoff.

**Spec:** `docs/superpowers/specs/2026-05-12-1.8.2-incremental-design.md`

**Scope:** 17 BLOCK items across 5 tiers (~19 days effort)
- L1-L4: Analyst critique items
- R1-R4: Ron refinements (post-1.8.1 followups)
- D1-D6: Deferred 1.8.1 items
- H1-H5: Higher-earner segment additions
- C1-C3: Code quality

**4 decision points:** require user input before plan finalization.

---

## After 1.8.2: V2.0 Plan B (Multi-Year Tax Strategy UI)

**Status:** Engine locked on `2.0/multi-year-engine` (951 passing tests). UI work paused while incremental releases ship.

**Spec:** `docs/superpowers/specs/2026-05-04-2.0-plan-b-multi-year-ui-design.md`
**Plan:** `docs/superpowers/plans/2026-05-04-2.0-plan-b-multi-year-ui.md` (12 phases, 53 tasks, 145 steps)

**Branch:** `2.0/plan-b-ui` (branched from `2.0/multi-year-engine`, not main)

**Estimated:** 3-4 weeks per memory file.

---

## Future tracks (parked)

- **V2.1 veteran/federal package:** Military Retirement / Railroad / FERS bundled together (see `~/.claude/projects/-Users-johnurban-Projects-RetireSmartIRA/memory/veteran-federal-income-segment.md`)
- **History Globe (separate project):** scroll-driven 3D Mapbox app, deployed on Vercel
