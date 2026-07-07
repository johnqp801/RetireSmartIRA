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

extension TaxImpactChart {
    var commentary: ChartCommentary {
        let base = "This adds up total tax paid so far under your plan versus doing nothing, year by year. A conversion plan usually pays more tax early, then pulls ahead as forced withdrawals shrink."
        let outcome: String
        let s = totalSavings
        if s > 1_000 {
            outcome = " Over the full horizon shown, the plan comes out about \(PlanSummary.shortDollars(s)) ahead."
        } else if s < -1_000 {
            outcome = " Over the full horizon shown, the plan pays about \(PlanSummary.shortDollars(-s)) more in total tax under these assumptions."
        } else {
            outcome = " Over the full horizon shown, the plan and doing nothing come out about even."
        }
        return ChartCommentary(title: "Cumulative tax: your plan vs doing nothing", body: base + outcome)
    }
}

extension ConversionLadderChart {
    var commentary: ChartCommentary {
        let title = "Modeled conversions by year"
        guard hasAnyConversion else {
            return ChartCommentary(
                title: title,
                body: "Under these assumptions, no Roth conversions are recommended, so there is no ladder to show.")
        }
        let years = points.filter { $0.conversion > 0 }.count
        let total = points.reduce(0.0) { $0 + $1.conversion }
        let body = "Each bar is the Roth conversion this plan models for that year. It converts about \(PlanSummary.shortDollars(total)) across \(years) year\(years == 1 ? "" : "s"), sized to use up lower tax brackets without pushing your income past the next cliff."
        return ChartCommentary(title: title, body: body)
    }
}

extension ThresholdMapChart {
    var commentary: ChartCommentary {
        let title = "Income vs tax cliffs by year"
        let base = "This plots each year's income against the thresholds it has to navigate. Toggle between Medicare and subsidy cliffs, which track your MAGI, and federal income-tax brackets, which track your taxable income."
        let note = (magiLines.isEmpty && bracketLines.isEmpty)
            ? ""
            : " Staying just under a line keeps you out of a higher Medicare premium tier, a lost subsidy, or a higher bracket for that year."
        return ChartCommentary(title: title, body: base + note)
    }
}

extension HeirFrontierChart {
    var commentary: ChartCommentary {
        let title = "Your taxes vs. what heirs keep"
        guard points.count > 1 else {
            return ChartCommentary(
                title: title,
                body: "At these assumptions every strategy weighting lands in essentially the same place, so there is no trade-off curve to plot.")
        }
        let body = "Each point is a different strategy weighting. Moving down and to the left lowers your lifetime tax; moving up and to the right leaves more after-tax money to your heirs. The highlighted point is your current selection."
        return ChartCommentary(title: title, body: body)
    }
}
