import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 4's actual deliverable, in executable form.
///
/// The audit in 2026-08-02-full-50-state-verification.md is a single-source
/// research memo and says so. This suite is what converts it into evidence: every
/// entry here is a jurisdiction whose shipped behavior was measured against its
/// own published form and found to disagree, with the form cited.
///
/// Reading a green run of this suite: a `knownDefect` entry passing does NOT mean
/// the engine agrees with the state's own form. It means the opposite -- the
/// engine matches `observedToday` and DELIBERATELY does not match
/// `expectedStateTax`, because `GoldenScenarioSingleYearTests` pins that exact,
/// measured disagreement. "All tests pass" means every jurisdiction either
/// matches its own published form or disagrees with it in the exact, catalogued
/// way its fixture says it does. See `.claude/memory/roadmap/
/// 2026-08-04-state-tax-phase4-ledger.md` for the full catalogue rendered as
/// prose and the comparison against the audit's predictions.
@Suite("Golden scenarios, defect catalogue")
struct GoldenScenarioDefectCatalogueTests {

    struct Entry {
        let state: String
        let scenario: String
        let tier: String
        let summary: String
        let observed: Double
        let expected: Double
    }

    static func catalogue() throws -> [Entry] {
        var entries: [Entry] = []
        for abbreviation in GoldenScenarioCoverageTests.covered {
            guard let file = try? GoldenScenario.load(abbreviation: abbreviation) else { continue }
            for scenario in file.scenarios {
                guard let defect = scenario.knownDefect else { continue }
                entries.append(Entry(state: abbreviation, scenario: scenario.name,
                                     tier: defect.tier, summary: defect.summary,
                                     observed: defect.observedToday,
                                     expected: scenario.expectedStateTax))
            }
        }
        return entries
    }

    @Test("The catalogue is non-empty and every entry is well formed")
    func catalogueIsWellFormed() throws {
        let entries = try Self.catalogue()
        #expect(!entries.isEmpty, """
            No defects catalogued at all. The audit predicted roughly 29 defective
            jurisdictions. An empty catalogue means either the fixtures were written from
            the app's own output rather than from published forms, or knownDefect blocks
            were omitted. Both are Phase 4 failures.
            """)
        for entry in entries {
            #expect(!entry.summary.isEmpty, "\(entry.state): defect with no mechanism named")
            #expect(["tier1", "tier2", "tier3", "tier4", "unclassified"].contains(entry.tier),
                    "\(entry.state): unrecognised tier '\(entry.tier)'")
            #expect(abs(entry.observed - entry.expected) >= 0.01,
                    "\(entry.state) / \(entry.scenario): catalogued as defective but the two figures agree")
        }
    }

    @Test("Print the catalogue, grouped by tier")
    func printCatalogue() throws {
        let entries = try Self.catalogue()
        let byTier = Dictionary(grouping: entries, by: \.tier)
        var report = "\nPHASE 4 DEFECT CATALOGUE: \(entries.count) cases across "
        report += "\(Set(entries.map(\.state)).count) jurisdictions\n"
        for tier in ["tier1", "tier2", "tier3", "tier4", "unclassified"] {
            guard let group = byTier[tier], !group.isEmpty else { continue }
            report += "\n\(tier.uppercased()), \(group.count) cases, "
            report += "\(Set(group.map(\.state)).count) jurisdictions\n"
            for entry in group.sorted(by: { $0.state < $1.state }) {
                let delta = entry.observed - entry.expected
                let direction = delta > 0 ? "OVERTAXES" : "UNDERTAXES"
                report += String(format: "  %@  %@ by $%.2f, %@\n",
                                 entry.state, direction, abs(delta), entry.summary)
            }
        }
        print(report)
        #expect(!entries.isEmpty)
    }

    // MARK: - Known but unpinned

    /// A real, confirmed defect the phase found but could NOT pin with a golden
    /// case. `catalogue()` above can only ever see what a fixture carries, so a
    /// defect like this is invisible to it -- and a real defect invisible to the
    /// catalogue is exactly the thing Phase 5 would never act on. This list is
    /// the deliberate, documented alternative to letting it disappear: DATA, not
    /// a comment, so it survives independent of any one report or ledger.
    ///
    /// Distinct from both a pinned `knownDefect` (measured, cited, in
    /// `catalogue()`) and a clean pass (measured, cited, agrees with the form):
    /// this is measured to be WRONG in direction and mechanism, and cited for
    /// the mechanism, but something stops a fixture from asserting it.
    ///
    /// TWO ADMISSIBLE KINDS OF BLOCKER, and a contributor deciding whether their
    /// finding belongs here should check theirs against both. The list held only
    /// the first kind until Phase 5b Task 3, and an earlier version of this
    /// comment defined the whole category by it, which was the differentia of
    /// the single member that happened to exist rather than the genus:
    ///
    ///   1. NO ADMISSIBLE FIGURE. The correct `expectedStateTax` depends on a
    ///      dollar amount no reachable primary source states, so the fixture
    ///      could be written but its expected value could not be derived. The
    ///      Missouri entry below. Resolved by a source becoming reachable.
    ///
    ///   2. NOT EXPRESSIBLE. The household cannot be described in the app's
    ///      model well enough for a fixture to assert a tax for it. Two ways
    ///      that happens, and a contributor should check theirs against both:
    ///      the household cannot be described AT ALL, so a fixture would
    ///      assert something unreachable (the Kansas TSP entry below: no
    ///      `PlanClassificationChoice` row writes a federal
    ///      defined-contribution plan, so no user can classify one); or it can
    ///      be described but NOT DISTINGUISHABLY from a household the state
    ///      taxes differently, so a fixture for it would carry inputs
    ///      identical to an existing case and a contradictory
    ///      `expectedStateTax` (the Massachusetts contributory entry below:
    ///      `(definedBenefit, ownStateOrLocal)` describes the exempt
    ///      contributory pension and the taxable noncontributory one
    ///      identically). Both are resolved by a product decision, not by
    ///      research.
    ///
    /// What both share, and what actually defines the category: a defect
    /// measured against a state's own published form, whose mechanism is cited,
    /// which no golden case can hold. A finding that COULD be pinned belongs in
    /// a fixture with a `knownDefect` block instead, not here.
    struct UnpinnedDefect {
        let state: String
        /// The mechanism, stated the same way a `knownDefect.summary` would be.
        let summary: String
        /// What's missing, and what would resolve it. Not "give up" -- a
        /// concrete blocker Phase 5 (or a later pass) can check again.
        let blockedOn: String
    }

    static let knownButUnpinned: [UnpinnedDefect] = [
        UnpinnedDefect(
            state: "AZ",
            summary: """
                Arizona's UNCLASSIFIED-pension default still grants the Line 29a
                $2,500 allowance to a pension of any source. Phase 5b Task 6 shipped
                Arizona's per-source rules but deliberately left
                `pensionExemption` at `.partial(2500)` and deliberately did NOT
                name `.unknown` in the Line 29a denial rule, following New York's
                precedent rather than Kansas's: New York likewise leaves its blanket
                $20,000 exclusion applying to unclassified rows and warns through
                `unclassifiedPensionDisclosure`. The consequence is that a private
                pension the user has not yet classified keeps a $2,500 subtraction
                Arizona Form 140 Line 29a does not grant it, understating tax by up
                to $2,500 x 2.5% = $62.50. The alternative, denying `.unknown`,
                would have RAISED tax for every existing Arizona user who has not
                classified, including genuine government pensioners entitled to the
                allowance, so the defect was left in place and disclosed rather than
                traded for a different one.
                """,
            blockedOn: """
                NOT EXPRESSIBLE AS A GOLDEN CASE, for the same reason Hawaii's
                contributory household is not. The two households that would pin the
                two halves of this carry BYTE-IDENTICAL inputs: an unclassified
                PRIVATE pension and an unclassified GOVERNMENT pension are both
                `(unknown, unknown)` with the same amount, age, filing status and
                AGI, and their correct Arizona tax differs ($396.25 against $346.25
                at the AZ-1 income shape). A fixture case can assert one or the
                other, never both, and asserting either would encode a fact the
                inputs do not carry. Resolved not by a fixture but by the user
                classifying, which Arizona now prompts for: shipping
                `perSourceExemptions` is what makes
                `PlanClassificationChoice.shouldPromptForClassification` fire for
                Arizona residents, and `unclassifiedPensionDisclosure` is what tells
                them why it matters. Revisit if a later phase makes the unclassified
                state itself unreachable.
                """
        ),
        UnpinnedDefect(
            state: "AZ",
            summary: """
                Arizona's treatment of RAILROAD RETIREMENT benefits is unresolved, and
                Phase 5b Task 6 left it at the status quo rather than guessing. The
                shipped Arizona rules name `uniformedServices` (Line 29b, full) and deny
                `privateEmployer`, `otherStateOrLocal` and `nyStateOrLocal`;
                `railroadRetirement` is named by neither, so it falls through to the
                pooled `pensionExemption` and receives the Line 29a $2,500 allowance.
                That is exactly what Arizona did before this task, so nothing regressed,
                but it is unlikely to be right in either direction: 45 U.S.C. 231m is
                generally read as barring state taxation of Railroad Retirement Board
                benefits outright, and Kansas's Schedule S Line A14 already exempts them
                by name, which is why `PlanSource.railroadRetirement` exists at all. If
                that reading holds for Arizona, the direction is UNDER-exemption (the app
                over-taxes) on everything above $2,500. `railroadRetirement` is
                picker-reachable ("Railroad Retirement benefits"), so this is a live
                classification an Arizona user can select today.
                """,
            blockedOn: """
                NO AUTHORITY IN THE FIXTURE. statetax-2026-AZ.golden.json carries no
                railroad scenario and cites no Arizona provision covering these benefits;
                its nine cases quote Form 140 Lines 29a and 29b only. The shared
                procedure's Step 1 makes the golden fixture the specification and forbids
                re-researching the law, and neither available answer is derivable from
                what the fixture cites: a `full` rule and a `none` rule are both
                assertions about Arizona law that no quoted source in this repository
                supports. Guessing either way would put an uncited figure into a shipped
                config, which is the failure mode Missouri's entry above was created to
                avoid. Resolve by adding an Arizona golden case derived from the Arizona
                DOR's own published treatment of Railroad Retirement (and the federal
                preemption question), then naming `railroadRetirement` in whichever rule
                that case supports. The same question is open for `governmentUnspecified`,
                which also falls through to the $2,500 allowance, though that case is a
                deliberate non-answer: `PlanSource.governmentUnspecified`'s own doc
                comment forbids any rule treating it as a specific jurisdiction.
                """
        ),
        UnpinnedDefect(
            state: "MO",
            summary: """
                Missouri's public pension exemption is coded `.full` (unlimited) in
                StateTaxData.swift. Real law (MO-A 2025, Part 3, Section A, Line 2)
                caps it at the LESSER of the pension received or each individual's own
                maximum Social Security benefit, reduced by any Social Security
                deduction the same person claims. This is the exact defect the
                2026-08-02 audit named in section 5, Confirmed CORRECT, as a caveat --
                not a Tier 1 finding. The 2026-08-04 b5 batch confirmed the
                mechanism directly against the published MO-A form and Missouri DOR's
                pension FAQ, and hand-derived the correct arithmetic for a $150,000 /
                $120,000 MFJ public-pension case: correct tax $6,157.41 against the
                engine's measured $0.00.
                """,
            blockedOn: """
                The one figure `expectedStateTax` needs -- the 2026 maximum Social
                Security benefit at full retirement age -- has no reachable official
                source as of 2026-08-04. Tried, in order, and all exhausted: the 2026
                Federal Register COLA determination notice (reachable, official, does
                not carry this figure); ssa.gov's press release, fact-sheet, and OACT
                example-max pages (every path returns HTTP 403 to both WebFetch and
                curl); CRS Report 94-803 (reachable, does not carry this figure);
                Missouri's own 2026 MO-A form (404, not yet published); the Wayback
                Machine (no snapshot of the SSA pages that would carry it). The
                scenario that would have pinned this was written, verified arithmetic
                for a secondary-sourced $49,824 figure, and then DELETED rather than
                shipped on that secondary source, per this phase's own citation
                discipline (Missouri's fixture now carries 3 scenarios, not 4).
                Revisit when ssa.gov becomes reachable from this environment, or when
                Missouri DOR publishes the 2026 MO-A form.
                """
        ),
        UnpinnedDefect(
            state: "KS",
            summary: """
                Kansas's Schedule S Line A14 exempts federal retirement benefits
                "including Thrift Savings Plans" by name, inside the same federal
                category the Phase 5b Task 3 rule implements. A TSP is a
                defined-contribution plan, and that rule ships
                `matchStructures: ["definedBenefit"]`, so a Kansas resident holding a
                TSP is taxed in full on it. The direction is UNDER-exemption, i.e. the
                app over-taxes, which is the opposite direction from every other
                finding in this file. The constraint is deliberate and is the safer of
                the two errors available: Line A14 names "Kansas Public Employees'
                Retirement (KPERS) ANNUITIES", not the separate KPERS 457
                deferred-compensation plan, so dropping the structure constraint to
                reach TSP would simultaneously grant an unauthorised full exclusion to
                every government salary-reduction plan. See the KS-5 fixture's own
                source string, which quotes the A14 language, and
                Phase5bKansasPerSourceTests.namedSourceInAnotherStructureIsNotMatched,
                which pins the constraint this entry records the cost of.
                """,
            blockedOn: """
                NOT a missing dollar figure, unlike the Missouri entry above: this one
                is blocked on EXPRESSIVENESS, and this list is widened by exactly one
                kind of blocker to hold it rather than letting a real, measured
                under-exemption live only in a task report. No golden case can pin it,
                because no fixture can describe the household: `PlanClassificationChoice`
                has no row writing a federal DEFINED-CONTRIBUTION plan, so a Kansas TSP
                holder cannot classify one through the app at all, and a fixture
                asserting a tax for a classification no user can select would assert
                something unreachable. Resolving it needs a product decision, not
                research: either a picker row for a federal defined-contribution plan
                plus a second Kansas rule scoped to it, or an explicit decision that
                federal TSP stays unmodelled and is disclosed to Kansas users. Both are
                out of Task 3's scope. Revisit when Phase 6's disclosure work decides
                which.
                """
        ),
        UnpinnedDefect(
            state: "MA",
            summary: """
                Massachusetts excludes a Massachusetts state or local employee
                CONTRIBUTORY pension from Massachusetts gross income (mass.gov, Tax
                Treatment of Government Pensions in Massachusetts). A NONCONTRIBUTORY
                municipal pension is on none of that guidance's enumerated exempt
                categories and stays ordinary taxable income. The Phase 5b Task 4 rule
                ships `matchSources: ["ownStateOrLocal", "uniformedServices"]` at
                `definedBenefit`, and `RetirementPlanClassification` has no
                contributory axis, so a Massachusetts resident holding a
                noncontributory municipal pension is granted the full exclusion and is
                UNDER-taxed. Measured: $0.00 against $3,000.00 on the fixture's own
                $60,000 single filer at the flat 5% rate. The direction is
                under-taxation, which is the dangerous direction, and it is recorded
                here rather than avoided because the alternative was to leave the three
                CITED Massachusetts corrections (MA-1, MA-3, MA-4) undelivered to
                protect a category the fixture's own source note states is an inference
                from a closed list rather than a sentence on the page. It is REACHABLE
                by a real user, unlike the Kansas entry above: the picker's "Government
                pension, my own state or locality" row is the only row such a person
                can honestly select, and it writes exactly the classification the rule
                matches.
                """,
            blockedOn: """
                NOT EXPRESSIBLE, the same blocker kind as the Kansas entry above but
                for a different reason, and the reason is why no golden case can hold
                it. The contributory and noncontributory Massachusetts municipal
                households are described by the SAME `RetirementPlanClassification`:
                `(definedBenefit, ownStateOrLocal)`. Every field that would describe
                one describes the other. A golden case for the noncontributory
                household would therefore carry inputs byte-identical to MA-1's and a
                contradictory `expectedStateTax` ($3,000.00 against MA-1's $0.00), so
                the fixture set would assert a contradiction rather than a defect.
                Writing it was attempted in Task 4 and rejected for that reason.
                Resolving it needs a THIRD classification axis, employee-contributory
                against employer-funded, on `RetirementPlanClassification`, matched by
                `PerSourceExemptionRule`, with a picker affordance so a real user can
                state it and a migration default for every saved row that cannot. That
                axis is not Massachusetts-only and must not be designed from
                Massachusetts alone: Hawaii's golden fixture (Phase 5b Task 5) turns on
                the same axis in the OPPOSITE direction (employer-funded exempt,
                employee-funded taxable) and currently proxies it through
                `PlanStructure`, a different forced fit for the same missing dimension.
                Two jurisdictions with two incompatible proxies is a missing dimension,
                not a quirk. Revisit once Hawaii's authority-derived fixture has been
                read, and design the axis against both; the phase's own precedent is
                that a shared classification axis lands in the model task
                (`isSurvivorBenefit`, Task 1) and is consumed by the jurisdiction tasks,
                not invented by one of them.
                """
        ),
        UnpinnedDefect(
            state: "MA",
            summary: """
                mass.gov's Tax Treatment of Government Pensions in Massachusetts
                enumerates a closed list of exempt pension categories, and that list
                includes FEDERAL CONTRIBUTORY pensions and RAILROAD RETIREMENT
                alongside the two categories the Phase 5b Task 4 rule implements. The
                shipped rule names `ownStateOrLocal` and `uniformedServices` only, so a
                Massachusetts resident holding a CSRS or FERS annuity, or a Railroad
                Retirement benefit, is taxed in full on it. Measured: $3,000.00 against
                $0.00 on the fixture's own $60,000 single filer at the flat 5% rate,
                pinned by
                `Phase5bMassachusettsPerSourceTests.federalCivilianIsTaxedInFullToday`.
                The direction is UNDER-exemption, i.e. the app over-taxes, the same
                direction as the Kansas TSP entry above and the opposite of the
                Massachusetts contributory entry above it. The omission is deliberate
                and is the safer of the two errors available, but it is an error and it
                is not disclosed to the affected user anywhere in the app.
                """,
            blockedOn: """
                NEITHER blocker kind above fits exactly, and saying which it is closest
                to is more useful than forcing it. It is NOT kind 2: the household is
                fully expressible, `PlanClassificationChoice.federalCivilianPension`
                writes `(definedBenefit, federalCivilian)` and a user can select it
                today, so a golden case COULD be written. It is kind 1 in shape but not
                in substance: what is missing is not a dollar amount (the figure is
                $0.00 if the category is exempt) but a REVIEWED derivation of the rule
                itself. The only statement of these two categories anywhere on this
                branch is a paraphrase inside golden case MA-2's own `source` prose, not
                a quoted primary source, and Phase 4's discipline is that every
                `expectedStateTax` was derived from the jurisdiction's published
                authority by a reviewer who independently opened the document. Task 4's
                shared procedure forbids researching the law again, so this task could
                not supply that derivation and deliberately did not widen the rule from
                a paraphrase. Note also that mass.gov's category is federal
                CONTRIBUTORY, so the same missing contributory axis recorded in the
                entry above applies here too, even though every federal civilian annuity
                is in practice contributory. Resolved by a reviewed primary-source pass
                over mass.gov adding MA golden cases for a federal civilian pension and
                a Railroad Retirement benefit, after which the rule can be widened to
                whatever those cases support. Note the MA-4 fixture's warning is NOT in
                conflict with this and must not be read as one: it says only that the
                MILITARY exclusion must not be written against `federalCivilian`,
                because mass.gov treats federal civilian pay under a separate heading.
                """
        ),
        UnpinnedDefect(
            state: "HI",
            summary: """
                Hawaii's pension exclusion applies to the EMPLOYER-FUNDED PORTION of a
                pension: "The pension exclusion applies only to amounts attributable to
                employer contributions" (Hawaii Schedule J Instructions, REV 2025, page
                2, quoted in full by the HI-1 golden case). A PARTIALLY employer-funded
                pension, which is what every contributory defined-benefit plan is,
                therefore carries a partial exclusion. This app applies NONE of it: no
                field on `RetirementPlanClassification` records who funded a plan, so
                `statetax-2026-HI.json` ships no `perSourceExemptions` at all and every
                Hawaii pension dollar is taxed at Hawaii's 12-bracket schedule. The
                direction is OVER-taxation, the same direction as the Kansas TSP entry
                above and the safer of the two errors available. The fully
                employer-funded ENDPOINT of this same defect IS pinned: by HI-1 and HI-3,
                whose every row is that endpoint, and by the definedBenefit row of the
                mixed household HI-4. This entry is about the MIDDLE of the range, which
                none of them reaches.
                """,
            blockedOn: """
                BOTH blocker kinds at once, which no earlier entry in this list has, and
                either one alone would be enough.

                Kind 2, NOT EXPRESSIBLE, is the harder one and it is squarely true: the
                household cannot be described distinguishably. A contributory
                defined-benefit pension and the fully noncontributory one HI-1 already
                pins are the SAME classification, `(definedBenefit, privateEmployer)`,
                because `RetirementPlanClassification` carries structure and source and
                nothing about funding. A fixture for the contributory private-sector
                household would therefore carry inputs byte-identical to HI-1's and a
                contradictory `expectedStateTax`.

                Kind 1, NO ADMISSIBLE FIGURE, needs stating carefully, because a loose
                version of it would rule out the very axis this entry goes on to
                recommend. It is NOT true that the arithmetic is unavailable in
                principle: a golden fixture COULD carry a stipulated employer-funded
                share as an INPUT, exactly as it carries `amount`, and the correct
                `expectedStateTax` would then follow from Schedule J arithmetically, with
                no new research and no unciteable number. What is missing is narrower and
                more concrete, and these are the three things a model task has to solve:
                a FIELD on the classification to hold the share, a PICKER AFFORDANCE so a
                real user can supply it, and an answer to whether a real user CAN supply
                it, since Schedule J makes the taxpayer compute the employer-funded
                portion from cost basis rather than reading it off a 1099-R. A fixture
                asserting a tax against a share no user can state or enter would assert
                something unreachable, which is the Kansas TSP entry's failure mode above.

                This is also the record of WHY Hawaii ships no rule, which is Phase 5b
                Task 5's whole deliverable. Task 5 measured the alternative rather than
                arguing it: a rule of `matchStructures: ["definedBenefit"]` with an empty
                `matchSources` was temporarily added to the shipped Hawaii config, and
                the golden suite reported HI-1, HI-3 and HI-4 as ALL THREE matching their
                published form ($0.00, $0.00, $266.00) with no fixture objecting, while
                that rule silently granted a full Hawaii exclusion to every contributory
                defined-benefit pension including every federal civilian annuity. Trading
                a disclosed over-taxation for an undisclosed under-taxation over a larger
                population is the wrong direction, and the plan's own Step 3 ("if the
                fixture set has no case that would catch that, ADD one") cannot be
                satisfied here, per kind 2 above.

                Resolving it needs the SAME third axis the Massachusetts contributory
                entry above names, and Task 5's finding is that the two jurisdictions do
                not want the same shape of it: Massachusetts needs a CATEGORICAL fact
                (contributory excluded, noncontributory taxable, mass.gov's own closed
                list), while Hawaii needs a PROPORTION. A boolean axis designed from
                Massachusetts would be exactly right for Massachusetts and right only at
                the two endpoints for Hawaii, silently wrong for every partially
                employer-funded plan in between, which is most of them. Design it against
                both, in a model task, per this phase's own precedent that a shared
                classification axis lands in the model task (`isSurvivorBenefit`, Task 1)
                and is consumed by the jurisdiction tasks rather than invented by one of
                them. Until then Hawaii stays "disclosed, not modelled" per Phase 4, and
                the disclosure is live in two places: `IncomeSourcesView.swift`'s Hawaii
                caption and `MultiYearCPABriefing.hawaiiPensionSplitLimitation`.
                """
        ),
        UnpinnedDefect(
            state: "NC",
            summary: """
                North Carolina's BAILEY exclusion is not modelled, and Phase 5b Task 7
                deliberately shipped no rule for it. NCDOR exempts a pension from the
                named North Carolina and federal retirement systems "if the retiree had
                five or more years of creditable service as of August 12, 1989". The app
                has no vesting axis, so the only rule it can express is keyed on
                `planSource` and `planStructure`, and such a rule exempts EVERY North
                Carolina state and local pension rather than only the Bailey class. The
                three NC golden cases each STIPULATE Bailey vesting in prose because no
                field can hold it, and their `knownDefect` blocks stay. Direction of the
                CURRENT defect: North Carolina OVER-taxes a Bailey-vested retiree, worth
                $1,486.27 a year at NC-1's shape ($50,000 pension, single, age 70).

                Task 7 measured the alternative rather than arguing it, per Task 5's
                standard. A rule of `matchSources: ["ownStateOrLocal", "federalCivilian"]`
                at `matchStructures: ["definedBenefit"]`, treatment `full`, was temporarily
                added to the shipped North Carolina config and the golden suite reported
                ALL THREE defect cases as matching their published form ($0.00, $0.00,
                $379.05), with the only guard in the set (NC-2, a private pension) raising
                no objection. The mutation was reverted. The green outcome was available
                and it is wrong: that rule silently exempts every North Carolina public
                employee first hired after August 1984, who cannot have five years of
                creditable service by 1989-08-12, and who is fully taxable on that pension
                at North Carolina's 3.99% flat rate.

                The class is CLOSED and can only shrink; its complement can only grow. To
                have entered NC public service by August 1984 a person must be at least 60
                in 2026, and at a normal entry age 64 to 67. Every NC public employee
                retiring today, and in every future year, is outside the class. So the rule
                would trade a bounded over-taxation of a closed, aging cohort for an
                undisclosed UNDER-taxation of an open and growing one, which is the same
                trade Task 5 declined for Hawaii.

                The evidentiary shape is Hawaii's, not Massachusetts's. Task 4 shipped
                Massachusetts because its corrections rested on quoted affirmative statute
                while its residual gap rested on an inference. Here the GRANT and the LIMIT
                are the same quoted NCDOR sentence: the conditional "if the retiree had
                five or more years of creditable service as of August 12, 1989" does
                exactly what the word "only" does in Hawaii's Schedule J sentence. No
                source in the fixture exempts any North Carolina pension unconditionally,
                so no narrower sub-rule escapes the over-match either.

                THE ONE PLACE NORTH CAROLINA IS WEAKER THAN HAWAII, recorded because it
                cuts against the decision above rather than for it. Task 5 could rest part
                of Hawaii's case on the fact that Hawaii's over-taxation is DISCLOSED, on
                two surfaces (`IncomeSourcesView.swift`'s Hawaii caption and
                `MultiYearCPABriefing.hawaiiPensionSplitLimitation`). North Carolina's is
                disclosed NOWHERE: grepping the production sources for "Bailey" or
                "northCarolina" across `IncomeSourcesView`, `MultiYearCPABriefing` and
                `UnclassifiedPensionDisclosure` returns nothing, confirming Task 2's
                finding. So a Bailey-vested North Carolina retiree is over-taxed by
                $1,486.27 at NC-1's shape with no on-screen warning at all. That does NOT
                argue for shipping the wrong rule, which would replace a silent
                over-taxation with a silent under-taxation over a larger group; it argues
                for a DISCLOSURE, and it is a Phase 6 item. It cannot be an
                `unclassifiedPensionDisclosure` sentence: that string is in bidirectional
                lockstep with `perSourceExemptions`, and it would be false for North
                Carolina anyway, because a North Carolina pension can be perfectly
                classified and still be taxed wrongly. The right shape is a Hawaii-style
                caption, which is user-facing copy needing John's approval, alongside the
                caption-hoisting work Task 5 already deferred for Hawaii and Massachusetts.
                """,
            blockedOn: """
                NOT EXPRESSIBLE AS A GOLDEN CASE, and the plan's Step 3 ("if the fixture
                set has no case that would catch that, ADD one") therefore cannot be
                satisfied, which forecloses shipping a rule procedurally and not merely as
                a judgement call. The case that would catch the over-match is a
                NON-Bailey-vested North Carolina state pension, and its inputs are
                BYTE-IDENTICAL to NC-1's: `(definedBenefit, ownStateOrLocal)`, $50,000,
                single, age 70, AGI $50,000. The two correct answers are $1,486.27 and
                $0.00. A fixture can assert one or the other, never both. This is the same
                blocker shape as Hawaii's contributory household and Arizona's unclassified
                pension. `Phase5bNorthCarolinaDecisionTests
                .noNorthCarolinaGoldenCaseCouldCatchTheVestingOverMatch` proves it from the
                fixture's own bytes rather than asserting it.

                What WOULD resolve it is a third classification axis carrying Bailey
                membership. Unlike Hawaii's employer-funded PROPORTION, this one is
                genuinely expressible and genuinely answerable: it is a boolean, a golden
                fixture could carry it as an input the way it carries `amount`, and a
                retiree entitled to the exclusion already claims it on Form D-400 Schedule
                S Line 20, so many users can answer it from their own return. Task 7 did
                NOT decline it as impossible. It declined it as out of scope for a
                jurisdiction task, on this phase's own precedent that a shared
                classification axis lands in the MODEL task (`isSurvivorBenefit`, Task 1)
                and is consumed by the jurisdiction tasks rather than invented by one of
                them, and because Task 1's axis is itself still unconsumed in production
                (Task 9's work) in the very matching function and the five-times-drifted
                `DataManager` mirror a second axis would have to change at the same time.

                Weigh before building it: this axis would serve ONE jurisdiction and one
                cohort whose correct-answer population declines monotonically to zero,
                while becoming a permanent field in stored user data that cannot be removed
                without a migration. It is also not a DATE axis despite the plan's framing.
                "Five or more years of creditable service as of August 12, 1989" is a
                service-credit computation, not a date a user holds, so the honest picker
                question is a Bailey-membership boolean, and a user who guesses it wrong
                moves their own tax by 3.99% of the pension in whichever direction they
                guessed, with nothing to cross-check them.

                Military retired pay is NOT one of the open questions here, and an earlier
                draft of this entry wrongly said it was. North Carolina's answer is already
                shipped: `MilitaryRetirementExemption.stateTaxableAmount` returns
                `.fullyExempt` for "NC". What is open is that the shipped answer is reachable
                by only ONE of the two paths a user has, which is its own catalogue entry
                below. `railroadRetirement` and `governmentUnspecified` remain genuinely
                uncited in the North Carolina fixture, and Step 1 forbids re-researching the
                law, so Task 7 left those at the status quo rather than inventing a citation,
                following Task 6's railroad precedent.
                """
        ),
        UnpinnedDefect(
            state: "NC",
            summary: """
                MILITARY RETIRED PAY HAS TWO PATHS IN NORTH CAROLINA WITH OPPOSITE ANSWERS,
                and the divergence is reachable by a real user today. It predates Phase 5b
                Task 7 and was found by that task's own mirror sweep.

                Path 1, by INCOME TYPE. `MilitaryRetirementExemption.stateTaxableAmount`
                returns `.fullyExempt` for "NC" ("North Carolina, full exemption enacted
                2021"), consumed by `TaxCalculationEngine` and mirrored in `DataManager`, for
                rows whose `IncomeSource.type` is `.militaryRetirement`.
                `IncomeSourcesView`'s `stateTreatmentHint` renders a green "Fully exempt from
                North Carolina state tax" badge for them. Result: $0 of North Carolina tax.

                Path 2, by CLASSIFICATION. Phase 5b Task 3 added the "Military retired pay"
                picker row, which writes `(definedBenefit, uniformedServices)` onto a
                `.pension` row. North Carolina ships no `perSourceExemptions`, so nothing
                reads that classification and the income is taxed in full.
                `Phase5bNorthCarolinaDecisionTests.northCarolinaIsUnaffectedByClassification`
                MEASURES $1,486.27 for `uniformedServices` at a $50,000 pension, single, age
                70. That test asserts the figure deliberately, because inertness is Task 7's
                deliverable, but the figure contradicts path 1 for the same money.

                The two loops are disjoint (a row has exactly one `type`), so there is no
                double exclusion and no arithmetic bug. The defect is that the ANSWER depends
                on which screen the user entered the money from, and the pension picker is
                offered unconditionally to every state
                (`IncomeSourcesView.swift`, the `incomeType == .pension` section), so a North
                Carolina user can reach the taxed path without doing anything unusual.
                Direction: OVER-taxation by the full amount of the military pension, against
                a state answer the app itself already displays as fully exempt.

                Task 6 found and pinned the SAME divergence in Arizona
                (`bothMilitaryRoutesAgree`), where it happened to resolve because Arizona's
                new `uniformedServices` rule made the two paths agree. North Carolina has no
                such rule and cannot get one from Task 7, so the divergence stays open here.
                """,
            blockedOn: """
                NOT A GOLDEN-CASE DEFECT, which is why it needs this entry rather than a
                fixture. The golden harness's `ClassifiedPensionSource` schema builds
                `.pension` rows only; it has no way to express an `IncomeType`, so path 1 is
                unreachable from `GoldenScenarioSingleYearTests` and the two paths cannot be
                compared there at all. Arizona's equivalent is pinned in a hand-written
                DataManager test, not in a fixture, for the same reason.

                NOT FIXABLE BY TASK 7, and this is the point worth carrying forward. The
                obvious repair is a North Carolina `perSourceExemptions` rule naming
                `uniformedServices` at `full`, which would make the two paths agree. Task 7
                cannot ship it: North Carolina's entire Task 7 finding is that its fixture
                establishes the Bailey exclusion and nothing else, no fixture case or cited
                provision covers military retired pay under the Bailey settlement, and Step 1
                forbids re-researching the law. Shipping a `uniformedServices` rule on the
                strength of `MilitaryRetirementExemption`'s own comment would also import
                that table's authority, which no golden fixture has ever audited.

                RESOLVE IT by deciding, in a task with authority to establish the law,
                whether North Carolina's military exemption should be expressed as a
                per-source rule. If yes, the two paths converge, this entry is deleted, and
                `northCarolinaIsUnaffectedByClassification` must be narrowed to exclude
                `uniformedServices` in the same change, since it currently asserts the taxed
                figure for every source. The broader structural fix, which Task 6 also
                gestured at, is that `IncomeType.militaryRetirement` and
                `PlanSource.uniformedServices` are two encodings of one fact and one of them
                should eventually be derived from the other.
                """
        ),
        UnpinnedDefect(
            state: "ID",
            summary: """
                Idaho's Retirement Benefits Deduction (Form 39R Line 8) is granted only to
                a CLOSED list of plans, and membership in that list turns on facts
                `RetirementPlanClassification` does not carry, so Phase 5b Task 8 shipped
                NO Idaho `perSourceExemptions` and Idaho still grants no deduction at all.
                The five pinned defects ID-2, ID-3, ID-4, ID-5 and ID-8 record the
                resulting over-taxation and STAY. This entry records why they were not
                fixed, and `blockedOn` below distinguishes the branches that COULD NOT be
                fixed from the one that was DECLINED.

                TWO CONDITIONS, both quoted from the fixture's own Form 39R citations,
                neither expressible. FIRST, the civilian grant is "Retirement annuities
                paid by the U.S. Civil Service Retirement System (CSRS)" where "the
                employee must have established eligibility before 1984". FERS is a
                different system and is not on the list. The picker offers exactly one row
                for both, "Government pension, federal civilian", writing
                `(definedBenefit, federalCivilian)`, and there is no pre-1984 eligibility
                field anywhere on the classification. SECOND, the own-state grant covers
                PERSI FIREFIGHTERS and certain Idaho POLICE, not PERSI generally, while
                the picker's "Government pension, my own state or locality" row writes
                `(definedBenefit, ownStateOrLocal)` for every Idaho public retiree
                including teachers and general state employees.

                THE POPULATION IS WHAT DECIDED IT, exactly as for North Carolina's Bailey
                entry above. A pre-1984 eligibility condition means the qualifying civilian
                class CLOSED IN 1984 and can never gain a member; that is entailed by the
                quoted condition itself, not imported from outside the fixture. Its
                complement has grown with every federal civilian hire for forty-two years,
                so a `federalCivilian` rule would be wrong for the majority of federal
                civilian retirees in Idaho today and for a larger majority every year, in
                the UNDER-taxation direction. Shipping would trade a bounded, disclosed
                over-taxation of a closed and shrinking cohort for an undisclosed
                under-taxation of a growing one.

                REACHABLE, not theoretical: both over-matching rows are rows a real user
                selects, and Task 8's caption
                (`IncomeSourcesView.idahoRetirementBenefitsDeductionCaption`) is the only
                surface that reaches them, since Idaho ships no rule and therefore gets
                neither the classification prompt nor the unclassified-pension disclosure.
                """,
            blockedOn: """
                TWO BRANCHES WITH DIFFERENT ANSWERS, and conflating them is the mistake
                this paragraph exists to prevent. An earlier version of this entry said
                shipping was "foreclosed procedurally, not as a judgement call" without
                qualification. That is TRUE of the civilian branches and FALSE of the
                military one, and a future task that read only the unqualified claim would
                stop looking at a rule that is actually available.

                BRANCH 1, `federalCivilian` and `ownStateOrLocal`, is
                NOT EXPRESSIBLE AS A GOLDEN CASE: the same blocker kind as the North
                Carolina Bailey entry and the Massachusetts contributory entry above,
                which is why this phrase is kept on one line for the deletion guard that
                greps it. The case that would catch the
                over-match is a FERS retiree at 65 or older: its inputs are byte-identical
                to ID-2's, the same `(definedBenefit, federalCivilian)` row at the same
                amount, age, filing status and AGI, with a contradictory `expectedStateTax`
                of $840.05 against ID-2's $0.00. A fixture can assert one or the other,
                never both. The PERSI half has the same shape against a hypothetical Idaho
                police-or-fire case. Step 3 is a requirement of the procedure rather than a
                preference, so for THESE branches shipping is foreclosed procedurally.

                BRANCH 2, `uniformedServices` ALONE: EXPRESSIBLE, and declined as a
                JUDGEMENT CALL rather than foreclosed. Task 8's review found a partial
                shape the task had not evaluated, in Arizona's actual shipped form: route
                the cap through the pooled `pensionExemption` as
                `.steppedPhaseoutByFilingStatus(48216, 72324, one 100% band)` with
                `regularExemptionMinAge: 62`, and use ONE `.none` per-source rule
                enumerating the nine non-military `PlanSource` cases so that military
                retired pay is the only thing left in the pool. MEASURED against the
                shipped Idaho config: ID-3 GOES GREEN and nothing else moves (ID-1, ID-6
                and ID-7 stay correctly taxed, ID-2, ID-4, ID-5 and ID-8 stay pinned).
                Idaho's cap IS expressible this way, since the MFJ maximum is 1.5x the
                single one and `exemptionAppliesPerIndividual` can only double.

                WHY BRANCH 2 WAS DECLINED ANYWAY, three reasons, none of them
                expressibility. FIRST and largest, Line 8a reduces the maximum
                DOLLAR-FOR-DOLLAR by Social Security and Railroad Retirement benefits
                RECEIVED, and nothing in the model carries that reduction. A single
                military retiree at 65 with a $60,000 pension and $30,000 of Social
                Security has a real Idaho maximum of $18,216, not $48,216: measured, that
                is $934.60 of tax against the $0.00 the rule would produce, so roughly $935
                a year of UNDISCLOSED UNDER-TAXATION. That is the COMMON case rather than
                an edge case, since most military retirees draw Social Security, and
                under-taxation is the dangerous direction. SECOND, Idaho ships
                `exemptionAttribution: .household`, so on a joint return an under-62
                military spouse inherits a 62-plus spouse's gate and draws a deduction Line
                8e denies them. THIRD, the `.none` rule must enumerate nine `PlanSource`
                cases BY HAND, so any case added later silently falls INTO the pool and
                receives Idaho's deduction with no test failing. Both the Social Security
                offset and the split-age joint return ARE pinnable as golden cases, so a
                future task may legitimately reach a different conclusion here; it should
                do so by pinning them first, not by shipping the rule and hoping.

                UPDATED BY PHASE 5b TASK 9, WHICH RE-OPENED THIS AND RE-MEASURED IT. Task
                9 added `matchMinAge` to `PerSourceExemptionRule` for D.C. Code Section
                47-1803.02(a)(2)(N)(ii), and Task 8's reflective tripwire in
                `Phase5bIdahoDecisionTests` fired on the first full-suite run, as designed.
                A THIRD shape is now expressible and was measured against the shipped Idaho
                config: `matchSources: ["uniformedServices"]`, `matchStructures:
                ["definedBenefit"]`, `matchMinAge: 62`, treatment `full`. Result: ID-3 GOES
                GREEN and NOTHING ELSE MOVES, with ID-7 (military at 55) still correctly
                denied and ID-1 and ID-6 (civilians at 60 and 63) untouched. Reverted.
                TWO of the three objections above are now GONE: the age gate exists, and
                the household-attribution objection is gone too, because `matchMinAge` is
                evaluated against the ROW OWNER's own age rather than the household
                maximum. What survives is the FIRST and largest one, and it is decisive:
                `treatment: full` is UNCAPPED, so this shape over-exempts a military
                pension above the $48,216 / $72,324 maximum outright, on top of the
                unmodelled Social Security offset, and a `.partial` per-source treatment is
                banned phase-wide because `treatment` is evaluated inside the engine's
                per-row loop. Both of those ARE pinnable, unlike the FERS collision, so
                Step 3 requires the catching cases be ADDED, at which point the rule fails
                them. Idaho still ships nothing.

                RESOLVE IT with a product decision rather than research: a plan-detail axis
                carrying the eligibility facts (pre-1984 CSRS eligibility; police-or-fire
                service within a state system) for branch 1, and for branch 2 a
                benefits-received offset on the pooled cap plus a HOUSEHOLD-level cap a
                per-source rule can carry. The per-source age gate that half of this
                sentence used to ask for now EXISTS: Task 9 shipped `matchMinAge`, and
                that half is done. Design the classification axis against Massachusetts
                and Hawaii too rather than from Idaho alone, per the precedent in the MA
                entry above that a shared classification axis lands in the model task and
                is consumed by the jurisdiction tasks. Until then Idaho's five pinned
                defects and this entry are the record, and the caption is the disclosure.
                """
        ),
        UnpinnedDefect(
            state: "DC",
            summary: """
                A District of Columbia survivor annuitant whose pension row was saved
                before Phase 5b Task 9 is over-taxed, silently, on every surface. Task 9
                shipped DC's rule under D.C. Code Section 47-1803.02(a)(2)(N)(ii) keyed on
                `isSurvivorBenefit == true`, and NO ROW SAVED BEFORE THAT FIELD EXISTED
                CARRIES IT: the decoder resolves an absent key to `nil`, which is "never
                asked" and deliberately satisfies neither a `true` nor a `false` rule
                condition. So a DC survivor whose $50,000 annuity is already correctly
                classified as a federal civilian pension keeps paying the full $1,924.00
                that DC-2's fixture pins as the pre-correction figure, until they re-open
                the row and answer the new toggle.

                THE PART THAT MAKES IT A DEFECT RATHER THAN A MIGRATION IS THE SILENCE.
                Both disclosure surfaces gate on the pension being UNCLASSIFIED:
                `UnclassifiedPensionDisclosure.text(for:scope:)` composes a sentence only
                for a household whose pension is unclassified, and
                `PlanClassificationChoice.shouldPromptForClassification` requires
                `planSource == .unknown` or a genuine mix. This user is fully classified,
                so State Comparison shows nothing, the CPA briefing handed to a preparer
                shows nothing, and the Income Sources prompt does not fire. The new
                survivor toggle is visible only once they are already inside the editor,
                which is the one place they have no reason to go. This is the
                input-surface-only disclosure gap Phase 5b Task 4 routed to Phase 6,
                reappearing in a form where the trigger is not a missing answer to a
                question the user was asked, but a question that did not exist when they
                answered.

                DIRECTION: over-taxation, which is the safe one, and it is exactly the
                figure the app produced before the rule shipped. Nobody is told a tax is
                lower than it is.
                """,
            blockedOn: """
                NO GOLDEN CASE CAN PIN IT, of either admissible kind, and specifically the
                second: the household is describable, but not distinguishably from one the
                District taxes differently. A fixture row either states
                `isSurvivorBenefit` or omits it, and omitting it is EXACTLY what DC-5 (the
                holder's own federal civilian pension, correctly fully taxable) already
                does. A fixture for "a survivor benefit whose survivor fact was never
                recorded" would carry inputs byte-identical to DC-5's with a contradictory
                `expectedStateTax`, so the two cannot both be asserted. The distinction is
                not in the data at all: it is between a `nil` that means "own pension" and
                a `nil` that means "survivor benefit, not yet asked", and the model
                deliberately does not tell them apart, because inventing the difference is
                what would let an unanswered question claim an exclusion.

                RESOLVE IT with a product decision, not research, and the same one
                Massachusetts's and Idaho's entries are waiting on: a disclosure surface
                that fires for a CLASSIFIED pension whose jurisdiction's rules turn on a
                fact the row does not carry. Concretely, extend the
                `UnclassifiedPensionDisclosure` gate from "planSource is unknown" to
                "this jurisdiction's shipped rules consult a dimension this row leaves
                nil", which for DC is `matchIsSurvivorBenefit` against
                `IncomeSource.isSurvivorBenefit` and is already computable from live
                config by `PlanClassificationChoice.residenceUsesSurvivorDimension`. A
                one-time migration prompt for existing DC rows would close it faster and
                is the narrower option. Until then this entry and the survivor toggle in
                the pension editor are the record.
                """
        ),
        UnpinnedDefect(
            state: "DC",
            summary: """
                THE NON-RESIDENT CASE. DC's survivor rule is UNREACHABLE for every user
                who does not live in the District, so the DC column of State Comparison
                overstates DC's tax for every survivor annuitant in the other fifty
                jurisdictions. This is a DIFFERENT and PERMANENT population from the
                pre-existing-row entry above, which is why it is a separate entry: that
                one closes for any DC resident who re-opens their pension row, and this
                one never closes for anybody, because the control that would close it is
                not shown to them at all.

                THE MECHANISM, in three steps, each one deliberate on its own.
                `IncomeSourcesView`'s survivor toggle is the ONLY writer of
                `IncomeSource.isSurvivorBenefit`, and both the control and the save path
                are gated on
                `PlanClassificationChoice.residenceUsesSurvivorDimension(dataManager
                .selectedState)`, i.e. on RESIDENCE. `StateComparisonView` nevertheless
                computes every jurisdiction's tax for a non-resident, and Phase 5b Task
                3b established that State Comparison is VIEWED-STATE relative while the
                CPA briefing is RESIDENCE relative, and that the asymmetry is deliberate.
                So a California widow aged 65 holding a federal survivor annuity has no
                way to record that she is a survivor, her stored row carries
                `isSurvivorBenefit == nil`, and DC's rule correctly declines to match a
                row that was never asked. DC's column computes as though subparagraph
                (N)(ii) did not exist: $1,924.00 at DC-2's shape, against the $0.00 DC-2
                pins as correct for that household.

                AND NOTHING DISCLOSES IT. `StateComparisonPresentation
                .showsUnclassifiedPensionLimitation` gates on `hasUnclassifiedPension`,
                and this pension is perfectly classified as a federal civilian
                defined-benefit pension. The survivor fact is not a missing answer to a
                question she declined to answer; it is a question the app never puts to
                her, because she lives somewhere else.

                DIRECTION: over-statement of DC, which is the safe direction for a
                comparison grid. Nobody is shown a tax lower than it is. The cost is a
                user who rules the District out of a relocation shortlist on a number
                that is $1,924.00 a year too high.
                """,
            blockedOn: """
                A PRODUCT DECISION ABOUT WHO IS ASKED A QUESTION, not research, and not
                anything a golden case could hold. `GoldenScenarioSingleYearTests` drives
                one jurisdiction's config against one household's rows and has no notion
                of residence at all, so it cannot express "the row could not have carried
                this flag because of where the taxpayer lives". The defect is in the
                AFFORDANCE, one layer above every surface a fixture reaches, which is the
                same place Task 3's Kansas finding lived: a green suite and an
                undelivered fix.

                THE OBVIOUS REPAIR IS NOT OBVIOUSLY RIGHT, which is why the whole-branch
                review recorded this rather than shipping it. Changing the gate to "ANY
                jurisdiction ships a survivor rule" would put a third question, and the
                DC-specific caption approved by John on 2026-08-05, in front of every user
                in all fifty-one jurisdictions, for a fact that cannot move a single
                dollar of their own tax. That is precisely the noise
                `residenceUsesSurvivorDimension`'s own doc comment declines to make and
                `shouldPromptForClassification` declines before it. Narrower shapes exist
                (ask only once a user opens State Comparison; ask only for the
                jurisdictions actually on screen; disclose rather than ask) and every one
                of them needs new user-facing copy, which is out of scope for a review
                fix and is John's to approve.

                THE SMALLER OPTION, and the one to weigh first: extend
                `StateComparisonPresentation` with a viewed-state limitation that fires
                for a CLASSIFIED pension when the VIEWED state's shipped rules consult a
                dimension the row leaves nil. That is the same extension the
                pre-existing-row entry above asks for, but keyed to the viewed state
                rather than to residence, so the two want one mechanism with two gates,
                exactly as `showsUnclassifiedPensionLimitation` and
                `MultiYearCPABriefing.unclassifiedPensionLimitation` already are. Build
                them together in Phase 6, or neither.
                """
        ),
        UnpinnedDefect(
            state: "NY",
            summary: """
                New York's treatment of RAILROAD RETIREMENT benefits is unresolved, and
                the Phase 5b whole-branch review left it at the status quo rather than
                guessing, following the Arizona railroad precedent above.

                New York's rule now names `nyStateOrLocal`, `federalCivilian` and
                `uniformedServices` at `definedBenefit`. `railroadRetirement` is named by
                none of them, so a row carrying it falls through to the pooled
                `pensionExemption`, New York's capped $20,000 Line 29 exclusion. The
                capped answer is unlikely to be right: 45 U.S.C. 231m is generally read
                as barring state taxation of Railroad Retirement Board benefits outright,
                and Kansas's Schedule S Line A14 exempts them by name, which is why
                `PlanSource.railroadRetirement` exists at all. If that reading holds for
                New York, the direction is UNDER-exemption, i.e. the app over-taxes,
                on everything above $20,000.

                THIS BRANCH CREATED THE REACHABLE FORM OF IT, which is why it is recorded
                here rather than inherited silently. Phase 5b Task 3 added the "Railroad
                Retirement benefits" picker row to every jurisdiction. Before it existed,
                a New York railroad retiree's nearest pick was "Government pension,
                federal civilian", which New York's rule matched and which produced the
                uncapped exclusion; after it, the honest pick produces the capped one. So
                the new row can move this user in the OVER-taxation direction by up to
                the whole pension above $20,000, on the same mechanism the military row
                moved them by, and the military half was fixable from the fixture's own
                authority while this half is not.
                """,
            blockedOn: """
                NO AUTHORITY IN THE FIXTURE, the same blocker as Arizona's railroad entry
                above and resolved the same way. statetax-2026-NY.golden.json carries no
                railroad scenario and cites no New York provision covering these
                benefits; its five cases quote IT-201 Line 26, Line 29 and tax.ny.gov's
                "Information for retired persons" only. Step 1 of the shared procedure
                makes the golden fixture the specification and forbids re-researching the
                law, and neither available answer is derivable from what the fixture
                cites.

                AND THE QUOTED SENTENCE ARGUES AGAINST THE EASY GUESS, which is worth
                recording because it is the reason `railroadRetirement` was NOT added
                alongside `uniformedServices` in the same change. Line 26 eligibility is a
                CLOSED list: an officer, employee, or beneficiary of an officer or
                employee of NYS, a NY locality, certain named NY public authorities, or
                the United States. A retired member of the uniformed services is squarely
                inside it, which is what authorised the military widening. A railroad
                retiree is not: the Railroad Retirement Board administers the benefit, but
                the person was an employee of a private carrier, not of the United States.
                Whatever exempts these benefits in New York is therefore a DIFFERENT
                mechanism from Line 26 (federal preemption, reached through a separate
                subtraction), and encoding it as a Line 26 per-source rule would put an
                uncited claim into a shipped config.

                Resolve by adding a New York golden case derived from New York's own
                published treatment of Railroad Retirement benefits and the federal
                preemption question, then naming `railroadRetirement` in whichever rule
                that case supports. The identical question is open for Arizona and
                Massachusetts, so a single reviewed pass over 45 U.S.C. 231m and the three
                states' forms would close all three at once, and should.
                """
        )
    ]

    @Test("Every known-but-unpinned defect names both a real mechanism and a concrete blocker")
    func knownButUnpinnedIsWellFormed() {
        #expect(!Self.knownButUnpinned.isEmpty, """
            No known-but-unpinned defects recorded. Missouri's public-pension cap is a
            confirmed real defect the phase found and could not pin (see the Task 5
            report and the 2026-08-04 ledger). An empty list here would silently drop
            it from Phase 5's inheritance.
            """)
        for entry in Self.knownButUnpinned {
            #expect(!entry.summary.isEmpty, "\(entry.state): unpinned defect with no mechanism named")
            #expect(!entry.blockedOn.isEmpty, "\(entry.state): unpinned defect with no stated blocker")
        }
    }

    /// Missouri's deletion guard, which the entry has been missing since Phase
    /// 5a and which the Phase 5b whole-branch review added.
    ///
    /// The test above is deliberately weak: it asserts the ARRAY is non-empty
    /// and that each entry's two strings are non-blank, so any INDIVIDUAL entry
    /// deletes in silence. Every other entry is guarded from its jurisdiction's
    /// own Phase 5b test file. Missouri has none, because Missouri was never a
    /// Phase 5b jurisdiction: it is the one entry this list inherited rather
    /// than wrote, and it is the oldest and therefore the likeliest to be
    /// tidied away by someone who no longer remembers why it is here.
    ///
    /// It lives in this file for want of a Missouri suite, which is weaker than
    /// the others only in that a deleter has the entry and the guard on screen
    /// at once. It is not weaker in what it PROVES: the condition is re-derived
    /// from Missouri's shipped configuration, so the entry cannot outlive the
    /// defect either. Move it to a Missouri suite the moment one exists.
    @Test("Missouri's uncapped public-pension exemption stays recorded as a known-but-unpinned defect")
    func theMissouriPublicPensionCapGapStaysRecorded() throws {
        let entry = try #require(
            Self.knownButUnpinned.first {
                $0.state == "MO" && $0.summary.contains("Social Security benefit")
            },
            """
            Missouri's public-pension cap defect is no longer recorded. MO-A 2025 Part 3
            Section A Line 2 caps the exemption at the LESSER of the pension received or
            each individual's own maximum Social Security benefit, reduced by any Social
            Security deduction the same person claims; this app codes it as unlimited,
            measured at $0.00 against a correct $6,157.41 for a $150,000 / $120,000 MFJ
            public-pension household. If a Missouri golden case now pins that figure,
            delete this test alongside the entry and say which case replaced it. If not,
            a confirmed defect was dropped from the phase's inheritance.
            """)
        // Substrings must not straddle a line break in the entry's multiline
        // literal, which is why this selects short, single-line fragments
        // rather than whole sentences.
        #expect(entry.blockedOn.contains("ssa.gov"))

        // The condition, re-derived from the shipped config rather than
        // restated: Missouri's pooled pension exemption is still UNCAPPED, which
        // is the whole mechanism the entry describes.
        let missouri = StateTaxData.config(for: .missouri).retirementExemptions
        if case .full = missouri.pensionExemption {} else {
            Issue.record("""
                Missouri's pensionExemption is no longer `.full`. If it was capped against \
                the MO-A Line 2 maximum, this entry is resolved and must be deleted with \
                this test, and the correction needs a golden case and a baseline-movement \
                ledger record like every other Phase 5 correction.
                """)
        }
    }
}
