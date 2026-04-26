import XCTest
import SwiftUI
@testable import RetireSmartIRA

/// WCAG AA contrast assertions for color tokens.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §9.
///
/// Failures here mean a token combination doesn't meet WCAG AA (4.5:1 normal text,
/// 3:1 large text). When a test fails, file a finding rather than silently adjusting
/// hex values — the spec's color contract is the source of truth.
final class ContrastAssertionTests: XCTestCase {

    // MARK: - WCAG ratio calculation

    /// Computes the WCAG 2.1 contrast ratio between two colors at a given color scheme.
    /// Reference: https://www.w3.org/TR/WCAG21/#contrast-minimum
    private func contrastRatio(_ a: Color, _ b: Color, scheme: ColorScheme) -> Double {
        let l1 = relativeLuminance(a, scheme: scheme)
        let l2 = relativeLuminance(b, scheme: scheme)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Resolves a SwiftUI Color to its sRGB components in the given color scheme,
    /// then computes the WCAG relative luminance.
    private func relativeLuminance(_ color: Color, scheme: ColorScheme) -> Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        #if canImport(UIKit)
        let trait = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: trait)
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        let appearance: NSAppearance = scheme == .dark
            ? (NSAppearance(named: .darkAqua) ?? NSAppearance.current)
            : (NSAppearance(named: .aqua) ?? NSAppearance.current)
        appearance.performAsCurrentDrawingAppearance {
            let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        #endif

        let channels = [r, g, b].map { c -> Double in
            let ch = Double(c)
            return ch <= 0.03928 ? ch / 12.92 : pow((ch + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private let aaThreshold = 4.5
    private let aaLargeTextThreshold = 3.0

    private func assertContrast(
        _ fg: Color,
        on bg: Color,
        scheme: ColorScheme,
        threshold: Double,
        label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let ratio = contrastRatio(fg, bg, scheme: scheme)
        XCTAssertGreaterThanOrEqual(
            ratio,
            threshold,
            "[\(scheme == .dark ? "dark" : "light")] \(label): contrast = \(String(format: "%.2f", ratio)), need ≥ \(threshold)",
            file: file,
            line: line
        )
    }

    // MARK: - Light mode: text on surfaces

    func test_lightMode_textPrimaryOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textPrimary, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "textPrimary on surfaceCard")
    }

    func test_lightMode_textPrimaryOnSurfaceApp_meetsAA() {
        assertContrast(.UI.textPrimary, on: .UI.surfaceApp, scheme: .light, threshold: aaThreshold, label: "textPrimary on surfaceApp")
    }

    func test_lightMode_textSecondaryOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textSecondary, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "textSecondary on surfaceCard")
    }

    func test_lightMode_textTertiaryOnSurfaceCard_meetsAALarge() {
        // textTertiary is for disabled/projected — only used for large text or non-essential info
        assertContrast(.UI.textTertiary, on: .UI.surfaceCard, scheme: .light, threshold: aaLargeTextThreshold, label: "textTertiary on surfaceCard (large text)")
    }

    func test_lightMode_textUtilityOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textUtility, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "textUtility on surfaceCard")
    }

    // MARK: - Light mode: brand on surfaces

    func test_lightMode_brandTealOnSurfaceCard_meetsAA() {
        assertContrast(.UI.brandTeal, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "brandTeal on surfaceCard")
    }

    func test_lightMode_whiteOnBrandTeal_meetsAA() {
        assertContrast(.white, on: .UI.brandTeal, scheme: .light, threshold: aaThreshold, label: "white on brandTeal (primary button text)")
    }

    // MARK: - Light mode: semantic on surfaces

    func test_lightMode_amberOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.amber, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "amber on surfaceCard (deadline text)")
    }

    func test_lightMode_redOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.red, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "red on surfaceCard (error text)")
    }

    func test_lightMode_greenOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.green, on: .UI.surfaceCard, scheme: .light, threshold: aaThreshold, label: "green on surfaceCard (refund text)")
    }

    // MARK: - Light mode: semantic-tint pairings (badges)

    func test_lightMode_greenOnGreenTint_meetsAALarge() {
        assertContrast(.Semantic.green, on: .Semantic.greenTint, scheme: .light, threshold: aaLargeTextThreshold, label: "green on greenTint (REFUND badge)")
    }

    func test_lightMode_amberOnAmberTint_meetsAALarge() {
        assertContrast(.Semantic.amber, on: .Semantic.amberTint, scheme: .light, threshold: aaLargeTextThreshold, label: "amber on amberTint (DUE badge)")
    }

    func test_lightMode_redOnRedTint_meetsAALarge() {
        assertContrast(.Semantic.red, on: .Semantic.redTint, scheme: .light, threshold: aaLargeTextThreshold, label: "red on redTint (ERROR badge)")
    }

    // MARK: - Dark mode: text on surfaces

    func test_darkMode_textPrimaryOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textPrimary, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "textPrimary on surfaceCard")
    }

    func test_darkMode_textSecondaryOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textSecondary, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "textSecondary on surfaceCard")
    }

    func test_darkMode_textUtilityOnSurfaceCard_meetsAA() {
        assertContrast(.UI.textUtility, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "textUtility on surfaceCard")
    }

    // MARK: - Dark mode: brand on surfaces

    /// Brand teal as foreground on dark card surface uses the LARGE-TEXT threshold (3.0:1)
    /// per WCAG 2.1 §1.4.3. In dark mode, brand teal is darkened (`#2A7585`) so white
    /// button text passes 4.5:1; that same darkness can't simultaneously satisfy 4.5:1
    /// against `#1C1C1E` as a foreground color (the ranges don't overlap mathematically).
    ///
    /// We accept this because brand teal is never used for body text in this app — only
    /// for ≥16pt info-button glyphs, ≥15pt tertiary/secondary button labels, and section
    /// headers. All qualify as "large text" or graphical objects under WCAG.
    func test_darkMode_brandTealOnSurfaceCard_meetsAALarge() {
        assertContrast(.UI.brandTeal, on: .UI.surfaceCard, scheme: .dark, threshold: aaLargeTextThreshold, label: "brandTeal on surfaceCard (large text only)")
    }

    func test_darkMode_whiteOnBrandTeal_meetsAA() {
        assertContrast(.white, on: .UI.brandTeal, scheme: .dark, threshold: aaThreshold, label: "white on brandTeal (primary button text)")
    }

    // MARK: - Dark mode: semantic on surfaces

    func test_darkMode_amberOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.amber, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "amber on surfaceCard (deadline text)")
    }

    func test_darkMode_redOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.red, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "red on surfaceCard (error text)")
    }

    func test_darkMode_greenOnSurfaceCard_meetsAA() {
        assertContrast(.Semantic.green, on: .UI.surfaceCard, scheme: .dark, threshold: aaThreshold, label: "green on surfaceCard (refund text)")
    }
}
