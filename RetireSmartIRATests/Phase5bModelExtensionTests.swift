import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 5b Task 1: the model extension that makes `ownStateOrLocal`,
/// `uniformedServices`, `railroadRetirement` and the survivor flag
/// expressible at all. Types only; nothing in production consumes them yet
/// (that is Tasks 3 through 9). See `.superpowers/sdd/task-1-brief.md`.
///
/// The gate for this task is inertness, proved by the full suite and by
/// explicit New York checks recorded in the task report, not by this file.
/// This file's job is narrower and different: prove the three new cases are
/// REACHABLE, and prove they are correctly EXCLUSIVE of the case each one
/// was carved out of. That exclusivity, not mere existence, is the entire
/// reason Task 1 exists -- see the file-level finding in the task brief
/// about Kansas's KPERS fixtures being forced onto `otherStateOrLocal`, the
/// exact case whose reason for existing is to stop this.
@Suite("Phase 5b Task 1: model extension reachability and exclusivity")
struct Phase5bModelExtensionTests {

    // MARK: - ownStateOrLocal / otherStateOrLocal: the matched pair

    /// A rule modelled on what a Kansas KPERS exclusion would need to say,
    /// now that the model can say it: KPERS is the taxpayer's OWN state
    /// system, not a stand-in for "any state government pension."
    static let ownStateRule = PerSourceExemptionRule(
        matchSources: [.ownStateOrLocal],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("A rule naming ownStateOrLocal matches an own-state defined-benefit pension")
    func ownStateRuleMatchesOwnState() {
        #expect(Self.ownStateRule.matches(structure: .definedBenefit, source: .ownStateOrLocal))
    }

    @Test("A rule naming ownStateOrLocal does NOT match otherStateOrLocal -- the whole point of the pair")
    func ownStateRuleDoesNotMatchOtherState() {
        // This is the defect the task brief describes: Kansas's obvious rule,
        // matchSources: ["otherStateOrLocal", "federalCivilian"], would have
        // exempted a California public pension for a Kansas resident. A rule
        // that instead correctly names ownStateOrLocal must reject
        // otherStateOrLocal outright.
        #expect(!Self.ownStateRule.matches(structure: .definedBenefit, source: .otherStateOrLocal))
    }

    static let otherStateRule = PerSourceExemptionRule(
        matchSources: [.otherStateOrLocal],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("A rule naming otherStateOrLocal matches an out-of-state defined-benefit pension")
    func otherStateRuleMatchesOtherState() {
        #expect(Self.otherStateRule.matches(structure: .definedBenefit, source: .otherStateOrLocal))
    }

    @Test("A rule naming otherStateOrLocal does NOT match ownStateOrLocal -- the reverse direction of the pair")
    func otherStateRuleDoesNotMatchOwnState() {
        #expect(!Self.otherStateRule.matches(structure: .definedBenefit, source: .ownStateOrLocal))
    }

    // MARK: - uniformedServices / federalCivilian

    static let uniformedServicesRule = PerSourceExemptionRule(
        matchSources: [.uniformedServices],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("A rule naming uniformedServices matches military retired pay")
    func uniformedServicesRuleMatchesUniformedServices() {
        #expect(Self.uniformedServicesRule.matches(structure: .definedBenefit, source: .uniformedServices))
    }

    @Test("A rule naming uniformedServices does NOT match federalCivilian -- Vermont's split")
    func uniformedServicesRuleDoesNotMatchFederalCivilian() {
        // Vermont's uncapped military exclusion and its $10,000 CSRS
        // exclusion are indistinguishable unless a rule naming one rejects
        // the other outright.
        #expect(!Self.uniformedServicesRule.matches(structure: .definedBenefit, source: .federalCivilian))
    }

    static let federalCivilianRule = PerSourceExemptionRule(
        matchSources: [.federalCivilian],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("A rule naming federalCivilian matches CSRS/FERS pay")
    func federalCivilianRuleMatchesFederalCivilian() {
        #expect(Self.federalCivilianRule.matches(structure: .definedBenefit, source: .federalCivilian))
    }

    @Test("A rule naming federalCivilian does NOT match uniformedServices -- the reverse direction")
    func federalCivilianRuleDoesNotMatchUniformedServices() {
        #expect(!Self.federalCivilianRule.matches(structure: .definedBenefit, source: .uniformedServices))
    }

    // MARK: - railroadRetirement / federalCivilian

    static let railroadRetirementRule = PerSourceExemptionRule(
        matchSources: [.railroadRetirement],
        matchStructures: [.definedBenefit],
        treatment: .full
    )

    @Test("A rule naming railroadRetirement matches Railroad Retirement Board benefits")
    func railroadRetirementRuleMatchesRailroadRetirement() {
        #expect(Self.railroadRetirementRule.matches(structure: .definedBenefit, source: .railroadRetirement))
    }

    @Test("A rule naming railroadRetirement does NOT match federalCivilian -- Kansas exempts it by name, distinct from CSRS/FERS")
    func railroadRetirementRuleDoesNotMatchFederalCivilian() {
        #expect(!Self.railroadRetirementRule.matches(structure: .definedBenefit, source: .federalCivilian))
    }

    @Test("A rule naming federalCivilian does NOT match railroadRetirement -- the reverse direction")
    func federalCivilianRuleDoesNotMatchRailroadRetirement() {
        #expect(!Self.federalCivilianRule.matches(structure: .definedBenefit, source: .railroadRetirement))
    }

    // MARK: - uniformedServices / railroadRetirement (both carved from the federal-adjacent bucket)

    @Test("A rule naming uniformedServices does NOT match railroadRetirement")
    func uniformedServicesRuleDoesNotMatchRailroadRetirement() {
        #expect(!Self.uniformedServicesRule.matches(structure: .definedBenefit, source: .railroadRetirement))
    }

    @Test("A rule naming railroadRetirement does NOT match uniformedServices")
    func railroadRetirementRuleDoesNotMatchUniformedServices() {
        #expect(!Self.railroadRetirementRule.matches(structure: .definedBenefit, source: .uniformedServices))
    }

    // MARK: - Round-trip: the new cases decode/encode like any other PlanSource case

    @Test("Each new PlanSource case round-trips through JSON encode/decode", arguments: [
        PlanSource.ownStateOrLocal, .uniformedServices, .railroadRetirement
    ])
    func newCaseRoundTripsThroughJSON(source: PlanSource) throws {
        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(PlanSource.self, from: data)
        #expect(decoded == source)
    }

    @Test("Each new PlanSource case is present in allCases (CaseIterable)")
    func newCasesAreInAllCases() {
        #expect(PlanSource.allCases.contains(.ownStateOrLocal))
        #expect(PlanSource.allCases.contains(.uniformedServices))
        #expect(PlanSource.allCases.contains(.railroadRetirement))
    }

    // MARK: - isSurvivorBenefit: reachable, defaults to nil, does not disturb Equatable

    @Test("isSurvivorBenefit defaults to nil and does not need to be supplied at existing call sites")
    func survivorFlagDefaultsToNil() {
        let classification = RetirementPlanClassification(structure: .definedBenefit, source: .federalCivilian)
        #expect(classification.isSurvivorBenefit == nil)
    }

    @Test("infer(incomeType:) and infer(accountType:) still produce isSurvivorBenefit == nil")
    func inferenceStillProducesNilSurvivorFlag() {
        #expect(RetirementPlanClassification.infer(incomeType: .rmd).isSurvivorBenefit == nil)
        #expect(RetirementPlanClassification.infer(incomeType: .pension).isSurvivorBenefit == nil)
        #expect(RetirementPlanClassification.infer(accountType: .traditionalIRA).isSurvivorBenefit == nil)
        #expect(RetirementPlanClassification.infer(accountType: .traditional401k).isSurvivorBenefit == nil)
    }

    @Test("Two classifications equal in structure and source remain Equatable-equal regardless of the new flag's presence")
    func equatableUnaffectedByNewFlag() {
        // Both sides take the same nil default today; this pins that adding
        // the property did not silently break Equatable synthesis for every
        // existing comparison in Phase3bClassificationTests.
        let a = RetirementPlanClassification(structure: .ira, source: .individual)
        let b = RetirementPlanClassification(structure: .ira, source: .individual)
        #expect(a == b)
    }

    // MARK: - Decode trap regression: the new cases must not break the user-save fallback

    /// Mirrors `Phase3bPersistenceTests.corruptedIncomeSourceRowDoesNotDiscardTheRest`,
    /// which pins that ONE unrecognised classification string on a user-saved
    /// row does not discard the other four -- the exact bug Phase 3b's ledger
    /// records. `PlanClassificationUserSaveDecoding.decode`'s fallback logic
    /// (`RetirementPlanClassification.swift`) is unchanged by this task: it is
    /// already generic over any `RetirementPlanClassificationCase`, so it
    /// requires no edit to keep working, but "requires no edit" is a claim
    /// that needs to be run, not assumed. This re-runs the identical proof
    /// through the real `PersistenceManager.loadAll` path with a raw value
    /// that no build shipping the new cases would ever write, confirming the
    /// fallback still holds after the enum grew.
    @MainActor
    @Test("A saved planSource value this build does not recognise still falls back to .unknown, not a thrown decode that discards the row")
    func unrecognisedFutureCaseFallsBackToUnknown() throws {
        let corruptedJSON = """
        [
          {"id": "\(UUID().uuidString)", "name": "RMD", "type": "RMD", "annualAmount": 20000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "You",
           "planStructure": "unknown", "planSource": "notARealSourceFromAnEvenLaterBuild"},
          {"id": "\(UUID().uuidString)", "name": "Pension", "type": "Pension", "annualAmount": 45000,
           "federalWithholding": 4000, "stateWithholding": 0, "owner": "You",
           "planStructure": "unknown", "planSource": "unknown"}
        ]
        """.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "phase5b-corrupted-income-row-\(UUID().uuidString)")!
        defaults.set(corruptedJSON, forKey: PersistenceManager.StorageKey.incomeSources)

        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)

        #expect(dm.incomeSources.count == 2,
                "one row carrying a value this build does not recognise must not discard the other row")
        let corrupted = try #require(dm.incomeSources.first { $0.name == "RMD" })
        #expect(corrupted.planSource == .unknown)
        #expect(PlanClassificationUserSaveDecoding.unrecognisedClassificationEncountered)
    }

    /// The forward half of the same proof: a value that a NEWER build wrote
    /// using one of THIS task's own new cases must decode as that case, not
    /// fall back to `.unknown`, when read by this same build. Confirms the
    /// new cases are reachable through the real user-save path, not only
    /// through a rule constructed directly in a unit test.
    @MainActor
    @Test("A saved planSource value using a new Phase 5b case decodes to that case, not to .unknown")
    func newCaseDecodesCorrectlyThroughUserSavePath() throws {
        let json = """
        [
          {"id": "\(UUID().uuidString)", "name": "KPERS", "type": "Pension", "annualAmount": 30000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "You",
           "planStructure": "definedBenefit", "planSource": "ownStateOrLocal"}
        ]
        """.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "phase5b-new-case-round-trip-\(UUID().uuidString)")!
        defaults.set(json, forKey: PersistenceManager.StorageKey.incomeSources)

        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)

        #expect(dm.incomeSources.count == 1)
        #expect(dm.incomeSources.first?.planSource == .ownStateOrLocal)
        #expect(dm.incomeSources.first?.planStructure == .definedBenefit)
    }
}
