import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 3b Task 1: the two-dimension domain model (`PlanStructure` x
/// `PlanSource`) and its migration inference. Types only; nothing in
/// production consumes them yet. See
/// docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
/// sections 3.1, 3.2, 3.3 and 3.6.
@Suite("Phase 3b: RetirementPlanClassification and PerSourceExemptionRule")
struct Phase3bClassificationTests {

    // MARK: - 3.6 Migration inference: IncomeType

    @Test("An RMD income row infers ira / individual")
    func incomeRMDInfersIRAIndividual() {
        let result = RetirementPlanClassification.infer(incomeType: .rmd)
        #expect(result == RetirementPlanClassification(structure: .ira, source: .individual))
    }

    @Test("A pension income row infers unknown / unknown, deferred to the picker")
    func incomePensionInfersUnknownUnknown() {
        let result = RetirementPlanClassification.infer(incomeType: .pension)
        #expect(result == RetirementPlanClassification(structure: .unknown, source: .unknown))
    }

    @Test("Every other IncomeType infers unknown / unknown")
    func incomeEverythingElseInfersUnknownUnknown() {
        let classified: Set<IncomeType> = [.rmd, .pension]
        for type in IncomeType.allCases where !classified.contains(type) {
            let result = RetirementPlanClassification.infer(incomeType: type)
            #expect(
                result == RetirementPlanClassification(structure: .unknown, source: .unknown),
                "IncomeType.\(type) should infer unknown/unknown"
            )
        }
    }

    // MARK: - 3.6 Migration inference: AccountType

    @Test("A traditional IRA account infers ira / individual")
    func accountTraditionalIRAInfersIRAIndividual() {
        let result = RetirementPlanClassification.infer(accountType: .traditionalIRA)
        #expect(result == RetirementPlanClassification(structure: .ira, source: .individual))
    }

    @Test("A traditional 401(k) account infers definedContribution / privateEmployer")
    func accountTraditional401kInfersDefinedContributionPrivateEmployer() {
        let result = RetirementPlanClassification.infer(accountType: .traditional401k)
        #expect(result == RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer))
    }

    @Test("Every other AccountType infers unknown / unknown")
    func accountEverythingElseInfersUnknownUnknown() {
        let classified: Set<AccountType> = [.traditionalIRA, .traditional401k]
        for type in AccountType.allCases where !classified.contains(type) {
            let result = RetirementPlanClassification.infer(accountType: type)
            #expect(
                result == RetirementPlanClassification(structure: .unknown, source: .unknown),
                "AccountType.\(type) should infer unknown/unknown"
            )
        }
    }

    // MARK: - 3.3 / 3.4a PerSourceExemptionRule.matches

    /// New York's actual Line 26 rule from section 3.3, reused across the
    /// matching tests below.
    static let nyLine26Rule = PerSourceExemptionRule(
        matchSources: [.nyStateOrLocal, .federalCivilian],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("NY Line 26 rule matches a NY state/local defined-benefit pension")
    func nyRuleMatchesNYStateOrLocalDefinedBenefit() {
        #expect(Self.nyLine26Rule.matches(structure: .definedBenefit, source: .nyStateOrLocal))
    }

    @Test("NY Line 26 rule matches a federal civilian defined-benefit pension")
    func nyRuleMatchesFederalCivilianDefinedBenefit() {
        #expect(Self.nyLine26Rule.matches(structure: .definedBenefit, source: .federalCivilian))
    }

    @Test("NY Line 26 rule does NOT match an out-of-state defined-benefit pension (the defect this design removes)")
    func nyRuleDoesNotMatchOutOfStateDefinedBenefit() {
        // This is the regression test named in the brief: a California or
        // Illinois public pension held by a New York resident must not
        // receive the uncapped exclusion.
        #expect(!Self.nyLine26Rule.matches(structure: .definedBenefit, source: .otherStateOrLocal))
    }

    @Test("NY Line 26 rule does NOT match a NY-sourced defined-contribution plan (structure gate)")
    func nyRuleDoesNotMatchDefinedContributionEvenFromNY() {
        // A government employee's 403(b) is excluded from Line 26 by its
        // definedContribution structure, not by its source, so it falls
        // through to the capped $20,000 exemption.
        #expect(!Self.nyLine26Rule.matches(structure: .definedContribution, source: .nyStateOrLocal))
    }

    @Test("NY Line 26 rule does NOT match governmentUnspecified, which is not itself a jurisdiction")
    func nyRuleDoesNotMatchGovernmentUnspecified() {
        // governmentUnspecified records "a government employer, jurisdiction
        // not established." A rule that names specific jurisdictions must
        // never treat it as one of them.
        #expect(!Self.nyLine26Rule.matches(structure: .definedBenefit, source: .governmentUnspecified))
    }

    @Test("Empty matchSources means any source, gated only by structure")
    func emptyMatchSourcesMeansAny() {
        let anySourceDefinedBenefit = PerSourceExemptionRule(
            matchSources: [],
            matchStructures: [.definedBenefit],
            treatment: .full
        )
        #expect(anySourceDefinedBenefit.matches(structure: .definedBenefit, source: .nyStateOrLocal))
        #expect(anySourceDefinedBenefit.matches(structure: .definedBenefit, source: .otherStateOrLocal))
        #expect(anySourceDefinedBenefit.matches(structure: .definedBenefit, source: .governmentUnspecified))
        #expect(!anySourceDefinedBenefit.matches(structure: .definedContribution, source: .nyStateOrLocal))
    }

    @Test("Empty matchStructures means any structure, gated only by source")
    func emptyMatchStructuresMeansAny() {
        let anyStructureNYSource = PerSourceExemptionRule(
            matchSources: [.nyStateOrLocal],
            matchStructures: [],
            treatment: .full
        )
        #expect(anyStructureNYSource.matches(structure: .definedBenefit, source: .nyStateOrLocal))
        #expect(anyStructureNYSource.matches(structure: .definedContribution, source: .nyStateOrLocal))
        #expect(anyStructureNYSource.matches(structure: .ira, source: .nyStateOrLocal))
        #expect(!anyStructureNYSource.matches(structure: .definedBenefit, source: .federalCivilian))
    }

    // MARK: - Step 3a: unrecognised strings must throw, never fall back silently

    @Test("An unrecognized PlanStructure string throws DecodingError instead of silently defaulting")
    func planStructureDecodeThrowsOnUnrecognizedString() throws {
        let malformed = Data("\"notARealStructure\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PlanStructure.self, from: malformed)
        }
    }

    @Test("The PlanStructure decode error names both the type and the bad value")
    func planStructureDecodeErrorIsDiagnosable() {
        let malformed = Data("\"notARealStructure\"".utf8)
        do {
            _ = try JSONDecoder().decode(PlanStructure.self, from: malformed)
            Issue.record("Expected decoding to throw; it succeeded instead")
        } catch let error as DecodingError {
            let description = String(describing: error)
            #expect(description.contains("PlanStructure"))
            #expect(description.contains("notARealStructure"))
        } catch {
            Issue.record("Expected a DecodingError, got \(type(of: error)): \(error)")
        }
    }

    @Test("An unrecognized PlanSource string throws DecodingError instead of silently defaulting")
    func planSourceDecodeThrowsOnUnrecognizedString() throws {
        let malformed = Data("\"notARealSource\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PlanSource.self, from: malformed)
        }
    }

    @Test("The PlanSource decode error names both the type and the bad value")
    func planSourceDecodeErrorIsDiagnosable() {
        let malformed = Data("\"notARealSource\"".utf8)
        do {
            _ = try JSONDecoder().decode(PlanSource.self, from: malformed)
            Issue.record("Expected decoding to throw; it succeeded instead")
        } catch let error as DecodingError {
            let description = String(describing: error)
            #expect(description.contains("PlanSource"))
            #expect(description.contains("notARealSource"))
        } catch {
            Issue.record("Expected a DecodingError, got \(type(of: error)): \(error)")
        }
    }

    @Test("A hand-edited PerSourceExemptionRule with a bogus matchStructures entry throws, not silently coerced")
    func perSourceExemptionRuleDecodeThrowsOnBogusStructureInArray() throws {
        // Simulates a hand-edited state config file: the array-context path,
        // not just a bare top-level string, must also surface the error
        // rather than being caught somewhere and swallowed.
        let malformed = Data("""
        {"matchSources": ["nyStateOrLocal"],
         "matchStructures": ["notARealStructure"],
         "treatment": {"kind": "full"}}
        """.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PerSourceExemptionRule.self, from: malformed)
        }
    }
}
