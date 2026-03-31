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

    init(id: UUID = UUID(), name: String, accountType: AccountType, balance: Double, institution: String = "", owner: Owner = .primary,
         beneficiaryType: BeneficiaryType? = nil, decedentRBDStatus: DecedentRBDStatus? = nil,
         yearOfInheritance: Int? = nil, decedentBirthYear: Int? = nil,
         beneficiaryBirthYear: Int? = nil, minorChildMajorityYear: Int? = nil) {
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
