# MetricCard Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land 3 surgical `MetricCard` swaps and 7 documenting comments to clear the actual MetricCard-related technical debt across the views, per the 1.9 Task 3 spec.

**Architecture:** Three independent card swaps in three views (`IncomeSourcesView`, `AccountsView`, `DashboardView`), plus inline `// Intentionally ad-hoc: …` comments on 7 ad-hoc cards across 4 files explaining why MetricCard doesn't fit. No new types, no API changes to MetricCard itself, no test changes. Each swap commits independently for easy revert.

**Tech Stack:** SwiftUI · existing `MetricCard` component (`RetireSmartIRA/Theme/Components/MetricCard.swift`) · existing token system

**Source spec:** `docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md`

---

## Working agreement

- **Branch:** `1.9/metriccard-sweep`, created from main. Independent of PR #1 (snapshot testing Pass 1) — these touch different files.
- **No new dependencies.** Just uses the existing `MetricCard` component.
- **No test changes.** Behavior is unchanged; only card rendering shape changes. Existing 670+ tests must keep passing throughout.
- **No `project.pbxproj` edits.** Project uses Xcode 16's `PBXFileSystemSynchronizedRootGroup`.
- **`xcodebuild` invocations** use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` prefix (this machine's `xcode-select` points to Command Line Tools).
- **Commit cadence:** every task ends with a commit. Each swap is its own commit so any regression can be reverted in isolation.
- **Visual review is the regression net.** Manual smoke check after each swap, in light + dark mode. Snapshot test coverage of these screens lands in Pass 2 — not a Task 3 dependency.

---

## File structure (modified)

```
RetireSmartIRA/
├── IncomeSourcesView.swift                 ← MODIFY: swap 1 card (Phase 1)
├── AccountsView.swift                      ← MODIFY: swap 1 card + 1 comment (Phases 2, 4)
├── DashboardView.swift                     ← MODIFY: swap 1 card (Phase 3)
├── LegacyImpactView.swift                  ← MODIFY: 1 comment (Phase 4)
├── TaxPlanningView.swift                   ← MODIFY: 2 comments (Phase 4)
├── QuarterlyTaxView.swift                  ← MODIFY: 2 comments (Phase 4)
└── SocialSecurityPlannerView.swift         ← MODIFY: 1 comment (Phase 4)
```

No new files. No test files touched. No deletions.

---

## Phase 0 — Setup

### Task 0.1: Create feature branch

**Files:** N/A (git only)

- [ ] **Step 1: Create and switch to feature branch from main**

```bash
git checkout main
git checkout -b 1.9/metriccard-sweep
```

Expected: `Switched to a new branch '1.9/metriccard-sweep'`.

- [ ] **Step 2: Verify clean state**

```bash
git status
```

Expected: working tree should show only the pre-existing `M RetireSmartIRA.xcodeproj/project.pbxproj` and possibly `M RetireSmartIRA/Theme/README.md` (the README change is awaiting PR #1's merge to normalize). No other modifications. **Do NOT stage or commit either pre-existing change** — they're inherited from main's working tree state, not from this work.

If anything else is modified, stop and resolve before proceeding.

---

### Task 0.2: Confirm existing test baseline

**Files:** N/A (verification only)

Establishes the green baseline so we know our changes are responsible for any later failures.

- [ ] **Step 1: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: ~688 (or higher if PR #1 has merged in the meantime).

- [ ] **Step 2: Note the baseline count**

Record the exact number from Step 1. The completion gate: every later xcodebuild test run reports the same count, with 0 failures, since Task 3 doesn't add any tests.

---

## Phase 1 — Swap 1: IncomeSourcesView "Total Annual Income"

### Task 1.1: Replace ad-hoc card with `MetricCard`

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift:21-34`

The current ad-hoc card is at lines 21-34:

```swift
                // Total Income Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Annual Income")
                        .font(.headline)

                    Text(dataManager.totalAnnualIncome(), format: .currency(code: "USD"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.UI.textPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
```

- [ ] **Step 1: Replace with `MetricCard`**

Use the `Edit` tool to replace lines 20-34 (the comment line + the entire card definition) with:

```swift
                // Total Income Card — uses canonical MetricCard
                MetricCard(
                    label: "Total Annual Income",
                    value: dataManager.totalAnnualIncome().formatted(.currency(code: "USD")),
                    category: .informational
                )
```

Notes for the implementer:
- `MetricCard` requires the value as `String`, so `.formatted(.currency(code: "USD"))` converts the `Decimal`/`Double` from `totalAnnualIncome()` to a currency-formatted string at the call site.
- The `MetricCard` provides its own padding, background, corner radius, shadow, and the 4pt brand-teal top stripe — the ad-hoc card chrome is no longer needed.
- The visual will be more compact than the prior ad-hoc card (MetricCard's value font is 18pt bold vs the prior `.largeTitle` ≈ 34pt). This is intended — it matches the canonical pattern.

- [ ] **Step 2: Build to confirm it compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If it fails, the most likely cause is the `dataManager.totalAnnualIncome()` return type — confirm it has a `.formatted(.currency(code:))` extension. If `totalAnnualIncome()` returns `Decimal`, the call works as written. If it returns `Double`, same. If it returns something else, adapt the conversion.

- [ ] **Step 3: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: same count as Task 0.2 baseline. No regressions.

- [ ] **Step 4: Manual visual check**

Build and run the app with the `-DemoProfile` launch arg. Navigate to the Income & Deductions tab. Confirm:
- The "Total Annual Income" card has a 4pt brand-teal top stripe at the top
- Label "TOTAL ANNUAL INCOME" displays in uppercase, small, gray
- The currency value is bold and clearly readable
- Card has rounded corners, white surface (light mode) or dark surface (dark mode), shadow

Switch to dark mode (System Settings → Appearance → Dark) or use the macOS Window menu equivalent. Confirm the card adapts: dark surface, dark-mode brand-teal stripe, white-on-dark text.

If the card looks visually broken or out of place, STOP and report.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/IncomeSourcesView.swift
git commit -m "Swap IncomeSourcesView 'Total Annual Income' to MetricCard"
```

---

## Phase 2 — Swap 2: AccountsView "Total IRA Balance" (3-card split)

### Task 2.1: Replace ad-hoc 3-column card with `HStack` of 3 `MetricCard`s

**Files:**
- Modify: `RetireSmartIRA/AccountsView.swift:18-65`

The current ad-hoc card is at lines 18-65:

```swift
                // Total Balance Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total IRA Balance")
                        .font(.headline)
                    
                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Traditional")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dataManager.totalTraditionalIRABalance, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Roth")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dataManager.totalRothBalance, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.UI.textPrimary)
                        }

                        if dataManager.hasInheritedAccounts {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inherited")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.totalInheritedBalance, format: .currency(code: "USD"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.UI.textSecondary)
                            }
                        }
                    }

                    Text("Roth balances are tax-free but included here for your total portfolio picture and legacy projections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
```

The replacement breaks the single ad-hoc card into:
1. A small section header text "IRA Balances" (preserves the grouping signal that the prior single card provided)
2. An `HStack` of 2 or 3 `MetricCard`s, one per balance type
3. The Roth balance footnote, kept as a caption below the HStack

- [ ] **Step 1: Replace the ad-hoc card with the new structure**

Use the `Edit` tool to replace lines 17-65 (the comment line + the entire card definition + everything up to but not including the closing `}` and the next `// Accounts List` comment) with:

```swift
                // IRA balance summary — split into 3 MetricCards per 1.9 Task 3
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("IRA Balances")
                        .font(.headline)

                    HStack(spacing: Spacing.sm) {
                        MetricCard(
                            label: "Traditional",
                            value: dataManager.totalTraditionalIRABalance.formatted(.currency(code: "USD")),
                            category: .informational
                        )

                        MetricCard(
                            label: "Roth",
                            value: dataManager.totalRothBalance.formatted(.currency(code: "USD")),
                            category: .informational
                        )

                        if dataManager.hasInheritedAccounts {
                            MetricCard(
                                label: "Inherited",
                                value: dataManager.totalInheritedBalance.formatted(.currency(code: "USD")),
                                category: .informational
                            )
                        }
                    }

                    Text("Roth balances are tax-free but included here for your total portfolio picture and legacy projections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
```

Notes for the implementer:
- The outer `VStack` provides the grouping (header + cards + footnote). The card chrome (background, corner radius, shadow) lives on each `MetricCard` individually, not on the outer VStack. This is intentional — each balance is now its own visually distinct card.
- The 3 (or 2) cards in the `HStack` will use equal width by default since `MetricCard` has `.frame(maxWidth: .infinity)` internally via its label/value layout.
- `Spacing.sm` is 12pt; matches the spec's overall spacing system.
- `.formatted(.currency(code: "USD"))` converts the balance to the currency string. Confirm `totalTraditionalIRABalance`, `totalRothBalance`, `totalInheritedBalance` are `Decimal` or `Double` (they should be — they're sum of account balances).

- [ ] **Step 2: Build to confirm it compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. If it fails, check `Spacing.sm` is the correct token (it should be 12pt — defined in `RetireSmartIRA/Theme/Spacing.swift`). If `Spacing` is unavailable, use the literal `12` instead.

- [ ] **Step 3: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: same count as baseline.

- [ ] **Step 4: Manual visual check**

Run with `-DemoProfile`. Navigate to the Accounts tab. Confirm:
- A small "IRA Balances" header text above the cards
- 3 `MetricCard`s in a row (Traditional / Roth / Inherited), each with the brand-teal top stripe and currency values
- All 3 cards same height, equal width
- The Roth footnote below the cards in italicized gray

Test at multiple window widths if practical:
- Standard macOS window (~1280pt) — should fit all 3 cards comfortably
- Narrow window (~600pt) — cards may compress; check that text doesn't truncate awkwardly

If the layout looks broken or unreadable at any width, STOP and report. Possible fallback: change the outer container from `HStack` to `LazyVGrid(columns: [.init(.adaptive(minimum: 180))])` for graceful wrapping.

Test in light + dark mode.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/AccountsView.swift
git commit -m "Swap AccountsView 'Total IRA Balance' to 3 MetricCards in HStack"
```

---

## Phase 3 — Swap 3: DashboardView headerCard

### Task 3.1: Replace headerCard with header text + `MetricCard`s

**Files:**
- Modify: `RetireSmartIRA/DashboardView.swift:131-207`

This is the most complex swap. The current `headerCard` (lines 133-207) shows:
- Year + filing status (top row, header-style text)
- Your age + spouse age (conditional) + RMD status (bottom row, 2-3 metrics)
- A `.sheet` modifier for PDF sharing attached to the card

The replacement keeps the year/filing-status header text outside the cards (since those are header content, not metrics), and replaces the bottom HStack with `MetricCard`s.

- [ ] **Step 1: Replace the headerCard body**

Use the `Edit` tool to replace lines 131-207 (the `// MARK: - Header Card` comment and the entire `headerCard` computed property) with:

```swift
    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header row: year + filing status
            HStack {
                Text("\(String(dataManager.currentYear)) Tax Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                Text(dataManager.filingStatus.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Metrics row: ages + RMD status, each as its own MetricCard
            HStack(spacing: Spacing.sm) {
                MetricCard(
                    label: "Your Age",
                    value: "\(dataManager.currentAge)",
                    category: .informational
                )

                if dataManager.enableSpouse {
                    MetricCard(
                        label: "\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Age",
                        value: "\(dataManager.spouseCurrentAge)",
                        category: .informational
                    )
                }

                if dataManager.isRMDRequired {
                    MetricCard(
                        label: "RMD Status",
                        value: "Required",
                        category: .informational
                    )
                } else {
                    MetricCard(
                        label: "Years Until RMD",
                        value: "\(dataManager.yearsUntilRMD)",
                        category: .informational
                    )
                }
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                let name = dataManager.userName.isEmpty ? "" : "_\(dataManager.userName)"
                ShareSheet(pdfData: pdfData, fileName: "TaxSummary\(name)_\(dataManager.currentYear).pdf")
            }
        }
        #endif
    }
```

Notes for the implementer:
- The outer `VStack` is no longer styled as a card (no background, no corner radius, no shadow) — that styling now lives on each individual `MetricCard`.
- The "Your Age" / spouse age / RMD status metrics each become their own `MetricCard`. All use `.informational` category (brand-teal stripe). RMD "Required" is informational, not amber, per the spec's color contract — it's a fact, not a deadline.
- The `.sheet` modifier is preserved — it's attached to the outer VStack now (was attached to the prior card), which works fine since it just needs to be in the view hierarchy.
- `Spacing.sm` is 12pt. Falls back to literal `12` if needed.
- The "Required" label text (line 175-177 in the original) had a comment about why it's bold-not-red. That comment becomes obsolete with `MetricCard` — the new design's category controls the visual emphasis.

- [ ] **Step 2: Build to confirm it compiles**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: same count as baseline.

- [ ] **Step 4: Manual visual check (mandatory; high-visibility area)**

Run with `-DemoProfile`. The Dashboard is the FIRST screen the user sees, so a layout regression here is high-visibility.

Confirm:
- Header row: "{year} Tax Year" left + filing status right (e.g., "Married Filing Jointly")
- Below the header: 2 or 3 `MetricCard`s in a row depending on demo profile (Pat 64 + Sue 62 → 3 cards: Your Age 64, Sue Age 62, Years Until RMD 9)
- Each card has the brand-teal top stripe, label, and value
- All cards same height
- PDF share button still works (test by tapping it; confirm the sheet opens)

Test at multiple window widths:
- Standard macOS window — 3 cards comfortably side-by-side
- Narrow window (~600pt) — cards may need to wrap or compress; check readability
- iPad portrait if applicable

Test in light + dark mode.

If narrow-width layout is ugly, fall back to `LazyVGrid(columns: [.init(.adaptive(minimum: 200))])` instead of `HStack`. Document the decision in the commit message.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/DashboardView.swift
git commit -m "Swap DashboardView headerCard to MetricCards (year/filing-status header preserved as text)"
```

---

## Phase 4 — Decline-to-swap comments

### Task 4.1: Add documenting comments to 7 ad-hoc cards

**Files:** all in same task since all 7 comments use the same format and target small line ranges.

- Modify: `RetireSmartIRA/AccountsView.swift:140` (above `struct AccountRow: View`)
- Modify: `RetireSmartIRA/LegacyImpactView.swift:154` (above `private var painVsGainHeader`)
- Modify: `RetireSmartIRA/TaxPlanningView.swift:584` (above `private var deductionComparisonCard`)
- Modify: `RetireSmartIRA/TaxPlanningView.swift:2515` (above `private var scenarioSummaryCard`)
- Modify: `RetireSmartIRA/QuarterlyTaxView.swift:174` (above `private var annualTaxSummary`)
- Modify: `RetireSmartIRA/QuarterlyTaxView.swift:601` (above `private var safeHarborCard`)
- Modify: `RetireSmartIRA/SocialSecurityPlannerView.swift:191` (above `private var statusCard`)

Plus, also handle the deferred-candidate comment for the quarterly payment range display:
- Modify: `RetireSmartIRA/QuarterlyTaxView.swift` near line ~226 (find the per-quarter payment / quarterly range subview within `annualTaxSummary`)

The standard format for "decline to swap" comments:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — <reason>.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
```

The format for the deferred-candidate comment (different — flags it as a future opportunity rather than a permanent decline):

```swift
    // Candidate for MetricCard swap — range UX deserves its own treatment first.
    // Revisit after Pass 2 snapshot tests cover this screen.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
```

- [ ] **Step 1: Add comment above `AccountsView.AccountRow`**

In `RetireSmartIRA/AccountsView.swift`, find `struct AccountRow: View {` (line 140). Use `Edit` to add this comment immediately above:

```swift
// Intentionally ad-hoc: MetricCard doesn't fit — list-row context with multiple inline badges
// (owner, beneficiary, account type). MetricCard is for standalone metrics, not list items.
// See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
struct AccountRow: View {
```

- [ ] **Step 2: Add comment above `LegacyImpactView.painVsGainHeader`**

In `RetireSmartIRA/LegacyImpactView.swift`, find `private var painVsGainHeader: some View {` (line 154). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — side-by-side comparison ("Cost Today" vs "Family Gain")
    // with arrow visual. The comparison structure is the whole point; MetricCard is single-value.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var painVsGainHeader: some View {
```

- [ ] **Step 3: Add comment above `TaxPlanningView.deductionComparisonCard`**

In `RetireSmartIRA/TaxPlanningView.swift`, find `private var deductionComparisonCard: some View {` (line 584). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — Standard vs Itemized side-by-side comparison
    // with checkmarks. Comparison structure is the point.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var deductionComparisonCard: some View {
```

- [ ] **Step 4: Add comment above `TaxPlanningView.scenarioSummaryCard`**

In `RetireSmartIRA/TaxPlanningView.swift`, find `private var scenarioSummaryCard: some View {` (line 2515). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — multi-row tax breakdown with conditional sections
    // (deduction status, before/after columns, tax impact). Detailed analysis card, not a metric.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var scenarioSummaryCard: some View {
```

- [ ] **Step 5: Add comment above `QuarterlyTaxView.annualTaxSummary`**

In `RetireSmartIRA/QuarterlyTaxView.swift`, find `private var annualTaxSummary: some View {` (line 174). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — detailed tax line-item breakdown with multiple
    // rows and dividers. A summary table, not a metric card.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var annualTaxSummary: some View {
```

- [ ] **Step 6: Add comment above `QuarterlyTaxView.safeHarborCard`**

In `RetireSmartIRA/QuarterlyTaxView.swift`, find `private var safeHarborCard: some View {` (line 601). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — interactive picker control + detailed
    // explanation table. Control card, not metric card.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var safeHarborCard: some View {
```

- [ ] **Step 7: Add comment above `SocialSecurityPlannerView.statusCard`**

In `RetireSmartIRA/SocialSecurityPlannerView.swift`, find `private var statusCard: some View {` (line 191). Use `Edit` to add:

```swift
    // Intentionally ad-hoc: MetricCard doesn't fit — interactive multi-state benefit-status display
    // with conditional buttons (claim entry, edit benefit). MetricCard is read-only and single-state.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var statusCard: some View {
```

- [ ] **Step 8: Add deferred-candidate comment to `QuarterlyTaxView` quarterly payment**

In `RetireSmartIRA/QuarterlyTaxView.swift`, search for the quarterly payment / range display within `annualTaxSummary` (approximately lines 226-251). Look for text like "Per Quarter Payment" or "Quarterly Range":

```bash
grep -n "Per Quarter Payment\|Quarterly Range\|perQuarterPayment\|quarterlyRange" RetireSmartIRA/QuarterlyTaxView.swift
```

Find the start of the relevant subview block (look for the VStack or HStack that contains the per-quarter or range label + value display). Use `Edit` to add the deferred-candidate comment immediately above:

```swift
            // Candidate for MetricCard swap — range UX deserves its own treatment first.
            // Revisit after Pass 2 snapshot tests cover this screen.
            // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
```

(Indentation may need adjustment based on the surrounding code — match the indentation of the line below where the comment is placed.)

- [ ] **Step 9: Build to confirm compiles**

Comments are inert; compilation should succeed trivially:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  -quiet 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: same count as baseline. Comments don't change behavior.

- [ ] **Step 11: Commit all comments together**

```bash
git add RetireSmartIRA/AccountsView.swift \
        RetireSmartIRA/LegacyImpactView.swift \
        RetireSmartIRA/TaxPlanningView.swift \
        RetireSmartIRA/QuarterlyTaxView.swift \
        RetireSmartIRA/SocialSecurityPlannerView.swift
git commit -m "Document 7 'intentionally ad-hoc' cards + 1 deferred MetricCard candidate"
```

---

## Phase 5 — Final validation

### Task 5.1: Final test suite verification

**Files:** N/A (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project RetireSmartIRA.xcodeproj \
  -scheme RetireSmartIRA \
  -destination 'platform=macOS' \
  2>&1 | grep -cE "passed on 'My Mac"
```

Expected: same count as Task 0.2 baseline (no tests added or removed).

- [ ] **Step 2: Confirm no `project.pbxproj` modifications from this work**

```bash
git diff main..1.9/metriccard-sweep -- RetireSmartIRA.xcodeproj/project.pbxproj
```

Expected: empty diff. If non-empty, something inadvertently touched the pbxproj — investigate before merging.

- [ ] **Step 3: Confirm no test changes**

```bash
git diff main..1.9/metriccard-sweep -- RetireSmartIRATests/
```

Expected: empty diff. Task 3 doesn't add or change tests.

---

### Task 5.2: Manual visual smoke check across all 3 affected screens

**Files:** N/A (verification only)

- [ ] **Step 1: Build and launch with `-DemoProfile`**

Open `RetireSmartIRA.xcodeproj` in Xcode, select the `RetireSmartIRA` scheme, and run with `-DemoProfile` argument set in the scheme's run arguments. The demo profile populates Pat (64) + Sue (62), MFJ California, $200K Roth conversion, etc.

- [ ] **Step 2: Visually verify each affected screen in light mode**

Walk through each of the 3 affected screens:

1. **Dashboard tab** (`DashboardView`):
   - Year header text ("2026 Tax Year") + filing status ("Married Filing Jointly") on the right
   - 3 `MetricCard`s below: "Your Age" 64, "Sue Age" 62, "Years Until RMD" {value}
   - Cards same height, equal width, brand-teal top stripes
   - PDF share button (if visible) still functional

2. **Income & Deductions tab** (`IncomeSourcesView`):
   - "Total Annual Income" `MetricCard` with currency value
   - Below it: existing "Income Sources" list section unchanged

3. **Accounts tab** (`AccountsView`):
   - Small "IRA Balances" header text
   - 3 `MetricCard`s in a row: Traditional / Roth / Inherited (assuming demo profile has inherited accounts; otherwise 2 cards)
   - Below: Roth caption italicized
   - Below that: existing "Accounts" list section unchanged

- [ ] **Step 3: Repeat in dark mode**

Switch macOS to Dark mode (System Settings → Appearance → Dark, or use Window menu equivalent). Repeat Step 2.

For each screen, confirm:
- Card surface shifts from white (#FFFFFF) to dark (#1C1C1E)
- Brand-teal stripes shift to the dark variant (#2A7585)
- Text color shifts to white-ish on dark
- Footnotes/captions remain readable (`.secondary` foreground style adapts)

- [ ] **Step 4: Test multiple window widths**

For the 3 affected screens, resize the macOS window to:
- Standard width (~1280pt)
- Narrow width (~600pt)

If any screen looks visually broken at narrow width (truncated text, overlapping cards, wrapping to incomprehensible layout), STOP and report. Fallback options documented in the swap tasks.

- [ ] **Step 5: Test sheets/dialogs still work**

- Trigger the PDF share button on Dashboard — sheet opens, contains PDF data
- (Other sheets/dialogs in these screens shouldn't be affected since the swap only changed visual rendering)

---

### Task 5.3: PR creation

**Files:** N/A (git only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin 1.9/metriccard-sweep 2>&1 | tail -5
```

Expected: `* [new branch]      1.9/metriccard-sweep -> 1.9/metriccard-sweep`.

- [ ] **Step 2: Create the PR**

```bash
gh pr create --title "1.9 Task 3: MetricCard sweep — 3 swaps + 7 documenting comments" --body "$(cat <<'EOF'
## Summary

Surgical execution of the 1.9 Task 3 MetricCard sweep. A pre-brainstorm audit found the actual technical debt was much narrower than the roadmap framing suggested — the 1.8 "decline-to-swap" judgment calls were largely correct because most "card-shaped" view content is not semantically a metric. This PR clears the small real debt and documents the rest.

**Three `MetricCard` swaps:**
- `IncomeSourcesView` "Total Annual Income" — clean swap to single `MetricCard`
- `AccountsView` "Total IRA Balance" — split into 3 `MetricCard`s (Traditional / Roth / Inherited) in `HStack`
- `DashboardView` headerCard — year/filing-status header text preserved + `MetricCard`s for ages and RMD status

**Seven documenting comments:**
- `AccountsView.AccountRow` — list-row, not metric
- `LegacyImpactView.painVsGainHeader` — comparison, not metric
- `TaxPlanningView.deductionComparisonCard` — comparison, not metric
- `TaxPlanningView.scenarioSummaryCard` — multi-row breakdown, not metric
- `QuarterlyTaxView.annualTaxSummary` — summary table, not metric
- `QuarterlyTaxView.safeHarborCard` — control card, not metric
- `SocialSecurityPlannerView.statusCard` — interactive multi-state, not metric

**One deferred candidate:**
- `QuarterlyTaxView` quarterly payment range display — flagged for revisit after Pass 2 snapshot coverage lands

**Out of scope (rejected during brainstorm):**
- Expanding `MetricCard`'s API for multi-value/range/comparison support — keeps the component narrow
- New canonical card components — view patterns are heterogeneous enough that forcing them into one family adds complexity

## Test plan

- [x] All ~688 pre-existing tests still pass (no test changes in this PR)
- [x] No `project.pbxproj` modifications
- [x] No SPM dependencies added
- [x] All 3 affected screens visually verified in light + dark mode
- [x] All 7 decline-to-swap comments added with clear reasons
- [x] Standard + narrow window widths checked

## Spec / plan

- Spec: `docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md`
- Plan: `docs/superpowers/plans/2026-04-30-metriccard-sweep.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" 2>&1 | tail -5
```

Expected: outputs the URL of the new PR.

- [ ] **Step 3: Confirm PR is open**

The output of Step 2 includes the PR URL (e.g., `https://github.com/johnqp801/RetireSmartIRA/pull/2`). Visit it to confirm:
- Title is correct
- Body renders the markdown properly
- Diff shows only the expected files (5 view files + the deferred-candidate comment file)
- No `project.pbxproj` or test changes in the diff

---

## Out of scope for this plan

These were rejected during brainstorm and explicitly do NOT belong in this PR:

- Expanding `MetricCard`'s API for multi-value, range, or comparison support
- New canonical card components (`CompositeCard`, `ComparisonCard`, `StatusCard`)
- Snapshot test coverage for the affected screens (Pass 2 of snapshot testing)
- Any structural refactor of the affected views beyond the card swaps
- The deferred `QuarterlyTaxView` quarterly payment range card swap

If any of these come up during execution, stop and report rather than expanding scope.

---

*End of plan.*
