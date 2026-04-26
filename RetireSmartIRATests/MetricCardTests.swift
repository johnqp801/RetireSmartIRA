import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class MetricCardTests: XCTestCase {
    func test_allCategoriesExist() {
        let _ : [MetricCard.Category] = [.informational, .actionRequired, .error]
    }

    func test_eachCategoryProvidesAStripeColor() {
        for category in [MetricCard.Category.informational, .actionRequired, .error] {
            _ = category.stripeColor
        }
    }

    func test_minimalCardConstructsWithoutCrash() {
        _ = MetricCard(label: "Total Tax", value: "$12,847")
    }

    func test_fullyConfiguredCardConstructsWithoutCrash() {
        _ = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
    }

    func test_defaultCategoryIsInformational() {
        // Confirms initializer signature has category defaulting (compile-time check).
        _ = MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
    }
}
