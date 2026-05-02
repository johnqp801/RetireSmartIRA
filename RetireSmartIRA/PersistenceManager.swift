//
//  PersistenceManager.swift
//  RetireSmartIRA
//
//  Handles UserDefaults persistence for all domain managers.
//  Extracted from DataManager as part of God Class decomposition.
//

import Foundation

struct PersistenceManager {

    // MARK: - Storage Keys

    enum StorageKey {
        static let birthDate = "birthDate"
        static let spouseBirthDate = "spouseBirthDate"
        static let birthYear = "birthYear"             // legacy migration
        static let spouseBirthYear = "spouseBirthYear" // legacy migration
        static let filingStatus = "filingStatus"
        static let selectedState = "selectedState"
        static let planYear = "planYear"
        static let spouseName = "spouseName"
        static let enableSpouse = "enableSpouse"
        static let iraAccounts = "iraAccounts"
        static let incomeSources = "incomeSources"
        static let quarterlyPayments = "quarterlyPayments"
        static let yourRothConversion = "yourRothConversion"
        static let spouseRothConversion = "spouseRothConversion"
        static let yourExtraWithdrawal = "yourExtraWithdrawal"
        static let spouseExtraWithdrawal = "spouseExtraWithdrawal"
        static let yourQCDAmount = "yourQCDAmount"
        static let spouseQCDAmount = "spouseQCDAmount"
        static let qcdAmount = "qcdAmount"             // legacy migration
        static let yourWithdrawalQuarter = "yourWithdrawalQuarter"
        static let spouseWithdrawalQuarter = "spouseWithdrawalQuarter"
        static let yourRothConversionQuarter = "yourRothConversionQuarter"
        static let spouseRothConversionQuarter = "spouseRothConversionQuarter"
        static let stockDonationEnabled = "stockDonationEnabled"
        static let stockPurchasePrice = "stockPurchasePrice"
        static let stockCurrentValue = "stockCurrentValue"
        static let stockPurchaseDate = "stockPurchaseDate"
        static let cashDonationAmount = "cashDonationAmount"
        static let inheritedExtraWithdrawals = "inheritedExtraWithdrawals"
        static let deductionOverride = "deductionOverride"
        static let completedActionKeys = "completedActionKeys"
        static let deductionItems = "deductionItems"
        static let priorYearStateBalance = "priorYearStateBalance"
        static let priorYearFederalTax = "priorYearFederalTax"
        static let priorYearStateTax = "priorYearStateTax"
        static let priorYearAGI = "priorYearAGI"
        static let safeHarborMethod = "safeHarborMethod"
        static let userName = "userName"
        static let primaryGrowthRate = "primaryGrowthRate"
        static let spouseGrowthRate = "spouseGrowthRate"
        static let enableLegacyPlanning = "enableLegacyPlanning"
        static let legacyHeirType = "legacyHeirType"
        static let legacyHeirEstimatedSalary = "legacyHeirEstimatedSalary"
        static let legacyHeirBirthYear = "legacyHeirBirthYear"
        static let legacyHeirFilingStatus = "legacyHeirFilingStatus"
        static let legacySpouseSurvivorYears = "legacySpouseSurvivorYears"
        static let legacyGrowthRate = "legacyGrowthRate"
        static let taxBrackets = "taxBrackets"

        // 1.9 Medicare
        static let yourMedicarePlanType = "yourMedicarePlanType"
        static let spouseMedicarePlanType = "spouseMedicarePlanType"
        static let yourMedicarePartBOverride = "yourMedicarePartBOverride"
        static let spouseMedicarePartBOverride = "spouseMedicarePartBOverride"
        static let yourMedicarePartDOverride = "yourMedicarePartDOverride"
        static let spouseMedicarePartDOverride = "spouseMedicarePartDOverride"
        static let yourMedigapOverride = "yourMedigapOverride"
        static let spouseMedigapOverride = "spouseMedigapOverride"
        static let yourAdvantageOverride = "yourAdvantageOverride"
        static let spouseAdvantageOverride = "spouseAdvantageOverride"
    }

    // MARK: - Load All

    @MainActor
    static func loadAll(into dm: DataManager, defaults: UserDefaults = .standard) {
        // Tax brackets
        if let data = defaults.data(forKey: StorageKey.taxBrackets),
           let decoded = try? JSONDecoder().decode(TaxBrackets.self, from: data) {
            dm.currentTaxBrackets = decoded
        }

        // Profile: birth date with legacy Int migration
        if let birthInterval = defaults.object(forKey: StorageKey.birthDate) as? Double {
            dm.birthDate = Date(timeIntervalSince1970: birthInterval)
        } else if defaults.object(forKey: StorageKey.birthYear) != nil {
            let year = defaults.integer(forKey: StorageKey.birthYear)
            var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
            if let date = Calendar.current.date(from: c) { dm.birthDate = date }
        }

        if let raw = defaults.string(forKey: StorageKey.filingStatus),
           let status = FilingStatus(rawValue: raw) {
            dm.filingStatus = status
        }
        if let raw = defaults.string(forKey: StorageKey.selectedState),
           let state = USState(rawValue: raw) {
            dm.selectedState = state
        }
        // Plan year — persisted so year-specific labels stay stable across
        // calendar rollover. If missing (pre-1.7.2 install), default to the
        // system year at load time and save it back so it's stable from here on.
        if defaults.object(forKey: StorageKey.planYear) != nil {
            dm.planYear = defaults.integer(forKey: StorageKey.planYear)
        } else {
            dm.planYear = Calendar.current.component(.year, from: Date())
            defaults.set(dm.planYear, forKey: StorageKey.planYear)
        }
        if let name = defaults.string(forKey: StorageKey.spouseName) {
            dm.spouseName = name
        }
        if let name = defaults.string(forKey: StorageKey.userName) {
            dm.userName = name
        }

        // Spouse birth date with legacy Int migration
        if let spouseInterval = defaults.object(forKey: StorageKey.spouseBirthDate) as? Double {
            dm.spouseBirthDate = Date(timeIntervalSince1970: spouseInterval)
        } else if defaults.object(forKey: StorageKey.spouseBirthYear) != nil {
            let year = defaults.integer(forKey: StorageKey.spouseBirthYear)
            var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
            if let date = Calendar.current.date(from: c) { dm.spouseBirthDate = date }
        }
        if defaults.object(forKey: StorageKey.enableSpouse) != nil {
            dm.enableSpouse = defaults.bool(forKey: StorageKey.enableSpouse)
        }

        // Accounts
        if let data = defaults.data(forKey: StorageKey.iraAccounts),
           let decoded = try? JSONDecoder().decode([IRAAccount].self, from: data) {
            dm.iraAccounts = decoded
        }

        // Income & Deductions
        if let data = defaults.data(forKey: StorageKey.incomeSources),
           let decoded = try? JSONDecoder().decode([IncomeSource].self, from: data) {
            dm.incomeSources = decoded
        }
        // Migrate legacy `.rothConversion` income sources (pre-1.7.2) into the
        // scenario slider. IncomeSource.init decode marks legacy sources with
        // the `legacyRothConversionSentinelPrefix` on `name`; this block moves
        // the amount to the slider, preserves any withholding as an "Other"
        // placeholder so totals don't silently change, and removes the sentinel
        // sources.
        migrateLegacyRothConversionSources(into: dm)
        if let data = defaults.data(forKey: StorageKey.deductionItems),
           let decoded = try? JSONDecoder().decode([DeductionItem].self, from: data) {
            dm.deductionItems = decoded
        }
        if defaults.object(forKey: StorageKey.priorYearStateBalance) != nil {
            dm.priorYearStateBalance = defaults.double(forKey: StorageKey.priorYearStateBalance)
        }
        if defaults.object(forKey: StorageKey.priorYearFederalTax) != nil {
            dm.priorYearFederalTax = defaults.double(forKey: StorageKey.priorYearFederalTax)
        }
        if defaults.object(forKey: StorageKey.priorYearStateTax) != nil {
            dm.priorYearStateTax = defaults.double(forKey: StorageKey.priorYearStateTax)
        }
        if defaults.object(forKey: StorageKey.priorYearAGI) != nil {
            dm.priorYearAGI = defaults.double(forKey: StorageKey.priorYearAGI)
        }
        if let raw = defaults.string(forKey: StorageKey.safeHarborMethod),
           let method = SafeHarborMethod(rawValue: raw) {
            dm.safeHarborMethod = method
        }

        // Scenario state
        if let data = defaults.data(forKey: StorageKey.quarterlyPayments),
           let decoded = try? JSONDecoder().decode([QuarterlyPayment].self, from: data) {
            dm.quarterlyPayments = decoded
        }
        if defaults.object(forKey: StorageKey.yourRothConversion) != nil {
            dm.yourRothConversion = defaults.double(forKey: StorageKey.yourRothConversion)
        }
        if defaults.object(forKey: StorageKey.spouseRothConversion) != nil {
            dm.spouseRothConversion = defaults.double(forKey: StorageKey.spouseRothConversion)
        }
        if defaults.object(forKey: StorageKey.yourExtraWithdrawal) != nil {
            dm.yourExtraWithdrawal = defaults.double(forKey: StorageKey.yourExtraWithdrawal)
        }
        if defaults.object(forKey: StorageKey.spouseExtraWithdrawal) != nil {
            dm.spouseExtraWithdrawal = defaults.double(forKey: StorageKey.spouseExtraWithdrawal)
        }
        if defaults.object(forKey: StorageKey.yourQCDAmount) != nil {
            dm.yourQCDAmount = defaults.double(forKey: StorageKey.yourQCDAmount)
        }
        if defaults.object(forKey: StorageKey.spouseQCDAmount) != nil {
            dm.spouseQCDAmount = defaults.double(forKey: StorageKey.spouseQCDAmount)
        }
        // Migrate from legacy single qcdAmount → assign to primary
        if dm.yourQCDAmount == 0 && dm.spouseQCDAmount == 0,
           defaults.object(forKey: StorageKey.qcdAmount) != nil {
            dm.yourQCDAmount = defaults.double(forKey: StorageKey.qcdAmount)
        }
        // Withdrawal/conversion quarter timing
        if defaults.object(forKey: StorageKey.yourWithdrawalQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.yourWithdrawalQuarter)
            dm.yourWithdrawalQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.spouseWithdrawalQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.spouseWithdrawalQuarter)
            dm.spouseWithdrawalQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.yourRothConversionQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.yourRothConversionQuarter)
            dm.yourRothConversionQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.spouseRothConversionQuarter) != nil {
            let v = defaults.integer(forKey: StorageKey.spouseRothConversionQuarter)
            dm.spouseRothConversionQuarter = (1...4).contains(v) ? v : 4
        }
        if defaults.object(forKey: StorageKey.stockDonationEnabled) != nil {
            dm.stockDonationEnabled = defaults.bool(forKey: StorageKey.stockDonationEnabled)
        }
        if defaults.object(forKey: StorageKey.stockPurchasePrice) != nil {
            dm.stockPurchasePrice = defaults.double(forKey: StorageKey.stockPurchasePrice)
        }
        if defaults.object(forKey: StorageKey.stockCurrentValue) != nil {
            dm.stockCurrentValue = defaults.double(forKey: StorageKey.stockCurrentValue)
        }
        if defaults.object(forKey: StorageKey.stockPurchaseDate) != nil {
            let interval = defaults.double(forKey: StorageKey.stockPurchaseDate)
            if interval > 0 {
                dm.stockPurchaseDate = Date(timeIntervalSince1970: interval)
            }
        }
        if defaults.object(forKey: StorageKey.cashDonationAmount) != nil {
            dm.cashDonationAmount = defaults.double(forKey: StorageKey.cashDonationAmount)
        }
        if let data = defaults.data(forKey: StorageKey.inheritedExtraWithdrawals),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            dm.inheritedExtraWithdrawals = Dictionary(uniqueKeysWithValues:
                decoded.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
        }
        if let raw = defaults.string(forKey: StorageKey.deductionOverride),
           let choice = DeductionChoice(rawValue: raw) {
            dm.deductionOverride = choice
        }
        if let data = defaults.data(forKey: StorageKey.completedActionKeys),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            dm.completedActionKeys = decoded
        }

        // Growth rates
        if defaults.object(forKey: StorageKey.primaryGrowthRate) != nil {
            dm.primaryGrowthRate = defaults.double(forKey: StorageKey.primaryGrowthRate)
        }
        if defaults.object(forKey: StorageKey.spouseGrowthRate) != nil {
            dm.spouseGrowthRate = defaults.double(forKey: StorageKey.spouseGrowthRate)
        }

        // Legacy planning
        if defaults.object(forKey: StorageKey.enableLegacyPlanning) != nil {
            dm.enableLegacyPlanning = defaults.bool(forKey: StorageKey.enableLegacyPlanning)
        }
        if let heirType = defaults.string(forKey: StorageKey.legacyHeirType) {
            dm.legacyHeirType = heirType
        }
        if defaults.object(forKey: StorageKey.legacyHeirEstimatedSalary) != nil {
            dm.legacyHeirEstimatedSalary = defaults.double(forKey: StorageKey.legacyHeirEstimatedSalary)
        }
        if let raw = defaults.string(forKey: StorageKey.legacyHeirFilingStatus),
           let status = FilingStatus(rawValue: raw) {
            dm.legacyHeirFilingStatus = status
        }
        if defaults.object(forKey: StorageKey.legacyHeirBirthYear) != nil {
            let stored = defaults.integer(forKey: StorageKey.legacyHeirBirthYear)
            dm.legacyHeirBirthYear = stored > 0 ? stored : nil
        }
        if defaults.object(forKey: StorageKey.legacySpouseSurvivorYears) != nil {
            let stored = defaults.integer(forKey: StorageKey.legacySpouseSurvivorYears)
            dm.legacySpouseSurvivorYears = stored > 0 ? stored : 10
        }
        if defaults.object(forKey: StorageKey.legacyGrowthRate) != nil {
            dm.legacy.legacyGrowthRate = defaults.double(forKey: StorageKey.legacyGrowthRate)
        }

        // 1.9 Medicare plan type + premium overrides
        if let raw = defaults.string(forKey: StorageKey.yourMedicarePlanType),
           let plan = MedicarePlanType(rawValue: raw) {
            dm.scenario.yourMedicarePlanType = plan
        }
        if let raw = defaults.string(forKey: StorageKey.spouseMedicarePlanType),
           let plan = MedicarePlanType(rawValue: raw) {
            dm.scenario.spouseMedicarePlanType = plan
        }
        if defaults.object(forKey: StorageKey.yourMedicarePartBOverride) != nil {
            dm.scenario.yourMedicarePartBOverride = defaults.double(forKey: StorageKey.yourMedicarePartBOverride)
        }
        if defaults.object(forKey: StorageKey.spouseMedicarePartBOverride) != nil {
            dm.scenario.spouseMedicarePartBOverride = defaults.double(forKey: StorageKey.spouseMedicarePartBOverride)
        }
        if defaults.object(forKey: StorageKey.yourMedicarePartDOverride) != nil {
            dm.scenario.yourMedicarePartDOverride = defaults.double(forKey: StorageKey.yourMedicarePartDOverride)
        }
        if defaults.object(forKey: StorageKey.spouseMedicarePartDOverride) != nil {
            dm.scenario.spouseMedicarePartDOverride = defaults.double(forKey: StorageKey.spouseMedicarePartDOverride)
        }
        if defaults.object(forKey: StorageKey.yourMedigapOverride) != nil {
            dm.scenario.yourMedigapOverride = defaults.double(forKey: StorageKey.yourMedigapOverride)
        }
        if defaults.object(forKey: StorageKey.spouseMedigapOverride) != nil {
            dm.scenario.spouseMedigapOverride = defaults.double(forKey: StorageKey.spouseMedigapOverride)
        }
        if defaults.object(forKey: StorageKey.yourAdvantageOverride) != nil {
            dm.scenario.yourAdvantageOverride = defaults.double(forKey: StorageKey.yourAdvantageOverride)
        }
        if defaults.object(forKey: StorageKey.spouseAdvantageOverride) != nil {
            dm.scenario.spouseAdvantageOverride = defaults.double(forKey: StorageKey.spouseAdvantageOverride)
        }

        // Social Security Planner data
        dm.loadSSData()
    }

    // MARK: - Legacy Data Migration

    /// Migrate pre-1.7.2 `.rothConversion` income sources into the scenario
    /// Roth Conversion slider. Sentinel-prefixed names (applied during decode
    /// in `IncomeSource.init(from:)`) identify legacy sources. Each source:
    ///   - `annualAmount` is added to `yourRothConversion` or `spouseRothConversion`
    ///     based on its `owner`.
    ///   - Any federal/state withholding is preserved as a new "Other" income
    ///     source named "Migrated: withholding from prior Roth conversion". This
    ///     keeps total-withholding sums (and therefore Safe Harbor / quarterly
    ///     estimated-tax calculations) stable across the migration. Users can
    ///     delete the placeholder if they prefer.
    ///   - The legacy source is then removed from `incomeSources`.
    /// No-op when no legacy sources are present.
    @MainActor
    private static func migrateLegacyRothConversionSources(into dm: DataManager) {
        let prefix = IncomeSource.legacyRothConversionSentinelPrefix
        let legacySources = dm.incomeSources.filter { $0.name.hasPrefix(prefix) }
        guard !legacySources.isEmpty else { return }

        var migratedSources: [IncomeSource] = []
        for source in legacySources {
            if source.owner == .spouse {
                dm.spouseRothConversion += source.annualAmount
            } else {
                dm.yourRothConversion += source.annualAmount
            }

            let originalName = String(source.name.dropFirst(prefix.count))
            let withholdingTotal = source.federalWithholding + source.stateWithholding
            if withholdingTotal > 0 {
                migratedSources.append(
                    IncomeSource(
                        name: "Migrated: withholding from prior Roth conversion (\(originalName))",
                        type: .other,
                        annualAmount: 0,
                        federalWithholding: source.federalWithholding,
                        stateWithholding: source.stateWithholding,
                        owner: source.owner
                    )
                )
            }
        }
        dm.incomeSources.removeAll { $0.name.hasPrefix(prefix) }
        dm.incomeSources.append(contentsOf: migratedSources)
    }

    // MARK: - Save All

    @MainActor
    static func saveAll(from dm: DataManager, defaults: UserDefaults = .standard) {
        // Profile
        defaults.set(dm.birthDate.timeIntervalSince1970, forKey: StorageKey.birthDate)
        defaults.set(dm.filingStatus.rawValue, forKey: StorageKey.filingStatus)
        defaults.set(dm.selectedState.rawValue, forKey: StorageKey.selectedState)
        defaults.set(dm.planYear, forKey: StorageKey.planYear)
        defaults.set(dm.spouseName, forKey: StorageKey.spouseName)
        defaults.set(dm.userName, forKey: StorageKey.userName)
        defaults.set(dm.spouseBirthDate.timeIntervalSince1970, forKey: StorageKey.spouseBirthDate)
        defaults.set(dm.enableSpouse, forKey: StorageKey.enableSpouse)

        // Accounts
        if let data = try? JSONEncoder().encode(dm.iraAccounts) {
            defaults.set(data, forKey: StorageKey.iraAccounts)
        }

        // Income & Deductions
        if let data = try? JSONEncoder().encode(dm.incomeSources) {
            defaults.set(data, forKey: StorageKey.incomeSources)
        }
        if let data = try? JSONEncoder().encode(dm.deductionItems) {
            defaults.set(data, forKey: StorageKey.deductionItems)
        }
        defaults.set(dm.priorYearStateBalance, forKey: StorageKey.priorYearStateBalance)
        defaults.set(dm.priorYearFederalTax, forKey: StorageKey.priorYearFederalTax)
        defaults.set(dm.priorYearStateTax, forKey: StorageKey.priorYearStateTax)
        defaults.set(dm.priorYearAGI, forKey: StorageKey.priorYearAGI)
        defaults.set(dm.safeHarborMethod.rawValue, forKey: StorageKey.safeHarborMethod)

        // Scenario state
        if let data = try? JSONEncoder().encode(dm.quarterlyPayments) {
            defaults.set(data, forKey: StorageKey.quarterlyPayments)
        }
        defaults.set(dm.yourRothConversion, forKey: StorageKey.yourRothConversion)
        defaults.set(dm.spouseRothConversion, forKey: StorageKey.spouseRothConversion)
        defaults.set(dm.yourExtraWithdrawal, forKey: StorageKey.yourExtraWithdrawal)
        defaults.set(dm.spouseExtraWithdrawal, forKey: StorageKey.spouseExtraWithdrawal)
        defaults.set(dm.yourQCDAmount, forKey: StorageKey.yourQCDAmount)
        defaults.set(dm.spouseQCDAmount, forKey: StorageKey.spouseQCDAmount)
        defaults.set(dm.yourWithdrawalQuarter, forKey: StorageKey.yourWithdrawalQuarter)
        defaults.set(dm.spouseWithdrawalQuarter, forKey: StorageKey.spouseWithdrawalQuarter)
        defaults.set(dm.yourRothConversionQuarter, forKey: StorageKey.yourRothConversionQuarter)
        defaults.set(dm.spouseRothConversionQuarter, forKey: StorageKey.spouseRothConversionQuarter)
        defaults.set(dm.stockDonationEnabled, forKey: StorageKey.stockDonationEnabled)
        defaults.set(dm.stockPurchasePrice, forKey: StorageKey.stockPurchasePrice)
        defaults.set(dm.stockCurrentValue, forKey: StorageKey.stockCurrentValue)
        defaults.set(dm.stockPurchaseDate.timeIntervalSince1970, forKey: StorageKey.stockPurchaseDate)
        defaults.set(dm.cashDonationAmount, forKey: StorageKey.cashDonationAmount)
        let inheritedDict = Dictionary(uniqueKeysWithValues: dm.inheritedExtraWithdrawals.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(inheritedDict) {
            defaults.set(data, forKey: StorageKey.inheritedExtraWithdrawals)
        }
        if let override = dm.deductionOverride {
            defaults.set(override.rawValue, forKey: StorageKey.deductionOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.deductionOverride)
        }
        if let data = try? JSONEncoder().encode(dm.completedActionKeys) {
            defaults.set(data, forKey: StorageKey.completedActionKeys)
        }

        // Growth rates
        defaults.set(dm.primaryGrowthRate, forKey: StorageKey.primaryGrowthRate)
        defaults.set(dm.spouseGrowthRate, forKey: StorageKey.spouseGrowthRate)

        // Legacy planning
        defaults.set(dm.enableLegacyPlanning, forKey: StorageKey.enableLegacyPlanning)
        defaults.set(dm.legacyHeirType, forKey: StorageKey.legacyHeirType)
        defaults.set(dm.legacyHeirEstimatedSalary, forKey: StorageKey.legacyHeirEstimatedSalary)
        defaults.set(dm.legacyHeirFilingStatus.rawValue, forKey: StorageKey.legacyHeirFilingStatus)
        if let birthYear = dm.legacyHeirBirthYear {
            defaults.set(birthYear, forKey: StorageKey.legacyHeirBirthYear)
        } else {
            defaults.removeObject(forKey: StorageKey.legacyHeirBirthYear)
        }
        defaults.set(dm.legacySpouseSurvivorYears, forKey: StorageKey.legacySpouseSurvivorYears)
        if let customRate = dm.legacy.legacyGrowthRate {
            defaults.set(customRate, forKey: StorageKey.legacyGrowthRate)
        } else {
            defaults.removeObject(forKey: StorageKey.legacyGrowthRate)
        }

        // 1.9 Medicare plan type + premium overrides
        defaults.set(dm.scenario.yourMedicarePlanType.rawValue, forKey: StorageKey.yourMedicarePlanType)
        defaults.set(dm.scenario.spouseMedicarePlanType.rawValue, forKey: StorageKey.spouseMedicarePlanType)
        if let v = dm.scenario.yourMedicarePartBOverride {
            defaults.set(v, forKey: StorageKey.yourMedicarePartBOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.yourMedicarePartBOverride)
        }
        if let v = dm.scenario.spouseMedicarePartBOverride {
            defaults.set(v, forKey: StorageKey.spouseMedicarePartBOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.spouseMedicarePartBOverride)
        }
        if let v = dm.scenario.yourMedicarePartDOverride {
            defaults.set(v, forKey: StorageKey.yourMedicarePartDOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.yourMedicarePartDOverride)
        }
        if let v = dm.scenario.spouseMedicarePartDOverride {
            defaults.set(v, forKey: StorageKey.spouseMedicarePartDOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.spouseMedicarePartDOverride)
        }
        if let v = dm.scenario.yourMedigapOverride {
            defaults.set(v, forKey: StorageKey.yourMedigapOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.yourMedigapOverride)
        }
        if let v = dm.scenario.spouseMedigapOverride {
            defaults.set(v, forKey: StorageKey.spouseMedigapOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.spouseMedigapOverride)
        }
        if let v = dm.scenario.yourAdvantageOverride {
            defaults.set(v, forKey: StorageKey.yourAdvantageOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.yourAdvantageOverride)
        }
        if let v = dm.scenario.spouseAdvantageOverride {
            defaults.set(v, forKey: StorageKey.spouseAdvantageOverride)
        } else {
            defaults.removeObject(forKey: StorageKey.spouseAdvantageOverride)
        }

        // Social Security Planner data
        dm.saveSSData()
    }

    // MARK: - Tax Brackets

    static func saveTaxBrackets(_ brackets: TaxBrackets, defaults: UserDefaults = .standard) {
        if let encoded = try? JSONEncoder().encode(brackets) {
            defaults.set(encoded, forKey: StorageKey.taxBrackets)
        }
    }
}
