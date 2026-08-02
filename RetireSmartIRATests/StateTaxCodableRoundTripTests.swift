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
