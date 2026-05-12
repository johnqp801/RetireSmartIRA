// SliderHelpers.swift
// RetireSmartIRA
//
// Utility functions for slider UX — adaptive caps, etc.

import Foundation

/// Computes an adaptive slider maximum for IRA balance-based sliders.
///
/// For users with large IRA balances, a full-range slider is hypersensitive —
/// every pixel of drag can represent thousands of dollars. This formula caps the
/// slider at a "comfortable" range while the text field continues to accept the
/// full balance.
///
/// Formula: min(20% of balance, $500K), floored at min(balance, $50K).
///
/// | Balance  | Slider max        |
/// |----------|-------------------|
/// | $0       | $0                |
/// | $30K     | $30K (floor wins) |
/// | $100K    | $50K (floor wins) |
/// | $500K    | $100K             |
/// | $1M      | $200K             |
/// | $3M      | $500K (cap wins)  |
/// | $7.3M+   | $500K (cap)       |
func adaptiveSliderCap(balance: Double) -> Double {
    let twentyPercent = balance * 0.20
    let cappedAt500K = min(twentyPercent, 500_000)
    return max(cappedAt500K, min(balance, 50_000))
}
