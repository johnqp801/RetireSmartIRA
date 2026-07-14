import Testing
import SwiftUI
@testable import RetireSmartIRA

/// Pure-logic coverage for the Cumulative Benefits chart's claim-age line
/// selection and coloring (Alan feedback #4).
///
/// Bug: the chart plotted all 9 claim-age lines (62-70) against a 6-token
/// teal ramp, so adjacent ages collided ("67"/"68" both tealRamp5, "69"/"70"
/// both tealRamp6). This pins `SSCumulativeChartColors.displayLines` to the
/// "show key ages only" resolution: 62, FRA, 70, plus the user's planned
/// claiming age when it is set and distinct from those three -- each with
/// its own distinct color token.
@Suite("SSCumulativeChartColors.displayLines")
struct SSCumulativeChartColorsTests {

    /// Mirrors the real label set SSCalculationEngine.claimingScenarios produces
    /// for a worker whose FRA is 67 (born 1960+).
    private let labelsFRA67 = (62...70).map { age in
        age == 67 ? "Claim at 67 (FRA)" : "Claim at \(age)"
    }

    /// Mirrors the label set for a worker whose FRA is 66 (born 1943-1954).
    private let labelsFRA66 = (62...70).map { age in
        age == 66 ? "Claim at 66 (FRA)" : "Claim at \(age)"
    }

    // MARK: - Key-ages-only selection

    @Test("default (no planned age) shows exactly 62, FRA, 70")
    func defaultKeyAgesNoPlannedAge() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: nil)

        #expect(lines.map(\.label) == ["Claim at 62", "Claim at 67 (FRA)", "Claim at 70"])
    }

    @Test("FRA is matched by the (FRA) suffix, not hardcoded to 67")
    func fraMatchedBySuffixNotHardcoded() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA66, plannedAge: nil)

        #expect(lines.map(\.label) == ["Claim at 62", "Claim at 66 (FRA)", "Claim at 70"])
        #expect(!lines.map(\.label).contains("Claim at 67"))
    }

    // MARK: - Distinct colors

    @Test("every displayed label maps to a distinct color token")
    func allDisplayedTokensAreDistinct() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: nil)
        let tokens = lines.map(\.token)

        #expect(Set(tokens).count == tokens.count)
    }

    @Test("67 (FRA) and 70 -- Alan's comparison -- use different tokens")
    func fraVsSeventyUseDifferentTokens() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: nil)

        let fraToken = lines.first { $0.label == "Claim at 67 (FRA)" }?.token
        let seventyToken = lines.first { $0.label == "Claim at 70" }?.token

        #expect(fraToken != nil)
        #expect(seventyToken != nil)
        #expect(fraToken != seventyToken)
    }

    // MARK: - Planned claiming age

    @Test("planned age distinct from key ages adds a fourth, distinctly colored line")
    func plannedAgeDistinctAddsFourthLine() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: 65)

        #expect(lines.map(\.label) == ["Claim at 62", "Claim at 67 (FRA)", "Claim at 70", "Claim at 65"])

        let plannedLine = lines.last!
        #expect(plannedLine.isPlanned == true)
        #expect(lines.dropLast().allSatisfy { $0.isPlanned == false })

        let tokens = lines.map(\.token)
        #expect(Set(tokens).count == tokens.count)
    }

    @Test("planned age matching 62 does not duplicate the line, but flags it as planned")
    func plannedAgeMatchingSixtyTwoDoesNotDuplicate() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: 62)

        #expect(lines.count == 3)
        #expect(lines[0].label == "Claim at 62")
        #expect(lines[0].isPlanned == true)
        #expect(lines[1].isPlanned == false)
        #expect(lines[2].isPlanned == false)
    }

    @Test("planned age matching FRA does not duplicate the line, but flags it as planned")
    func plannedAgeMatchingFRADoesNotDuplicate() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: 67)

        #expect(lines.count == 3)
        let fraLine = lines.first { $0.label == "Claim at 67 (FRA)" }
        #expect(fraLine?.isPlanned == true)
    }

    @Test("planned age matching 70 does not duplicate the line, but flags it as planned")
    func plannedAgeMatchingSeventyDoesNotDuplicate() {
        let lines = SSCumulativeChartColors.displayLines(availableLabels: labelsFRA67, plannedAge: 70)

        #expect(lines.count == 3)
        let line70 = lines.first { $0.label == "Claim at 70" }
        #expect(line70?.isPlanned == true)
    }

    // MARK: - Defensive: missing labels

    @Test("a missing key-age label is skipped rather than crashing")
    func missingLabelIsSkippedGracefully() {
        let partialLabels = ["Claim at 62", "Claim at 63", "Claim at 67 (FRA)"]

        let lines = SSCumulativeChartColors.displayLines(availableLabels: partialLabels, plannedAge: nil)

        #expect(lines.map(\.label) == ["Claim at 62", "Claim at 67 (FRA)"])
    }
}
