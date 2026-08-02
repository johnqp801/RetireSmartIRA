import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax Codable round trips (Phase 1)")
struct StateTaxCodableRoundTripTests {

    @Test("StateVerification round-trips through JSON")
    func verificationRoundTrips() throws {
        let original = StateVerification(
            lastVerified: "2026-08-02",
            primarySources: ["https://www.ksrevenue.gov/webfile/help/scheduleS_A.html"],
            billReferences: ["SB 1 (2024 special session)"],
            knownLimitations: ["Public pensions are not distinguished from private."]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StateVerification.self, from: data)
        #expect(decoded == original)
    }

    @Test("StateVerification defaults to unverified with empty collections")
    func verificationUnverifiedDefault() {
        let unverified = StateVerification.unverified
        #expect(unverified.lastVerified == "")
        #expect(unverified.primarySources.isEmpty)
        #expect(unverified.knownLimitations.isEmpty)
        #expect(unverified.billReferences.isEmpty)
        #expect(unverified.isVerified == false)
    }

    @Test("StateTaxSystem round-trips every case")
    func taxSystemRoundTrips() throws {
        let cases: [StateTaxSystem] = [
            .noIncomeTax,
            .specialLimited,
            .flat(rate: 0.038),
            .progressive(
                single: [TaxBracket(threshold: 0, rate: 0.052),
                         TaxBracket(threshold: 23_000, rate: 0.0558)],
                married: [TaxBracket(threshold: 0, rate: 0.052),
                          TaxBracket(threshold: 46_000, rate: 0.0558)]
            )
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateTaxSystem.self, from: data)
            #expect(decoded.matchesShape(of: original), "round trip lost \(original)")
        }
    }

    @Test("StateDeduction round-trips every case")
    func stateDeductionRoundTrips() throws {
        let cases: [StateDeduction] = [
            .none,
            .conformsToFederal,
            .fixed(single: 3_360, married: 3_360),
            .fixed(single: 8_000, married: 16_000)
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateDeduction.self, from: data)
            switch (decoded, original) {
            case (.none, .none), (.conformsToFederal, .conformsToFederal):
                break
            case let (.fixed(s1, m1), .fixed(s2, m2)):
                #expect(s1 == s2 && m1 == m2)
            default:
                Issue.record("round trip lost \(original)")
            }
        }
    }

    @Test("EstimatedPaymentSchedule round-trips")
    func estimatedScheduleRoundTrips() throws {
        let original = EstimatedPaymentSchedule.california
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EstimatedPaymentSchedule.self, from: data)
        #expect(decoded == original)
    }

    @Test("StateSafeHarborRule round-trips every case")
    func safeHarborRoundTrips() throws {
        let cases: [StateSafeHarborRule] = [
            .mirrorsFederal,
            .flatRate(1.10),
            .agiThreshold(threshold: 250_000, lowRate: 1.00, highRate: 1.10),
            .mirrorsFederalWithDisqualification(disqualifyAGI: 1_000_000),
            .noPenalty
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StateSafeHarborRule.self, from: data)
            #expect(decoded == original, "round trip lost \(original)")
        }
    }

    @Test("ExemptionLevel round-trips every case including NJ's stepped phaseout")
    func exemptionLevelRoundTrips() throws {
        let cases: [RetirementIncomeExemptions.ExemptionLevel] = [
            .none,
            .full,
            .partial(maxExempt: 31_110),
            .steppedPhaseoutByFilingStatus(
                maxExemptSingle: 75_000,
                maxExemptMFJ: 100_000,
                tiers: [
                    .init(upperBound: 100_000, mfjPercent: 1.0, singlePercent: 1.0),
                    .init(upperBound: 125_000, mfjPercent: 0.50, singlePercent: 0.375),
                    .init(upperBound: 150_000, mfjPercent: 0.25, singlePercent: 0.1875),
                    .init(upperBound: .infinity, mfjPercent: 0.0, singlePercent: 0.0)
                ]
            )
        ]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(
                RetirementIncomeExemptions.ExemptionLevel.self, from: data)
            // Compare behaviorally: the exclusion each produces must match.
            // eligibleIncome includes 90_000, which sits strictly between NJ's
            // two caps (75_000 single / 100_000 MFJ). At totalGrossIncome
            // 40_000 or 90_000 (both within the first, 100%-retained tier),
            // chartMax's percent >= 1.0 branch returns the cap directly, so
            // excludedAmount clamps to min(eligibleIncome, cap). With
            // eligibleIncome 50_000 that clamp never binds (50_000 is below
            // both caps), so a swap of maxExemptSingle/maxExemptMFJ would be
            // invisible; 90_000 is above the single cap and below the MFJ cap,
            // so a swap changes the single-filer result and is caught.
            for eligibleIncome in [50_000.0, 90_000.0] {
                for income in [40_000.0, 90_000.0, 130_000.0, 200_000.0] {
                    for married in [true, false] {
                        #expect(
                            decoded.excludedAmount(eligibleIncome: eligibleIncome,
                                                   totalGrossIncome: income,
                                                   isMarried: married,
                                                   perIndividualMultiplier: 1)
                            == original.excludedAmount(eligibleIncome: eligibleIncome,
                                                       totalGrossIncome: income,
                                                       isMarried: married,
                                                       perIndividualMultiplier: 1),
                            "round trip changed behavior at eligibleIncome \(eligibleIncome) income \(income) married \(married)")
                    }
                }
            }
            // Structural check on the caps and tiers, in addition to the
            // behavioral check above. It is necessary: tierPercent's lookup is
            // `tiers.first { income <= $0.upperBound } ?? tiers.last`, so the
            // LAST tier is always selected as a fallback regardless of its own
            // upperBound value. That makes excludedAmount() blind to corruption
            // of the last tier's bound specifically -- a decode that silently
            // turned .infinity into 0 would still pass every behavioral
            // assertion above. Confirmed by mutation testing during
            // implementation. This check closes that gap directly. The caps
            // are bound and compared here too (not discarded with `_, _,`)
            // because a maxExemptSingle/maxExemptMFJ swap is a similarly quiet
            // regression that the behavioral loop above only partially covers.
            if case .steppedPhaseoutByFilingStatus(let originalSingle, let originalMFJ, let originalTiers) = original,
               case .steppedPhaseoutByFilingStatus(let decodedSingle, let decodedMFJ, let decodedTiers) = decoded {
                #expect(originalSingle == decodedSingle,
                        "round trip changed maxExemptSingle")
                #expect(originalMFJ == decodedMFJ,
                        "round trip changed maxExemptMFJ")
                #expect(decodedTiers.count == originalTiers.count,
                        "round trip changed the tier count")
                for (o, d) in zip(originalTiers, decodedTiers) {
                    #expect(o.upperBound.isInfinite == d.upperBound.isInfinite,
                            "round trip changed whether a tier's upperBound is infinite")
                    if !o.upperBound.isInfinite {
                        #expect(o.upperBound == d.upperBound,
                                "round trip changed a finite tier's upperBound")
                    }
                    #expect(o.mfjPercent == d.mfjPercent && o.singlePercent == d.singlePercent,
                            "round trip changed a tier's percentages")
                }
            }
        }
    }

    @Test("RetirementIncomeExemptions round-trips with every field populated")
    func retirementExemptionsRoundTrip() throws {
        let original = RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .partial(maxExempt: 65_000),
            iraWithdrawalExemption: .partial(maxExempt: 42_000),
            exemptionAppliesPerIndividual: true,
            regularExemptionMinAge: 65,
            earlyAgeTier: .init(ageRange: 62...64, level: .partial(maxExempt: 35_000)),
            pensionAndIRAShareSingleCap: true,
            otherRetirementIncomeExclusion: true,
            capitalGainsTreatment: .taxedAsOrdinary
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: data)

        #expect(decoded.socialSecurityExempt == original.socialSecurityExempt)
        #expect(decoded.exemptionAppliesPerIndividual == original.exemptionAppliesPerIndividual)
        #expect(decoded.regularExemptionMinAge == original.regularExemptionMinAge)
        #expect(decoded.pensionAndIRAShareSingleCap == original.pensionAndIRAShareSingleCap)
        #expect(decoded.otherRetirementIncomeExclusion == original.otherRetirementIncomeExclusion)
        // ExemptionLevel/CapGainsTreatment aren't Equatable in production code
        // (same reason exemptionLevelRoundTrips above compares behaviorally),
        // so compare structurally via the matchesShape helpers below.
        // pensionExemption (65_000) and iraWithdrawalExemption (42_000) use
        // distinct values so a field swap between them is visible.
        #expect(decoded.pensionExemption.matchesShape(of: original.pensionExemption),
                "round trip lost or corrupted pensionExemption")
        #expect(decoded.iraWithdrawalExemption.matchesShape(of: original.iraWithdrawalExemption),
                "round trip lost or corrupted iraWithdrawalExemption")
        #expect(decoded.capitalGainsTreatment.matchesShape(of: original.capitalGainsTreatment),
                "round trip lost or corrupted capitalGainsTreatment")

        switch (decoded.earlyAgeTier, original.earlyAgeTier) {
        case let (d?, o?):
            #expect(d.ageRange == o.ageRange)
            #expect(d.level.matchesShape(of: o.level), "round trip lost or corrupted earlyAgeTier.level")
        case (nil, nil):
            break
        default:
            Issue.record("round trip changed earlyAgeTier presence")
        }
    }

    @Test("Decoding tolerates a file missing optional fields")
    func retirementExemptionsDecodesSparseJSON() throws {
        let sparse = Data("""
        {"socialSecurityExempt": true,
         "pensionExemption": {"kind": "none"},
         "iraWithdrawalExemption": {"kind": "none"}}
        """.utf8)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: sparse)
        #expect(decoded.regularExemptionMinAge == 0)
        #expect(decoded.earlyAgeTier == nil)
        #expect(decoded.exemptionAppliesPerIndividual == false)
        #expect(decoded.pensionAndIRAShareSingleCap == false)
        #expect(decoded.otherRetirementIncomeExclusion == false)
        #expect(decoded.capitalGainsTreatment.matchesShape(of: .followsFederal))
    }

    @Test("Decoding a completely empty JSON object yields every declared default")
    func retirementExemptionsDecodesAllDefaultsFromEmptyJSON() throws {
        // Guards the highest-risk detail in this task: socialSecurityExempt's
        // declared default is `true`, not `false`. This is the one case where
        // the JSON key is genuinely absent (not merely present-and-true, as in
        // the sparse test above), so a `?? false` typo in init(from:) would be
        // caught here and nowhere else.
        let empty = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: empty)
        #expect(decoded.socialSecurityExempt == true)
        #expect(decoded.pensionExemption.matchesShape(of: .none))
        #expect(decoded.iraWithdrawalExemption.matchesShape(of: .none))
        #expect(decoded.exemptionAppliesPerIndividual == false)
        #expect(decoded.regularExemptionMinAge == 0)
        #expect(decoded.earlyAgeTier == nil)
        #expect(decoded.pensionAndIRAShareSingleCap == false)
        #expect(decoded.otherRetirementIncomeExclusion == false)
        #expect(decoded.capitalGainsTreatment.matchesShape(of: .followsFederal))
    }
}

extension RetirementIncomeExemptions.ExemptionLevel {
    /// Structural equality for test assertions. ExemptionLevel does not
    /// conform to Equatable in production code (see exemptionLevelRoundTrips
    /// above, which compares behaviorally for the same reason).
    func matchesShape(of other: Self) -> Bool {
        switch (self, other) {
        case (.none, .none), (.full, .full):
            return true
        case let (.partial(a), .partial(b)):
            return a == b
        case let (.steppedPhaseoutByFilingStatus(s1, m1, t1), .steppedPhaseoutByFilingStatus(s2, m2, t2)):
            return s1 == s2 && m1 == m2 && t1.count == t2.count &&
                zip(t1, t2).allSatisfy {
                    $0.upperBound == $1.upperBound &&
                    $0.mfjPercent == $1.mfjPercent &&
                    $0.singlePercent == $1.singlePercent
                }
        default:
            return false
        }
    }
}

extension RetirementIncomeExemptions.CapGainsTreatment {
    /// Structural equality for test assertions; not Equatable in production code.
    func matchesShape(of other: Self) -> Bool {
        switch (self, other) {
        case (.followsFederal, .followsFederal),
             (.taxedAsOrdinary, .taxedAsOrdinary),
             (.noStateTax, .noStateTax):
            return true
        default:
            return false
        }
    }
}

extension StateTaxSystem {
    /// Structural equality ignoring TaxBracket.id, which is regenerated on decode.
    func matchesShape(of other: StateTaxSystem) -> Bool {
        switch (self, other) {
        case (.noIncomeTax, .noIncomeTax), (.specialLimited, .specialLimited):
            return true
        case let (.flat(a), .flat(b)):
            return a == b
        case let (.progressive(s1, m1), .progressive(s2, m2)):
            let sameBrackets: ([TaxBracket], [TaxBracket]) -> Bool = { x, y in
                x.count == y.count && zip(x, y).allSatisfy {
                    $0.threshold == $1.threshold && $0.rate == $1.rate
                }
            }
            return sameBrackets(s1, s2) && sameBrackets(m1, m2)
        default:
            return false
        }
    }
}
