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
            // false, not the true default: makes an encode-side drop of this
            // field visible (decodeIfPresent(...) ?? true would silently
            // "recover" a dropped key back to true, masking the loss). See
            // retirementExemptionsEncodesExpectedJSONShape below for the
            // general, fixture-value-independent guard against this class of
            // bug across all nine fields.
            socialSecurityExempt: false,
            pensionExemption: .partial(maxExempt: 65_000),
            iraWithdrawalExemption: .partial(maxExempt: 42_000),
            exemptionAppliesPerIndividual: true,
            regularExemptionMinAge: 65,
            distributionMinAge: 55,
            earlyAgeTier: .init(ageRange: 62...64, level: .partial(maxExempt: 35_000)),
            pensionAndIRAShareSingleCap: true,
            otherRetirementIncomeExclusion: true,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.6)),
            capitalGainsTreatment: .taxedAsOrdinary
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetirementIncomeExemptions.self, from: data)

        #expect(decoded.socialSecurityExempt == original.socialSecurityExempt)
        #expect(decoded.exemptionAppliesPerIndividual == original.exemptionAppliesPerIndividual)
        #expect(decoded.regularExemptionMinAge == original.regularExemptionMinAge)
        #expect(decoded.distributionMinAge == original.distributionMinAge)
        #expect(decoded.pensionAndIRAShareSingleCap == original.pensionAndIRAShareSingleCap)
        #expect(decoded.otherRetirementIncomeExclusion == original.otherRetirementIncomeExclusion)
        #expect(decoded.agiPhaseout == original.agiPhaseout)
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

    @Test("Encoded JSON carries all eleven fields under their own keys, with the right values")
    func retirementExemptionsEncodesExpectedJSONShape() throws {
        // This is the general guard against the whole class of bug the two
        // Bool-heavy findings above raised: a dropped encode() line, or two
        // swapped CodingKeys labels, produces byte-identical JSON to the
        // correct output whenever the two fields involved happen to share a
        // value (all four Bools here are not forced into a single
        // arrangement the way the round-trip fixture is). Inspecting the raw
        // JSON dictionary directly -- independent of what init(from:) does
        // with it -- catches a dropped field, a swapped label, and a
        // default-masked field for all eleven keys at once, regardless of
        // fixture values.
        //
        // This fixture must be extended whenever a field is added to
        // RetirementIncomeExemptions. It was not, twice: neither
        // distributionMinAge (added when the hardcoded 59 age gate was made
        // configurable) nor agiPhaseout (added for the general phase-out
        // mechanism) was added here when it landed, so both could have been
        // dropped from the encoder with this whole suite staying green.
        let original = RetirementIncomeExemptions(
            socialSecurityExempt: false,
            pensionExemption: .partial(maxExempt: 65_000),
            iraWithdrawalExemption: .partial(maxExempt: 42_000),
            exemptionAppliesPerIndividual: true,
            regularExemptionMinAge: 65,
            distributionMinAge: 55,
            earlyAgeTier: .init(ageRange: 62...64, level: .partial(maxExempt: 35_000)),
            pensionAndIRAShareSingleCap: true,
            otherRetirementIncomeExclusion: true,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.6)),
            capitalGainsTreatment: .taxedAsOrdinary
        )
        let data = try JSONEncoder().encode(original)
        let raw = try JSONSerialization.jsonObject(with: data)
        let json = try #require(raw as? [String: Any])

        #expect(json["socialSecurityExempt"] as? Bool == false)
        #expect(json["exemptionAppliesPerIndividual"] as? Bool == true)
        #expect(json["regularExemptionMinAge"] as? Int == 65)
        #expect(json["distributionMinAge"] as? Int == 55)
        #expect(json["pensionAndIRAShareSingleCap"] as? Bool == true)
        #expect(json["otherRetirementIncomeExclusion"] as? Bool == true)
        #expect(json["capitalGainsTreatment"] as? String == "taxedAsOrdinary")

        let pension = try #require(json["pensionExemption"] as? [String: Any])
        #expect(pension["kind"] as? String == "partial")
        #expect(pension["maxExempt"] as? Double == 65_000)

        let ira = try #require(json["iraWithdrawalExemption"] as? [String: Any])
        #expect(ira["kind"] as? String == "partial")
        #expect(ira["maxExempt"] as? Double == 42_000)

        let ageTier = try #require(json["earlyAgeTier"] as? [String: Any])
        #expect(ageTier["minAge"] as? Int == 62)
        #expect(ageTier["maxAge"] as? Int == 64)
        let ageTierLevel = try #require(ageTier["level"] as? [String: Any])
        #expect(ageTierLevel["kind"] as? String == "partial")
        #expect(ageTierLevel["maxExempt"] as? Double == 35_000)

        let phaseout = try #require(json["agiPhaseout"] as? [String: Any])
        #expect(phaseout["thresholdSingle"] as? Double == 50_000)
        #expect(phaseout["thresholdMFJ"] as? Double == 75_000)
        #expect((phaseout["shape"] as? [String: Any])?["kind"] as? String == "linear")
        #expect((phaseout["shape"] as? [String: Any])?["perDollar"] as? Double == 1.6)
    }

    @Test("Two complementary Bool arrangements make every pair of the four Bool fields mutually distinguishable")
    func retirementExemptionsBooleanKeysAreMutuallyDistinguishable() throws {
        // retirementExemptionsEncodesExpectedJSONShape (above) proves the JSON
        // shape for ONE fixture, but a single fixture cannot prove every pair
        // of the four Bool fields (socialSecurityExempt,
        // exemptionAppliesPerIndividual, pensionAndIRAShareSingleCap,
        // otherRetirementIncomeExclusion) is protected against a swapped
        // CodingKeys label. Bool has only two values; with four fields,
        // pigeonhole guarantees at least one pair shares a value in any
        // single fixture, and a swap between two same-valued fields produces
        // BYTE-IDENTICAL JSON -- no test reading only the encoded output can
        // detect it, no matter how it inspects that output. Confirmed
        // empirically while building this fix: swapping
        // pensionAndIRAShareSingleCap and otherRetirementIncomeExclusion's
        // forKey labels (both `true` in the fixture above) left every test in
        // this suite green, including the JSON-shape test.
        //
        // The two fixtures below give each of the four Bool fields a
        // distinct 2-bit signature (one bit per fixture), so every pair of
        // fields differs in at least one fixture:
        //   field                            P       Q
        //   socialSecurityExempt             false   false
        //   exemptionAppliesPerIndividual     false   true
        //   pensionAndIRAShareSingleCap       true    false
        //   otherRetirementIncomeExclusion    true    true
        // Any swap between two Bool CodingKeys changes P, Q, or both.
        func boolsInEncodedJSON(_ ex: RetirementIncomeExemptions) throws -> [String: Bool] {
            let data = try JSONEncoder().encode(ex)
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            return [
                "socialSecurityExempt": try #require(json["socialSecurityExempt"] as? Bool),
                "exemptionAppliesPerIndividual": try #require(json["exemptionAppliesPerIndividual"] as? Bool),
                "pensionAndIRAShareSingleCap": try #require(json["pensionAndIRAShareSingleCap"] as? Bool),
                "otherRetirementIncomeExclusion": try #require(json["otherRetirementIncomeExclusion"] as? Bool)
            ]
        }

        let p = RetirementIncomeExemptions(
            socialSecurityExempt: false,
            exemptionAppliesPerIndividual: false,
            pensionAndIRAShareSingleCap: true,
            otherRetirementIncomeExclusion: true
        )
        let pJSON = try boolsInEncodedJSON(p)
        #expect(pJSON["socialSecurityExempt"] == false)
        #expect(pJSON["exemptionAppliesPerIndividual"] == false)
        #expect(pJSON["pensionAndIRAShareSingleCap"] == true)
        #expect(pJSON["otherRetirementIncomeExclusion"] == true)

        let q = RetirementIncomeExemptions(
            socialSecurityExempt: false,
            exemptionAppliesPerIndividual: true,
            pensionAndIRAShareSingleCap: false,
            otherRetirementIncomeExclusion: true
        )
        let qJSON = try boolsInEncodedJSON(q)
        #expect(qJSON["socialSecurityExempt"] == false)
        #expect(qJSON["exemptionAppliesPerIndividual"] == true)
        #expect(qJSON["pensionAndIRAShareSingleCap"] == false)
        #expect(qJSON["otherRetirementIncomeExclusion"] == true)
    }

    @Test("AgeTier decode throws a reportable error, not a ClosedRange trap, when minAge exceeds maxAge")
    func ageTierDecodeThrowsOnInvertedRange() throws {
        // ClosedRange's `...` traps the process when lowerBound > upperBound.
        // Task 9's loader reads real, possibly hand-edited JSON across 51
        // jurisdictions, so a malformed file must fail with a catchable
        // DecodingError rather than crash the app.
        let malformed = Data("""
        {"minAge": 70, "maxAge": 60, "level": {"kind": "none"}}
        """.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(RetirementIncomeExemptions.AgeTier.self, from: malformed)
        }
    }

    @Test("StateTaxConfig round-trips with verification metadata")
    func stateTaxConfigRoundTrips() throws {
        let original = StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.038),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            verification: StateVerification(
                lastVerified: "2026-08-02",
                primarySources: ["https://revenue.iowa.gov/"],
                billReferences: ["HF 2317 (signed 2022-03-01)"],
                knownLimitations: ["Roth conversion income is not yet exempted."]
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StateTaxConfig.self, from: data)

        #expect(decoded.state == .iowa)
        #expect(decoded.verification.lastVerified == "2026-08-02")
        #expect(decoded.verification.knownLimitations.count == 1)
        #expect(decoded.taxSystem.matchesShape(of: original.taxSystem))
        #expect(decoded.currentYearSafeHarborRate == original.currentYearSafeHarborRate)
        #expect(decoded.pretax401kContributionsTaxableForState
                == original.pretax401kContributionsTaxableForState)
    }

    @Test("Encoded JSON carries state as an abbreviation string, currentYearSafeHarborRate, estimatedPaymentSchedule, safeHarborRule, and a nested verification object")
    func stateTaxConfigEncodesExpectedJSONShape() throws {
        // Every value here is deliberately NOT the declared default (state has
        // no default; 0.95 != the 0.90 default; verification is not
        // .unverified), because a field left at its default cannot be proven
        // to have survived encode/decode -- a dropped key decodes right back
        // to that same default and the assertion would pass either way.
        //
        // estimatedPaymentSchedule and safeHarborRule are included here for
        // the same reason and are the highest-blast-radius fields in the
        // whole config: 24 of 51 states set an explicit safeHarborRule (20
        // .flatRate, plus KY .agiThreshold, CA .mirrorsFederalWithDisqualification,
        // ID .noPenalty, one explicit .mirrorsFederal), and California alone
        // sets a non-federal estimatedPaymentSchedule. A dropped encode line
        // for either field falls back silently to .mirrorsFederal / .federal
        // on decode -- exactly the default most states never override, so a
        // fixture that left them at their defaults could not have caught it.
        let original = StateTaxConfig(
            state: .pennsylvania,
            taxSystem: .flat(rate: 0.0307),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            estimatedPaymentSchedule: .california,
            safeHarborRule: .flatRate(1.10),
            currentYearSafeHarborRate: 0.95,
            verification: StateVerification(
                lastVerified: "2026-08-02",
                primarySources: ["https://www.revenue.pa.gov/"],
                billReferences: [],
                knownLimitations: []
            )
        )
        let data = try JSONEncoder().encode(original)
        let raw = try JSONSerialization.jsonObject(with: data)
        let json = try #require(raw as? [String: Any])

        #expect(json["state"] as? String == "PA")
        #expect(json["currentYearSafeHarborRate"] as? Double == 0.95)
        let verification = try #require(json["verification"] as? [String: Any])
        #expect(verification["lastVerified"] as? String == "2026-08-02")

        let schedule = try #require(json["estimatedPaymentSchedule"] as? [String: Any])
        #expect(schedule["q1Pct"] as? Double == 0.30)
        #expect(schedule["q2Pct"] as? Double == 0.40)
        #expect(schedule["q3Pct"] as? Double == 0.0)
        #expect(schedule["q4Pct"] as? Double == 0.30)

        let safeHarbor = try #require(json["safeHarborRule"] as? [String: Any])
        #expect(safeHarbor["kind"] as? String == "flatRate")
        #expect(safeHarbor["rate"] as? Double == 1.10)
    }

    @Test("Three fixtures make every pair of StateTaxConfig's five Bool fields mutually distinguishable")
    func stateTaxConfigBooleanKeysAreMutuallyDistinguishable() throws {
        // StateTaxConfig has FIVE Bool fields. Two fixtures give each field
        // only a 2-bit signature (2^2 = 4 < 5), so pigeonhole guarantees at
        // least one pair of fields shares a value in every 2-fixture scheme --
        // a CodingKeys label swap between that pair produces byte-identical
        // JSON, undetectable no matter how the output is inspected (this is
        // the same failure mode retirementExemptionsBooleanKeysAreMutuallyDistinguishable
        // above documents for four Bools with two fixtures).
        //
        // Three fixtures (2^3 = 8 >= 5) give every field a unique 3-bit
        // signature:
        //   field                                          A      B      C
        //   hsaContributionsTaxableForState                true   false  false
        //   traditionalIRAContributionsTaxableForState      false  true   false
        //   otherPreTaxDeductionsTaxableForState             false  false  true
        //   pretax401kContributionsTaxableForState           true   true   false
        //   capitalLossesClassIsolated                       true   false  true
        // Every pair of fields differs in at least one fixture, so a swap
        // between any two Bool CodingKeys changes at least one fixture's
        // encoded output.
        func config(hsa: Bool, ira: Bool, other: Bool, k401: Bool, capLoss: Bool) -> StateTaxConfig {
            StateTaxConfig(
                state: .iowa,
                taxSystem: .flat(rate: 0.038),
                retirementExemptions: RetirementIncomeExemptions(
                    socialSecurityExempt: true,
                    pensionExemption: .none,
                    iraWithdrawalExemption: .none,
                    capitalGainsTreatment: .followsFederal
                ),
                stateDeduction: .conformsToFederal,
                hsaContributionsTaxableForState: hsa,
                traditionalIRAContributionsTaxableForState: ira,
                otherPreTaxDeductionsTaxableForState: other,
                pretax401kContributionsTaxableForState: k401,
                capitalLossesClassIsolated: capLoss
            )
        }

        func boolsInEncodedJSON(_ config: StateTaxConfig) throws -> [String: Bool] {
            let data = try JSONEncoder().encode(config)
            let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            return [
                "hsaContributionsTaxableForState":
                    try #require(json["hsaContributionsTaxableForState"] as? Bool),
                "traditionalIRAContributionsTaxableForState":
                    try #require(json["traditionalIRAContributionsTaxableForState"] as? Bool),
                "otherPreTaxDeductionsTaxableForState":
                    try #require(json["otherPreTaxDeductionsTaxableForState"] as? Bool),
                "pretax401kContributionsTaxableForState":
                    try #require(json["pretax401kContributionsTaxableForState"] as? Bool),
                "capitalLossesClassIsolated":
                    try #require(json["capitalLossesClassIsolated"] as? Bool)
            ]
        }

        let a = try boolsInEncodedJSON(config(hsa: true, ira: false, other: false, k401: true, capLoss: true))
        #expect(a["hsaContributionsTaxableForState"] == true)
        #expect(a["traditionalIRAContributionsTaxableForState"] == false)
        #expect(a["otherPreTaxDeductionsTaxableForState"] == false)
        #expect(a["pretax401kContributionsTaxableForState"] == true)
        #expect(a["capitalLossesClassIsolated"] == true)

        let b = try boolsInEncodedJSON(config(hsa: false, ira: true, other: false, k401: true, capLoss: false))
        #expect(b["hsaContributionsTaxableForState"] == false)
        #expect(b["traditionalIRAContributionsTaxableForState"] == true)
        #expect(b["otherPreTaxDeductionsTaxableForState"] == false)
        #expect(b["pretax401kContributionsTaxableForState"] == true)
        #expect(b["capitalLossesClassIsolated"] == false)

        let c = try boolsInEncodedJSON(config(hsa: false, ira: false, other: true, k401: false, capLoss: true))
        #expect(c["hsaContributionsTaxableForState"] == false)
        #expect(c["traditionalIRAContributionsTaxableForState"] == false)
        #expect(c["otherPreTaxDeductionsTaxableForState"] == true)
        #expect(c["pretax401kContributionsTaxableForState"] == false)
        #expect(c["capitalLossesClassIsolated"] == true)
    }

    @Test("Decoding an unknown state abbreviation throws a DecodingError instead of silently defaulting")
    func stateTaxConfigDecodeThrowsOnUnknownAbbreviation() throws {
        // Task 9's loader reads 51 real files; a typo'd abbreviation must be
        // reportable, not silently coerced to some default state.
        let malformed = Data("""
        {"state": "ZZ",
         "taxSystem": {"kind": "flat", "rate": 0.05},
         "retirementExemptions": {"socialSecurityExempt": true,
                                  "pensionExemption": {"kind": "none"},
                                  "iraWithdrawalExemption": {"kind": "none"}},
         "stateDeduction": {"kind": "none"}}
        """.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(StateTaxConfig.self, from: malformed)
        }
    }

    @Test("Every StateSafeHarborRule used in the real config table round-trips")
    func allConfiguredSafeHarborRulesRoundTrip() throws {
        for (state, config) in StateTaxData.configs2026Legacy {
            let data = try JSONEncoder().encode(config.safeHarborRule)
            let decoded = try JSONDecoder().decode(StateSafeHarborRule.self, from: data)
            #expect(decoded == config.safeHarborRule,
                    "\(state.abbreviation) safe harbor rule lost in round trip")
        }
    }

    @Test("AGIPhaseout round-trips both shapes with distinct per-field values")
    func agiPhaseoutRoundTrips() throws {
        // Thresholds deliberately different from each other so a single/MFJ
        // swap is detectable, and perDollar deliberately not 1.0 so a dropped
        // payload is not masked by a plausible default.
        let cases: [AGIPhaseout] = [
            AGIPhaseout(thresholdSingle: 28_500, thresholdMFJ: 51_000, shape: .cliff),
            AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                        shape: .linear(perDollar: 1.6))
        ]
        for original in cases {
            let decoded = try JSONDecoder().decode(
                AGIPhaseout.self, from: JSONEncoder().encode(original))
            #expect(decoded == original)
        }
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
