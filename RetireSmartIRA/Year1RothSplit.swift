import Foundation

/// Re-distributes a new combined household Year-1 Roth conversion across the existing per-spouse
/// split, preserving the prior ratio in whole dollars with an exact sum. Falls back to all-primary
/// when there was no prior conversion. The multi-year engine sums the two fields, so the split
/// never changes totals or tax; this only avoids silently discarding a deliberately-entered spouse
/// amount when the household total is edited from the Multi-Year tab.
enum Year1RothSplit {
    static func apply(newTotal: Double, your: Double, spouse: Double) -> (your: Double, spouse: Double) {
        let clamped = max(0, newTotal)
        let old = your + spouse
        guard old > 0 else { return (clamped, 0) }
        let newYour = (clamped * (your / old)).rounded()
        return (newYour, max(0, clamped - newYour))
    }
}
