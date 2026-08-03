import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 3a adds fields that every state leaves at its default, so the phase
/// gate proves only that they changed nothing. That is necessary and not
/// sufficient: a field the engine never reads would also change nothing.
///
/// This suite proves each new field is LOAD-BEARING, by building a synthetic
/// config with the field set away from its default and asserting the engine
/// responds. Every state's real config still uses the default; these are
/// hand-built configs passed through `configOverride`.
@Suite("Phase 3a mechanisms are load-bearing")
struct StateTaxPhase3aMechanismTests {

    /// A flat 10% state with a full IRA exemption, so the exemption's presence
    /// or absence is visible as a clean 10% of the distribution amount.
    static func flatTenPercent(
        exemptions: RetirementIncomeExemptions
    ) -> StateTaxConfig {
        StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.10),
            retirementExemptions: exemptions,
            stateDeduction: .none
        )
    }

    static func tax(config: StateTaxConfig, age: Int, distributions: Double) -> Double {
        TaxCalculationEngine.calculateStateTax(
            income: distributions,
            forState: .iowa,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: [],
            currentAge: age,
            enableSpouse: false,
            spouseBirthYear: 2026 - age,
            currentYear: 2026,
            scenarioRetirementDistributions: distributions,
            configOverride: config
        )
    }

    @Test("distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59")
    func distributionMinAgeIsHonored() {
        let atFiftyFive = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                distributionMinAge: 55))
        let atDefault = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full))

        // Age 56: exempt under a 55 gate, taxed under the default 59 gate.
        #expect(Self.tax(config: atFiftyFive, age: 56, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 56, distributions: 40_000) == 4_000)

        // Age 60 is above both gates, so both configs exempt. This pair does
        // not catch a mutant the pair above misses; it documents the intended
        // shape of the boundary, that the two configs agree above it and
        // disagree below it.
        #expect(Self.tax(config: atFiftyFive, age: 60, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 60, distributions: 40_000) == 0)
    }

    @Test("distributionMinAge defaults to 59, reproducing the previous hardcoded gate")
    func distributionMinAgeDefaultsTo59() {
        #expect(RetirementIncomeExemptions().distributionMinAge == 59)
    }

    @Test("distributionMinAge also gates per-individual cap doubling, not only scenario distributions")
    func distributionMinAgeGatesPerIndividualDoubling() {
        // Reaches `ageQualifiesForExemption`, which is only called from
        // `bothSpousesQualify` and therefore needs enableSpouse: true. Its
        // distributionMinAge fallback runs only when regularExemptionMinAge is
        // 0, so this config leaves that at its default. A $20,000 partial cap
        // that doubles is the cheapest way to make the multiplier observable.
        func config(distributionMinAge: Int) -> StateTaxConfig {
            Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 20_000),
                iraWithdrawalExemption: .none,
                exemptionAppliesPerIndividual: true,
                distributionMinAge: distributionMinAge))
        }

        func tax(config: StateTaxConfig, spouseAge: Int) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 40_000, forState: .iowa, filingStatus: .marriedFilingJointly,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                             annualAmount: 40_000)],
                currentAge: 60, enableSpouse: true,
                spouseBirthYear: 2026 - spouseAge, currentYear: 2026,
                configOverride: config)
        }

        // Spouse is 56. Under a 55 gate BOTH spouses qualify, the cap doubles
        // to 40,000 and the whole pension is excluded. Under the default 59
        // gate the spouse does not qualify, the cap stays 20,000, and 20,000
        // remains taxable at 10 percent.
        #expect(tax(config: config(distributionMinAge: 55), spouseAge: 56) == 0)
        #expect(tax(config: config(distributionMinAge: 59), spouseAge: 56) == 2_000)

        // Spouse at 60 is above BOTH gates, so both configs double the cap.
        // Without this pair the first could pass for a config that simply
        // never doubles.
        #expect(tax(config: config(distributionMinAge: 55), spouseAge: 60) == 0)
        #expect(tax(config: config(distributionMinAge: 59), spouseAge: 60) == 0)
    }

    // MARK: - personalExemption

    /// New Jersey's four documented outcomes, from
    /// TaxCalculationEngine.njPersonalExemptions' own doc comment:
    ///   single under 65 -> 1,000; single 65+ -> 2,000;
    ///   MFJ both under 65 -> 2,000; MFJ both 65+ -> 4,000.
    static let njExemption = StatePersonalExemption(
        single: 1_000, marriedFilingJointly: 2_000,
        seniorAdditionalPerFiler: 1_000, seniorAge: 65)

    @Test("StatePersonalExemption reproduces New Jersey's four documented outcomes")
    func personalExemptionMatchesNJ() {
        let e = Self.njExemption
        #expect(e.amount(filingStatus: .single, enableSpouse: false,
                         primaryAge: 64, spouseAge: 64) == 1_000)
        #expect(e.amount(filingStatus: .single, enableSpouse: false,
                         primaryAge: 65, spouseAge: 65) == 2_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                         primaryAge: 64, spouseAge: 64) == 2_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                         primaryAge: 65, spouseAge: 65) == 4_000)
    }

    @Test("A filer on MFJ with no spouse configured gets the single amounts")
    func personalExemptionIgnoresMFJWithoutASpouse() {
        let e = Self.njExemption
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: false,
                         primaryAge: 64, spouseAge: 64) == 1_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: false,
                         primaryAge: 70, spouseAge: 70) == 2_000)
    }

    @Test("Only one spouse over the senior age gets exactly one senior addition")
    func personalExemptionSeniorIsPerFiler() {
        #expect(Self.njExemption.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                                        primaryAge: 66, spouseAge: 60) == 3_000)
    }

    @Test("A state with no senior addition ignores age entirely")
    func personalExemptionWithoutSeniorTierIgnoresAge() {
        // Shaped like Kansas: a flat per-return amount, no age component.
        // NOTE: Kansas's real config is NOT given this value in Phase 3a.
        // Correcting Kansas is Phase 5a, gated by a golden scenario.
        let flat = StatePersonalExemption(
            single: 9_160, marriedFilingJointly: 18_320,
            seniorAdditionalPerFiler: 0, seniorAge: 65)
        #expect(flat.amount(filingStatus: .single, enableSpouse: false,
                            primaryAge: 80, spouseAge: 80) == 9_160)
        #expect(flat.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                            primaryAge: 80, spouseAge: 80) == 18_320)
    }

    @Test("New Jersey's shipped config carries its four exemption values exactly")
    func newJerseyConfigExemptionValuesArePinned() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let nj = try #require(configs[.newJersey]?.personalExemption)
        // Pinned against the CONFIG, not against a hand-built fixture that
        // duplicates it. NJ-1040: $1,000 regular per filer, plus $1,000 per
        // filer age 65+. Without this, seniorAge could be set anywhere from 62
        // to 65 and every existing NJ test would still pass, silently granting
        // an exemption to filers aged 63 and 64.
        #expect(nj.single == 1_000)
        #expect(nj.marriedFilingJointly == 2_000)
        #expect(nj.seniorAdditionalPerFiler == 1_000)
        #expect(nj.seniorAge == 65)
    }

    @Test("New Jersey's config carries the personal exemption; no other state does")
    func onlyNewJerseyCarriesAPersonalExemptionInPhase3a() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        for state in USState.allCases {
            let config = try #require(configs[state])
            if state == .newJersey {
                #expect(config.personalExemption != nil)
            } else {
                #expect(config.personalExemption == nil,
                        """
                        \(state.abbreviation) gained a personal exemption in Phase 3a. \
                        Phase 3a adds no state's exemption except New Jersey's, which \
                        already existed in hardcoded form. Kansas and the rest are Phase 5a.
                        """)
            }
        }
    }

    // MARK: - AGI phase-out

    @Test("A cliff phase-out removes the whole exclusion above the threshold and nothing below it")
    func agiPhaseoutCliff() {
        let cliff = AGIPhaseout(thresholdSingle: 28_500, thresholdMFJ: 51_000, shape: .cliff)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 28_500, isMarried: false) == 8_000)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 28_501, isMarried: false) == 0)
        // The MFJ threshold is a DIFFERENT number, so a single/married swap is visible.
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 40_000, isMarried: true) == 8_000)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 40_000, isMarried: false) == 0)
    }

    @Test("A dollar-for-dollar phase-out reduces the exclusion by the excess and floors at zero")
    func agiPhaseoutLinearDollarForDollar() {
        // Virginia's shape: $12,000 reduced $1 per $1 over $50,000 / $75,000.
        let va = AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                             shape: .linear(perDollar: 1.0))
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 50_000, isMarried: false) == 12_000)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 55_000, isMarried: false) == 7_000)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 62_000, isMarried: false) == 0)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 90_000, isMarried: false) == 0)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 80_000, isMarried: true) == 7_000)
    }

    @Test("A fractional ramp reaches zero at the far end of the band")
    func agiPhaseoutLinearFractional() {
        // Connecticut's shape: full below 75,000, zero at 100,000, so a
        // 100% exclusion of a 40,000 pension ramps out over a 25,000 band.
        let ct = AGIPhaseout(thresholdSingle: 75_000, thresholdMFJ: 100_000,
                             shape: .linear(perDollar: 40_000 / 25_000))
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 75_000, isMarried: false) == 40_000)
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 87_500, isMarried: false) == 20_000)
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 100_000, isMarried: false) == 0)
    }

    @Test("agiPhaseout reaches the engine and reduces real computed tax")
    func agiPhaseoutIsWiredIntoTheEngine() {
        let exemptions = RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .partial(maxExempt: 12_000),
            iraWithdrawalExemption: .none,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0)))
        let config = Self.flatTenPercent(exemptions: exemptions)

        func tax(income: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: income, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                             annualAmount: 40_000)],
                currentAge: 70, enableSpouse: false, spouseBirthYear: 1956,
                currentYear: 2026, configOverride: config)
        }
        // At 50,000: full 12,000 exclusion -> 38,000 taxable -> 3,800.
        #expect(tax(income: 50_000) == 3_800)
        // At 55,000: exclusion cut to 7,000 -> 48,000 taxable -> 4,800.
        #expect(tax(income: 55_000) == 4_800)
        // At 70,000: exclusion gone -> 70,000 taxable -> 7,000.
        #expect(tax(income: 70_000) == 7_000)
    }

    @Test("agiPhaseout reduces the exclusion in the shared-cap branch too")
    func agiPhaseoutAppliesInTheSharedCapBranch() {
        // pensionAndIRAShareSingleCap routes pension and IRA through ONE
        // combined subtraction, a different branch from the per-type one
        // above. Three states set this flag today, so a phase-out landing on
        // one of them in Phase 5 must be reduced here as well.
        let config = Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .partial(maxExempt: 12_000),
            iraWithdrawalExemption: .partial(maxExempt: 12_000),
            pensionAndIRAShareSingleCap: true,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0))))

        func tax(income: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: income, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                             annualAmount: 40_000)],
                currentAge: 70, enableSpouse: false, spouseBirthYear: 1956,
                currentYear: 2026, configOverride: config)
        }
        // At 50,000 the full 12,000 shared cap applies: 38,000 taxable, 3,800.
        #expect(tax(income: 50_000) == 3_800)
        // At 55,000 the exclusion is cut by 5,000 to 7,000: 48,000 taxable, 4,800.
        #expect(tax(income: 55_000) == 4_800)
        // At 70,000 the exclusion is gone entirely: 70,000 taxable, 7,000.
        #expect(tax(income: 70_000) == 7_000)
    }

    @Test("agiPhaseout reduces the IRA subtraction, not only the pension one")
    func agiPhaseoutAppliesToTheIRASubtraction() {
        // The per-type branch subtracts pension and IRA separately. The
        // existing engine test leaves iraWithdrawalExemption at .none and
        // supplies no IRA income, so the IRA-side reduction is a no-op there
        // and a dropped reduction on that line survives. All six jurisdictions
        // this mechanism was built for phase out exclusions covering IRA
        // withdrawals, so this is the side that matters most.
        let config = Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .none,
            iraWithdrawalExemption: .partial(maxExempt: 12_000),
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0))))

        func tax(income: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: income, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "IRA", type: .rmd,
                                             annualAmount: 40_000)],
                currentAge: 70, enableSpouse: false, spouseBirthYear: 1956,
                currentYear: 2026, configOverride: config)
        }
        #expect(tax(income: 50_000) == 3_800)
        #expect(tax(income: 55_000) == 4_800)
        #expect(tax(income: 70_000) == 7_000)
    }

    @Test("No jurisdiction ships an agiPhaseout key in Phase 3a")
    func noStateShipsAnAGIPhaseoutKey() throws {
        var carriers: [String] = []
        for state in USState.allCases {
            let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: url)) as? [String: Any]
            let exemptions = object?["retirementExemptions"] as? [String: Any]
            if exemptions?["agiPhaseout"] != nil { carriers.append(state.abbreviation) }
        }
        // Raw keys, not decoded values: a broken decodeIfPresent would let a
        // decoded-value assertion pass against a file that does carry the key.
        #expect(carriers.isEmpty,
                """
                CT, VA, ME, RI, WV and NM get their phase-outs in Phase 5, each gated \
                by a golden scenario that also pins the correct income basis. Found: \(carriers)
                """)
    }

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
                    """
                    \(state.abbreviation) changed attribution in Phase 3a. Iowa and the \
                    per-person statutes adopt it in Phase 5c, each gated by a golden scenario.
                    """)
        }
    }
}
