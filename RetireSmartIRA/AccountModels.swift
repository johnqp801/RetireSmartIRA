//
//  AccountModels.swift
//  RetireSmartIRA
//
//  Account-related data models extracted from DataManager.
//

import Foundation

enum Owner: String, Codable, CaseIterable {
    case primary = "You"
    case spouse = "Spouse"
    case joint = "Joint"

    /// Owners selectable for a retirement account.
    ///
    /// An IRA is an *Individual* Retirement Arrangement — it has exactly one
    /// owner under IRS rules — so `.joint` is never offered here, and `.spouse`
    /// is offered only once a spouse is actually configured.  Picking an owner
    /// who doesn't exist leaves the account priced off a profile with no ages,
    /// which is how a $900,000 IRA once displayed a $450,000 RMD.
    ///
    /// `current` is always included so opening an account saved under the old
    /// rules neither blanks the picker nor silently rewrites its owner.
    static func retirementOwnerOptions(enableSpouse: Bool, including current: Owner) -> [Owner] {
        var options: [Owner] = [.primary]
        if enableSpouse { options.append(.spouse) }
        if !options.contains(current) { options.append(current) }
        return options
    }
}

struct IRAAccount: Identifiable, Codable {
    let id: UUID
    var name: String
    var accountType: AccountType
    var balance: Double
    var institution: String
    var owner: Owner

    // Inherited IRA fields (nil for regular accounts)
    var beneficiaryType: BeneficiaryType?
    var decedentRBDStatus: DecedentRBDStatus?
    var yearOfInheritance: Int?
    var decedentBirthYear: Int?
    var beneficiaryBirthYear: Int?
    var minorChildMajorityYear: Int?

    /// How this retirement plan is structured. Phase 3b. Always has a
    /// value: accounts created before this phase, or created without
    /// specifying it, fall back to
    /// `RetirementPlanClassification.infer(accountType:)` per design doc
    /// section 3.6, never left unset. See `planSource` for the orthogonal
    /// jurisdiction/employer dimension.
    var planStructure: PlanStructure

    /// Where this retirement plan's contributions originate. Phase 3b. Same
    /// fallback rule as `planStructure`.
    var planSource: PlanSource

    init(id: UUID = UUID(), name: String, accountType: AccountType, balance: Double, institution: String = "", owner: Owner = .primary,
         beneficiaryType: BeneficiaryType? = nil, decedentRBDStatus: DecedentRBDStatus? = nil,
         yearOfInheritance: Int? = nil, decedentBirthYear: Int? = nil,
         beneficiaryBirthYear: Int? = nil, minorChildMajorityYear: Int? = nil,
         planStructure: PlanStructure? = nil, planSource: PlanSource? = nil) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.balance = balance
        self.institution = institution
        self.owner = owner
        self.beneficiaryType = beneficiaryType
        self.decedentRBDStatus = decedentRBDStatus
        self.yearOfInheritance = yearOfInheritance
        self.decedentBirthYear = decedentBirthYear
        self.beneficiaryBirthYear = beneficiaryBirthYear
        self.minorChildMajorityYear = minorChildMajorityYear
        // No caller-supplied classification falls back to inference from
        // `accountType`, same rule the decoder applies. Every call site
        // across the app that predates Phase 3b (AccountsView,
        // InheritedAccountInput, dozens of tests) constructs IRAAccount
        // without these two parameters, so this default is load-bearing.
        let inferred = RetirementPlanClassification.infer(accountType: accountType)
        self.planStructure = planStructure ?? inferred.structure
        self.planSource = planSource ?? inferred.source
    }

    // MARK: - Data Migration
    //
    // Phase 3b (design doc section 3.6): planStructure/planSource are new
    // non-optional fields. This decodes USER-SAVED data
    // (`PersistenceManager.loadAll` wraps its `[IRAAccount]` decode in
    // `try?`), so `PlanClassificationUserSaveDecoding.decode` never throws:
    // an absent key falls back to `RetirementPlanClassification.infer(accountType:)`,
    // letting a blob written before this phase, which has neither key,
    // decode without user intervention and land on the correct
    // classification, and a PRESENT but unrecognised raw value falls back
    // to `.unknown` with `unrecognisedClassificationEncountered` set,
    // instead of throwing and, via that `try?`, discarding every stored
    // account. Shipped state JSON decodes `PlanStructure`/`PlanSource`
    // directly and keeps the strict throw; see design doc section 6 and
    // `Phase3bClassificationTests`. Custom Codable conformance is required
    // here (IRAAccount previously used fully synthesised Codable) because
    // synthesis cannot express "missing key -> inference fallback" for a
    // non-optional property.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        accountType = try container.decode(AccountType.self, forKey: .accountType)
        balance = try container.decode(Double.self, forKey: .balance)
        institution = try container.decode(String.self, forKey: .institution)
        owner = try container.decode(Owner.self, forKey: .owner)
        beneficiaryType = try container.decodeIfPresent(BeneficiaryType.self, forKey: .beneficiaryType)
        decedentRBDStatus = try container.decodeIfPresent(DecedentRBDStatus.self, forKey: .decedentRBDStatus)
        yearOfInheritance = try container.decodeIfPresent(Int.self, forKey: .yearOfInheritance)
        decedentBirthYear = try container.decodeIfPresent(Int.self, forKey: .decedentBirthYear)
        beneficiaryBirthYear = try container.decodeIfPresent(Int.self, forKey: .beneficiaryBirthYear)
        minorChildMajorityYear = try container.decodeIfPresent(Int.self, forKey: .minorChildMajorityYear)

        let inferred = RetirementPlanClassification.infer(accountType: accountType)
        planStructure = PlanClassificationUserSaveDecoding.decode(
            PlanStructure.self, from: container, forKey: .planStructure, inferredFallback: inferred.structure)
        planSource = PlanClassificationUserSaveDecoding.decode(
            PlanSource.self, from: container, forKey: .planSource, inferredFallback: inferred.source)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, accountType, balance, institution, owner
        case beneficiaryType, decedentRBDStatus, yearOfInheritance, decedentBirthYear, beneficiaryBirthYear, minorChildMajorityYear
        case planStructure, planSource
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(accountType, forKey: .accountType)
        try container.encode(balance, forKey: .balance)
        try container.encode(institution, forKey: .institution)
        try container.encode(owner, forKey: .owner)
        try container.encodeIfPresent(beneficiaryType, forKey: .beneficiaryType)
        try container.encodeIfPresent(decedentRBDStatus, forKey: .decedentRBDStatus)
        try container.encodeIfPresent(yearOfInheritance, forKey: .yearOfInheritance)
        try container.encodeIfPresent(decedentBirthYear, forKey: .decedentBirthYear)
        try container.encodeIfPresent(beneficiaryBirthYear, forKey: .beneficiaryBirthYear)
        try container.encodeIfPresent(minorChildMajorityYear, forKey: .minorChildMajorityYear)
        try container.encode(planStructure, forKey: .planStructure)
        try container.encode(planSource, forKey: .planSource)
    }
}

enum AccountType: String, Codable, CaseIterable {
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case traditional401k = "Traditional 401(k)"
    case roth401k = "Roth 401(k)"
    case inheritedTraditionalIRA = "Inherited Traditional IRA"
    case inheritedRothIRA = "Inherited Roth IRA"

    var isInherited: Bool {
        self == .inheritedTraditionalIRA || self == .inheritedRothIRA
    }

    var isTraditionalType: Bool {
        self == .traditionalIRA || self == .traditional401k || self == .inheritedTraditionalIRA
    }

    var isRothType: Bool {
        self == .rothIRA || self == .roth401k || self == .inheritedRothIRA
    }
}

enum BeneficiaryType: String, Codable, CaseIterable {
    case spouse = "Spouse"
    case minorChild = "Minor Child"
    case disabled = "Disabled Individual"
    case chronicallyIll = "Chronically Ill Individual"
    case notTenYearsYounger = "Not >10 Years Younger"
    case nonEligibleDesignated = "Non-Eligible Designated"

    /// Eligible Designated Beneficiaries get lifetime stretch; others get 10-year rule
    var isEligibleDesignated: Bool {
        switch self {
        case .spouse, .minorChild, .disabled, .chronicallyIll, .notTenYearsYounger:
            return true
        case .nonEligibleDesignated:
            return false
        }
    }
}

enum DecedentRBDStatus: String, Codable, CaseIterable {
    case beforeRBD = "Before RBD"
    case afterRBD = "After RBD"
}
