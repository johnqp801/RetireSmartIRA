# Session: 2026-06-16 — Pincer article synced to V8 submission doc

**Repo touched:** retiresmartira-website (PR #5 merged to main, deployed via Vercel).
Plus the V8 .docx on the Desktop.
**Status:** ✅ Shipped. Live article and the V8 Word doc are now in sync.

---

## TL;DR

Updated the live ACA/IRMAA pincer article (`/articles/aca-irmaa-pincer-2026`) to
match the hand-edited **V8 editorial-submission .docx** (`~/Desktop/aca-irmaa-pincer-submission V8.docx`).
Ported all the V8 prose changes into the TSX page, kept the website-only interactive
bits, fixed two typos V8 introduced, and corrected a live chart-caption color
mismatch. Shipped via feature branch + PR #5 (merged `--merge --delete-branch`,
fast-forward `ed93cb2..660e3ea`). Then applied the same two typo fixes back into
the V8 .docx so doc and site stay aligned.

---

## 1. What changed in the article (page.tsx)

Source of truth was the V8 doc text (extracted by unpacking the .docx and pulling
`<w:t>` runs). Changes ported:

- **Intro** fully rewritten to V8's "early 60s and retired" opener + "hidden cost
  of those decisions" paragraph (replaced the old "Most people approaching Medicare
  think about these two things separately" intro).
- **Section headings:** "The IRMAA clock starts before you turn 65" → "...when
  you're 63, not 65"; "What you can actually do about it" → "What you can do about
  it"; "The window closes faster than you think" → "You need to plan this out now".
- **"If you're 63 in 2026" list** — arrows (→) converted to V8 prose sentences.
- **Longer-horizon RMD paragraph** reframed to V8's "One longer-horizon point,
  separate from the two-year window..." (was "There's also a proactive case").
- **Worked-example rows** relabeled; combined value `$24,000–$45,000+` →
  `Potentially $45,000+`.
- Assorted wording/punctuation aligned to V8: "real cashflow problems," "every
  penny," "reasonable proxy" (was "reliable"), "It is ironic, but," callout title
  "The math can become absurd" (was "The math is worse than it looks"), the 4-item
  lever list, HSA sentence split, SSA-44 comma form, FAQ Q2.

## 2. Two deliberate deviations from a literal V8 copy

1. **Fixed two typos V8 introduced by hand-editing** (then applied the SAME fixes
   back into the .docx so they don't diverge):
   - "you'll looking at roughly" → "you'll be looking at roughly"
   - heading "63 not 65" → "63, not 65" (added comma)
2. **Kept website-only elements** the Word doc can't carry: interactive
   `PincerChart`, internal link to the IRMAA bracket article, source hyperlinks,
   App Store CTA. (V8 has an "About the author" bio at the end instead.)

## 3. Chart-caption color fix (bonus)

The live caption said the subsidized bars are "green while subsidized." The actual
`PincerChart` component renders them **indigo** (`#4F46E5`; legend uses
`bg-indigo-600`, over-cliff bars `#A32D2D` red). V8 said "indigo," so changing it
both matched the doc AND corrected a real mismatch that was live on the site.
Verified by grepping PincerChart fills before editing.

## 4. Ship sequence

- 3 earlier website commits from the 2026-06-16 NJ/cleanup session (`bb26c03` GA
  opt-out, `107a85f` em-dash removal, `ed93cb2` AI-tell) were confirmed **already on
  origin/main** — not stranded.
- Branched `article/pincer-v8-sync` off main, committed (`c53db35`), pushed, opened
  **PR #5**, user merged `gh pr merge 5 --merge --delete-branch`. Fast-forward, clean.
- V8 .docx repacked in place with `pack.py --original` (validation passed, chart
  `image1.png` preserved). Overwrote V8 rather than creating a V9 — corrections to
  V8 itself, keeps naming aligned with the synced site version.

## 5. Verification

- Preview (port 3000): page 200, no console errors, no em dashes, no arrows.
- DOM check confirmed all five H2s, new intro, "real cashflow problems," "indigo
  while subsidized," "The math can become absurd" callout, longer-horizon RMD
  paragraph, "You need to plan this out now," "Potentially $45,000+" row.
- .docx re-unpacked and verified: both fixes present, old typos gone (count 0),
  media intact.

## 6. Open / next

- Optional: verify the production URL after Vercel finishes deploying.
- The pincer article remains the editorial-submission candidate (V8 .docx is the
  artifact). No outlet/placement decided in this session.
- Article #4 topic still unchosen; ConvertKit email-capture setup still the stated
  priority before media outreach (decision-log 2026-06-10).

## Reference
- Prior session: `2026-06-16-nj-feedback-website-cleanup-pincer-submission.md`
- Fact-checked pincer source draft: `drafts/articles/2026-06-10-aca-irmaa-pincer-fact-checked.md`
- PR: https://github.com/johnqp801/retiresmartira-website/pull/5
