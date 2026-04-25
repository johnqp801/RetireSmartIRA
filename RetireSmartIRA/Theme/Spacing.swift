import CoreGraphics

/// Spacing scale (8pt grid with 4pt half-steps).
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §6.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}
