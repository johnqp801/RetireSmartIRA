import XCTest
import SwiftUI
@testable import RetireSmartIRA

@MainActor
final class MetricCardSnapshotTests: XCTestCase {
    // MARK: - Informational (default)
    func test_informational_light() {
        let view = MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
            .frame(width: 240)
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_informational_light")
    }
    func test_informational_dark() {
        let view = MetricCard(label: "Total Tax", value: "$12,847", delta: "+$1,240 vs 2025")
            .frame(width: 240)
            .padding()
            .background(Color.UI.surfaceApp)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_informational_dark")
    }

    // MARK: - Action Required (amber)
    func test_actionRequired_light() {
        let view = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_actionRequired_light")
    }
    func test_actionRequired_dark() {
        let view = MetricCard(
            label: "Q2 Estimated",
            value: "$3,212",
            delta: "Due Jun 15",
            deltaIsAmber: true,
            category: .actionRequired,
            badge: .due
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_actionRequired_dark")
    }

    // MARK: - Error (red)
    func test_error_light() {
        let view = MetricCard(
            label: "ACA Subsidy",
            value: "$0",
            delta: "Cliff exceeded",
            category: .error,
            badge: .error
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.light)
        assertSnapshot(of: view, named: "MetricCard_error_light")
    }
    func test_error_dark() {
        let view = MetricCard(
            label: "ACA Subsidy",
            value: "$0",
            delta: "Cliff exceeded",
            category: .error,
            badge: .error
        )
        .frame(width: 240)
        .padding()
        .background(Color.UI.surfaceApp)
        .preferredColorScheme(.dark)
        assertSnapshot(of: view, named: "MetricCard_error_dark")
    }
}
