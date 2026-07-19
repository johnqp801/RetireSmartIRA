import Foundation

/// Decides what the Year-1 Roth conversion field should commit to the shared model after the user
/// stops typing. Extracted from `Year1EditorView` so the rule is testable on its own: the field
/// receives both user keystrokes and programmatic syncs (the plan's Year-1 amount is written back
/// into the field whenever the engine settles), and only the former should change the override.
enum Year1OverrideCommit {
    /// - Parameters:
    ///   - parsed: the digits currently in the field, as a number.
    ///   - plannedYear1: what the modeled plan actually converts in Year 1.
    ///   - currentOverride: the user's existing explicit override (0 = following the plan).
    /// - Returns: the value to write to the override (0 = clear it and follow the plan).
    static func target(parsed: Double, plannedYear1: Double, currentOverride: Double) -> Double {
        // "The field matches the plan" only means "follow the plan" when there is no override to
        // begin with. Once an override is active the plan is PINNED to it, so the two are always
        // equal and that test can no longer tell a user edit apart from the engine syncing the
        // field back to itself. Treating the match as a clear there wipes the user's conversion.
        // An active override is cleared by emptying the field, or by "Reset to optimal".
        if currentOverride == 0 && abs(parsed - plannedYear1) < 1 { return 0 }
        return parsed
    }
}
