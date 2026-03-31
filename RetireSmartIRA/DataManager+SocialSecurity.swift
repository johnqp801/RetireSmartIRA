//
//  DataManager+SocialSecurity.swift
//  RetireSmartIRA
//
//  Extension for Social Security Planner persistence and bridge methods.
//  Stored @Published properties are declared in DataManager.swift (Swift limitation).
//

import Foundation

extension DataManager {

    // MARK: - SS Persistence Keys (mirroring StorageKey pattern)

    private enum SSStorageKey {
        static let primarySSBenefit = "primarySSBenefit"
        static let spouseSSBenefit = "spouseSSBenefit"
        static let primaryEarningsHistory = "primaryEarningsHistory"
        static let spouseEarningsHistory = "spouseEarningsHistory"
        static let ssWhatIfParams = "ssWhatIfParams"
        static let ssAutoSync = "ssAutoSync"
    }

    // MARK: - Load / Save

    func loadSSData() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: SSStorageKey.primarySSBenefit),
           let decoded = try? JSONDecoder().decode(SSBenefitEstimate.self, from: data) {
            self.primarySSBenefit = decoded
        }
        if let data = defaults.data(forKey: SSStorageKey.spouseSSBenefit),
           let decoded = try? JSONDecoder().decode(SSBenefitEstimate.self, from: data) {
            self.spouseSSBenefit = decoded
        }
        if let data = defaults.data(forKey: SSStorageKey.primaryEarningsHistory),
           let decoded = try? JSONDecoder().decode(SSEarningsHistory.self, from: data) {
            self.primaryEarningsHistory = decoded
        }
        if let data = defaults.data(forKey: SSStorageKey.spouseEarningsHistory),
           let decoded = try? JSONDecoder().decode(SSEarningsHistory.self, from: data) {
            self.spouseEarningsHistory = decoded
        }
        if let data = defaults.data(forKey: SSStorageKey.ssWhatIfParams),
           let decoded = try? JSONDecoder().decode(SSWhatIfParameters.self, from: data) {
            self.ssWhatIfParams = decoded
        }
        if defaults.object(forKey: SSStorageKey.ssAutoSync) != nil {
            self.ssAutoSync = defaults.bool(forKey: SSStorageKey.ssAutoSync)
        }
    }

    func saveSSData() {
        let defaults = UserDefaults.standard

        if let benefit = primarySSBenefit,
           let data = try? JSONEncoder().encode(benefit) {
            defaults.set(data, forKey: SSStorageKey.primarySSBenefit)
        } else {
            defaults.removeObject(forKey: SSStorageKey.primarySSBenefit)
        }
        if let benefit = spouseSSBenefit,
           let data = try? JSONEncoder().encode(benefit) {
            defaults.set(data, forKey: SSStorageKey.spouseSSBenefit)
        } else {
            defaults.removeObject(forKey: SSStorageKey.spouseSSBenefit)
        }
        if let history = primaryEarningsHistory,
           let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: SSStorageKey.primaryEarningsHistory)
        } else {
            defaults.removeObject(forKey: SSStorageKey.primaryEarningsHistory)
        }
        if let history = spouseEarningsHistory,
           let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: SSStorageKey.spouseEarningsHistory)
        } else {
            defaults.removeObject(forKey: SSStorageKey.spouseEarningsHistory)
        }
        if let data = try? JSONEncoder().encode(ssWhatIfParams) {
            defaults.set(data, forKey: SSStorageKey.ssWhatIfParams)
        }
        defaults.set(ssAutoSync, forKey: SSStorageKey.ssAutoSync)
    }

    // MARK: - Bridge Methods to Calculation Engine

    // Note: birthYear and spouseBirthYear are already defined in DataManager.swift

    /// FRA for primary user
    var primaryFRA: (years: Int, months: Int) {
        SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
    }

    /// FRA for spouse
    var spouseFRA: (years: Int, months: Int) {
        SSCalculationEngine.fullRetirementAge(birthYear: spouseBirthYear)
    }

    /// Generate all claiming scenarios for a given owner
    func ssClaimingScenarios(for owner: Owner) -> [SSClaimingScenario] {
        let benefit: SSBenefitEstimate?
        let birthYr: Int
        let lifeExp: Int

        switch owner {
        case .primary:
            benefit = primarySSBenefit
            birthYr = birthYear
            lifeExp = ssWhatIfParams.primaryLifeExpectancy
        case .spouse:
            benefit = spouseSSBenefit
            birthYr = spouseBirthYear
            lifeExp = ssWhatIfParams.spouseLifeExpectancy
        default:
            return []
        }

        guard let b = benefit, b.benefitAtFRA > 0 else { return [] }

        return SSCalculationEngine.claimingScenarios(
            pia: b.benefitAtFRA,
            birthYear: birthYr,
            lifeExpectancy: lifeExp,
            colaRate: ssWhatIfParams.colaRate
        )
    }

    /// Break-even comparisons for key claiming age pairs
    func ssBreakEvenComparisons(for owner: Owner) -> [SSBreakEvenComparison] {
        let scenarios = ssClaimingScenarios(for: owner)
        let lifeExp = owner == .primary
            ? ssWhatIfParams.primaryLifeExpectancy
            : ssWhatIfParams.spouseLifeExpectancy
        let birthYr = owner == .primary ? birthYear : spouseBirthYear
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYr)
        return SSCalculationEngine.breakEvenComparisons(scenarios: scenarios, lifeExpectancy: lifeExp, fraAge: fra.years)
    }

    /// Chart data for cumulative benefit visualization
    func ssCumulativeChartData(for owner: Owner) -> [SSCumulativeChartPoint] {
        let scenarios = ssClaimingScenarios(for: owner)
        let lifeExp = owner == .primary
            ? ssWhatIfParams.primaryLifeExpectancy
            : ssWhatIfParams.spouseLifeExpectancy
        return SSCalculationEngine.cumulativeChartData(scenarios: scenarios, maxAge: lifeExp + 5)
    }

    /// Monthly benefit at the planned claiming age for a given owner
    func ssPlannedMonthlyBenefit(for owner: Owner) -> Double {
        let benefit: SSBenefitEstimate?
        let birthYr: Int

        switch owner {
        case .primary:
            benefit = primarySSBenefit
            birthYr = birthYear
        case .spouse:
            benefit = spouseSSBenefit
            birthYr = spouseBirthYear
        default:
            return 0
        }

        guard let b = benefit, b.hasData else { return 0 }
        if b.isAlreadyClaiming { return b.currentBenefit }
        let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYr)
        return SSCalculationEngine.benefitAtAge(
            claimingAge: b.plannedClaimingAge,
            claimingMonth: b.plannedClaimingMonth,
            pia: b.benefitAtFRA,
            fraYears: fra.years, fraMonths: fra.months
        )
    }

    // MARK: - Couples Strategy

    /// Build the 9×9 couples claiming matrix
    func ssCouplesMatrix() -> [SSCouplesMatrixCell] {
        guard let pBenefit = primarySSBenefit, pBenefit.benefitAtFRA > 0,
              let sBenefit = spouseSSBenefit, sBenefit.benefitAtFRA > 0 else { return [] }

        return SSCalculationEngine.couplesMatrix(
            primaryPIA: pBenefit.benefitAtFRA, primaryBirthYear: birthYear,
            primaryLifeExpectancy: ssWhatIfParams.primaryLifeExpectancy,
            spousePIA: sBenefit.benefitAtFRA, spouseBirthYear: spouseBirthYear,
            spouseLifeExpectancy: ssWhatIfParams.spouseLifeExpectancy,
            colaRate: ssWhatIfParams.colaRate,
            discountRate: ssWhatIfParams.discountRate
        )
    }

    /// Get the highest-lifetime couples strategy
    func ssCouplesTopStrategy() -> SSCouplesTopStrategy? {
        let matrix = ssCouplesMatrix()
        guard !matrix.isEmpty,
              let pBenefit = primarySSBenefit,
              let sBenefit = spouseSSBenefit else { return nil }

        return SSCalculationEngine.couplesTopStrategy(
            matrix: matrix,
            primaryPIA: pBenefit.benefitAtFRA,
            spousePIA: sBenefit.benefitAtFRA
        )
    }

    // MARK: - Survivor Analysis

    /// Generate survivor scenarios for the current couple
    func ssSurvivorScenarios() -> [SSSurvivorScenario] {
        guard let pBenefit = primarySSBenefit, pBenefit.hasData,
              let sBenefit = spouseSSBenefit, sBenefit.hasData else { return [] }

        return SSCalculationEngine.survivorScenarios(
            primaryBenefit: pBenefit, primaryBirthYear: birthYear,
            spouseBenefit: sBenefit, spouseBirthYear: spouseBirthYear
        )
    }

    // MARK: - AIME/PIA from Earnings History

    /// Calculate PIA from stored earnings history for the given owner
    func ssCalculatePIA(for owner: Owner) -> SSPIAResult? {
        let history: SSEarningsHistory?
        let birthYr: Int

        switch owner {
        case .primary:
            history = primaryEarningsHistory
            birthYr = birthYear
        case .spouse:
            history = spouseEarningsHistory
            birthYr = spouseBirthYear
        default:
            return nil
        }

        guard let h = history, !h.records.isEmpty else { return nil }

        return SSCalculationEngine.calculatePIA(
            records: h.records,
            birthYear: birthYr,
            futureEarningsPerYear: h.futureEarningsPerYear,
            futureWorkYears: h.futureWorkYears
        )
    }

    // MARK: - Auto-Sync to Income Sources

    /// Sync SS benefit estimates to IncomeSource entries so existing tax calculations pick them up.
    /// Called when user changes claiming age or benefit estimates and ssAutoSync is true.
    func syncSSToIncomeSources() {
        guard ssAutoSync else { return }

        syncSSIncomeSource(for: .primary, benefit: primarySSBenefit, birthYear: birthYear)
        if enableSpouse {
            syncSSIncomeSource(for: .spouse, benefit: spouseSSBenefit, birthYear: spouseBirthYear)
        }
    }

    private func syncSSIncomeSource(for owner: Owner, benefit: SSBenefitEstimate?, birthYear: Int) {
        guard let b = benefit, b.hasData else {
            // Remove any auto-synced SS income source for this owner
            incomeSources.removeAll { $0.type == .socialSecurity && $0.owner == owner && $0.name.hasSuffix("(SS Planner)") }
            return
        }

        let monthlyBenefit: Double
        if b.isAlreadyClaiming {
            monthlyBenefit = b.currentBenefit
        } else {
            let fra = SSCalculationEngine.fullRetirementAge(birthYear: birthYear)
            monthlyBenefit = SSCalculationEngine.benefitAtAge(
                claimingAge: b.plannedClaimingAge, claimingMonth: b.plannedClaimingMonth,
                pia: b.benefitAtFRA, fraYears: fra.years, fraMonths: fra.months
            )
        }
        let annualBenefit = monthlyBenefit * 12
        let sourceName = owner == .primary ? "Social Security (SS Planner)" : "Spouse Social Security (SS Planner)"

        if let idx = incomeSources.firstIndex(where: { $0.type == .socialSecurity && $0.owner == owner && $0.name.hasSuffix("(SS Planner)") }) {
            incomeSources[idx].annualAmount = annualBenefit
        } else {
            incomeSources.append(IncomeSource(
                name: sourceName,
                type: .socialSecurity,
                annualAmount: annualBenefit,
                owner: owner
            ))
        }
    }
}
