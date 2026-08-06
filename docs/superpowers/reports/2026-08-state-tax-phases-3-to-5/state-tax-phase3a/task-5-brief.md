### Task 5: Per-qualifying-spouse attribution

Spec §3.3e. The age gate today is `max(primaryAge, spouseAge)` for the exemption level and `||` for the distribution gate, so **either** spouse qualifying unlocks the exemption for all household retirement income. At least seven statutes (OK, DE, LA, AR, AL, WI, RI) are per-person, and Iowa's exclusion is explicitly per-qualifying-spouse.

**Files:**
- Modify: `RetireSmartIRA/StateTaxData.swift`
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift`
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

**Interfaces:**
- Produces: `ExemptionAttribution` (enum, `.household` default) and `RetirementIncomeExemptions.exemptionAttribution: ExemptionAttribution`.

**The convention this task chooses, and it is the only place in Phase 3a that chooses one.** Under `.perQualifyingSpouse`:
- A `.pension` or `.rmd` `IncomeSource` row is gated by ITS OWNER's age. `IncomeSource` already carries `owner: Owner` and the military-retirement loop directly above already uses it this way, so this reuses an established pattern rather than inventing one.
- An `.joint`-owned row is gated by the more generous of the two ages, matching what `.joint` means everywhere else in this codebase.
- `scenarioRetirementDistributions` is a single scalar with no owner in the engine's signature, so it is gated on the PRIMARY's age. Write this limitation into the doc comment in the same sentence as the rule, and state that a state adopting `.perQualifyingSpouse` must carry a matching `knownLimitations` entry.

None of this is reachable in Phase 3a: every state stays `.household`. Iowa's Phase 4 golden scenario is what confirms or corrects the convention, and it will be the first case that can.

- [ ] **Step 1: Write the failing test**

Add to `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`:

```swift
    // MARK: - attribution

    static func mfjTax(
        config: StateTaxConfig, primaryAge: Int, spouseAge: Int,
        sources: [IncomeSource], scenarioDistributions: Double = 0
    ) -> Double {
        let income = sources.reduce(0) { $0 + $1.annualAmount } + scenarioDistributions
        return TaxCalculationEngine.calculateStateTax(
            income: income, forState: .iowa, filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: primaryAge, enableSpouse: true,
            spouseBirthYear: 2026 - spouseAge, currentYear: 2026,
            scenarioRetirementDistributions: scenarioDistributions,
            configOverride: config)
    }

    static func attributionConfig(_ attribution: ExemptionAttribution) -> StateTaxConfig {
        flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .full,
            iraWithdrawalExemption: .full,
            regularExemptionMinAge: 65,
            exemptionAttribution: attribution))
    }

    @Test("Household attribution exempts a non-qualifying spouse's pension when the other qualifies")
    func householdAttributionIsTodaysBehavior() {
        let config = Self.attributionConfig(.household)
        let spousePension = [IncomeSource(name: "Pension", type: .pension,
                                          annualAmount: 40_000, owner: .spouse)]
        // Primary 70 qualifies, spouse 60 does not. Household: fully exempt.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: spousePension) == 0)
    }

    @Test("Per-qualifying-spouse attribution taxes the non-qualifying spouse's own pension")
    func perQualifyingSpouseAttributionGatesByOwner() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        let spousePension = [IncomeSource(name: "Pension", type: .pension,
                                          annualAmount: 40_000, owner: .spouse)]
        // Spouse is 60, below the 65 gate, so the spouse's own pension is taxed
        // even though the primary qualifies.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: spousePension) == 4_000)
        // Once the spouse qualifies, it is exempt again. Without this second
        // case the first could pass for a config that exempts nothing.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 66,
                            sources: spousePension) == 0)
    }

    @Test("Per-qualifying-spouse attribution still exempts the qualifying spouse's own pension")
    func perQualifyingSpouseAttributionKeepsTheQualifyingOwnersExemption() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        let primaryPension = [IncomeSource(name: "Pension", type: .pension,
                                           annualAmount: 40_000, owner: .primary)]
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: primaryPension) == 0)
    }

    @Test("A joint-owned row qualifies when either spouse qualifies, under both attributions")
    func jointOwnedRowsUseTheMoreGenerousAge() {
        let jointPension = [IncomeSource(name: "Pension", type: .pension,
                                         annualAmount: 40_000, owner: .joint)]
        #expect(Self.mfjTax(config: Self.attributionConfig(.household),
                            primaryAge: 70, spouseAge: 60, sources: jointPension) == 0)
        #expect(Self.mfjTax(config: Self.attributionConfig(.perQualifyingSpouse),
                            primaryAge: 70, spouseAge: 60, sources: jointPension) == 0)
    }

    @Test("Scenario distributions have no owner, so per-spouse attribution gates them on the primary")
    func scenarioDistributionsAreAttributedToThePrimary() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        // Primary 60 below the gate, spouse 70 above it. Household would exempt;
        // per-spouse attributes the unowned scalar to the primary, so it is taxed.
        #expect(Self.mfjTax(config: config, primaryAge: 60, spouseAge: 70,
                            sources: [], scenarioDistributions: 40_000) == 4_000)
        #expect(Self.mfjTax(config: Self.attributionConfig(.household),
                            primaryAge: 60, spouseAge: 70,
                            sources: [], scenarioDistributions: 40_000) == 0)
    }

    @Test("Every jurisdiction uses household attribution in Phase 3a")
    func noStateUsesPerSpouseAttributionYet() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        for state in USState.allCases {
            let config = try #require(configs[state])
            #expect(config.retirementExemptions.exemptionAttribution == .household,
                    "\(state.abbreviation) changed attribution in Phase 3a. Iowa and the \
                    per-person statutes adopt it in Phase 5c, each gated by a golden scenario.")
        }
    }
```

`IncomeSource`'s initializer signature must be checked before writing these: confirm `owner:` is an accepted argument with a default, and match the real parameter order. Run `grep -n "init(" -A 20 RetireSmartIRA/IncomeModels.swift` first.

- [ ] **Step 2: Run it, watch it fail to compile**

Expected: `cannot find 'ExemptionAttribution' in scope`. Paste it.

- [ ] **Step 3: Add the type and field**

In `RetireSmartIRA/StateTaxData.swift`, above `struct RetirementIncomeExemptions`:

```swift
/// How a state's retirement exemption is attributed between spouses on a
/// joint return.
enum ExemptionAttribution: String, Codable, Equatable, Sendable {
    /// Either spouse qualifying unlocks the exemption for all of the
    /// household's retirement income. This is what the engine did for every
    /// state before Phase 3a and it remains every state's value through
    /// Phase 3a.
    case household

    /// Each spouse's exemption is gated by that spouse's own age and applies
    /// only to income attributed to that spouse. Iowa's exclusion is written
    /// this way, as are at least seven other per-person statutes (OK, DE, LA,
    /// AR, AL, WI, RI).
    ///
    /// ATTRIBUTION RULES, and the one limitation they carry:
    ///   - A `.pension` or `.rmd` income row is gated by its `owner`'s age.
    ///   - A `.joint`-owned row is gated by the more generous of the two ages,
    ///     which is what `.joint` means elsewhere in this codebase.
    ///   - `scenarioRetirementDistributions` reaches the engine as a single
    ///     scalar with no owner, so it is gated on the PRIMARY's age. A state
    ///     adopting this case must carry a `knownLimitations` sentence saying
    ///     so, because a household whose spouse holds the IRA will be modeled
    ///     conservatively.
    case perQualifyingSpouse
}
```

Inside `RetirementIncomeExemptions`, after `exemptionAppliesPerIndividual`:

```swift
    /// See `ExemptionAttribution`. `.household` reproduces the behavior every
    /// state had before Phase 3a.
    var exemptionAttribution: ExemptionAttribution = .household
```

- [ ] **Step 4: Wire the engine**

In `applyRetirementExemptions`, `effectiveAge` and the `pensionIncome` / `rmdSourceIncome` sums become attribution-aware. Replace the `pensionIncome` and `rmdSourceIncome` computations with owner-filtered versions:

```swift
        /// Whether income owned by `owner` is eligible under the state's
        /// attribution rule. Under `.household` every row is eligible when any
        /// spouse qualifies, which is what `effectiveAge` already encodes.
        func ownerQualifies(_ owner: Owner) -> Bool {
            guard exemptions.exemptionAttribution == .perQualifyingSpouse, enableSpouse else {
                return true
            }
            switch owner {
            case .primary: return ageQualifiesForExemption(primaryAge)
            case .spouse:  return ageQualifiesForExemption(spouseAge)
            case .joint:   return ageQualifiesForExemption(primaryAge)
                                || ageQualifiesForExemption(spouseAge)
            }
        }

        let pensionIncome = incomeSources
            .filter { $0.type == .pension && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }
        let rmdSourceIncome = incomeSources
            .filter { $0.type == .rmd && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }
```

and the scalar's gate:

```swift
        // Under `.perQualifyingSpouse` the scalar has no owner to attribute it
        // to, so it is gated on the primary. See ExemptionAttribution.
        let retirementAge: Bool
        switch exemptions.exemptionAttribution {
        case .household:
            retirementAge = primaryAge >= exemptions.distributionMinAge
                || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
        case .perQualifyingSpouse:
            retirementAge = primaryAge >= exemptions.distributionMinAge
        }
```

**Placement.** On `main` @ `e540e9f` the nested `ageQualifiesForExemption` is declared around line 531, `pensionIncome` around 571 and `rmdSourceIncome` around 582, so `ownerQualifies` slots in between with nothing to move. Verify those positions before editing rather than trusting these numbers: earlier tasks in this phase touch the same function and will have shifted them.

`.rmd` rows keep their existing ungated treatment under `.household`, which is every state's setting in this phase. Do not take the opportunity to gate them: the divergence where an ungated `.rmd` row and a 59-gated scalar disagree is a real finding from Phase 2 and it is pinned by the baseline scenario "single 55 rmd rows not scenario distributions". Closing it here would be an unattributed behavior change.

- [ ] **Step 5: Codable**

`ExemptionAttribution` is a `String`-backed enum, so its conformance is synthesized. Add `exemptionAttribution` to `RetirementIncomeExemptions`'s `CodingKeys`, `try c.encode(exemptionAttribution, forKey: .exemptionAttribution)` to `encode(to:)`, and to `init(from:)`:

```swift
            exemptionAttribution: try c.decodeIfPresent(
                ExemptionAttribution.self, forKey: .exemptionAttribution) ?? .household,
```

- [ ] **Step 6: Run the mechanism tests and the baseline, then the full suite**

The baseline scenarios "MFJ 57 with spouse 61" and "MFJ 61 with spouse 56" are the ones that catch an accidental attribution change here. Confirm they pass, then run the full suite tee'd to `/tmp/phase3a-task5.log`, paste both summary lines, confirm the tree.

- [ ] **Step 7: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): per-qualifying-spouse attribution mode, every state still household"
```

---

