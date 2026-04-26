import CoreGraphics

/// Corner-radius tokens. Nested radii descend so curves harmonize.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §6.
enum Radius {
    /// Outer cards, modals, sheets.
    static let card:   CGFloat = 12
    /// Text fields, dropdowns, segmented controls.
    static let input:  CGFloat = 8
    /// All button sizes.
    static let button: CGFloat = 6
    /// Tags / status badges (rounded rectangles, NOT true pills).
    static let badge:  CGFloat = 4

    /// True pill shape: radius is half the component's height.
    /// Reserved for filter chips, segmented controls (future use).
    static func capsule(forHeight height: CGFloat) -> CGFloat {
        height / 2
    }
}
