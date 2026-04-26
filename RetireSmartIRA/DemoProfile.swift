//
//  DemoProfile.swift
//  RetireSmartIRA
//
//  Static demo data for App Store screenshot capture.
//  Loaded only when the `-DemoProfile` launch argument is present.
//  All values are designed to populate every chart and scorecard with
//  realistic, non-zero numbers that tell a coherent story about a married
//  couple approaching retirement.
//
//  SAFETY: All reads and writes during a demo session go to a dedicated
//  UserDefaults suite, never UserDefaults.standard. The user's real data
//  is completely untouched whether or not the launch argument is active.
//

#if DEBUG
import Foundation

enum DemoProfile {

    // MARK: - Activation

    /// True when `-DemoProfile` is present in the launch arguments.
    static let isActive: Bool = {
        ProcessInfo.processInfo.arguments.contains("-DemoProfile")
    }()

    // MARK: - Demo Suite

    static let suiteName = "com.john.RetireSmartIRA.demo"

    /// The UserDefaults suite for the current session.
    /// Demo mode → dedicated suite (never pollutes real data).
    /// Normal mode → standard suite.
    static var defaults: UserDefaults {
        isActive
            ? UserDefaults(suiteName: suiteName) ?? .standard
            : .standard
    }

    // MARK: - Reset & Populate

    /// Clears the demo suite and populates every manager from the spec.
    /// Called once at app launch when `-DemoProfile` is active.
    @MainActor
    static func reset(into dataManager: DataManager) {
        // 1. Clear demo suite to start fresh
        UserDefaults().removePersistentDomain(forName: suiteName)

        // 2. Populate every manager with demo values
        configureProfile(dataManager.profile)
        configureAccounts(dataManager.accounts)
        configureIncomeDeductions(dataManager.incomeDeductions)
        configureSocialSecurity(dataManager.socialSecurity)
        configureScenario(dataManager.scenario)
    }

    // MARK: - Per-manager Configuration

    @MainActor
    private static func configureProfile(_ profile: ProfileManager) {
        profile.userName = "Pat"

        // Pat: 64 in 2026 — 1 year from Medicare, IRMAA tier shifts visible
        var c = DateComponents()
        c.year = 1962; c.month = 6; c.day = 15
        if let d = Calendar.current.date(from: c) { profile.birthDate = d }

        profile.spouseName = "Sue"

        // Sue: 62 in 2026 — earliest claim age for SS, "should she claim now?" decision live
        var cs = DateComponents()
        cs.year = 1964; cs.month = 9; cs.day = 22
        if let d = Calendar.current.date(from: cs) { profile.spouseBirthDate = d }

        profile.enableSpouse = true
        profile.filingStatus = .marriedFilingJointly
        profile.selectedState = .california
        profile.currentYear = 2026
        profile.planYear = 2026
    }

    @MainActor
    private static func configureAccounts(_ accounts: AccountsManager) {
        accounts.iraAccounts = [
            IRAAccount(
                name: "Vanguard Traditional IRA",
                accountType: .traditionalIRA,
                balance: 1_200_000,
                institution: "Vanguard",
                owner: .primary
            ),
            IRAAccount(
                name: "Vanguard Roth IRA",
                accountType: .rothIRA,
                balance: 200_000,
                institution: "Vanguard",
                owner: .primary
            ),
            IRAAccount(
                name: "Fidelity Traditional IRA",
                accountType: .traditionalIRA,
                balance: 400_000,
                institution: "Fidelity",
                owner: .spouse
            ),
            IRAAccount(
                name: "Fidelity Roth IRA",
                accountType: .rothIRA,
                balance: 80_000,
                institution: "Fidelity",
                owner: .spouse
            ),
            IRAAccount(
                name: "Inherited from Mom",
                accountType: .inheritedTraditionalIRA,
                balance: 250_000,
                institution: "Schwab",
                owner: .primary,
                beneficiaryType: .nonEligibleDesignated,
                decedentRBDStatus: .afterRBD,
                yearOfInheritance: 2023,
                decedentBirthYear: 1942,
                beneficiaryBirthYear: 1962
            )
        ]
    }

    @MainActor
    private static func configureIncomeDeductions(_ id: IncomeDeductionsManager) {
        id.incomeSources = [
            IncomeSource(
                name: "Consulting",
                type: .consulting,
                annualAmount: 120_000,
                federalWithholding: 18_000,
                stateWithholding: 9_000,
                owner: .primary
            ),
            IncomeSource(
                name: "Part-time",
                type: .consulting,
                annualAmount: 60_000,
                federalWithholding: 7_500,
                stateWithholding: 3_500,
                owner: .spouse
            ),
            IncomeSource(
                name: "Teachers Pension",
                type: .pension,
                annualAmount: 3_500,
                owner: .spouse
            ),
            IncomeSource(
                name: "Brokerage interest",
                type: .interest,
                annualAmount: 1_170,
                owner: .primary
            ),
            IncomeSource(
                name: "Muni bonds",
                type: .taxExemptInterest,
                annualAmount: 46_927,
                owner: .primary
            ),
            IncomeSource(
                name: "Brokerage dividends",
                type: .dividends,
                annualAmount: 48_860,
                owner: .primary
            ),
            IncomeSource(
                name: "Qualified portion",
                type: .qualifiedDividends,
                annualAmount: 42_000,
                owner: .primary
            ),
            IncomeSource(
                name: "VTI realization",
                type: .capitalGainsLong,
                annualAmount: 64_219,
                owner: .primary
            ),
            IncomeSource(
                name: "Inherited IRA RMD",
                type: .rmd,
                annualAmount: 11_302,
                owner: .primary
            )
        ]

        id.deductionItems = [
            DeductionItem(
                name: "Primary residence mortgage",
                type: .mortgageInterest,
                annualAmount: 15_000,
                owner: .primary
            ),
            DeductionItem(
                name: "Property taxes",
                type: .propertyTax,
                annualAmount: 12_000,
                owner: .primary
            ),
            DeductionItem(
                name: "State income tax",
                type: .saltTax,
                annualAmount: 8_000,
                owner: .primary
            ),
            DeductionItem(
                name: "Charitable contributions",
                type: .other,
                annualAmount: 5_000,
                owner: .primary
            )
        ]

        id.priorYearStateBalance = 0
        id.priorYearFederalTax = 38_000
        id.priorYearStateTax = 9_000
        id.priorYearAGI = 285_000
    }

    @MainActor
    private static func configureSocialSecurity(_ ss: SocialSecurityManager) {
        ss.primarySSBenefit = SSBenefitEstimate(
            owner: .primary,
            benefitAt62: 2660,
            benefitAtFRA: 3800,
            benefitAt70: 4712,
            plannedClaimingAge: 70,
            plannedClaimingMonth: 0,
            isAlreadyClaiming: false,
            currentBenefit: 0
        )

        ss.spouseSSBenefit = SSBenefitEstimate(
            owner: .spouse,
            benefitAt62: 1680,
            benefitAtFRA: 2400,
            benefitAt70: 2976,
            plannedClaimingAge: 67,
            plannedClaimingMonth: 0,
            isAlreadyClaiming: false,
            currentBenefit: 0
        )

        ss.ssWhatIfParams = SSWhatIfParameters(
            primaryLifeExpectancy: 88,
            spouseLifeExpectancy: 91,
            colaRate: 2.5,
            discountRate: 0
        )

        ss.ssAutoSync = true
    }

    @MainActor
    private static func configureScenario(_ scenario: ScenarioStateManager) {
        scenario.yourRothConversion = 200_000
        scenario.spouseRothConversion = 0
        scenario.yourRothConversionQuarter = 4
        scenario.yourExtraWithdrawal = 0
        scenario.spouseExtraWithdrawal = 0
        scenario.yourQCDAmount = 0
        scenario.spouseQCDAmount = 0
    }
}
#endif
