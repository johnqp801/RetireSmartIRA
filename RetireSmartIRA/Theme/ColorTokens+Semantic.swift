import SwiftUI

/// Semantic namespace — meaning-bearing colors with strict one-job rules.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §2.
///
/// **Strict rules:**
/// - `green` = money literally returning to user (refunds only). NOT savings, gains, or "good outcomes" generally.
/// - `amber` = action required (deadlines, missing input, IRMAA proximity). NEVER applied to dollar amounts themselves.
/// - `red`   = error / blocking state only (form validation, crossed cliffs). NEVER for "tax owed."
extension Color {
    enum Semantic {
        // MARK: - Green (refund only)
        // Asset is "SemanticGreen" (not "Green") to avoid Xcode auto-generated
        // symbol collision with NSColor.green / Color.green system colors.
        static let green         = Color("SemanticGreen", bundle: .main)
        static let greenHover    = Color("GreenHover",    bundle: .main)
        static let greenPressed  = Color("GreenPressed",  bundle: .main)
        static let greenDisabled = Color("GreenDisabled", bundle: .main)
        static let greenTint     = Color("GreenTint",     bundle: .main)

        // MARK: - Amber (action required)
        static let amber         = Color("Amber",         bundle: .main)
        static let amberHover    = Color("AmberHover",    bundle: .main)
        static let amberPressed  = Color("AmberPressed",  bundle: .main)
        static let amberDisabled = Color("AmberDisabled", bundle: .main)
        static let amberTint     = Color("AmberTint",     bundle: .main)

        // MARK: - Red (error / blocking only)
        // Asset is "SemanticRed" (not "Red") to avoid Xcode auto-generated
        // symbol collision with NSColor.red / Color.red system colors.
        static let red           = Color("SemanticRed",   bundle: .main)
        static let redHover      = Color("RedHover",      bundle: .main)
        static let redPressed    = Color("RedPressed",    bundle: .main)
        static let redDisabled   = Color("RedDisabled",   bundle: .main)
        static let redTint       = Color("RedTint",       bundle: .main)
    }
}
