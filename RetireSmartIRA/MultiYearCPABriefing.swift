import Foundation

/// Value-type inputs for the CPA briefing PDF. Pure data; assembled by the view from manager
/// and DataManager state. Figures are nominal (future dollars).
struct CPABriefingModel: Equatable, Sendable {
    let preparedFor: String
    let taxYear: Int
    let filingStatusLabel: String
    let stateLabel: String
    let primaryBirthYear: Int
    let summary: PlanSummary
    let comparison: PlanComparison
    let yearRows: [YearRecommendation]
    let frontier: HeirFrontierResult?
    /// When legacy planning is off, the briefing omits the heir metric (the frontier is also nil).
    let includeHeirs: Bool
    let assumptions: MultiYearAssumptions
    let limitations: [String]
    let positioning: String
}

/// Builds the CPA briefing as a self-contained HTML document for the shared PDF render backend.
enum MultiYearCPABriefingHTML {

    // Currency: whole-dollar USD.
    private static let currency: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 0
        return f
    }()
    private static func fmt(_ v: Double) -> String { currency.string(from: NSNumber(value: v)) ?? "$0" }
    private static func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
    /// Exposed only so the test can compare against the same escaping the builder applies.
    static func escapeForTest(_ s: String) -> String { esc(s) }

    static func build(_ m: CPABriefingModel) -> String {
        var h = header(m)
        h += execSummary(m)
        h += comparisonSection(m)
        h += ladderSection(m)
        h += yearByYearSection(m)
        if let frontier = m.frontier { h += frontierSection(frontier) }
        h += assumptionsSection(m)
        h += limitationsSection(m)
        h += footer()
        return h
    }

    private static func header(_ m: CPABriefingModel) -> String {
        let date = Date().formatted(date: .long, time: .omitted)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 11px; color: #333; line-height: 1.4; margin: 0; padding: 0; }
        h1 { font-size: 18px; color: #1a1a2e; border-bottom: 2px solid #2563eb; padding-bottom: 6px; margin: 0 0 4px 0; }
        h2 { font-size: 13px; color: #1e40af; margin: 18px 0 8px 0; border-bottom: 1px solid #ddd; padding-bottom: 4px; }
        table { width: 100%; border-collapse: collapse; margin: 6px 0 12px 0; }
        th { background: #f1f5f9; font-weight: 600; padding: 4px 6px; text-align: right; border-bottom: 2px solid #cbd5e1; font-size: 9px; }
        th:first-child, td:first-child { text-align: left; }
        td { padding: 3px 6px; border-bottom: 1px solid #e2e8f0; font-size: 9px; text-align: right; }
        .sub { color: #666; font-size: 10px; }
        .note { color: #666; font-size: 10px; margin: 4px 0; }
        table.yby th, table.yby td { font-size: 8px; padding: 2px 3px; white-space: nowrap; }
        </style></head><body>
        <h1>Multi-Year Roth Conversion Plan</h1>
        <div class="sub">Prepared for \(esc(m.preparedFor)) &middot; \(esc(m.filingStatusLabel)) &middot; \(esc(m.stateLabel)) &middot; Plan base year \(m.taxYear) &middot; \(date)</div>
        <div class="note">\(esc(m.positioning))</div>
        """
    }

    private static func execSummary(_ m: CPABriefingModel) -> String {
        let savings = m.comparison.lifetimeTax.doingNothing - m.comparison.lifetimeTax.plan
        return """
        <h2>Executive summary</h2>
        <table>
        <tr><td>Recommended Roth conversions</td><td>\(fmt(m.summary.totalConversions)) over \(m.summary.conversionYears) year(s)</td></tr>
        <tr><td>Projected lifetime tax (plan)</td><td>\(fmt(m.summary.lifetimeTax))</td></tr>
        <tr><td>Projected lifetime tax (doing nothing)</td><td>\(fmt(m.comparison.lifetimeTax.doingNothing))</td></tr>
        <tr><td>Lifetime tax difference</td><td>\(fmt(savings))</td></tr>
        </table>
        <div class="note">Figures are nominal (future dollars) unless stated otherwise.</div>
        """
    }

    private static func comparisonSection(_ m: CPABriefingModel) -> String {
        func row(_ label: String, _ p: PlanComparison.Pair) -> String {
            "<tr><td>\(label)</td><td>\(fmt(p.plan))</td><td>\(fmt(p.doingNothing))</td></tr>"
        }
        return """
        <h2>Your plan vs. doing nothing</h2>
        <table>
        <tr><th>Metric</th><th>Your plan</th><th>Doing nothing</th></tr>
        \(row("Lifetime tax", m.comparison.lifetimeTax))
        \(row("Ending traditional IRA", m.comparison.endingTraditional))
        \(row("Ending Roth IRA", m.comparison.endingRoth))
        \(m.includeHeirs ? row("What heirs keep", m.comparison.heirsKeep) : "")
        \(row("Peak forced RMD", m.comparison.peakForcedRMD))
        </table>
        """
    }

    private static func ladderSection(_ m: CPABriefingModel) -> String {
        var rows = ""
        for r in m.yearRows {
            let conv = r.actions.reduce(0.0) { a, act in
                if case let .rothConversion(amount) = act { return a + amount }; return a }
            if conv > 0 { rows += "<tr><td>\(r.year)</td><td>\(fmt(conv))</td></tr>" }
        }
        if rows.isEmpty { rows = "<tr><td>-</td><td>No conversions recommended</td></tr>" }
        return """
        <h2>Recommended conversions by year</h2>
        <table><tr><th>Year</th><th>Roth conversion</th></tr>\(rows)</table>
        """
    }

    private static func yearByYearSection(_ m: CPABriefingModel) -> String {
        var rows = ""
        for r in m.yearRows {
            let age = r.year - m.primaryBirthYear
            let conv = r.actions.reduce(0.0) { a, act in
                if case let .rothConversion(amount) = act { return a + amount }; return a }
            // Compact currency (e.g. $785k, $1.5M) so the 12-column table fits portrait width
            // without wrapping each value onto two lines.
            let s = PlanSummary.shortDollars
            rows += """
            <tr><td>\(r.year)</td><td>\(age)</td><td>\(s(r.agi))</td><td>\(s(r.taxableIncome))</td>\
            <td>\(s(r.taxBreakdown.federal))</td><td>\(s(r.taxBreakdown.state))</td>\
            <td>\(s(r.taxBreakdown.irmaa))</td><td>\(s(r.rmd))</td><td>\(s(conv))</td>\
            <td>\(s(r.endOfYearBalances.traditional + r.endOfYearBalances.inheritedTraditional))</td>\
            <td>\(s(r.endOfYearBalances.roth + r.endOfYearBalances.inheritedRoth))</td>\
            <td>\(s(r.endOfYearBalances.taxable))</td></tr>
            """
        }
        return """
        <h2>Year-by-year detail</h2>
        <div class="note">Amounts are rounded (k = thousands, M = millions).</div>
        <table class="yby">
        <tr><th>Year</th><th>Age</th><th>AGI</th><th>Taxable</th><th>Fed</th><th>State</th><th>IRMAA</th><th>RMD</th><th>Conv</th><th>End Trad</th><th>End Roth</th><th>End Txbl</th></tr>
        \(rows)
        </table>
        """
    }

    private static func frontierSection(_ frontier: HeirFrontierResult) -> String {
        var rows = ""
        for p in frontier.points {
            rows += "<tr><td>\(pct(p.weight))</td><td>\(fmt(p.ownerLifetimeTaxToday))</td><td>\(fmt(p.heirAfterTaxInheritanceToday))</td></tr>"
        }
        return """
        <h2>Owner vs. heirs trade-off</h2>
        <table><tr><th>Heir weight</th><th>Your lifetime tax</th><th>What heirs keep</th></tr>\(rows)</table>
        <div class="note">Figures in today's dollars.</div>
        """
    }

    private static func assumptionsSection(_ m: CPABriefingModel) -> String {
        let a = m.assumptions
        return """
        <h2>Assumptions</h2>
        <table>
        <tr><td>Investment growth</td><td>\(pct(a.investmentGrowthRate))</td></tr>
        <tr><td>Inflation (CPI)</td><td>\(pct(a.cpiRate))</td></tr>
        <tr><td>Future tax rate on leftover traditional IRA</td><td>\(pct(a.terminalLiquidationTaxRate))</td></tr>
        <tr><td>Plan through age</td><td>\(a.horizonEndAge)</td></tr>
        <tr><td>Withdrawal order</td><td>\(esc(a.withdrawalOrderingRule.displayName))</td></tr>
        </table>
        """
    }

    private static func limitationsSection(_ m: CPABriefingModel) -> String {
        let items = m.limitations.map { "<li>\(esc($0))</li>" }.joined()
        return """
        <h2>Limitations</h2>
        <ul>\(items)</ul>
        <div class="note">This document is an educational planning estimate and is not tax advice. Tax thresholds are modeled at 2026 levels and are not inflation-adjusted. Please review with a qualified tax professional.</div>
        """
    }

    private static func footer() -> String { "</body></html>" }
}
