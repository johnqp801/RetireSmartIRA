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
    /// A4: the ADDITIONAL traditional-IRA withdrawal taken to pay this year's conversion tax when
    /// taxable funds were short (the gross-up). 0 when taxable covered the tax bill in full.
    /// Surfaced so "convert $Y" is not read as the whole IRA outflow for the year.
    let taxFundingWithdrawal: Double

    init(_ rec: YearRecommendation, baselineIRMAA: Double = 0) {
        self.year = rec.year
        self.conversion = rec.executedRothConversion
        self.agi = rec.agi
        self.irmaaSurcharge = max(0, rec.taxBreakdown.irmaa - baselineIRMAA)
        self.taxFundingWithdrawal = rec.taxFundingWithdrawal
    }

    var hasIRMAASurcharge: Bool { irmaaSurcharge > 0 }
    var hasTaxFundingWithdrawal: Bool { taxFundingWithdrawal > 0 }

    var conversionLabel: String { conversion > 0 ? "convert \(PlanSummary.shortDollars(conversion))" : "no conversion" }
    var agiLabel: String { "AGI \(PlanSummary.shortDollars(agi))" }
    /// Compact "IRMAA +$Xk" tag for the conversion-attributable surcharge, empty when there is none.
    var irmaaLabel: String { hasIRMAASurcharge ? "IRMAA +\(PlanSummary.shortDollars(irmaaSurcharge))" : "" }
    /// "IRA withdrawn to pay tax: $X" disclosure line, empty when taxable funded the tax in full.
    var taxFundingLabel: String {
        hasTaxFundingWithdrawal ? "IRA withdrawn to pay tax: \(PlanSummary.shortDollars(taxFundingWithdrawal))" : ""
    }
}
