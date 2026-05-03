//
//  IncomeModels.swift
//  RetireSmartIRA
//
//  Income and deduction data models extracted from DataManager.
//

import Foundation

struct IncomeSource: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: IncomeType
    var annualAmount: Double
    var federalWithholding: Double
    var stateWithholding: Double
    var owner: Owner

    /// Combined federal + state withholding for this source
    var totalWithholding: Double { federalWithholding + stateWithholding }

    init(id: UUID = UUID(), name: String, type: IncomeType, annualAmount: Double, federalWithholding: Double = 0, stateWithholding: Double = 0, owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.type = type
        self.annualAmount = annualAmount
        self.federalWithholding = federalWithholding
        self.stateWithholding = stateWithholding
        self.owner = owner
    }

    // MARK: - Data Migration
    //
    // Decodes:
    //   (1) Legacy single "taxWithholding" field → federalWithholding.
    //   (2) Legacy `.rothConversion` IncomeType raw value ("Roth Conversion").
    //       The enum case was removed in 1.7.2 because Roth conversions are now
    //       modeled exclusively via the Scenarios slider. Sources decoded with
    //       the legacy raw value are marked with a sentinel name prefix so
    //       `PersistenceManager.loadAll` can migrate them into yourRothConversion
    //       / spouseRothConversion and remove them from the income list.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let decodedName = try container.decode(String.self, forKey: .name)

        // Decode type as raw string so we can detect the removed `.rothConversion` case.
        let typeRaw = try container.decode(String.self, forKey: .type)
        if typeRaw == IncomeType.legacyRothConversionRawValue {
            type = .other
            name = IncomeSource.legacyRothConversionSentinelPrefix + decodedName
        } else if let matched = IncomeType(rawValue: typeRaw) {
            type = matched
            name = decodedName
        } else {
            // Unknown type (future enum value, corrupt data): fall back to .other
            type = .other
            name = decodedName
        }

        annualAmount = try container.decode(Double.self, forKey: .annualAmount)
        owner = try container.decode(Owner.self, forKey: .owner)

        // Try new keys first; fall back to legacy "taxWithholding" → federalWithholding
        if let fed = try? container.decode(Double.self, forKey: .federalWithholding) {
            federalWithholding = fed
            stateWithholding = (try? container.decode(Double.self, forKey: .stateWithholding)) ?? 0
        } else {
            let legacy = (try? container.decode(Double.self, forKey: .taxWithholding)) ?? 0
            federalWithholding = legacy
            stateWithholding = 0
        }
    }

    /// Sentinel prefix applied to the `name` of legacy `.rothConversion` income
    /// sources during decode. `PersistenceManager.loadAll` detects this prefix
    /// and migrates the source (amount → scenario slider; withholding → an "Other"
    /// placeholder) before any UI sees it. No user will ever see the sentinel.
    static let legacyRothConversionSentinelPrefix = "__LEGACY_ROTH_CONVERSION__::"

    private enum CodingKeys: String, CodingKey {
        case id, name, type, annualAmount, federalWithholding, stateWithholding, owner, taxWithholding
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(annualAmount, forKey: .annualAmount)
        try container.encode(federalWithholding, forKey: .federalWithholding)
        try container.encode(stateWithholding, forKey: .stateWithholding)
        try container.encode(owner, forKey: .owner)
    }
}

enum IncomeType: String, Codable, CaseIterable {
    case socialSecurity = "Social Security"
    case pension = "Pension"
    case dividends = "Dividends"
    case qualifiedDividends = "Qualified Dividends"
    case interest = "Interest"
    case taxExemptInterest = "Tax-Exempt Interest"
    case capitalGainsShort = "Capital Gains (Short-term)"
    case capitalGainsLong = "Capital Gains (Long-term)"
    case consulting = "Employment/Other Income"
    case stateTaxRefund = "State Tax Refund"
    case rmd = "RMD"
    // IRC §104(a)(4): VA Disability compensation is excluded from gross income.
    // It never enters federal AGI, federal taxable income, state AGI, provisional
    // income for Social Security taxation, MAGI for ACA/IRMAA, NIIT, or AMT.
    // Tracked here for user budgeting only — the entire tax engine treats it as zero.
    case vaDisability = "VA Disability"
    case other = "Other"

    /// User-facing display name for the income-type picker. Defaults to the
    /// Codable raw value; override only where the UI should read differently
    /// than the stored serialization key (so stored data stays backward
    /// compatible without a migration).
    var displayName: String {
        switch self {
        case .dividends: return "Ordinary Dividends"   // pairs with "Qualified Dividends"
        case .interest: return "Taxable Interest"      // pairs with "Tax-Exempt Interest"
        default: return rawValue
        }
    }

    /// Legacy (pre-1.7.2) raw value for the removed `.rothConversion` case.
    /// Roth conversion is now exclusively modeled via the Scenarios-tab slider,
    /// not as an income line. Persisted data containing this raw value is
    /// migrated on load via `IncomeSource.init(from:)` + `PersistenceManager.loadAll`.
    static let legacyRothConversionRawValue = "Roth Conversion"
}

enum FilingStatus: String, Codable, CaseIterable {
    case single = "Single"
    case marriedFilingJointly = "Married Filing Jointly"
}

enum DeductionChoice: String, Codable {
    case standard
    case itemized
}

struct DeductionItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: DeductionType
    var annualAmount: Double
    var owner: Owner

    init(id: UUID = UUID(), name: String, type: DeductionType, annualAmount: Double, owner: Owner = .primary) {
        self.id = id
        self.name = name
        self.type = type
        self.annualAmount = annualAmount
        self.owner = owner
    }
}

enum DeductionType: String, Codable, CaseIterable {
    case mortgageInterest = "Mortgage Interest"
    case propertyTax = "Property Tax"
    case saltTax = "State & Local Tax (SALT)"
    case medicalExpenses = "Medical Expenses"
    case other = "Other Itemized"
}
