import Foundation

/// Testable display model for one year of the recommended ladder.
struct LadderRow: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let conversion: Double
    let agi: Double
    /// EXTRA Medicare IRMAA this year *attributable to converting* — this year's plan IRMAA
    /// minus the no-conversion baseline's IRMAA for the same year, floored at 0. A year whose
    /// surcharge the user's other income would trigger anyway shows 0 here (not flagged).
    let irmaaSurcharge: Double
    /// A4: the ADDITIONAL traditional-IRA withdrawal taken to pay this year's total tax bill when
    /// taxable funds were short (the gross-up) — not conversion-tax-only; a zero-conversion year can
    /// still have a gross-up. 0 when taxable covered the tax bill in full.
    /// Surfaced so "convert $Y" is not read as the whole IRA outflow for the year.
    let taxFundingWithdrawal: Double
    /// V2.3: THIS year's tax exceeded the taxable plus traditional assets available to pay it.
    let isInfeasible: Bool
    /// V2.3: an EARLIER year failed, so this year's opening balances descend from a state the
    /// household could not have reached. Independent of `isInfeasible`: a later failure is both.
    let dependsOnInfeasibleYear: Bool
    /// This year's own funding shortfall in dollars. 0 when this year itself was funded.
    let fundingShortfall: Double

    init(_ rec: YearRecommendation, baselineIRMAA: Double = 0) {
        self.year = rec.year
        self.conversion = rec.executedRothConversion
        self.agi = rec.agi
        self.irmaaSurcharge = max(0, rec.taxBreakdown.irmaa - baselineIRMAA)
        self.taxFundingWithdrawal = rec.taxFundingWithdrawal
        self.isInfeasible = rec.isInfeasible
        self.dependsOnInfeasibleYear = rec.dependsOnInfeasibleYear
        self.fundingShortfall = rec.underfunded ?? 0
    }

    var hasIRMAASurcharge: Bool { irmaaSurcharge > 0 }
    var hasTaxFundingWithdrawal: Bool { taxFundingWithdrawal > 0 }

    /// Mirrors `YearRecommendation.isFullyFunded`: presentable as a funded recommendation only
    /// when the year neither failed itself nor descends from one that did.
    var isFullyFunded: Bool { !isInfeasible && !dependsOnInfeasibleYear }
    var showsFundingWarning: Bool { !isFullyFunded }

    /// The funding warning rendered under the row. Empty when the year is fully funded.
    ///
    /// A year that failed on its own reports its OWN shortfall even when it is also downstream
    /// of an earlier failure: showing only the inherited note there would hide real money.
    var fundingWarningLabel: String {
        if isInfeasible { return V2Disclosures.infeasibleYearExplanation(shortfall: fundingShortfall) }
        if dependsOnInfeasibleYear { return V2Disclosures.dependsOnInfeasibleYearExplanation }
        return ""
    }

    /// True when `year` carries a real (non-empty) override — drives the row badge.
    static func hasOverride(year: Int, overrides: [Int: YearOverride]) -> Bool {
        overrides[year]?.pruned != nil
    }

    var conversionLabel: String { conversion > 0 ? "convert \(PlanSummary.shortDollars(conversion))" : "no conversion" }
    var agiLabel: String { "AGI \(PlanSummary.shortDollars(agi))" }
    /// Compact "IRMAA +$Xk" tag for the conversion-attributable surcharge, empty when there is none.
    var irmaaLabel: String { hasIRMAASurcharge ? "IRMAA +\(PlanSummary.shortDollars(irmaaSurcharge))" : "" }
    /// "IRA withdrawn to pay tax: $X" disclosure line, empty when taxable funded the tax in full.
    var taxFundingLabel: String {
        hasTaxFundingWithdrawal ? "IRA withdrawn to pay tax: \(PlanSummary.shortDollars(taxFundingWithdrawal))" : ""
    }
}
