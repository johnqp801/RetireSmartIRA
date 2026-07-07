import Foundation

// Deterministic, per-chart plain-language commentary. Each property reads only fields the model
// already holds and degrades gracefully on empty/degenerate input. Keep the voice plain and
// non-alarmist; no em dashes. Auto-generated financial text that is subtly wrong is worse than
// none, so every branch here is covered by ChartCommentaryTests.

extension BalancesChart {
    var commentary: ChartCommentary {
        let base = "Each line is a projected balance under this plan: your Traditional IRA or 401(k), your Roth, and your taxable accounts, shown year by year."
        let trend: String
        if let last = points.last, last.roth > last.traditional, last.roth > 0 {
            trend = " By the end of the plan, more of your money sits in the tax-free Roth than in the Traditional account, which is still taxed when withdrawn."
        } else if let last = points.last, last.traditional > 0 {
            trend = " The Traditional balance is the part that still faces income tax when it is withdrawn or passed to heirs."
        } else {
            trend = ""
        }
        let band = hasBand
            ? " The shaded band shows how the total shifts under higher or lower constant growth. It is growth-assumption sensitivity, not a probability or the odds of success."
            : ""
        return ChartCommentary(title: "Account balances over time", body: base + trend + band)
    }
}
