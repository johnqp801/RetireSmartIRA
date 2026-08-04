//
//  RMDCalculatorView.swift
//  RetireSmartIRA
//
//  Calculate Required Minimum Distributions
//

import SwiftUI
import Charts

// MARK: - Projection Chart Data (pure, testable)

/// A single bar segment in the projected-RMD chart.
struct RMDChartDataPoint: Identifiable {
    let id = UUID()
    let year: Int
    let yearLabel: String
    let amount: Double
    let category: String
}

/// The one place that names a projection-chart series, and the one predicate for
/// "is this a regular (non-inherited) series".
///
/// The literal "IRA / 401(k)" used to be typed out at four separate call sites: the
/// series identity, the legend, `hasRegularRMDs`, the peak callout and the combined
/// peak's per-year total.  Splitting the regular bar per person would have silently
/// dropped the peak marker and undercounted the combined peak for couples.  Every
/// one of those call sites now routes through here.
enum RMDChartSeries {
    /// The inherited series is never split per person: an inherited account already
    /// carries its owner on the account row itself.
    static let inherited = "Inherited IRA"

    /// The regular series name for a household with no spouse.  This exact string is
    /// what single filers have always seen on this chart; it must not change.
    static let regularSingle = "IRA / 401(k)"

    /// The primary person's regular series, used only when a spouse is enabled.
    static let regularYours = "Your IRA / 401(k)"

    /// The spouse's regular series.  Matches the possessive convention the spouse
    /// RMD card on this screen already uses ("Karen's RMD" / "Spouse's RMD").
    static func regularSpouse(spouseName: String) -> String {
        spouseName.isEmpty ? "Spouse's IRA / 401(k)" : "\(spouseName)'s IRA / 401(k)"
    }

    /// The primary person's series name.  Only a household with a spouse gets the
    /// attributed "Your ..." form.
    static func regularPrimary(hasSpouse: Bool) -> String {
        hasSpouse ? regularYours : regularSingle
    }

    /// True for every series that is a living person's own IRA/401(k) RMD.
    static func isRegular(_ category: String) -> Bool {
        category != inherited
    }

    /// The color each series present in `data` is drawn with, in plotting order.
    ///
    /// Built from the data rather than enumerated as literals, so a couple's two
    /// regular series cannot fall through to default colors that collide with the
    /// inherited sand.
    static func styles(for data: [RMDChartDataPoint]) -> [ChartSeriesStyle] {
        var ordered: [String] = []
        for point in data where !ordered.contains(point.category) {
            ordered.append(point.category)
        }

        let regularPalette = [Color.Chart.heroTeal, Color.Chart.tealRamp4, Color.Chart.tealRamp2]
        var regularIndex = 0
        var styles: [ChartSeriesStyle] = []
        for category in ordered {
            if category == inherited {
                styles.append(ChartSeriesStyle(category: category, color: Color.Chart.callout))
            } else {
                let color = regularPalette[min(regularIndex, regularPalette.count - 1)]
                styles.append(ChartSeriesStyle(category: category, color: color))
                regularIndex += 1
            }
        }
        return styles
    }

    /// Per-year household total across every regular series, in plotting order.
    ///
    /// This is what the single combined "IRA / 401(k)" bar used to hold, and it is
    /// what the peak callouts read so the split cannot shrink the reported peak.
    static func regularTotalsByYear(_ data: [RMDChartDataPoint]) -> [(year: Int, total: Double)] {
        var totals: [Int: Double] = [:]
        var order: [Int] = []
        for point in data {
            if totals[point.year] == nil {
                order.append(point.year)
                totals[point.year] = 0
            }
            if isRegular(point.category) {
                totals[point.year, default: 0] += point.amount
            }
        }
        return order.map { (year: $0, total: totals[$0] ?? 0) }
    }
}

/// A series name paired with the color the chart draws it in.
struct ChartSeriesStyle: Identifiable {
    let category: String
    let color: Color
    var id: String { category }
}

/// The inputs the regular (non-inherited) projection series are built from.
struct RMDChartHousehold {
    var currentYear: Int
    var projectionYears: Int
    var primaryBalance: Double = 0
    var primaryCurrentAge: Int = 0
    var primaryRMDAge: Int = 73
    var primaryGrowthPercent: Double = 0
    var enableSpouse: Bool = false
    var spouseName: String = ""
    var spouseBalance: Double = 0
    var spouseCurrentAge: Int = 0
    var spouseRMDAge: Int = 73
    var spouseGrowthPercent: Double = 0
}

/// Builds the projection chart's regular series.
///
/// This lives outside the view on purpose.  The bug it fixes (both spouses summed
/// into a single bar) sat inside a private view computed property where no test
/// could see it.
enum RMDChartDataBuilder {

    /// Projects a balance forward using the given annual growth rate minus RMDs.
    static func projectBalance(
        years: Int,
        startingBalance: Double,
        startAge: Int,
        rmdStartAge: Int,
        growthPercent: Double
    ) -> Double {
        var balance = startingBalance
        let growthRate = growthPercent / 100.0

        for year in 0..<years {
            let age = startAge + year

            if age >= rmdStartAge {
                let rmd = RMDCalculationEngine.calculateRMD(for: age, balance: balance)
                balance -= rmd
            }

            balance *= (1 + growthRate)
        }

        return max(0, balance)
    }

    /// One regular series per person, year-major: every point for year N, then N+1.
    ///
    /// A person contributes a series only when they actually hold a balance, and the
    /// spouse contributes only when Enable Spouse is on; a disabled spouse produces
    /// no series at all rather than a flat zero one.  The per-person amounts for a
    /// year always sum to the single combined amount this chart used to draw.
    static func regularSeries(_ household: RMDChartHousehold) -> [RMDChartDataPoint] {
        struct Person {
            let category: String
            let balance: Double
            let currentAge: Int
            let rmdStartAge: Int
            let growthPercent: Double
        }

        var people: [Person] = []
        if household.primaryBalance > 0 {
            people.append(Person(
                category: RMDChartSeries.regularPrimary(hasSpouse: household.enableSpouse),
                balance: household.primaryBalance,
                currentAge: household.primaryCurrentAge,
                rmdStartAge: household.primaryRMDAge,
                growthPercent: household.primaryGrowthPercent
            ))
        }
        if household.enableSpouse && household.spouseBalance > 0 {
            people.append(Person(
                category: RMDChartSeries.regularSpouse(spouseName: household.spouseName),
                balance: household.spouseBalance,
                currentAge: household.spouseCurrentAge,
                rmdStartAge: household.spouseRMDAge,
                growthPercent: household.spouseGrowthPercent
            ))
        }

        guard household.projectionYears > 0, !people.isEmpty else { return [] }

        var points: [RMDChartDataPoint] = []
        for yearOffset in 0..<household.projectionYears {
            let projectedYear = household.currentYear + yearOffset
            let label = RMDCalculatorView.chartYearLabel(projectedYear)

            for person in people {
                let age = person.currentAge + yearOffset
                var amount: Double = 0
                if age >= person.rmdStartAge {
                    let balance = projectBalance(
                        years: yearOffset,
                        startingBalance: person.balance,
                        startAge: person.currentAge,
                        rmdStartAge: person.rmdStartAge,
                        growthPercent: person.growthPercent
                    )
                    amount = RMDCalculationEngine.calculateRMD(for: age, balance: balance)
                }
                points.append(RMDChartDataPoint(
                    year: projectedYear,
                    yearLabel: label,
                    amount: amount,
                    category: person.category
                ))
            }
        }
        return points
    }
}

struct RMDCalculatorView: View {
    @Environment(DataManager.self) var dataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var projectionYears = 10
    @State private var showGuide: Bool = false
    @State private var showAboutRMDs: Bool = false
    @State private var showTodaysDollars = false
    @State private var selectedDrawdownYear: Int?
    @State private var selectedCashSourceYear: Int?

    @Environment(\.availableWidth) private var availableWidth
    private var isWideLayout: Bool { horizontalSizeClass == .regular && availableWidth > 700 }

    var body: some View {
        @Bindable var dataManager = dataManager
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .onChange(of: dataManager.primaryGrowthRate) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseGrowthRate) { dataManager.saveAllData() }
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                statusCard
                guideCard
                currentYearRMD
                inheritedIRASection
                accountBreakdown
                rmdProjectionChart
                retirementDrawdownSection
                projectionsSection
                inheritedIRAProjectionsSection
                aboutRMDs
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    statusCard
                    guideCard
                    currentYearRMD
                    inheritedIRASection
                    accountBreakdown
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                LazyVStack(spacing: 24) {
                    rmdProjectionChart
                    retirementDrawdownSection
                    projectionsSection
                    inheritedIRAProjectionsSection
                    aboutRMDs
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Card

    private var hasInheritedRMDs: Bool {
        dataManager.inheritedIRARMDTotal > 0
    }

    /// Whether either person has reached RMD age, and who gets there first.
    /// All the logic lives in the pure type; this only supplies the inputs.
    private var rmdHouseholdStatus: RMDHouseholdStatus {
        RMDHouseholdStatus.resolve(
            primaryAge: dataManager.currentAge,
            primaryRmdAge: dataManager.rmdAge,
            spouseEnabled: dataManager.enableSpouse,
            spouseAge: dataManager.spouseCurrentAge,
            spouseRmdAge: dataManager.spouseRmdAge)
    }

    private var rmdStatusPresentation: RMDStatusPresentation {
        RMDStatusPresentation.build(
            status: rmdHouseholdStatus,
            primaryAge: dataManager.currentAge,
            primaryRmdAge: dataManager.rmdAge,
            spouseAge: dataManager.spouseCurrentAge,
            spouseRmdAge: dataManager.spouseRmdAge,
            primaryName: dataManager.userName,
            spouseName: dataManager.spouseName,
            hasInheritedRMDs: hasInheritedRMDs,
            firstRmdDeadlineYear: dataManager.currentYear + 1,
            // The same pair of conditions `hasAnyRMDs` below uses to decide
            // whether the dollar section renders at all. The badge and the
            // April 1 notice have to agree with it, or the card announces a
            // deadline above a section it has itself hidden.
            primaryHasTraditionalBalance: dataManager.primaryTraditionalIRABalance > 0,
            spouseHasTraditionalBalance: dataManager.spouseTraditionalIRABalance > 0)
    }

    /// "1 year" rather than "1 years" for the two original single-person
    /// countdown sentences below.
    private func yearsPhrase(_ years: Int) -> String {
        "\(years) \(years == 1 ? "year" : "years")"
    }

    private var statusCard: some View {
        // Resolved once so the badge, the headline number and the lines can
        // never disagree with one another. The warning icon reads the same
        // due-ness flag the badge text does, so an amber triangle can never
        // sit beside "Not Yet Required".
        let presentation = rmdStatusPresentation

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("RMD Status")
                            .font(.headline)
                        TabPurposeChip(purpose: .analysis)
                    }

                    if presentation.anyoneDue {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                            Text(presentation.badge)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else if hasInheritedRMDs {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                            Text("Inherited IRA RMDs Required")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.UI.textPrimary)
                            Text(presentation.badge)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(presentation.ageTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(presentation.ageValue)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
            }

            Divider()

            // Two people on different RMD clocks get a line each, naming the
            // person and that person's own trigger age. When the household
            // collapses to one person these are empty and the original
            // single-person branches below render untouched.
            if presentation.sections.showsHouseholdLines {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(presentation.lines.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(Color.UI.textPrimary)
                            Text(presentation.lines[index])
                                .font(.callout)
                        }
                    }
                }
            }

            // The deadline block serves whoever is actually required, not the
            // primary. In a household where only the spouse has reached her RMD
            // age, she is the one with a December 31 deadline.
            if presentation.sections.showsDeadlines {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Important Deadlines")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.Semantic.amber)
                        Text("Annual deadline: December 31")
                            .font(.callout)
                    }

                    if !presentation.firstYearNotices.isEmpty {
                        ForEach(presentation.firstYearNotices.indices, id: \.self) { index in
                            InlineHint(presentation.firstYearNotices[index])
                        }

                        Text("\u{26A0}\u{FE0F} Warning: Delaying means taking 2 RMDs in one year")
                            .font(.caption)
                            .foregroundStyle(Color.Semantic.amber)
                            .padding(.leading, 24)
                    }
                }
            } else if presentation.sections.showsInheritedCountdown {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color.Semantic.amber)
                        Text("Inherited IRA: \(dataManager.inheritedIRARMDTotal, format: .currency(code: "USD")) due by December 31")
                            .font(.callout)
                    }
                    // The household lines already say when each person's own
                    // RMDs begin, so this primary-only sentence would repeat one
                    // of them four lines further down the card.
                    if !presentation.sections.showsHouseholdLines {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(Color.UI.textPrimary)
                            Text("Own IRA RMDs start in \(yearsPhrase(dataManager.yearsUntilRMD)) (age \(dataManager.rmdAge))")
                                .font(.callout)
                        }
                    }
                }
            } else if presentation.sections.showsLegacyCountdown {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Color.UI.textPrimary)
                    Text("RMDs start in \(yearsPhrase(dataManager.yearsUntilRMD))")
                        .font(.callout)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - How to Use Guide

    private var guideCard: some View {
        DisclosureGroup(isExpanded: $showGuide) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Current Year RMD", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Shows your required withdrawal for this year based on actual account balances. This is the amount you must take by December 31.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("RMD Projections", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Models how your balances and required withdrawals change over time. Use the growth rate sliders to compare scenarios:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("0\u{2013}3%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Conservative \u{2014} bonds, CDs, money market")
                        }
                        HStack(spacing: 6) {
                            Text("4\u{2013}6%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Moderate \u{2014} balanced stock/bond portfolio")
                        }
                        HStack(spacing: 6) {
                            Text("7\u{2013}10%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Aggressive \u{2014} equity-heavy portfolio")
                        }
                        HStack(spacing: 6) {
                            Text("< 0%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Market downturn \u{2014} stress-test your plan")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Key Insight", systemImage: "lightbulb")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Higher growth means larger future balances but also larger future RMDs, which increases taxable income. Use the Scenarios tab to model the tax impact of different withdrawal strategies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("How to Use This Calculator", systemImage: "questionmark.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Current Year RMD

    /// Whether any RMDs (regular or inherited) are required this year
    private var hasAnyRMDs: Bool {
        (dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0)
        || (dataManager.enableSpouse && dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0)
        || hasInheritedRMDs
    }

    /// Grand total of all RMDs: regular + inherited
    private var grandTotalRMD: Double {
        dataManager.calculateCombinedRMD() + dataManager.inheritedIRARMDTotal
    }

    @ViewBuilder
    private var currentYearRMD: some View {
        if hasAnyRMDs {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: "\(dataManager.currentYear) Required Minimum Distribution")
                    .font(.headline)

                // Your RMD
                if dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0 {
                    let primaryRMD = dataManager.calculatePrimaryRMD()

                    VStack(spacing: 12) {
                        HStack {
                            Label("Your RMD", systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.primaryTraditionalIRABalance, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Factor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.lifeExpectancyFactor(for: dataManager.currentAge), specifier: "%.1f")")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(primaryRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.UI.textPrimary)
                            }
                        }

                        Text("(\(primaryRMD / dataManager.primaryTraditionalIRABalance * 100, specifier: "%.2f")% of balance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Spouse RMD
                if dataManager.enableSpouse && dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0 {
                    let spouseRMD = dataManager.calculateSpouseRMD()

                    VStack(spacing: 12) {
                        HStack {
                            Label(dataManager.spouseName.isEmpty ? "Spouse's RMD" : "\(dataManager.spouseName)'s RMD",
                                  systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.spouseTraditionalIRABalance, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Factor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.lifeExpectancyFactor(for: dataManager.spouseCurrentAge), specifier: "%.1f")")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(spouseRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.UI.textPrimary)
                            }
                        }

                        Text("(\(spouseRMD / dataManager.spouseTraditionalIRABalance * 100, specifier: "%.2f")% of balance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if dataManager.enableSpouse && !dataManager.spouseIsRMDRequired {
                    HStack {
                        Label(dataManager.spouseName.isEmpty ? "Spouse's RMD" : "\(dataManager.spouseName)'s RMD",
                              systemImage: "person.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Not yet required")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Inherited IRA RMDs summary
                if hasInheritedRMDs {
                    ForEach(dataManager.inheritedAccounts) { account in
                        let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)
                        if result.annualRMD > 0 {
                            VStack(spacing: 12) {
                                HStack {
                                    Label {
                                        HStack(spacing: 6) {
                                            Text(account.name)
                                            if dataManager.enableSpouse {
                                                Text(account.owner.rawValue)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.Chart.callout.opacity(0.2))
                                                    .foregroundStyle(Color.Chart.callout)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: "arrow.down.doc.fill")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    Spacer()
                                    Text("Inherited")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.Semantic.amberTint)
                                        .foregroundStyle(Color.Semantic.amber)
                                        .clipShape(Capsule())
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Balance")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(account.balance, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    if let deadline = result.mustEmptyByYear {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("Empty By")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(String(deadline))
                                                .font(.callout)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.Semantic.amber)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Required")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(result.annualRMD, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.UI.textPrimary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(PlatformColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                // Grand Total
                Divider()

                ViewThatFits {
                    HStack {
                        Text(dataManager.enableSpouse ? "Total Household RMD" : "Total Required Withdrawal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(grandTotalRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataManager.enableSpouse ? "Total Household RMD" : "Total Required Withdrawal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(grandTotalRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Inherited IRA RMDs

    @ViewBuilder
    private var inheritedIRASection: some View {
        if dataManager.hasInheritedAccounts {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Inherited IRA RMDs", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                    Spacer()
                }

                ForEach(dataManager.inheritedAccounts) { account in
                    let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(account.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if dataManager.enableSpouse {
                                        Text(account.owner.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.Chart.callout.opacity(0.2))
                                            .foregroundStyle(Color.Chart.callout)
                                            .clipShape(Capsule())
                                    }
                                }
                                if let beneficiary = account.beneficiaryType {
                                    Text(beneficiary.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(Color.UI.textSecondary)
                                }
                            }

                            Spacer()

                            Text(account.balance, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.medium)
                        }

                        // RMD amount
                        HStack {
                            Text("Required Withdrawal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if result.annualRMD > 0 {
                                Text(result.annualRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.UI.textPrimary)
                            } else {
                                Text("None required")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Deadline warning
                        if let deadline = result.mustEmptyByYear {
                            let remaining = result.yearsRemaining ?? 0
                            HStack(spacing: 6) {
                                Image(systemName: remaining <= 1 ? "exclamationmark.triangle.fill" : "clock")
                                    .foregroundStyle(remaining <= 1 ? Color.Semantic.amber : (remaining <= 3 ? Color.Semantic.amber : Color.UI.textSecondary))
                                Text("Must empty by end of \(String(deadline))")
                                    .font(.caption)
                                if remaining > 0 {
                                    Text("(\(remaining) years)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Rule description
                        Text(result.rule)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Total inherited RMD
                if dataManager.inheritedAccounts.count > 1 {
                    Divider()
                    HStack {
                        Text("Total Inherited IRA RMD")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(dataManager.inheritedIRARMDTotal, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                }

                // QCD ineligibility notice
                InlineHint("Inherited IRA distributions are not eligible for Qualified Charitable Distributions (QCDs).")
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Account Breakdown

    @ViewBuilder
    private var accountBreakdown: some View {
        if !dataManager.iraAccounts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Account Breakdown")
                    .font(.headline)

                ForEach(dataManager.iraAccounts.filter {
                    $0.accountType == .traditionalIRA || $0.accountType == .traditional401k
                }) { account in
                    let ownerContext = Self.ownerRMDContext(
                        owner: account.owner,
                        enableSpouse: dataManager.enableSpouse,
                        primaryAge: dataManager.currentAge,
                        primaryRMDAge: dataManager.rmdAge,
                        spouseAge: dataManager.spouseCurrentAge,
                        spouseRMDAge: dataManager.spouseRmdAge
                    )

                    if let ownerContext, ownerContext.age >= ownerContext.rmdAge {
                        let accountRMD = dataManager.calculateRMD(
                            for: ownerContext.age,
                            balance: account.balance
                        )

                        AccountRMDRow(
                            accountName: account.name,
                            ownerLabel: accountOwnerLabel(for: account),
                            balance: account.balance,
                            rmd: accountRMD
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack(spacing: 4) {
                                        Text(Self.accountTypeLabel(for: account))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let ownerLabel = accountOwnerLabel(for: account) {
                                            Text("·")
                                                .foregroundStyle(.secondary)
                                            Text(ownerLabel)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Text(account.balance, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            }

                            // The account names an owner who isn't set up, so there are
                            // no ages to price its RMD against and it sits outside every
                            // household total.  Say so rather than leaving it looking fine.
                            if ownerContext == nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Chart.callout)
                                    Text("Turn on Enable Spouse in My Profile to include this account's RMD.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - RMD Projection Chart

    private var hasChartData: Bool {
        dataManager.primaryTraditionalIRABalance > 0
        || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0)
        || dataManager.hasInheritedAccounts
    }

    /// The regular-RMD inputs, lifted out of the view so the series split is testable.
    private var chartHousehold: RMDChartHousehold {
        RMDChartHousehold(
            currentYear: dataManager.currentYear,
            projectionYears: projectionYears,
            primaryBalance: dataManager.primaryTraditionalIRABalance,
            primaryCurrentAge: dataManager.currentAge,
            primaryRMDAge: dataManager.rmdAge,
            primaryGrowthPercent: dataManager.primaryGrowthRate,
            enableSpouse: dataManager.enableSpouse,
            spouseName: dataManager.spouseName,
            spouseBalance: dataManager.spouseTraditionalIRABalance,
            spouseCurrentAge: dataManager.spouseCurrentAge,
            spouseRMDAge: dataManager.spouseRmdAge,
            spouseGrowthPercent: dataManager.spouseGrowthRate
        )
    }

    /// Combined stacked chart data: one regular series *per person* plus Inherited IRA.
    ///
    /// The chart window is strictly authoritative: it shows exactly `projectionYears`
    /// bars regardless of any inherited deadline.  When an NEDB deadline falls outside
    /// the window, `inheritedDeadlinesOutsideWindow` surfaces a notice instead.
    private var rmdChartData: [RMDChartDataPoint] {
        var data: [RMDChartDataPoint] = []

        // --- Pre-compute each inherited account's full projection once ---
        var inheritedProjections: [(account: IRAAccount, rows: [RMDCalculationEngine.InheritedProjectionRow])] = []
        if dataManager.hasInheritedAccounts {
            for account in dataManager.inheritedAccounts {
                let growthRate = account.owner == .spouse
                    ? dataManager.spouseGrowthRate
                    : dataManager.primaryGrowthRate
                let rows = RMDCalculationEngine.projectInheritedIRA(
                    account: account,
                    currentYear: dataManager.currentYear,
                    projectionYears: projectionYears,
                    growthPercent: growthRate
                )
                inheritedProjections.append((account: account, rows: rows))
            }
        }

        // --- Regular RMDs, one series per person (pure, tested seam) ---
        var regularByYear: [Int: [RMDChartDataPoint]] = [:]
        for point in RMDChartDataBuilder.regularSeries(chartHousehold) {
            regularByYear[point.year, default: []].append(point)
        }

        // --- Build per-year data points — strictly within the picker window ---
        for yearOffset in 0..<projectionYears {
            let projectedYear = dataManager.currentYear + yearOffset
            let label = Self.chartYearLabel(projectedYear)

            data.append(contentsOf: regularByYear[projectedYear] ?? [])

            // Inherited IRA RMDs — pull from pre-computed projection rows within window
            var inheritedRMD: Double = 0
            for projection in inheritedProjections {
                if let row = projection.rows.first(where: { $0.year == projectedYear }) {
                    inheritedRMD += row.rmd
                }
            }

            data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: inheritedRMD, category: RMDChartSeries.inherited))
        }
        return data
    }

    /// NEDB inherited accounts whose 10-year deadline falls outside the current picker window.
    /// Used to render a nudge notice below the projection chart.
    private var inheritedDeadlinesOutsideWindow: [(accountName: String, deadlineYear: Int, ownerLabel: String)] {
        let lastVisibleYear = dataManager.currentYear + projectionYears - 1
        return dataManager.inheritedAccounts.compactMap { account in
            guard let yearOfInheritance = account.yearOfInheritance,
                  let beneficiaryType = account.beneficiaryType else { return nil }
            // Only non-eligible designated beneficiaries have a hard 10-year deadline
            guard !beneficiaryType.isEligibleDesignated else { return nil }
            let deadline = yearOfInheritance + 10
            guard deadline > lastVisibleYear else { return nil }
            let ownerLabel = account.owner == .spouse
                ? (dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName)
                : "You"
            return (account.name, deadline, ownerLabel)
        }
    }

    /// Compact two-digit year label the projection chart's bars are keyed by (2029 -> '29).
    static func chartYearLabel(_ year: Int) -> String {
        "'\(String(year).suffix(2))"
    }

    /// The years that get an x-axis label on the projection chart.
    ///
    /// The chart plots a String category on x, and a category axis labels *every*
    /// bar unless it is handed an explicit subset — which turned the 20/30/40-year
    /// horizons into an unreadable smear of digits.  Thin down to round calendar
    /// years so the axis reads the way the drawdown charts below it already do.
    ///
    /// The step is always smaller than the window, so the result is never empty
    /// for a positive horizon.
    static func projectionAxisYears(currentYear: Int, projectionYears: Int) -> [Int] {
        guard projectionYears > 0 else { return [] }

        let step: Int
        switch projectionYears {
        case ...6:  step = 1     // 5-year window: every year
        case ...16: step = 2     // 10/15-year windows: every other year
        case ...32: step = 5     // 20/30-year windows: half-decades
        default:    step = 10    // 40-year window: decades
        }

        let labeled = (0..<projectionYears)
            .map { currentYear + $0 }
            .filter { $0 % step == 0 }

        // Swift Charts centers a category label under its bar, so a label on the
        // last bar overhangs the plot's trailing edge and renders as "…".  Drop it.
        // Only an issue when we're thinning — step-1 windows have bars wide enough
        // to carry the label.
        guard step > 1 else { return labeled }
        let trimmed = labeled.filter { $0 != currentYear + projectionYears - 1 }
        return trimmed.isEmpty ? labeled : trimmed
    }

    /// The subset of bar categories that get an x-axis label.
    private var chartXAxisLabels: [String] {
        Self.projectionAxisYears(
            currentYear: dataManager.currentYear,
            projectionYears: projectionYears
        ).map(Self.chartYearLabel)
    }

    /// Legend swatches for the projection chart, laid out by whichever container
    /// `ViewThatFits` picks: a couple's two named regular series are wider than the
    /// single "IRA / 401(k)" entry that used to sit here alone.
    @ViewBuilder
    private func chartLegendItems(_ styles: [ChartSeriesStyle]) -> some View {
        ForEach(styles) { style in
            HStack(spacing: 6) {
                Circle().fill(style.color).frame(width: 8, height: 8)
                Text(style.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Formats Y-axis labels compactly ($5K, $150K, etc.)
    private func chartYAxisLabel(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(String(format: "%.1f", amount / 1_000_000))M"
        } else if amount >= 1000 {
            return "$\(Int(amount / 1000))K"
        } else {
            return "$\(Int(amount))"
        }
    }

    @ViewBuilder
    private var rmdProjectionChart: some View {
        if hasChartData {
            let chartData = rmdChartData
            let seriesStyles = RMDChartSeries.styles(for: chartData)
            let styleColors = Dictionary(uniqueKeysWithValues: seriesStyles.map { ($0.category, $0.color) })
            let regularTotals = RMDChartSeries.regularTotalsByYear(chartData)
            let regularSeriesCount = seriesStyles.filter { RMDChartSeries.isRegular($0.category) }.count
            let hasRegularRMDs = chartData.contains { RMDChartSeries.isRegular($0.category) && $0.amount > 0 }
            let hasInheritedRMDs = chartData.contains { $0.category == RMDChartSeries.inherited && $0.amount > 0 }
            let anyRMDs = hasRegularRMDs || hasInheritedRMDs

            VStack(alignment: .leading, spacing: 16) {
                // Eye-catching header with gradient icon
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.UI.brandTeal.opacity(0.85), Color.Chart.callout.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Projected Annual RMDs")
                            .font(.headline)
                        Text("\(projectionYears)-Year Outlook")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if anyRMDs {
                    // Legend: one entry per series that actually draws a bar
                    let legendStyles = seriesStyles.filter { style in
                        chartData.contains { $0.category == style.category && $0.amount > 0 }
                    }
                    HStack {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) { chartLegendItems(legendStyles) }
                            VStack(alignment: .leading, spacing: 6) { chartLegendItems(legendStyles) }
                        }
                        Spacer()
                    }

                    // Single stacked bar chart
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Year", point.yearLabel),
                            y: .value("RMD", point.amount)
                        )
                        .foregroundStyle(by: .value("Type", point.category))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale(mapping: { (category: String) -> Color in
                        styleColors[category] ?? Color.Chart.heroTeal
                    })
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(chartYAxisLabel(amount))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: chartXAxisLabels) { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 220)

                    // Peak callouts
                    VStack(alignment: .leading, spacing: 4) {
                        // Regular peak reads the per-year HOUSEHOLD total, not one person's
                        // max, so splitting the bar per person cannot shrink the number.
                        if hasRegularRMDs,
                           let peak = regularTotals.max(by: { $0.total < $1.total }),
                           peak.total > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Color.Chart.heroTeal)
                                    .font(.caption)
                                Text(regularSeriesCount > 1 ? "IRA / 401(k) Peak (both):" : "IRA / 401(k) Peak:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(peak.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("in \(String(peak.year))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if hasInheritedRMDs,
                           let peak = chartData.filter({ $0.category == RMDChartSeries.inherited }).max(by: { $0.amount < $1.amount }),
                           peak.amount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(Color.Chart.callout)
                                    .font(.caption)
                                Text("Inherited IRA Peak:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(peak.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("in \(String(peak.year))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Combined peak when both types present
                        if hasRegularRMDs && hasInheritedRMDs {
                            // Sums EVERY regular series for the year; a `first(where:)`
                            // lookup would silently drop the spouse's bar for couples.
                            let totalsByYear: [(year: Int, total: Double)] = regularTotals.map { entry in
                                let inh = chartData.first(where: { $0.year == entry.year && $0.category == RMDChartSeries.inherited })?.amount ?? 0
                                return (year: entry.year, total: entry.total + inh)
                            }
                            if let peakTotal = totalsByYear.max(by: { $0.total < $1.total }), peakTotal.total > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(Color.UI.brandTeal)
                                        .font(.caption)
                                    Text("Combined Peak:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(peakTotal.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("in \(String(peakTotal.year))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No RMDs projected in this period")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Your first RMD begins at age \(dataManager.rmdAge)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.UI.brandTeal.opacity(0.3), Color.Chart.callout.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    // MARK: - Projections Section

    private var projectionsSection: some View {
        @Bindable var dataManager = dataManager
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RMD Projections")
                    .font(.headline)

                Spacer()

                Picker("Years", selection: $projectionYears) {
                    Text("5 years").tag(5)
                    Text("10 years").tag(10)
                    Text("15 years").tag(15)
                    Text("20 years").tag(20)
                    Text("30 years").tag(30)
                    Text("40 years").tag(40)
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }

            // Nudge notice: inherited NEDB deadlines outside the picker window
            let outsideDeadlines = inheritedDeadlinesOutsideWindow
            if !outsideDeadlines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(outsideDeadlines, id: \.deadlineYear) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text("\(entry.ownerLabel)'s \(entry.accountName) deadline: \(String(entry.deadlineYear)). Pick a longer horizon to see it.")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            // Growth rate controls
            if dataManager.primaryTraditionalIRABalance > 0 || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0) {
                VStack(spacing: 12) {
                    if dataManager.primaryTraditionalIRABalance > 0 {
                        HStack {
                            Text(dataManager.enableSpouse ? "\(dataManager.primaryLabel) Growth Rate" : "Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(dataManager.primaryGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $dataManager.primaryGrowthRate, in: -5...12, step: 0.5)
                            .tint(Color.UI.brandTeal)
                    }

                    if dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0 {
                        let spLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
                        HStack {
                            Text("\(spLabel)'s Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(dataManager.spouseGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $dataManager.spouseGrowthRate, in: -5...12, step: 0.5)
                            .tint(Color.Chart.callout)
                    }
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if dataManager.primaryTraditionalIRABalance > 0 || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0) {

                let showSpouse = dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0
                let spouseLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

                if showSpouse {
                    // The combined table is ~560pt wide and overflows an iPhone by
                    // nearly half, hiding the spouse's balance/RMD and the household
                    // total off the right edge.  Say so, and leave the scroll bar on:
                    // with no affordance at all it reads as "the spouse isn't included."
                    if horizontalSizeClass == .compact {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption2)
                            Text("Swipe the table sideways for \(spouseLabel)'s columns and the household total.")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    }

                    // Horizontal scroll for combined table on narrower screens
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Combined header row
                            HStack(spacing: 0) {
                                Text("Year")
                                    .frame(width: 50, alignment: .leading)
                                Text("Age")
                                    .frame(width: 32, alignment: .trailing)
                                Text("Balance")
                                    .frame(width: 95, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                                Color.clear.frame(width: 8)
                                Text("Age")
                                    .frame(width: 32, alignment: .trailing)
                                Text("Balance")
                                    .frame(width: 95, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                                Color.clear.frame(width: 8)
                                Text("Total")
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)

                            // Sub-header: owner labels
                            HStack(spacing: 0) {
                                Color.clear.frame(width: 50)
                                Text("You")
                                    .frame(width: 207, alignment: .center)
                                Color.clear.frame(width: 8)
                                Text(spouseLabel)
                                    .frame(width: 207, alignment: .center)
                                Color.clear.frame(width: 8)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)

                            // Combined projection rows
                            VStack(spacing: 6) {
                                ForEach(0..<projectionYears, id: \.self) { yearOffset in
                                    let projectedYear = dataManager.currentYear + yearOffset

                                    // Primary data
                                    let pAge = dataManager.currentAge + yearOffset
                                    let pHasBalance = dataManager.primaryTraditionalIRABalance > 0
                                    let pEligible = pAge >= dataManager.rmdAge && pHasBalance
                                    let pBalance: Double? = pEligible ? projectBalance(
                                        years: yearOffset,
                                        startingBalance: dataManager.primaryTraditionalIRABalance,
                                        startAge: dataManager.currentAge,
                                        rmdStartAge: dataManager.rmdAge,
                                        growthPercent: dataManager.primaryGrowthRate
                                    ) : nil
                                    let pRMD: Double? = pEligible ? dataManager.calculateRMD(
                                        for: pAge,
                                        balance: pBalance ?? 0
                                    ) : nil

                                    // Spouse data
                                    let sAge = dataManager.spouseCurrentAge + yearOffset
                                    let sEligible = sAge >= dataManager.spouseRmdAge
                                    let sBalance: Double? = sEligible ? projectBalance(
                                        years: yearOffset,
                                        startingBalance: dataManager.spouseTraditionalIRABalance,
                                        startAge: dataManager.spouseCurrentAge,
                                        rmdStartAge: dataManager.spouseRmdAge,
                                        growthPercent: dataManager.spouseGrowthRate
                                    ) : nil
                                    let sRMD: Double? = sEligible ? dataManager.calculateRMD(
                                        for: sAge,
                                        balance: sBalance ?? 0
                                    ) : nil

                                    let totalRMD = (pRMD ?? 0) + (sRMD ?? 0)

                                    CombinedRMDProjectionRow(
                                        year: projectedYear,
                                        isCurrentYear: yearOffset == 0,
                                        primaryAge: pHasBalance ? pAge : nil,
                                        primaryBalance: pBalance,
                                        primaryRMD: pRMD,
                                        spouseAge: sAge,
                                        spouseBalance: sBalance,
                                        spouseRMD: sRMD,
                                        totalRMD: totalRMD
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // Single-person header row
                    HStack(spacing: 0) {
                        Text("Year")
                            .frame(width: 50, alignment: .leading)
                        Text("Age")
                            .frame(width: 40, alignment: .trailing)
                        Spacer()
                        Text("Balance")
                            .frame(width: 140, alignment: .trailing)
                        Spacer()
                        Text("RMD")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                    // Single-person projection rows
                    VStack(spacing: 8) {
                        ForEach(0..<projectionYears, id: \.self) { yearOffset in
                            let projectedAge = dataManager.currentAge + yearOffset
                            let projectedYear = dataManager.currentYear + yearOffset

                            if projectedAge >= dataManager.rmdAge {
                                let projectedBalance = projectBalance(
                                    years: yearOffset,
                                    startingBalance: dataManager.primaryTraditionalIRABalance,
                                    startAge: dataManager.currentAge,
                                    rmdStartAge: dataManager.rmdAge,
                                    growthPercent: dataManager.primaryGrowthRate
                                )
                                let projectedRMD = dataManager.calculateRMD(
                                    for: projectedAge,
                                    balance: projectedBalance
                                )

                                RMDProjectionRow(
                                    year: projectedYear,
                                    age: projectedAge,
                                    balance: projectedBalance,
                                    rmd: projectedRMD,
                                    isCurrentYear: yearOffset == 0
                                )
                            }
                        }
                    }
                }
            } else {
                Text("Add Traditional IRA/401(k) accounts to see projections")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - About RMDs (Collapsible)

    private var aboutRMDs: some View {
        DisclosureGroup(isExpanded: $showAboutRMDs) {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "info.circle",
                    text: "RMDs are the minimum amount you must withdraw from retirement accounts annually",
                    color: Color.UI.brandTeal
                )

                InfoRow(
                    icon: "exclamationmark.triangle",
                    text: "Penalty for missing RMD: 25% of the amount not withdrawn",
                    color: Color.Semantic.amber
                )

                InfoRow(
                    icon: "checkmark.circle",
                    text: "Roth IRAs do NOT require RMDs during your lifetime",
                    color: Color.UI.textPrimary
                )

                InfoRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "RMD amount increases each year as life expectancy factor decreases",
                    color: Color.UI.brandTeal
                )
            }
            .padding(.top, 8)
        } label: {
            Label("About RMDs", systemImage: "book.closed")
                .font(.headline)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Inherited IRA Projections

    @ViewBuilder
    private var inheritedIRAProjectionsSection: some View {
        if dataManager.hasInheritedAccounts {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inherited IRA Projections")
                    .font(.headline)

                ForEach(dataManager.inheritedAccounts) { account in
                    let growthRate = account.owner == .spouse ? dataManager.spouseGrowthRate : dataManager.primaryGrowthRate
                    let projections = RMDCalculationEngine.projectInheritedIRA(
                        account: account,
                        currentYear: dataManager.currentYear,
                        projectionYears: projectionYears,
                        growthPercent: growthRate
                    )

                    if !projections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // Account header
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .foregroundStyle(Color.UI.brandTeal)
                                    Text(account.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if dataManager.enableSpouse {
                                        Text(account.owner.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.Chart.callout.opacity(0.2))
                                            .foregroundStyle(Color.Chart.callout)
                                            .clipShape(Capsule())
                                    }
                                }
                                Spacer()
                                if let beneficiary = account.beneficiaryType {
                                    Text(beneficiary.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.Semantic.amberTint)
                                        .foregroundStyle(Color.Semantic.amber)
                                        .clipShape(Capsule())
                                }
                            }

                            // Growth rate note
                            Text("Using \(growthRate, specifier: "%.1f")% annual growth rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            // Table header
                            HStack(spacing: 0) {
                                Text("Year")
                                    .frame(width: 50, alignment: .leading)
                                Text("Balance")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 90, alignment: .trailing)
                                if projections.first?.remaining != nil {
                                    Text("Left")
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)

                            // Rows
                            VStack(spacing: 4) {
                                ForEach(projections) { row in
                                    HStack(spacing: 0) {
                                        Text(String(row.year))
                                            .font(.caption)
                                            .fontWeight(row.year == dataManager.currentYear ? .bold : .regular)
                                            .frame(width: 50, alignment: .leading)

                                        Text(row.balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, alignment: .trailing)

                                        Text(row.rmd > 0 ? row.rmd.formatted(.currency(code: "USD").precision(.fractionLength(0))) : "—")
                                            .font(.caption)
                                            .fontWeight(row.isDeadline ? .bold : .medium)
                                            .foregroundStyle(row.isDeadline ? Color.Semantic.amber : (row.rmd > 0 ? Color.UI.textPrimary : Color.UI.textSecondary))
                                            .frame(width: 90, alignment: .trailing)

                                        if projections.first?.remaining != nil {
                                            if let remaining = row.remaining {
                                                Text("\(remaining)")
                                                    .font(.caption)
                                                    .fontWeight(remaining <= 1 ? .bold : .regular)
                                                    .foregroundStyle(remaining <= 1 ? Color.Semantic.amber : (remaining <= 3 ? Color.Semantic.amber : Color.UI.textSecondary))
                                                    .frame(width: 40, alignment: .trailing)
                                            } else {
                                                Text("—")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 40, alignment: .trailing)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        row.year == dataManager.currentYear ? Color.UI.surfaceInset :
                                        row.isDeadline ? Color.Semantic.amberTint :
                                        Color(PlatformColor.secondarySystemBackground)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // Deadline note
                            if let deadline = projections.last, deadline.isDeadline {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.Semantic.amber)
                                        .font(.caption)
                                    Text("Full remaining balance must be withdrawn by end of \(String(deadline.year))")
                                        .font(.caption)
                                        .foregroundStyle(Color.Semantic.amber)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(PlatformColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Retirement Drawdown (V1.9 Tasks 9 + 10)

    /// Deflates a nominal value to today's dollars when the toggle is on.
    private func drawdownDisplayValue(_ nominal: Double, yearOffset: Int) -> Double {
        guard showTodaysDollars else { return nominal }
        return nominal * pow(1 + dataManager.drawdownInflationPercent / 100.0, -Double(yearOffset))
    }

    /// First IRMAA tier MAGI threshold (nominal, today's config dollars) for the
    /// household's filing status. Reuses the same `DataManager.irmaa2026Tiers`
    /// path as the Dashboard IRMAA chart. Tier 1 is the first surcharge tier.
    private var drawdownIrmaaTier1Threshold: Double? {
        let tiers = DataManager.irmaa2026Tiers
        guard let tier1 = tiers.first(where: { $0.tier == 1 }) else { return nil }
        let isMFJ = dataManager.filingStatus == .marriedFilingJointly
        return isMFJ ? tier1.mfjThreshold : tier1.singleThreshold
    }

    /// Owner RMD-start and SS-start calendar-year markers within the current horizon.
    private var drawdownMarkers: [(year: Int, label: String)] {
        var markers: [(year: Int, label: String)] = []
        let lastYear = dataManager.currentYear + projectionYears - 1

        func addMarker(startAge: Int, currentAge: Int, year: Int, label: String) {
            guard startAge > currentAge else { return } // already started — no marker
            guard year >= dataManager.currentYear && year <= lastYear else { return }
            markers.append((year: year, label: label))
        }

        // RMD-start markers
        addMarker(startAge: dataManager.rmdAge,
                  currentAge: dataManager.currentAge,
                  year: dataManager.currentYear + (dataManager.rmdAge - dataManager.currentAge),
                  label: "RMDs begin")
        if dataManager.enableSpouse {
            let spLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
            addMarker(startAge: dataManager.spouseRmdAge,
                      currentAge: dataManager.spouseCurrentAge,
                      year: dataManager.currentYear + (dataManager.spouseRmdAge - dataManager.spouseCurrentAge),
                      label: "\(spLabel) RMDs")
        }

        // SS-start markers (from the SS planner's planned claiming age)
        if let primaryClaim = dataManager.primarySSBenefit?.plannedClaimingAge {
            addMarker(startAge: primaryClaim,
                      currentAge: dataManager.currentAge,
                      year: dataManager.currentYear + (primaryClaim - dataManager.currentAge),
                      label: "SS begins")
        }
        if dataManager.enableSpouse, let spouseClaim = dataManager.spouseSSBenefit?.plannedClaimingAge {
            let spLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
            addMarker(startAge: spouseClaim,
                      currentAge: dataManager.spouseCurrentAge,
                      year: dataManager.currentYear + (spouseClaim - dataManager.spouseCurrentAge),
                      label: "\(spLabel) SS")
        }

        // Merge markers that land on the same year so their labels stack
        // vertically in one annotation instead of overlapping horizontally.
        let grouped = Dictionary(grouping: markers, by: { $0.year })
        return grouped.keys.sorted().map { yr in
            (year: yr, label: grouped[yr]!.map { $0.label }.joined(separator: "\n"))
        }
    }

    private var hasDrawdownData: Bool {
        dataManager.primaryTraditionalIRABalance > 0
        || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0)
    }

    @ViewBuilder
    private var retirementDrawdownSection: some View {
        @Bindable var dataManager = dataManager
        if hasDrawdownData {
            VStack(alignment: .leading, spacing: 16) {
                Text("Retirement Drawdown")
                    .font(.headline)

                Text("Models how your IRA/401(k) balance is spent down over the \(projectionYears)-year horizon, after guaranteed income (Social Security and pensions). Uses the horizon selector above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Inputs card
                VStack(alignment: .leading, spacing: 16) {
                    // Mode picker
                    Picker("Drawdown mode", selection: $dataManager.drawdownMode) {
                        ForEach(DrawdownMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Conditional input by mode
                    switch dataManager.drawdownMode {
                    case .rmdOnly:
                        Text("Withdraws only the IRS-required minimum once RMDs begin at 73/75. The balance grows otherwise — your baseline if you don't voluntarily draw from these accounts.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    case .spendingGap:
                        HStack {
                            Text("Target annual spending")
                                .font(.subheadline)
                            Spacer()
                            CurrencyField(
                                value: $dataManager.drawdownSpendingTarget,
                                range: 0...1_000_000,
                                color: Color.UI.textPrimary
                            )
                        }
                        Text("Household spending goal in today's dollars. We withdraw only the gap not covered by guaranteed income.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    case .withdrawalRate:
                        HStack {
                            Text("Withdrawal rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(dataManager.drawdownRatePercent, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $dataManager.drawdownRatePercent, in: 2...8, step: 0.1)
                            .tint(Color.UI.brandTeal)
                        Text("Annual withdrawal as a percent of the starting balance each year.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Inflation rate
                    HStack {
                        Text("Inflation rate")
                            .font(.subheadline)
                        Spacer()
                        Text("\(dataManager.drawdownInflationPercent, specifier: "%.1f")%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 50, alignment: .trailing)
                    }
                    Slider(value: $dataManager.drawdownInflationPercent, in: 0...6, step: 0.1)
                        .tint(Color.Chart.callout)

                    Toggle("Show in today's dollars", isOn: $showTodaysDollars)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                drawdownChart
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .onChange(of: dataManager.drawdownMode) { dataManager.saveAllData() }
            .onChange(of: dataManager.drawdownSpendingTarget) { dataManager.saveAllData() }
            .onChange(of: dataManager.drawdownRatePercent) { dataManager.saveAllData() }
            .onChange(of: dataManager.drawdownInflationPercent) { dataManager.saveAllData() }
        }
    }

    @ViewBuilder
    private var drawdownChart: some View {
        let years = dataManager.drawdownProjection(horizonYears: projectionYears).years
        if years.isEmpty {
            Text("Add Traditional IRA/401(k) accounts to see a drawdown projection.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            Chart {
                ForEach(years, id: \.calendarYear) { year in
                    AreaMark(
                        x: .value("Year", year.calendarYear),
                        y: .value("Withdrawal", drawdownDisplayValue(year.householdWithdrawal, yearOffset: year.yearOffset))
                    )
                    .foregroundStyle(Color.Chart.callout.opacity(0.18))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Year", year.calendarYear),
                        y: .value("Withdrawal", drawdownDisplayValue(year.householdWithdrawal, yearOffset: year.yearOffset)),
                        series: .value("Series", "Withdrawal")
                    )
                    .foregroundStyle(Color.Chart.callout)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Year", year.calendarYear),
                        y: .value("Balance", drawdownDisplayValue(year.householdBalanceEnd, yearOffset: year.yearOffset)),
                        series: .value("Series", "Balance")
                    )
                    .foregroundStyle(Color.Chart.heroTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Year", year.calendarYear),
                        y: .value("Projected income", drawdownDisplayValue(year.projectedIncome, yearOffset: year.yearOffset)),
                        series: .value("Series", "Projected income")
                    )
                    .foregroundStyle(Color.Chart.tealRamp4)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                }

                // IRMAA tier-1 crossing flags: compare NOMINAL projected income to the
                // NOMINAL inflated threshold (deflation is display-only). Plot the marker
                // at the displayed (possibly deflated) projected-income value.
                if let tier1 = drawdownIrmaaTier1Threshold {
                    ForEach(years.filter {
                        $0.projectedIncome >= DrawdownProjectionEngine.inflatedIrmaaTier1(
                            threshold: tier1,
                            inflationPercent: dataManager.drawdownInflationPercent,
                            yearOffset: $0.yearOffset)
                    }, id: \.calendarYear) { year in
                        PointMark(
                            x: .value("Year", year.calendarYear),
                            y: .value("Projected income", drawdownDisplayValue(year.projectedIncome, yearOffset: year.yearOffset))
                        )
                        .foregroundStyle(Color.Chart.callout)
                        .symbolSize(60)
                    }
                }

                ForEach(Array(drawdownMarkers.enumerated()), id: \.offset) { _, marker in
                    RuleMark(x: .value("Year", marker.year))
                        .foregroundStyle(Color.Chart.gray3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .annotation(position: .top, alignment: .center) {
                            Text(marker.label)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                }

                // Tap / hover readout: a rule at the selected year with a value callout.
                if let selYear = selectedDrawdownYear,
                   let sel = years.min(by: { abs($0.calendarYear - selYear) < abs($1.calendarYear - selYear) }) {
                    RuleMark(x: .value("Year", sel.calendarYear))
                        .foregroundStyle(Color.UI.textPrimary.opacity(0.3))
                        .annotation(position: .top, spacing: 2,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            drawdownSelectionCallout(for: sel)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(chartYAxisLabel(amount))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .chartXScale(domain: years.first!.calendarYear ... years.last!.calendarYear)
            .chartXSelection(value: $selectedDrawdownYear)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let yr = value.as(Int.self) {
                            Text("'\(String(yr).suffix(2))").font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 240)

            // Legend below the chart so it doesn't collide with the top marker labels.
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Color.Chart.heroTeal).frame(width: 8, height: 8)
                    Text("Year-end balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.Chart.callout).frame(width: 8, height: 8)
                    Text("Annual withdrawal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(Color.Chart.tealRamp4).frame(width: 8, height: 8)
                    Text("Projected income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(showTodaysDollars
                 ? "Values shown in today's dollars (deflated at \(String(format: "%.1f", dataManager.drawdownInflationPercent))% per year). Balance is the year-end IRA/401(k) total; withdrawal is the household amount taken that year."
                 : "Nominal future dollars. Balance is the year-end IRA/401(k) total; withdrawal is the household amount taken that year.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Approximate. Flags when projected income (withdrawals + Social Security/pension) reaches the first IRMAA tier; does not compute exact tax.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            DisclosureGroup("Show where the money comes from") {
                drawdownCashSourceChart(years: years)
            }
            .font(.caption)
            .padding(.top, 4)
        }
    }

    /// Stacked per-year breakdown of the household withdrawal into guaranteed
    /// income, the planned (gap/rate) portion, and the RMD-forced portion.
    @ViewBuilder
    private func drawdownSelectionCallout(for year: DrawdownYear) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(year.calendarYear)).font(.caption2).fontWeight(.semibold)
            drawdownCalloutRow(color: Color.Chart.heroTeal, label: "Balance",
                               value: drawdownDisplayValue(year.householdBalanceEnd, yearOffset: year.yearOffset))
            drawdownCalloutRow(color: Color.Chart.callout, label: "Withdrawal",
                               value: drawdownDisplayValue(year.householdWithdrawal, yearOffset: year.yearOffset))
            drawdownCalloutRow(color: Color.Chart.tealRamp4, label: "Income",
                               value: drawdownDisplayValue(year.projectedIncome, yearOffset: year.yearOffset))
        }
        .padding(6)
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    private func drawdownCalloutRow(color: Color, label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption2).fontWeight(.medium)
        }
    }

    @ViewBuilder
    private func cashSourceSelectionCallout(for year: DrawdownYear) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(year.calendarYear)).font(.caption2).fontWeight(.semibold)
            drawdownCalloutRow(color: Color.Chart.heroTeal, label: "Guaranteed",
                               value: drawdownDisplayValue(year.guaranteedIncome, yearOffset: year.yearOffset))
            drawdownCalloutRow(color: Color.Chart.gray3, label: "Planned draw",
                               value: drawdownDisplayValue(year.plannedPortion, yearOffset: year.yearOffset))
            drawdownCalloutRow(color: Color.Chart.callout, label: "RMD-forced",
                               value: drawdownDisplayValue(year.rmdForcedPortion, yearOffset: year.yearOffset))
        }
        .padding(6)
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    @ViewBuilder
    private func drawdownCashSourceChart(years: [DrawdownYear]) -> some View {
        if years.isEmpty {
            Text("No projection data.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.Chart.heroTeal).frame(width: 8, height: 8)
                        Text("Guaranteed").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.Chart.gray3).frame(width: 8, height: 8)
                        Text("Planned draw").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.Chart.callout).frame(width: 8, height: 8)
                        Text("RMD-forced").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Chart {
                    ForEach(years, id: \.calendarYear) { year in
                        BarMark(
                            x: .value("Year", year.calendarYear),
                            y: .value("Amount", drawdownDisplayValue(year.guaranteedIncome, yearOffset: year.yearOffset))
                        )
                        .foregroundStyle(Color.Chart.heroTeal)

                        BarMark(
                            x: .value("Year", year.calendarYear),
                            y: .value("Amount", drawdownDisplayValue(year.plannedPortion, yearOffset: year.yearOffset))
                        )
                        .foregroundStyle(Color.Chart.gray3)

                        BarMark(
                            x: .value("Year", year.calendarYear),
                            y: .value("Amount", drawdownDisplayValue(year.rmdForcedPortion, yearOffset: year.yearOffset))
                        )
                        .foregroundStyle(Color.Chart.callout)
                    }

                    if let selYear = selectedCashSourceYear,
                       let sel = years.min(by: { abs($0.calendarYear - selYear) < abs($1.calendarYear - selYear) }) {
                        RuleMark(x: .value("Year", sel.calendarYear))
                            .foregroundStyle(Color.UI.textPrimary.opacity(0.25))
                            .annotation(position: .top, spacing: 2,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                cashSourceSelectionCallout(for: sel)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(chartYAxisLabel(amount)).font(.caption2)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    }
                }
                .chartXScale(domain: years.first!.calendarYear ... years.last!.calendarYear)
                .chartXSelection(value: $selectedCashSourceYear)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let yr = value.as(Int.self) {
                                Text("'\(String(yr).suffix(2))").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                Text("Each bar splits that year's cash flow into guaranteed income (Social Security/pension), the planned withdrawal, and any amount RMDs force above the plan.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helper Functions

    /// Projects a balance forward using the given annual growth rate minus RMDs.
    private func projectBalance(years: Int, startingBalance: Double, startAge: Int, rmdStartAge: Int, growthPercent: Double) -> Double {
        RMDChartDataBuilder.projectBalance(
            years: years,
            startingBalance: startingBalance,
            startAge: startAge,
            rmdStartAge: rmdStartAge,
            growthPercent: growthPercent
        )
    }

    /// Returns the current age of the account's owner.
    /// The ages needed to price an account's RMD, or nil when the account names
    /// an owner who has no configured profile.
    ///
    /// A spouse-owned account with Enable Spouse off has no spouse ages to use:
    /// `spouseCurrentAge` and `spouseRmdAge` both report 0, `0 >= 0` reads as
    /// "RMD required", and the balance gets priced off the Uniform Lifetime
    /// Table's past-the-end 2.0 divisor — half the balance.  Returning nil makes
    /// the screen show no RMD and explain why instead.
    ///
    /// Joint accounts price off the primary, matching where their balance is
    /// counted in `AccountsManager.primaryTraditionalIRABalance`.
    static func ownerRMDContext(
        owner: Owner,
        enableSpouse: Bool,
        primaryAge: Int,
        primaryRMDAge: Int,
        spouseAge: Int,
        spouseRMDAge: Int
    ) -> (age: Int, rmdAge: Int)? {
        switch owner {
        case .primary, .joint:
            return (age: primaryAge, rmdAge: primaryRMDAge)
        case .spouse:
            guard enableSpouse else { return nil }
            return (age: spouseAge, rmdAge: spouseRMDAge)
        }
    }

    /// The account "Type" label shown for an account still below RMD age (the
    /// "not yet RMD age" branch of the accounts list) -- the classified
    /// display name, not the raw `accountType.rawValue` that used to print
    /// "Traditional 401(k)" over a classified 403(b)/457. Not `private`,
    /// and `static` rather than an instance method, so a test can call it
    /// directly without constructing this view. Whole-branch review Fix 4.
    static func accountTypeLabel(for account: IRAAccount) -> String {
        PlanClassificationChoice.accountDisplayName(
            accountType: account.accountType, planStructure: account.planStructure, planSource: account.planSource)
    }

    /// Owner caption for an account row, shown whenever it carries information —
    /// that is, for any non-primary owner even when no spouse is configured, so
    /// an orphaned account is never mistaken for the user's own.
    private func accountOwnerLabel(for account: IRAAccount) -> String? {
        if account.owner != .primary { return account.owner.rawValue }
        return dataManager.enableSpouse ? account.owner.rawValue : nil
    }

    private func accountOwnerAge(for account: IRAAccount) -> Int {
        switch account.owner {
        case .spouse:
            return dataManager.spouseCurrentAge
        default:
            return dataManager.currentAge
        }
    }

    /// Returns the RMD start age for the account's owner.
    private func accountOwnerRMDAge(for account: IRAAccount) -> Int {
        switch account.owner {
        case .spouse:
            return dataManager.spouseRmdAge
        default:
            return dataManager.rmdAge
        }
    }
}

// MARK: - Supporting Views

struct AccountRMDRow: View {
    let accountName: String
    var ownerLabel: String? = nil
    let balance: Double
    let rmd: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let ownerLabel = ownerLabel {
                        Text(ownerLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(balance, format: .currency(code: "USD"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Required Withdrawal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(rmd, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.UI.textPrimary)
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CombinedRMDProjectionRow: View {
    let year: Int
    let isCurrentYear: Bool
    let primaryAge: Int?
    let primaryBalance: Double?
    let primaryRMD: Double?
    let spouseAge: Int?
    let spouseBalance: Double?
    let spouseRMD: Double?
    let totalRMD: Double

    private let currencyFormat = FloatingPointFormatStyle<Double>.Currency(code: "USD").precision(.fractionLength(0))

    var body: some View {
        HStack(spacing: 0) {
            // Year
            Text("\(year)")
                .font(.caption)
                .fontWeight(isCurrentYear ? .bold : .regular)
                .frame(width: 50, alignment: .leading)

            // Primary: Age / Balance / RMD
            personColumns(age: primaryAge, balance: primaryBalance, rmd: primaryRMD)

            Color.clear.frame(width: 8)

            // Spouse: Age / Balance / RMD
            personColumns(age: spouseAge, balance: spouseBalance, rmd: spouseRMD)

            Color.clear.frame(width: 8)

            // Total RMD
            if totalRMD > 0 {
                Text(totalRMD, format: currencyFormat)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(isCurrentYear ? Color.UI.brandTeal : .primary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isCurrentYear ? Color.UI.surfaceInset : Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func personColumns(age: Int?, balance: Double?, rmd: Double?) -> some View {
        if let age = age {
            Text("\(age)")
                .font(.caption)
                .frame(width: 32, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }

        if let balance = balance {
            Text(balance, format: currencyFormat)
                .font(.caption2)
                .frame(width: 95, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 95, alignment: .trailing)
        }

        if let rmd = rmd {
            Text(rmd, format: currencyFormat)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

struct RMDProjectionRow: View {
    let year: Int
    let age: Int
    let balance: Double
    let rmd: Double
    let isCurrentYear: Bool

    var body: some View {
        HStack {
            Text("\(year)")
                .font(.callout)
                .fontWeight(isCurrentYear ? .bold : .regular)
                .frame(width: 50, alignment: .leading)

            Text("\(age)")
                .font(.callout)
                .frame(width: 40, alignment: .trailing)

            Spacer()

            Text(balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .trailing)

            Spacer()

            Text(rmd, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(isCurrentYear ? Color.UI.brandTeal : .primary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentYear ? Color.UI.surfaceInset : Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    RMDCalculatorView()
        .environment(DataManager())
}
