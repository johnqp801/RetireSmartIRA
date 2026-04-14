//
//  GuideView.swift
//  RetireSmartIRA
//
//  Get Started guide: setup checklist, tab guides, key concepts, and tips
//

import SwiftUI

struct GuideView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedTab: Int

    @Environment(\.availableWidth) private var availableWidth
    private var isWideLayout: Bool { horizontalSizeClass == .regular && availableWidth > 700 }

    // Section expansion states
    @State private var gatherExpanded: Bool = true
    @State private var myProfileGuideExpanded: Bool = false
    @State private var ssGuideExpanded: Bool = false
    @State private var accountsGuideExpanded: Bool = false
    @State private var incomeGuideExpanded: Bool = false
    @State private var taxSummaryGuideExpanded: Bool = false
    @State private var rmdGuideExpanded: Bool = false
    @State private var scenariosGuideExpanded: Bool = false
    @State private var quarterlyTaxGuideExpanded: Bool = false
    @State private var stateComparisonGuideExpanded: Bool = false
    @State private var keyConceptsExpanded: Bool = false
    @State private var tipsExpanded: Bool = false

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(PlatformColor.systemGroupedBackground))
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                welcomeHeader
                setupProgressCard
                gatherBeforeYouStart
                tabGuidesHeader
                myProfileGuide
                ssGuide
                incomeGuide
                accountsGuide
                rmdGuide
                scenariosGuide
                taxSummaryGuide
                quarterlyTaxGuide
                stateComparisonGuide
                keyConceptsSection
                tipsSection
                disclaimerCard
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(spacing: 24) {
                    welcomeHeader
                    setupProgressCard
                    gatherBeforeYouStart
                    keyConceptsSection
                    tipsSection
                    disclaimerCard
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    tabGuidesHeader
                    myProfileGuide
                    ssGuide
                    incomeGuide
                    accountsGuide
                    rmdGuide
                    scenariosGuide
                    taxSummaryGuide
                    quarterlyTaxGuide
                    stateComparisonGuide
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(.blue)
                Text("Get Started")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Plan your retirement tax strategy with confidence. This guide walks you through setting up the app and understanding its features. Plan to spend about 30 minutes on your first setup — see \"What to Gather Before You Start\" below.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Uses 2026 federal tax brackets and state tax rates for all 50 states.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Setup Progress Card

    private var setupProgressCard: some View {
        let progress = dataManager.setupProgress

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Setup Progress")
                    .font(.headline)
                Spacer()
                Text("\(progress.completedSteps) of \(progress.totalSteps)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(progress.isComplete ? .green : .secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(PlatformColor.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progress.isComplete ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * Double(progress.completedSteps) / Double(progress.totalSteps), height: 8)
                }
            }
            .frame(height: 8)

            VStack(alignment: .leading, spacing: 10) {
                setupStepRow(title: "Set your date of birth", isComplete: progress.hasSetBirthDate, targetTab: 1)
                setupStepRow(title: "Enter Social Security benefits", isComplete: progress.hasSSBenefits, targetTab: 9)
                setupStepRow(title: "Enter income sources", isComplete: progress.hasIncomeSources, targetTab: 2)
                setupStepRow(title: "Add retirement accounts", isComplete: progress.hasAccounts, targetTab: 3)
                setupStepRow(title: "Add deductions", isComplete: progress.hasDeductions, targetTab: 2)
            }

            if progress.isComplete {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("All set! Your data is ready for tax planning.")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func setupStepRow(title: String, isComplete: Bool, targetTab: Int) -> some View {
        Button {
            selectedTab = targetTab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isComplete ? .green : .secondary)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .strikethrough(isComplete)
                    .foregroundStyle(isComplete ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gather Before You Start

    private var gatherBeforeYouStart: some View {
        DisclosureGroup(isExpanded: $gatherExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Have these documents and numbers handy to get the most out of the app right away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                gatherCategory(
                    icon: "calendar",
                    title: "Personal Information",
                    color: .gray,
                    items: [
                        "Date of birth (yours and spouse\u{2019}s if married filing jointly)",
                        "State of residence",
                        "Filing status"
                    ]
                )

                gatherCategory(
                    icon: "building.columns.fill",
                    title: "Account Balances (as of Dec. 31 of prior year)",
                    color: .blue,
                    items: [
                        "Traditional IRA and/or Traditional 401(k) balances",
                        "Roth IRA and/or Roth 401(k) balances",
                        "Inherited IRA balances (plus year inherited, decedent\u{2019}s birth year, and your beneficiary type)"
                    ]
                )

                gatherCategory(
                    icon: "person.text.rectangle.fill",
                    title: "Social Security",
                    color: .blue,
                    items: [
                        "If already receiving: your current monthly benefit amount (from SSA-1099 or bank deposit)",
                        "If not yet claiming: estimated benefits at ages 62, FRA, and 70 (from ssa.gov/myaccount)",
                        "Spouse\u{2019}s benefit information if married filing jointly",
                        "Optional: earnings history XML from your Social Security Statement for AIME/PIA calculation"
                    ]
                )

                gatherCategory(
                    icon: "banknote.fill",
                    title: "Other Income Sources (annual amounts)",
                    color: .green,
                    items: [
                        "Pension or annuity amounts (current year statement or prior year 1099-R)",
                        "Interest and dividends (use prior year 1099-INT / 1099-DIV as a starting estimate)",
                        "Capital gains (use prior year 1099-B as a guide; adjust for known changes)",
                        "Employment, consulting, or other income (prior year W-2 / 1099-NEC as a baseline)"
                    ]
                )

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("For income that varies year to year \u{2014} interest, dividends, capital gains, consulting \u{2014} last year\u{2019}s tax documents are a good starting point. You can always update amounts as the year progresses.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                gatherCategory(
                    icon: "checkmark.shield.fill",
                    title: "Withholding (per income source)",
                    color: .green,
                    items: [
                        "Federal tax withholding from each source (W-4P elections or prior year statements)",
                        "State tax withholding from each source"
                    ]
                )

                gatherCategory(
                    icon: "building.columns.fill",
                    title: "Prior Year State Taxes",
                    color: .indigo,
                    items: [
                        "Balance due paid with your prior year\u{2019}s state return (usually in April)",
                        "Or state tax refund received (may be taxable if you itemized last year)"
                    ]
                )

                gatherCategory(
                    icon: "doc.text.fill",
                    title: "Deductions (if you may itemize)",
                    color: .orange,
                    items: [
                        "Mortgage interest (Form 1098)",
                        "Property tax (annual amount from county/city bill)",
                        "Unreimbursed medical expenses (insurance premiums, copays, dental, vision, prescriptions, long-term care)",
                        "Additional state and local taxes (city or local income tax if applicable)"
                    ]
                )

                gatherCategory(
                    icon: "doc.plaintext",
                    title: "Prior Year Tax Return (for reference)",
                    color: .purple,
                    items: [
                        "Total tax liability (to compare 100% safe harbor vs. 90% current year)",
                        "Whether you itemized or took the standard deduction",
                        "State tax refund amount (taxable if you itemized)"
                    ]
                )

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Don\u{2019}t sweat it \u{2014} not all of these will apply to you. Start with the basics (birth date, accounts, and income) and add details as you gather them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 24)
                Text("What to Gather Before You Start")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func gatherCategory(icon: String, title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.subheadline)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 28)
            }
        }
    }

    // MARK: - Tab Guides

    private var tabGuidesHeader: some View {
        HStack {
            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(.blue)
            Text("Tab Guides")
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabGuideSection<Content: View>(icon: String, title: String, color: Color, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func guidePoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var myProfileGuide: some View {
        tabGuideSection(icon: "person.crop.circle.fill", title: "My Profile", color: .gray, isExpanded: $myProfileGuideExpanded) {
            guidePoint("Set your date of birth to determine current age, RMD age, and QCD eligibility")
            guidePoint("Choose Single or Married Filing Jointly")
            guidePoint("If married, enable spouse tracking with name and date of birth")
            guidePoint("RMD age is calculated automatically: 72 (born before 1951), 73 (1951\u{2013}1959), or 75 (1960+)")
            guidePoint("Changes save automatically")
        }
    }

    private var ssGuide: some View {
        tabGuideSection(icon: "person.text.rectangle.fill", title: "Social Security", color: .blue, isExpanded: $ssGuideExpanded) {
            guidePoint("Enter your SSA benefit estimates (at ages 62, FRA, and 70), or toggle \u{201C}Already Receiving\u{201D} to enter your current monthly payment")
            guidePoint("If married, enter benefits for both you and your spouse")
            guidePoint("Claiming Optimizer: compare cumulative lifetime benefits at different claiming ages with break-even analysis")
            guidePoint("Couples Strategy: see a claiming-age matrix showing which combination maximizes household lifetime income")
            guidePoint("Survivor Analysis: understand how household income changes if either spouse passes first")
            guidePoint("Tax Impact card shows how much of your SS is taxable based on your total income")
            guidePoint("Auto-sync sends your SS benefit amounts to Income & Deductions automatically \u{2014} no need to enter them twice")
            guidePoint("Optional: import your earnings history XML from ssa.gov for an independent AIME/PIA calculation")
        }
    }

    private var accountsGuide: some View {
        tabGuideSection(icon: "building.columns.fill", title: "Accounts", color: .blue, isExpanded: $accountsGuideExpanded) {
            guidePoint("Add all retirement accounts: Traditional IRA, Roth IRA, Traditional 401(k), Roth 401(k)")
            guidePoint("Inherited IRAs: select Inherited Traditional IRA or Inherited Roth IRA, then fill in beneficiary type, year inherited, and birth years")
            guidePoint("Enter balances as of December 31 of the prior year \u{2014} these drive RMD calculations")
            guidePoint("Assign each account to an owner (You, Spouse, or Joint)")
            guidePoint("Only Traditional accounts have RMD requirements; Roth IRAs do not")
            guidePoint("Inherited IRA RMDs follow different rules \u{2014} see RMD Calculator for details and deadlines")
            guidePoint("Tap any account to edit; swipe to delete")
        }
    }

    private var incomeGuide: some View {
        tabGuideSection(icon: "banknote.fill", title: "Income & Deductions", color: .green, isExpanded: $incomeGuideExpanded) {
            guidePoint("Social Security income is auto-synced from the SS Planner \u{2014} look for the \u{201C}Managed by SS Planner\u{201D} badge")
            guidePoint("Add other income sources: pensions, dividends, interest, capital gains, employment/other income")
            guidePoint("Enter federal and state withholding for each source \u{2014} this reduces quarterly payment estimates")
            guidePoint("Social Security is taxed at 0%, 50%, or 85% based on combined income thresholds")
            guidePoint("Long-term capital gains and qualified dividends receive preferential federal tax rates")
            guidePoint("Add itemized deductions (mortgage interest, property tax, medical, SALT) to compare against the standard deduction")
            guidePoint("The app automatically picks whichever deduction is higher, or you can override in Scenarios")
        }
    }

    private var taxSummaryGuide: some View {
        tabGuideSection(icon: "chart.bar.fill", title: "Tax Summary", color: .purple, isExpanded: $taxSummaryGuideExpanded) {
            guidePoint("Shows your complete financial picture at a glance")
            guidePoint("Income Breakdown: all sources plus RMD amounts")
            guidePoint("Tax Projection: federal + state tax, withholding credit, quarterly payment estimate")
            guidePoint("Tax Rates: marginal and average rates for both federal and your selected state")
            guidePoint("Action Items: a to-do list generated from your RMDs, conversions, QCDs, and quarterly payments")
            guidePoint("Account Balances: Traditional vs. Roth totals with per-owner breakdown if married")
        }
    }

    private var rmdGuide: some View {
        tabGuideSection(icon: "calendar.badge.clock", title: "RMD Calculator", color: .red, isExpanded: $rmdGuideExpanded) {
            guidePoint("Shows whether RMDs are required based on your age and birth year")
            guidePoint("Displays current year RMD amount using the IRS Uniform Lifetime Table factor")
            guidePoint("Per-account breakdown showing each account\u{2019}s RMD contribution")
            guidePoint("Projection tool: model future RMDs over multiple years with adjustable growth rates")
            guidePoint("Key deadline: December 31 each year (first-year RMD can be delayed to April 1 of next year, but two RMDs in one year)")
            guidePoint("If married, shows separate projections for each spouse plus combined household totals")
        }
    }

    private var scenariosGuide: some View {
        tabGuideSection(icon: "slider.horizontal.3", title: "Scenarios", color: .orange, isExpanded: $scenariosGuideExpanded) {
            guidePoint("This is the scenario modeling engine \u{2014} changes here flow to Tax Summary and Quarterly Tax")
            guidePoint("Withdrawal Timing: choose which quarter you plan to take each withdrawal or conversion \u{2014} this shifts the tax obligation to that quarter\u{2019}s estimated payment")
            guidePoint("Roth Conversions: set conversion amounts and see real-time bracket impact")
            guidePoint("QCD (Qualified Charitable Distribution): donate up to $111k/person directly from IRA to charity; satisfies RMD tax-free; requires age 70\u{00BD}+")
            guidePoint("Appreciated Stock Donation: donate appreciated stock to avoid tax on the gain — long-term holdings get a fair market value deduction; short-term holdings are deductible at cost basis")
            guidePoint("Cash Donations: direct cash gifts that provide a tax benefit when itemizing")
            guidePoint("Bracket Analysis shows whether your scenario pushes you into a higher federal or state bracket")
            guidePoint("Medicare IRMAA shows your current tier, annual surcharge, and how close you are to the next cliff \u{2014} scenario decisions that push you into a higher tier are flagged with a warning")
            guidePoint("Per-Decision Tax Impact shows the incremental tax cost or savings of each decision, including IRMAA surcharge changes")
        }
    }

    private var quarterlyTaxGuide: some View {
        tabGuideSection(icon: "dollarsign.circle.fill", title: "Quarterly Tax", color: .purple, isExpanded: $quarterlyTaxGuideExpanded) {
            guidePoint("Shows estimated quarterly tax payments based on all income and Scenario decisions")
            guidePoint("Annual tax summary: gross income, deductions, taxable income, federal + state tax")
            guidePoint("Federal and state withholding from income sources is credited against each tax liability")
            guidePoint("Payment schedule with IRS deadlines: April 15, June 15, September 15, January 15")
            guidePoint("Payment amounts vary by quarter based on when withdrawals and conversions are planned")
            guidePoint("Based on 90% safe harbor rule: pay 90% of current year tax to avoid underpayment penalties")
            guidePoint("Automatically recalculates when Scenario decisions change")
        }
    }

    private var stateComparisonGuide: some View {
        tabGuideSection(icon: "map.fill", title: "State Comparison", color: .teal, isExpanded: $stateComparisonGuideExpanded) {
            guidePoint("Ranks all 50 states + DC by state income tax based on your current income scenario")
            guidePoint("Shows your state\u{2019}s rank, tax amount, and effective rate at a glance")
            guidePoint("Tap any state for a detailed breakdown: retirement income exemptions, bracket-by-bracket calculations, and a side-by-side comparison to your current state")
            guidePoint("Highlights potential savings if you relocated to a lower-tax state")
            guidePoint("Accounts for state-specific retirement income exemptions (Social Security, pensions, IRA/RMD withdrawals)")
            guidePoint("Search by state name or abbreviation to quickly find any state")
        }
    }

    // MARK: - Key Concepts

    private var keyConceptsSection: some View {
        DisclosureGroup(isExpanded: $keyConceptsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                conceptItem(
                    icon: "calendar",
                    title: "RMD Age Rules",
                    description: "Born before 1951: age 72. Born 1951\u{2013}1959: age 73. Born 1960+: age 75. Missing an RMD incurs a 25% penalty."
                )
                conceptItem(
                    icon: "person.text.rectangle.fill",
                    title: "Social Security Claiming Age",
                    description: "Claiming at 62 reduces your benefit up to 30%. Each year you delay past FRA adds 8% in delayed retirement credits up to age 70. For couples, the higher earner delaying often maximizes lifetime household income and survivor benefits. Already receiving? Your current benefit is automatically included in tax calculations."
                )
                conceptItem(
                    icon: "arrow.right.arrow.left",
                    title: "Roth Conversion Window",
                    description: "The years between retirement and RMD age are often ideal for converting Traditional IRA funds to Roth at potentially lower tax rates. You can still do Roth conversions after RMDs begin — you just must take your RMD first. Even in higher brackets, conversions may benefit your long-term tax picture and legacy."
                )
                conceptItem(
                    icon: "heart.fill",
                    title: "QCD Strategy",
                    description: "Qualified Charitable Distributions (up to $111,000/person/year) go directly from your IRA to charity. They satisfy your RMD but are excluded from taxable income. Available at age 70\u{00BD}+. Only donations to qualifying charities are eligible — see IRS Publication 590-B for details (irs.gov/publications/p590b)."
                )
                conceptItem(
                    icon: "doc.plaintext",
                    title: "Standard vs. Itemized",
                    description: "The app compares your standard deduction (including age-based senior bonuses) against your itemized total. Charitable contributions from Scenarios are included automatically."
                )
                conceptItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Scenario Flow",
                    description: "Scenario decisions flow through to Tax Summary (tax projection, action items) and Quarterly Tax (estimated payments). All three views stay in sync."
                )
                conceptItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Preferential Tax Rates",
                    description: "Long-term capital gains and qualified dividends are taxed at 0%, 15%, or 20% federally. Some states (like California) tax capital gains as ordinary income."
                )
                conceptItem(
                    icon: "person.2.fill",
                    title: "Filing Status Impact",
                    description: "Married Filing Jointly has wider tax brackets, a higher standard deduction, and different Social Security taxation thresholds compared to Single."
                )
                conceptItem(
                    icon: "map.fill",
                    title: "State Tax Comparisons",
                    description: "State income tax varies dramatically \u{2014} nine states have no income tax, while others tax retirement income heavily. Many states exempt Social Security, and some exempt pensions or IRA withdrawals partially or fully. Where you live in retirement can save (or cost) thousands per year in state taxes."
                )
                conceptItem(
                    icon: "arrow.down.doc.fill",
                    title: "Inherited IRAs (BDAs)",
                    description: "Inherited IRAs have different rules based on your relationship to the decedent. Eligible Designated Beneficiaries (spouse, disabled, chronically ill, minor child, not >10 years younger) get lifetime stretch. All others must empty the account within 10 years. If the decedent had already begun RMDs, annual distributions are also required in years 1\u{2013}9. RMDs are calculated using the account balance as of December 31 of the prior year. Inherited IRA distributions are NOT eligible for QCDs."
                )
                conceptItem(
                    icon: "cross.case.fill",
                    title: "Medicare IRMAA",
                    description: "Income-Related Monthly Adjustment Amount adds surcharges to Medicare Parts B and D premiums when your MAGI exceeds thresholds. Unlike tax brackets, IRMAA uses cliffs \u{2014} crossing a threshold by even $1 triggers the full surcharge for that tier. IRMAA is based on income from 2 years prior, so this year\u{2019}s Roth conversions and withdrawals affect future premiums."
                )
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: 24)
                Text("Key Concepts")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func conceptItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tips & Best Practices

    private var tipsSection: some View {
        DisclosureGroup(isExpanded: $tipsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                tipItem(
                    icon: "arrow.right.arrow.left",
                    color: .orange,
                    title: "Convert Before RMDs",
                    description: "If you have years before RMDs start, consider Roth conversions to fill up lower tax brackets each year."
                )
                tipItem(
                    icon: "heart.fill",
                    color: .red,
                    title: "Use QCDs If Eligible",
                    description: "If you are age 70\u{00BD}+ and have RMDs, QCDs are the most tax-efficient way to give to charity. Donations must go to a qualifying organization — see IRS Publication 590-B for eligible recipients."
                )
                tipItem(
                    icon: "chart.bar.fill",
                    color: .blue,
                    title: "Watch the Brackets",
                    description: "Use Scenarios\u{2019} bracket analysis to find the sweet spot where you maximize conversions without jumping to a higher marginal rate."
                )
                tipItem(
                    icon: "cross.case.fill",
                    color: .pink,
                    title: "Watch IRMAA Cliffs",
                    description: "IRMAA surcharges are cliff-based \u{2014} crossing a threshold by even $1 can add over $1,100/year per person in Medicare premiums. Check the IRMAA section in Scenarios before finalizing Roth conversions or withdrawals. Your income this year affects premiums two years from now."
                )
                tipItem(
                    icon: "person.text.rectangle.fill",
                    color: .blue,
                    title: "SS and Tax Planning Together",
                    description: "Social Security benefits can be up to 85% taxable depending on your other income. Roth conversions increase provisional income, which can push more SS into the taxable range. Use the Tax Impact card in the SS Planner to see the interaction, and coordinate conversion amounts with your SS taxability."
                )
                tipItem(
                    icon: "dollarsign.circle",
                    color: .green,
                    title: "Track Withholding",
                    description: "Enter federal and state withholding on each income source so quarterly payment estimates reflect what you have already paid."
                )
                tipItem(
                    icon: "doc.text.fill",
                    color: .purple,
                    title: "Check Deductions",
                    description: "If you have significant mortgage interest, property tax, or medical expenses, add them. Charitable contributions may push you over the standard deduction threshold."
                )
                tipItem(
                    icon: "arrow.clockwise",
                    color: .teal,
                    title: "Revisit Quarterly",
                    description: "Review your scenario each quarter. Life changes, market fluctuations, and new income can shift your optimal strategy."
                )
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text("Tips & Best Practices")
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func tipItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                Text("Disclaimer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text("This app provides estimates for planning purposes only. Local and city income taxes (e.g. NYC, Yonkers) are not included. Consult with a qualified tax professional or financial advisor for personalized advice. Tax laws and regulations may change.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

#Preview {
    GuideView(selectedTab: .constant(0))
        .environmentObject(DataManager())
}
