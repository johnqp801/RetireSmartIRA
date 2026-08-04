import Testing
import Foundation
@testable import RetireSmartIRA

/// The five surfaces that described RMD status from the PRIMARY alone while
/// the money next to them was already correctly combined.
///
/// The spouse's RMD was never missing from the tax math. Toggling
/// `enableSpouse` on the household below moves total tax from $780 to
/// $4,976.55, so every figure was already there. What was wrong was the text
/// above the figures, which is what a customer reads first and believes.
///
/// Each site gets a couple test and a single-filer test. The single-filer
/// tests are compatibility pins: those users must see byte-for-byte what they
/// saw before.
@Suite("RMD display attribution", .serialized)
@MainActor
struct RMDDisplayAttributionTests {

    /// Household X from the audit: primary 61 holding nothing, spouse 78
    /// holding $1,000,000. Her RMD is due this year; his is 14 years away.
    private func householdX() -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .marriedFilingJointly
        dm.selectedState = .florida
        dm.userName = "John"
        dm.spouseName = "Karen"
        dm.birthDate = date(1965)          // age 61, RMD age 75
        dm.enableSpouse = true
        dm.spouseBirthDate = date(1948)    // age 78, RMD age 72
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "Her IRA", accountType: .traditionalIRA,
                       balance: 1_000_000, owner: .spouse)
        ]
        return dm
    }

    /// Both people past their RMD age, unequal balances. Used where a test
    /// needs two live RMD figures rather than one.
    private func bothRequiredHousehold() -> DataManager {
        let dm = householdX()
        dm.birthDate = date(1950)          // age 76, RMD age 72
        dm.iraAccounts = [
            IRAAccount(name: "His IRA", accountType: .traditionalIRA,
                       balance: 100_000, owner: .primary),
            IRAAccount(name: "Her IRA", accountType: .traditionalIRA,
                       balance: 900_000, owner: .spouse)
        ]
        return dm
    }

    /// A solo filer 14 years from his own RMD. No spouse exists to leak in.
    private func singleFiler(birthYear: Int = 1965) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .florida
        dm.userName = "John"
        dm.birthDate = date(birthYear)
        dm.enableSpouse = false
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000)
        ]
        dm.iraAccounts = [
            IRAAccount(name: "His IRA", accountType: .traditionalIRA,
                       balance: 1_000_000, owner: .primary)
        ]
        return dm
    }

    private func date(_ year: Int) -> Date {
        var c = DateComponents(); c.year = year; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }

    /// The export's own currency shape, so the amount assertions cannot drift
    /// apart from the renderer over a rounding rule.
    private func exportAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }

    // MARK: - P1: the CPA briefing PDF

    @Test("P1 couple: the briefing states both people's RMD ages and never contradicts the spouse RMD it bills")
    func cpaBriefingStatesBothPeoplesRMDAgesWithoutContradiction() {
        let dm = householdX()
        let spouseRMD = dm.calculateSpouseRMD()
        #expect(spouseRMD > 0)

        let html = PDFExportService.buildHTML(from: PDFExportData(from: dm))

        // Personal Information now names each person with that person's OWN
        // RMD age, rather than printing the primary's countdown as if it were
        // the household's.
        #expect(html.contains("Karen RMD Status"))
        #expect(html.contains("Has reached RMD age 72"))
        #expect(html.contains("John RMD Status"))
        #expect(html.contains("Reaches RMD age 75 in 14 years"))

        // The Income Sources table still bills the spouse's RMD, unchanged.
        #expect(html.contains("Karen&#39;s RMD") || html.contains("Karen's RMD"))
        #expect(html.contains(exportAmount(spouseRMD)))

        // The contradiction itself: page one must not tell a CPA that no
        // distribution is required for 14 years while page one bills for one.
        #expect(!html.contains("RMD Begins"))
        #expect(!html.contains("(14 years)"))
    }

    @Test("P1 single filer: the briefing's Personal Information rows are byte-for-byte what they were")
    func cpaBriefingSingleFilerPersonalInfoUnchanged() {
        let waiting = PDFExportService.sectionPersonalInfo(
            PDFExportData(from: singleFiler(birthYear: 1965)))
        #expect(waiting.contains("<tr><td>RMD Begins</td><td>Age 75 (14 years)</td></tr>"))
        #expect(!waiting.contains("RMD Status"))

        let required = PDFExportService.sectionPersonalInfo(
            PDFExportData(from: singleFiler(birthYear: 1950)))
        #expect(required.contains("<tr><td>RMD Status</td><td class=\"red\">Required</td></tr>"))
        #expect(!required.contains("RMD Begins"))
    }

    @Test("P1 couple: the Income Sources owner column names the primary rather than the word Primary")
    func cpaBriefingOwnerColumnNamesThePrimary() {
        let dm = bothRequiredHousehold()
        #expect(dm.calculatePrimaryRMD() > 0)

        let html = PDFExportService.sectionIncomeSources(PDFExportData(from: dm))
        #expect(html.contains("<td>John</td>"))
        #expect(html.contains("<td>Karen</td>"))
        #expect(!html.contains("<td>Primary</td>"))
    }

    // MARK: - P2: the Tax Summary header card

    @Test("P2 couple: the Tax Summary header reads Required when only the spouse has reached RMD age")
    func taxSummaryHeaderReadsRequiredWhenOnlyTheSpouseIsRequired() {
        let metric = DashboardView.rmdHeadlineMetric(householdX())

        #expect(metric.label == "RMD Status")
        #expect(metric.value == "Required")
        // Whoever got there first is named, so the card cannot be read as the
        // primary's own status.
        #expect(metric.detail == "Karen has reached RMD age 72")
        // The old primary-only countdown is exactly what the customer saw.
        #expect(metric.label != "Years Until RMD")
        #expect(metric.value != "14")
    }

    @Test("P2 single filer: the Tax Summary header card is unchanged")
    func taxSummaryHeaderSingleFilerUnchanged() {
        let waiting = DashboardView.rmdHeadlineMetric(singleFiler(birthYear: 1965))
        #expect(waiting.label == "Years Until RMD")
        #expect(waiting.value == "14")
        #expect(waiting.detail == nil)

        let required = DashboardView.rmdHeadlineMetric(singleFiler(birthYear: 1950))
        #expect(required.label == "RMD Status")
        #expect(required.value == "Required")
        #expect(required.detail == nil)
    }

    // MARK: - P3: the collapsed Scenarios withdrawal card

    @Test("P3 couple: the collapsed withdrawal card labels the combined figure Combined RMDs")
    func collapsedWithdrawalCardSaysCombinedForCouples() {
        #expect(TaxPlanningView.collapsedRmdLabel(spouseEnabled: true) == "Combined RMDs")
        #expect(TaxPlanningView.collapsedRmdLabel(spouseEnabled: true) != "Required RMD")
    }

    @Test("P3 single filer: the collapsed withdrawal card still reads Required RMD")
    func collapsedWithdrawalCardSingleFilerUnchanged() {
        #expect(TaxPlanningView.collapsedRmdLabel(spouseEnabled: false) == "Required RMD")
    }

    // MARK: - P4: the Legacy tab's conversion-window note

    @Test("P4 couple: no gap-years advice once the spouse has reached RMD age, and the window names who ends it")
    func legacyGapYearsFollowsTheHousehold() {
        // Spouse six years past her RMD age: there is no window left at all.
        #expect(LegacyImpactView.conversionGapSentence(householdX()) == nil)

        // Neither required yet, and she gets there first at a different age.
        let dm = householdX()
        dm.spouseBirthDate = date(1958)   // age 68, RMD age 73 -> 5 years
        #expect(LegacyImpactView.conversionGapSentence(dm)
            == "Your household has 5 gap years before RMDs start, when Karen reaches RMD age 73.")
    }

    @Test("P4 single filer: the gap-years sentence is unchanged")
    func legacyGapYearsSingleFilerUnchanged() {
        #expect(LegacyImpactView.conversionGapSentence(singleFiler(birthYear: 1965))
            == "You have 14 gap years before RMDs start at age 75.")
        // Already required: silent, exactly as before.
        #expect(LegacyImpactView.conversionGapSentence(singleFiler(birthYear: 1950)) == nil)
    }

    // MARK: - P5: the RMD action items

    @Test("P5 couple: both RMD action items name their owner")
    func rmdActionItemsAreSymmetricallyNamed() {
        let dm = bothRequiredHousehold()
        let titles = dm.generatedActionItems.filter { $0.category == .rmd }.map(\.title)

        #expect(titles.count == 2)
        #expect(titles.contains { $0.hasPrefix("Take John's RMD: ") })
        #expect(titles.contains { $0.hasPrefix("Take Karen's RMD: ") })
        // The unnamed form is what read as an unexplained second figure.
        #expect(!titles.contains { $0.hasPrefix("Take RMD: ") })
    }

    @Test("P5 single filer: the RMD action item keeps its original bare wording")
    func rmdActionItemSingleFilerUnchanged() {
        let dm = singleFiler(birthYear: 1950)
        let titles = dm.generatedActionItems.filter { $0.category == .rmd }.map(\.title)

        #expect(titles.count == 1)
        #expect(titles[0].hasPrefix("Take RMD: "))
    }
}
