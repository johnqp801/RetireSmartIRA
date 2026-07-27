//
//  RMDProjectionAxisTests.swift
//  RetireSmartIRATests
//
//  Tests for x-axis label thinning on the "Projected Annual RMDs" bar chart.
//
//  Background:
//  That chart plots a String category on x (a "'29"-style year label), and a
//  category axis draws one label per bar unless it is handed an explicit
//  subset.  At the 20/30/40-year horizons that produced 20-40 labels crushed
//  into ~300pt of width — an unreadable smear of digits on iOS.
//
//  The fix thins the labels down to round calendar years, matching how the
//  drawdown charts further down the screen already read ('30, '40, '50, '60).
//  These tests pin the thinning rule for every option the picker offers.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RMD Projection Chart — X-Axis Label Thinning")
struct RMDProjectionAxisTests {

    /// Every horizon the segmented picker offers.
    private let pickerOptions = [5, 10, 15, 20, 30, 40]

    // MARK: - The invariant that actually broke

    @Test("No horizon crowds the axis with more labels than it can render")
    func labelCountStaysReadable() {
        for years in pickerOptions {
            let labeled = RMDCalculatorView.projectionAxisYears(
                currentYear: 2026,
                projectionYears: years
            )
            #expect(
                labeled.count <= 8,
                "\(years)-year horizon produced \(labeled.count) x-axis labels; ~8 is the most that fits on an iPhone-width chart"
            )
            #expect(!labeled.isEmpty, "\(years)-year horizon produced no x-axis labels at all")
        }
    }

    @Test("Labels stay inside the plotted window and ascend")
    func labelsStayInsideWindow() {
        for years in pickerOptions {
            let currentYear = 2026
            let lastPlottedYear = currentYear + years - 1
            let labeled = RMDCalculatorView.projectionAxisYears(
                currentYear: currentYear,
                projectionYears: years
            )

            #expect(labeled == labeled.sorted(), "\(years)-year labels are out of order")
            #expect(Set(labeled).count == labeled.count, "\(years)-year labels contain duplicates")

            for year in labeled {
                #expect(
                    year >= currentYear && year <= lastPlottedYear,
                    "\(years)-year horizon labeled \(year), outside \(currentYear)...\(lastPlottedYear)"
                )
            }
        }
    }

    // MARK: - The specific thinning rule, per picker option

    @Test("Short horizons label every year")
    func fiveYearHorizonLabelsEveryYear() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 5)
        #expect(labeled == [2026, 2027, 2028, 2029, 2030])
    }

    @Test("Ten-year horizon labels every other year")
    func tenYearHorizonLabelsEveryOtherYear() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 10)
        #expect(labeled == [2026, 2028, 2030, 2032, 2034])
    }

    @Test("Fifteen-year horizon labels every other year")
    func fifteenYearHorizonLabelsEveryOtherYear() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 15)
        #expect(labeled == [2026, 2028, 2030, 2032, 2034, 2036, 2038])
    }

    @Test("Twenty-year horizon lands on half-decades")
    func twentyYearHorizonLandsOnHalfDecades() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 20)
        #expect(labeled == [2030, 2035, 2040])
    }

    @Test("Thirty-year horizon lands on half-decades")
    func thirtyYearHorizonLandsOnHalfDecades() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 30)
        #expect(labeled == [2030, 2035, 2040, 2045, 2050])
    }

    @Test("Forty-year horizon lands on decades, like the drawdown chart")
    func fortyYearHorizonLandsOnDecades() {
        let labeled = RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 40)
        #expect(labeled == [2030, 2040, 2050, 2060])
    }

    // MARK: - The final bar's label gets clipped, so we never ask for it

    /// Swift Charts centers a category label under its bar, so a label on the
    /// LAST bar overhangs the plot's trailing edge and renders as "…".  This is
    /// what turned the 30-year axis into `'30 '35 '40 '45 '50 …` on iPhone.
    /// Safe to label every bar only when the step is 1 — those bars are wide.
    @Test("The last plotted year is never labeled once labels are thinned")
    func lastPlottedYearIsNeverLabeledWhenThinning() {
        for years in pickerOptions where years > 6 {
            for currentYear in 2026...2045 {
                let lastPlottedYear = currentYear + years - 1
                let labeled = RMDCalculatorView.projectionAxisYears(
                    currentYear: currentYear,
                    projectionYears: years
                )
                #expect(
                    !labeled.contains(lastPlottedYear),
                    "currentYear \(currentYear), \(years)-year horizon labeled the final bar (\(lastPlottedYear)); its label would clip to an ellipsis"
                )
            }
        }
    }

    @Test("Dropping the final label never empties the axis")
    func droppingFinalLabelNeverEmptiesAxis() {
        for years in pickerOptions {
            for currentYear in 2026...2045 {
                #expect(
                    !RMDCalculatorView.projectionAxisYears(
                        currentYear: currentYear,
                        projectionYears: years
                    ).isEmpty,
                    "currentYear \(currentYear), \(years)-year horizon lost every label"
                )
            }
        }
    }

    // MARK: - Robustness

    @Test("Thinning holds for any starting year, not just 2026")
    func holdsForAnyStartingYear() {
        for currentYear in 2026...2045 {
            for years in pickerOptions {
                let labeled = RMDCalculatorView.projectionAxisYears(
                    currentYear: currentYear,
                    projectionYears: years
                )
                #expect(
                    !labeled.isEmpty,
                    "currentYear \(currentYear), \(years)-year horizon produced no labels"
                )
                #expect(
                    labeled.count <= 8,
                    "currentYear \(currentYear), \(years)-year horizon produced \(labeled.count) labels"
                )
            }
        }
    }

    @Test("Degenerate horizons produce no labels rather than crashing")
    func degenerateHorizons() {
        #expect(RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 0).isEmpty)
        #expect(RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: -5).isEmpty)
    }

    @Test("A single-year window still labels its one year")
    func singleYearWindow() {
        #expect(
            RMDCalculatorView.projectionAxisYears(currentYear: 2026, projectionYears: 1) == [2026]
        )
    }

    // MARK: - Label formatting matches the bars

    @Test("Axis label strings match the two-digit format the bars are keyed by")
    func labelFormatMatchesBarCategories() {
        #expect(RMDCalculatorView.chartYearLabel(2026) == "'26")
        #expect(RMDCalculatorView.chartYearLabel(2030) == "'30")
        #expect(RMDCalculatorView.chartYearLabel(2065) == "'65")
        #expect(RMDCalculatorView.chartYearLabel(2100) == "'00")
    }
}
