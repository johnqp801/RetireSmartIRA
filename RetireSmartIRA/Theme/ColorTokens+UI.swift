import SwiftUI

/// UI namespace tokens — brand identity, surfaces, text.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §3.
extension Color {
    enum UI {
        // MARK: - Brand
        static let brandTeal          = Color("BrandTeal",          bundle: .main)
        static let brandTealHover     = Color("BrandTealHover",     bundle: .main)
        static let brandTealPressed   = Color("BrandTealPressed",   bundle: .main)
        static let brandTealDisabled  = Color("BrandTealDisabled",  bundle: .main)
        static let brandTealFocusRing = Color("BrandTealFocusRing", bundle: .main)

        // MARK: - Surfaces
        static let surfaceApp         = Color("SurfaceApp",         bundle: .main)
        static let surfaceCard        = Color("SurfaceCard",        bundle: .main)
        static let surfaceInset       = Color("SurfaceInset",       bundle: .main)
        static let surfaceModal       = Color("SurfaceModal",       bundle: .main)
        static let surfaceDivider     = Color("SurfaceDivider",     bundle: .main)

        // MARK: - Text
        static let textPrimary        = Color("TextPrimary",        bundle: .main)
        static let textSecondary      = Color("TextSecondary",      bundle: .main)
        static let textTertiary       = Color("TextTertiary",       bundle: .main)
        static let textUtility        = Color("TextUtility",        bundle: .main)
    }
}
