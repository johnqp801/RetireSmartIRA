//
//  PDFExportService.swift
//  RetireSmartIRA
//
//  Generates a comprehensive PDF tax summary for CPA sharing
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import WebKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Data Snapshot (thread-safe copy of DataManager state)

struct PDFExportData {
    // Personal
    let currentYear: Int
    let userName: String
    let spouseName: String
    let enableSpouse: Bool
    let currentAge: Int
    let spouseCurrentAge: Int
    let filingStatus: FilingStatus
    let selectedState: USState
    let isRMDRequired: Bool
    let spouseIsRMDRequired: Bool
    let rmdAge: Int
    let spouseRmdAge: Int
    let yearsUntilRMD: Int
    let isQCDEligible: Bool
    let spouseIsQCDEligible: Bool

    // Income
    let incomeSources: [IncomeSource]
    let scenarioBaseIncome: Double
    let scenarioGrossIncome: Double
    let estimatedAGI: Double

    // RMDs
    let primaryRMD: Double
    let spouseRMD: Double
    let inheritedIRARMDTotal: Double
    let scenarioCombinedRMD: Double
    let scenarioAdjustedRMD: Double

    // Scenario decisions
    let hasActiveScenario: Bool
    let yourRothConversion: Double
    let spouseRothConversion: Double
    let scenarioTotalRothConversion: Double
    let yourExtraWithdrawal: Double
    let spouseExtraWithdrawal: Double
    let scenarioTotalExtraWithdrawal: Double
    let yourQCDAmount: Double
    let spouseQCDAmount: Double
    let scenarioTotalQCD: Double
    let stockDonationEnabled: Bool
    let stockCurrentValue: Double
    let stockPurchasePrice: Double
    let scenarioStockIsLongTerm: Bool
    let scenarioStockGainAvoided: Double
    let cashDonationAmount: Double
    let scenarioTotalCharitable: Double

    // Deductions
    let standardDeductionAmount: Double
    let totalItemizedDeductions: Double
    let baseItemizedDeductions: Double
    let saltAfterCap: Double
    let totalSALTBeforeCap: Double
    let deductibleMedicalExpenses: Double
    let totalMedicalExpenses: Double
    let medicalAGIFloor: Double
    let scenarioCharitableDeductions: Double
    let scenarioEffectiveItemize: Bool
    let effectiveDeductionAmount: Double
    let deductionItems: [DeductionItem]

    // Tax
    let scenarioTaxableIncome: Double
    let scenarioFederalTax: Double
    let scenarioStateTax: Double
    let scenarioNIITAmount: Double
    let scenarioAMTAmount: Double
    let scenarioTotalTax: Double
    let federalMarginalRate: Double
    let federalAverageRate: Double
    let stateMarginalRate: Double
    let stateAverageRate: Double

    // Withholding
    let totalFederalWithholding: Double
    let totalStateWithholding: Double
    let totalWithholding: Double
    let scenarioRemainingFederalTax: Double
    let scenarioRemainingStateTax: Double
    let scenarioRemainingTax: Double

    // IRMAA
    let medicareMemberCount: Int
    let scenarioIRMAA: IRMAAResult
    let scenarioIRMAATotalSurcharge: Double

    // NIIT
    let scenarioNetInvestmentIncome: Double
    let scenarioNIIT: NIITResult

    // Quarterly
    let scenarioQuarterlyPayments: FederalStateQuarterlyBreakdown
    let quarterlyPayments: [QuarterlyPayment]

    // Safe harbor & state schedule
    let safeHarborMethod: SafeHarborMethod
    let priorYearSafeHarborAmount: Double
    let priorYearSafeHarborRate: Double
    let currentYearSafeHarborAmount: Double
    let stateEstimatedSchedule: EstimatedPaymentSchedule
    let selectedStateName: String
    let stateHasIncomeTax: Bool
    let estimatedStateSALTReminder: Double
    let autoEstimatedStatePayments: Double
    let requiresForm2210ScheduleAI: Bool
    let isStateDisqualifiedFromPriorYear: Bool
    let stateCurrentYearSafeHarborRate: Double

    // Accounts
    let iraAccounts: [IRAAccount]
    let primaryTraditionalIRABalance: Double
    let primaryRothBalance: Double
    let spouseTraditionalIRABalance: Double
    let spouseRothBalance: Double
    let totalInheritedBalance: Double

    // Action items
    let actionItems: [ActionItem]
    let completedActionKeys: Set<String>

    // Base case (pre-decision) tax computation
    let baseGrossIncome: Double
    let baseTaxableSS: Double
    let baseTaxableIncome: Double
    let baseFederalTax: Double
    let baseStateTax: Double
    let baseNIITAmount: Double
    let baseTotalTax: Double
    let baseFederalMarginalRate: Double
    let baseFederalAverageRate: Double
    let baseStateMarginalRate: Double
    let baseStateAverageRate: Double

    // Base case planning metrics — bracket headroom
    let baseBracketCurrentRate: Double
    let baseBracketRoomRemaining: Double
    let baseBracketNextThreshold: Double
    let baseBracketPlus1Rate: Double?       // rate of next bracket (nil if top)
    let baseBracketRoomToPlus2: Double?     // total room to 2 brackets up (nil if top or top−1)
    let baseBracketPlus2Rate: Double?       // rate 2 brackets up (nil if n/a)

    // Base case planning metrics — IRMAA
    let baseIRMAA: IRMAAResult
    let irmaaDistanceToTierPlus2: Double?

    // IRMAA tier savings
    let irmaaPreviousTierSurcharge: Double

    // Per-decision tax impacts
    let rothConversionTaxImpact: Double
    let rothConversionIRMAAImpact: Double
    let extraWithdrawalTaxImpact: Double
    let extraWithdrawalIRMAAImpact: Double
    let qcdTaxSavings: Double
    let qcdIRMAASavings: Double
    let stockDonationTaxSavings: Double
    let cashDonationTaxSavings: Double
    let inheritedExtraWithdrawalTaxImpact: Double
    let inheritedExtraWithdrawalIRMAAImpact: Double

    // Inherited IRA extra withdrawal amount
    let inheritedExtraWithdrawalTotal: Double

    init(from dm: DataManager) {
        currentYear = dm.currentYear
        userName = dm.userName
        spouseName = dm.spouseName
        enableSpouse = dm.enableSpouse
        currentAge = dm.currentAge
        spouseCurrentAge = dm.spouseCurrentAge
        filingStatus = dm.filingStatus
        selectedState = dm.selectedState
        isRMDRequired = dm.isRMDRequired
        spouseIsRMDRequired = dm.spouseIsRMDRequired
        rmdAge = dm.rmdAge
        spouseRmdAge = dm.spouseRmdAge
        yearsUntilRMD = dm.yearsUntilRMD
        isQCDEligible = dm.isQCDEligible
        spouseIsQCDEligible = dm.spouseIsQCDEligible

        incomeSources = dm.incomeSources
        scenarioBaseIncome = dm.scenarioBaseIncome
        scenarioGrossIncome = dm.scenarioGrossIncome
        estimatedAGI = dm.estimatedAGI

        primaryRMD = dm.calculatePrimaryRMD()
        spouseRMD = dm.calculateSpouseRMD()
        inheritedIRARMDTotal = dm.inheritedIRARMDTotal
        scenarioCombinedRMD = dm.scenarioCombinedRMD
        scenarioAdjustedRMD = dm.scenarioAdjustedRMD

        hasActiveScenario = dm.hasActiveScenario
        yourRothConversion = dm.yourRothConversion
        spouseRothConversion = dm.spouseRothConversion
        scenarioTotalRothConversion = dm.scenarioTotalRothConversion
        yourExtraWithdrawal = dm.yourExtraWithdrawal
        spouseExtraWithdrawal = dm.spouseExtraWithdrawal
        scenarioTotalExtraWithdrawal = dm.scenarioTotalExtraWithdrawal
        yourQCDAmount = dm.yourQCDAmount
        spouseQCDAmount = dm.spouseQCDAmount
        scenarioTotalQCD = dm.scenarioTotalQCD
        stockDonationEnabled = dm.stockDonationEnabled
        stockCurrentValue = dm.stockCurrentValue
        stockPurchasePrice = dm.stockPurchasePrice
        scenarioStockIsLongTerm = dm.scenarioStockIsLongTerm
        scenarioStockGainAvoided = dm.scenarioStockGainAvoided
        cashDonationAmount = dm.cashDonationAmount
        scenarioTotalCharitable = dm.scenarioTotalCharitable

        standardDeductionAmount = dm.standardDeductionAmount
        totalItemizedDeductions = dm.totalItemizedDeductions
        baseItemizedDeductions = dm.baseItemizedDeductions
        saltAfterCap = dm.saltAfterCap
        totalSALTBeforeCap = dm.totalSALTBeforeCap
        deductibleMedicalExpenses = dm.deductibleMedicalExpenses
        totalMedicalExpenses = dm.totalMedicalExpenses
        medicalAGIFloor = dm.medicalAGIFloor
        scenarioCharitableDeductions = dm.scenarioCharitableDeductions
        scenarioEffectiveItemize = dm.scenarioEffectiveItemize
        effectiveDeductionAmount = dm.effectiveDeductionAmount
        deductionItems = dm.deductionItems

        scenarioTaxableIncome = dm.scenarioTaxableIncome
        scenarioFederalTax = dm.scenarioFederalTax
        scenarioStateTax = dm.scenarioStateTax
        scenarioNIITAmount = dm.scenarioNIITAmount
        scenarioAMTAmount = dm.scenarioAMTAmount
        scenarioTotalTax = dm.scenarioTotalTax
        federalMarginalRate = dm.federalMarginalRate(income: dm.scenarioTaxableIncome, filingStatus: dm.filingStatus)
        federalAverageRate = dm.federalAverageRate(income: dm.scenarioTaxableIncome, filingStatus: dm.filingStatus)
        stateMarginalRate = dm.stateMarginalRate(income: dm.scenarioTaxableIncome, filingStatus: dm.filingStatus)
        stateAverageRate = dm.stateAverageRate(income: dm.scenarioTaxableIncome, filingStatus: dm.filingStatus)

        totalFederalWithholding = dm.totalFederalWithholding
        totalStateWithholding = dm.totalStateWithholding
        totalWithholding = dm.totalWithholding
        scenarioRemainingFederalTax = dm.scenarioRemainingFederalTax
        scenarioRemainingStateTax = dm.scenarioRemainingStateTax
        scenarioRemainingTax = dm.scenarioRemainingTax

        medicareMemberCount = dm.medicareMemberCount
        scenarioIRMAA = dm.scenarioIRMAA
        scenarioIRMAATotalSurcharge = dm.scenarioIRMAATotalSurcharge

        scenarioNetInvestmentIncome = dm.scenarioNetInvestmentIncome
        scenarioNIIT = dm.scenarioNIIT

        dm.syncQuarterlyPayments()
        scenarioQuarterlyPayments = dm.scenarioQuarterlyPayments
        quarterlyPayments = dm.quarterlyPayments

        safeHarborMethod = dm.safeHarborMethod
        priorYearSafeHarborAmount = dm.priorYearSafeHarborAmount
        priorYearSafeHarborRate = dm.priorYearSafeHarborRate
        currentYearSafeHarborAmount = dm.currentYearSafeHarborAmount
        stateEstimatedSchedule = dm.selectedStateConfig.estimatedPaymentSchedule
        selectedStateName = dm.selectedState.rawValue
        stateHasIncomeTax = dm.stateHasIncomeTax
        estimatedStateSALTReminder = dm.estimatedStateSALTReminder
        autoEstimatedStatePayments = dm.autoEstimatedStatePayments
        requiresForm2210ScheduleAI = dm.requiresForm2210ScheduleAI
        isStateDisqualifiedFromPriorYear = dm.isStateDisqualifiedFromPriorYear
        stateCurrentYearSafeHarborRate = dm.stateCurrentYearSafeHarborRate

        iraAccounts = dm.iraAccounts
        primaryTraditionalIRABalance = dm.primaryTraditionalIRABalance
        primaryRothBalance = dm.primaryRothBalance
        spouseTraditionalIRABalance = dm.spouseTraditionalIRABalance
        spouseRothBalance = dm.spouseRothBalance
        totalInheritedBalance = dm.totalInheritedBalance

        actionItems = dm.generatedActionItems
        completedActionKeys = dm.completedActionKeys

        // True base case tax computation (income sources + mandatory RMDs, no scenario decisions)
        let baseRMDTotal = dm.scenarioCombinedRMD  // primary + spouse + inherited (mandatory)
        baseTaxableSS = dm.calculateTaxableSocialSecurity(filingStatus: dm.filingStatus, additionalIncome: baseRMDTotal)
        let otherIncome = dm.incomeSources
            .filter { $0.type != .socialSecurity && $0.type != .capitalGainsLong && $0.type != .qualifiedDividends }
            .reduce(0) { $0 + $1.annualAmount }
        let capGains = dm.preferentialIncome()
        baseGrossIncome = otherIncome + baseTaxableSS + capGains + baseRMDTotal
        let baseDeduction = max(dm.standardDeductionAmount, dm.baseItemizedDeductions)
        baseTaxableIncome = max(0, baseGrossIncome - baseDeduction)

        baseFederalTax = dm.calculateFederalTax(income: baseTaxableIncome, filingStatus: dm.filingStatus)
        baseStateTax = dm.calculateStateTaxFromGross(
            grossIncome: baseGrossIncome,
            forState: dm.selectedState,
            filingStatus: dm.filingStatus,
            taxableSocialSecurity: baseTaxableSS)
        let baseNIITResult = dm.calculateNIIT(
            nii: dm.scenarioNetInvestmentIncome,
            magi: baseGrossIncome,
            filingStatus: dm.filingStatus)
        baseNIITAmount = baseNIITResult.annualNIITax
        baseTotalTax = baseFederalTax + baseStateTax + baseNIITAmount

        baseFederalMarginalRate = dm.federalMarginalRate(income: baseTaxableIncome, filingStatus: dm.filingStatus)
        baseFederalAverageRate = dm.federalAverageRate(income: baseTaxableIncome, filingStatus: dm.filingStatus)
        baseStateMarginalRate = dm.stateMarginalRate(income: baseTaxableIncome, filingStatus: dm.filingStatus)
        baseStateAverageRate = dm.stateAverageRate(income: baseTaxableIncome, filingStatus: dm.filingStatus)

        // Base case bracket headroom and IRMAA distances
        let baseBracket = dm.federalBracketInfo(income: baseTaxableIncome, filingStatus: dm.filingStatus)
        baseBracketCurrentRate = baseBracket.currentRate
        baseBracketRoomRemaining = baseBracket.roomRemaining
        baseBracketNextThreshold = baseBracket.nextThreshold

        // Next 2 bracket jumps (+1 needed because bracketInfo uses strict '>' comparison)
        if baseBracket.nextThreshold < Double.infinity {
            let nextBI = dm.federalBracketInfo(income: baseBracket.nextThreshold + 1, filingStatus: dm.filingStatus)
            baseBracketPlus1Rate = nextBI.currentRate
            if nextBI.nextThreshold < Double.infinity {
                // Room to top of next bracket = room in current + width of next bracket
                baseBracketRoomToPlus2 = baseBracket.roomRemaining + (nextBI.nextThreshold - baseBracket.nextThreshold)
                let plus2BI = dm.federalBracketInfo(income: nextBI.nextThreshold + 1, filingStatus: dm.filingStatus)
                baseBracketPlus2Rate = plus2BI.currentRate
            } else {
                baseBracketRoomToPlus2 = nil
                baseBracketPlus2Rate = nil
            }
        } else {
            baseBracketPlus1Rate = nil
            baseBracketRoomToPlus2 = nil
            baseBracketPlus2Rate = nil
        }

        let baseIRMAAResult = dm.calculateIRMAA(magi: baseGrossIncome, filingStatus: dm.filingStatus)
        baseIRMAA = baseIRMAAResult
        let tiers = DataManager.irmaa2026Tiers
        let baseTier = baseIRMAAResult.tier
        if baseTier + 2 < tiers.count {
            let threshold = dm.filingStatus == .single
                ? tiers[baseTier + 2].singleThreshold
                : tiers[baseTier + 2].mfjThreshold
            irmaaDistanceToTierPlus2 = threshold - baseGrossIncome
        } else {
            irmaaDistanceToTierPlus2 = nil
        }

        irmaaPreviousTierSurcharge = dm.scenarioIRMAAPreviousTierAnnualSurcharge

        // Per-decision tax impacts
        rothConversionTaxImpact = dm.rothConversionTaxImpact
        rothConversionIRMAAImpact = dm.rothConversionIRMAAImpact
        extraWithdrawalTaxImpact = dm.extraWithdrawalTaxImpact
        extraWithdrawalIRMAAImpact = dm.extraWithdrawalIRMAAImpact
        qcdTaxSavings = dm.qcdTaxSavings
        qcdIRMAASavings = dm.qcdIRMAASavings
        stockDonationTaxSavings = dm.stockDonationTaxSavings
        cashDonationTaxSavings = dm.cashDonationTaxSavings
        inheritedExtraWithdrawalTaxImpact = dm.inheritedExtraWithdrawalTaxImpact
        inheritedExtraWithdrawalIRMAAImpact = dm.inheritedExtraWithdrawalIRMAAImpact

        inheritedExtraWithdrawalTotal = dm.inheritedExtraWithdrawalTotal
    }
}

// MARK: - PDF Export Service

struct PDFExportService {

    #if canImport(UIKit)
    /// Retained during async PDF generation (one at a time, enforced by @MainActor).
    private static var retainedRenderer: WebViewPDFRenderer?
    #endif

    @MainActor
    static func generatePDF(from data: PDFExportData) async -> Data {
        let html = buildHTML(from: data)

        #if canImport(UIKit)
        // iOS: WKWebView + viewPrintFormatter (properly respects CSS page-break rules)
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            let renderer = WebViewPDFRenderer { pdfData in
                continuation.resume(returning: pdfData)
            }
            retainedRenderer = renderer
            renderer.load(html: html)
        }
        retainedRenderer = nil
        return result

        #elseif canImport(AppKit)
        // macOS: Synchronous NSAttributedString + NSLayoutManager renderer.
        // WKWebView's NSPrintOperation crashes on macOS (EXC_BAD_ACCESS during
        // cleanup), so we convert HTML → attributed string and paginate manually
        // with section-aware page breaks.
        return renderWithAppKit(html)
        #endif
    }

    // MARK: - macOS: NSAttributedString + NSLayoutManager PDF Renderer

    #if canImport(AppKit)
    /// Renders HTML to a multi-page PDF using NSAttributedString + NSLayoutManager.
    /// This avoids WKWebView's problematic NSPrintOperation on macOS while producing
    /// properly paginated output with section-aware page breaks at "Section 2" and
    /// "Section 3" boundaries.
    private static func renderWithAppKit(_ html: String) -> Data {
        guard let htmlData = html.data(using: .utf8) else { return Data() }

        // Parse HTML → attributed string (uses macOS WebKit1 HTML importer)
        guard let attrStr = try? NSAttributedString(
            data: htmlData,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) else { return Data() }

        // Page geometry (US Letter with 0.75" margins)
        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let margin: CGFloat = 54
        let contentW = pageW - 2 * margin
        let contentH = pageH - 2 * margin

        // ── Text System Setup ──
        let storage = NSTextStorage(attributedString: attrStr)
        let lm = NSLayoutManager()
        storage.addLayoutManager(lm)

        let tc = NSTextContainer(size: NSSize(width: contentW, height: .greatestFiniteMagnitude))
        tc.lineFragmentPadding = 0
        lm.addTextContainer(tc)
        lm.ensureLayout(for: tc)

        let totalHeight = lm.usedRect(for: tc).height
        guard totalHeight > 0 else { return Data() }

        // ── Locate Section Break Markers ──
        // Search for invisible "PAGEBRK" markers inserted by buildHTML() before each
        // section boundary. These unique markers avoid false matches against the
        // introduction text (which also mentions "Section 2" and "Section 3").
        let fullText = storage.string as NSString
        var forcedBreakYs: [CGFloat] = []
        for marker in ["PAGEBRK"] {
            var search = NSRange(location: 0, length: fullText.length)
            while search.location < fullText.length {
                let hit = fullText.range(of: marker, options: [], range: search)
                guard hit.location != NSNotFound else { break }
                let glyphs = lm.glyphRange(forCharacterRange: hit, actualCharacterRange: nil)
                if glyphs.location != NSNotFound && glyphs.location < lm.numberOfGlyphs {
                    let lineRect = lm.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
                    forcedBreakYs.append(lineRect.origin.y)
                }
                search = NSRange(location: hit.location + hit.length,
                                 length: fullText.length - hit.location - hit.length)
            }
        }
        forcedBreakYs.sort()

        // ── Build Page Ranges ──
        var pages: [(startY: CGFloat, endY: CGFloat)] = []
        var cursor: CGFloat = 0
        var breakIdx = 0

        while cursor < totalHeight {
            var bottom = cursor + contentH

            // Advance past any forced breaks that are at or before the cursor
            while breakIdx < forcedBreakYs.count && forcedBreakYs[breakIdx] <= cursor {
                breakIdx += 1
            }
            // If a forced break falls within this page, end the page just before it
            if breakIdx < forcedBreakYs.count {
                let breakY = forcedBreakYs[breakIdx]
                if breakY > cursor && breakY < bottom {
                    bottom = breakY
                    breakIdx += 1
                }
            }

            // Snap to last complete line boundary (never clip text mid-line)
            bottom = min(bottom, totalHeight)
            if bottom < totalHeight {
                bottom = lastLineBreakBefore(bottom, from: cursor, layoutManager: lm, container: tc)
            }

            // Safety: ensure forward progress
            if bottom <= cursor {
                bottom = min(cursor + contentH, totalHeight)
            }

            pages.append((cursor, bottom))
            cursor = bottom
        }

        // ── Render Pages into PDF ──
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        for (startY, endY) in pages {
            let sliceH = endY - startY
            guard sliceH > 0 else { continue }

            ctx.beginPDFPage(nil)
            ctx.saveGState()

            // Coordinate transform: PDF origin is bottom-left; text system is top-left.
            ctx.translateBy(x: margin, y: pageH - margin)
            ctx.scaleBy(x: 1, y: -1)

            // Clip to this page's content area
            ctx.clip(to: CGRect(x: 0, y: 0, width: contentW, height: sliceH))

            // Translate so startY maps to y=0 (top of page)
            ctx.translateBy(x: 0, y: -startY)

            // Push graphics context so NSLayoutManager draws into our CGContext
            #if canImport(UIKit)
            UIGraphicsPushContext(ctx)
            #else
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            #endif

            let visibleRect = NSRect(x: 0, y: startY, width: contentW, height: sliceH)
            let glyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
            if glyphRange.length > 0 {
                lm.drawBackground(forGlyphRange: glyphRange, at: .zero)
                lm.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
            }

            #if canImport(UIKit)
            UIGraphicsPopContext()
            #else
            NSGraphicsContext.restoreGraphicsState()
            #endif
            ctx.restoreGState()
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return pdfData as Data
    }

    /// Returns the y-coordinate of the bottom of the last complete line that fits
    /// at or before `targetY`, starting the search from `startY`. This ensures
    /// page breaks fall between lines, never clipping text mid-glyph.
    private static func lastLineBreakBefore(
        _ targetY: CGFloat,
        from startY: CGFloat,
        layoutManager lm: NSLayoutManager,
        container tc: NSTextContainer
    ) -> CGFloat {
        guard lm.numberOfGlyphs > 0 else { return targetY }

        var glyphIdx = lm.glyphIndex(for: NSPoint(x: 0, y: startY + 1), in: tc)
        var lastGoodBottom = startY

        while glyphIdx < lm.numberOfGlyphs {
            var lineRange = NSRange()
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: &lineRange)

            if lineRect.maxY > targetY {
                // This line would exceed the page — break before it
                return max(lastGoodBottom, lineRect.origin.y)
            }

            lastGoodBottom = lineRect.maxY
            glyphIdx = NSMaxRange(lineRange)
        }

        return lastGoodBottom
    }
    #endif

    // MARK: - Formatting Helpers

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f
    }()

    private static func fmt(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private static func fmtPct(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private static func esc(_ str: String) -> String {
        str.replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - HTML Construction

    private static func buildHTML(from d: PDFExportData) -> String {
        var h = htmlHeader(taxYear: d.currentYear)

        // ── Lead with the Bottom Line ──
        h += sectionHeroSummary(d)
        h += sectionTaxBar(d)

        // ── Your Situation ──
        h += sectionPersonalInfo(d)
        h += sectionIncomeSources(d)    // includes RMDs as rows
        h += sectionDeductions(d)

        // ── Tax Calculation (side-by-side if scenario, single if not) ──
        h += sectionTaxComparison(d)

        if d.hasActiveScenario {
            // ── Scenario Details ──
            h += sectionScenarioDecisions(d)
            h += sectionPerDecisionImpact(d)
        }

        // ── What You Owe (withholding + remaining + quarterly) ──
        h += sectionWhatYouOwe(d)

        // ── Planning Insights (simplified callout boxes) ──
        h += sectionPlanningInsights(d)
        h += sectionNIIT(d)
        h += sectionIRMAA(d)

        // ── Appendix (accounts + action items on own page) ──
        h += sectionAppendix(d)

        h += htmlFooter()
        return h
    }

    // MARK: - HTML Header & Footer

    private static func htmlHeader(taxYear: Int) -> String {
        let dateStr = Date().formatted(date: .long, time: .omitted)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <style>
            body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 11px; color: #333; line-height: 1.4; margin: 0; padding: 0; }
            h1 { font-size: 18px; color: #1a1a2e; border-bottom: 2px solid #2563eb; padding-bottom: 6px; margin: 0 0 4px 0; }
            h2 { font-size: 13px; color: #1e40af; margin: 18px 0 8px 0; border-bottom: 1px solid #ddd; padding-bottom: 4px; page-break-after: avoid; break-after: avoid; }
            table { width: 100%; border-collapse: collapse; margin: 6px 0 12px 0; }
            th { background: #f1f5f9; font-weight: 600; padding: 5px 8px; text-align: left; border-bottom: 2px solid #cbd5e1; font-size: 10px; }
            td { padding: 4px 8px; border-bottom: 1px solid #e2e8f0; font-size: 11px; }
            tr:nth-child(even) { background: #f8fafc; }
            tr { page-break-inside: avoid; break-inside: avoid; }
            .amt { text-align: right; font-variant-numeric: tabular-nums; }
            .total td { font-weight: bold; border-top: 2px solid #334155; background: #f1f5f9; }
            .red { color: #dc2626; }
            .green { color: #16a34a; }
            .orange { color: #ea580c; }
            .blue { color: #2563eb; }
            .purple { color: #7c3aed; }
            .muted { color: #6b7280; font-size: 10px; }
            .kv { margin: 4px 0; page-break-inside: avoid; break-inside: avoid; }
            .kv td:first-child { color: #6b7280; width: 55%; }
            .kv td:last-child { text-align: right; font-weight: 600; }
            .disclaimer { font-size: 9px; color: #9ca3af; margin-top: 24px; border-top: 1px solid #e5e7eb; padding-top: 8px; }
            .check { color: #16a34a; } .uncheck { color: #9ca3af; }
            .page-break { page-break-after: always; break-after: page; }
            .section-start { page-break-before: always; break-before: page; }
            .impact-pos { color: #dc2626; } .impact-neg { color: #16a34a; } .impact-net td { font-weight: bold; border-top: 2px solid #334155; background: #f1f5f9; }
            .impact-cost td { background: #fef2f2; }
            .impact-save td { background: #f0fdf4; }
            .hero { text-align: center; margin: 12px 0 16px 0; padding: 14px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; page-break-inside: avoid; break-inside: avoid; }
            .hero-amount { font-size: 22px; font-weight: 700; color: #dc2626; margin: 4px 0; }
            .hero-label { font-size: 11px; color: #6b7280; margin: 2px 0; }
            .hero-delta { font-size: 13px; font-weight: 600; margin: 6px 0 0 0; }
            .tax-bar-container { margin: 8px 0 16px 0; page-break-inside: avoid; break-inside: avoid; }
            .tax-bar { display: flex; height: 24px; border-radius: 4px; overflow: hidden; margin: 4px 0; }
            .tax-bar-seg { display: flex; align-items: center; justify-content: center; color: white; font-size: 9px; font-weight: 600; min-width: 2px; }
            .tax-bar-legend { display: flex; gap: 14px; margin-top: 6px; font-size: 9px; color: #6b7280; }
            .tax-bar-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; margin-right: 3px; vertical-align: middle; }
            .callout { padding: 10px 14px; margin: 6px 0; border-radius: 6px; font-size: 10.5px; line-height: 1.5; page-break-inside: avoid; break-inside: avoid; }
            .callout-green { background: #f0fdf4; border-left: 3px solid #16a34a; }
            .callout-blue { background: #eff6ff; border-left: 3px solid #2563eb; }
            .callout-orange { background: #fff7ed; border-left: 3px solid #ea580c; }
            .callout strong { font-weight: 600; }
            .compare th { text-align: right; width: 25%; }
            .compare th:first-child { text-align: left; width: 50%; }
            .compare td.amt { width: 25%; }
        </style>
        </head><body>
        <div style="text-align:center; margin-bottom:16px;">
            <h1>Tax Planning Summary</h1>
            <p class="muted">RetireSmart IRA &bull; \(taxYear) Tax Year &bull; Prepared \(dateStr)</p>
        </div>
        """
    }

    private static func htmlFooter() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return """
        <div class="disclaimer">
            <p>This document provides estimates for planning purposes only. Local and city income taxes
            (e.g. NYC, Yonkers) are not included. Consult with a qualified tax professional or financial
            advisor for personalized advice. Tax laws and regulations may change.</p>
            <p>Generated by RetireSmart IRA v\(version)</p>
        </div>
        </body></html>
        """
    }

    // MARK: - Section: Hero Summary (Bottom Line)

    private static func sectionHeroSummary(_ d: PDFExportData) -> String {
        if d.hasActiveScenario {
            let delta = d.scenarioTotalTax - d.baseTotalTax
            let deltaCls = delta >= 0 ? "red" : "green"
            let deltaSign = delta >= 0 ? "+" : "−"
            return """
            <div class="hero">
                <p class="hero-label">Estimated Total Tax</p>
                <p class="hero-amount">\(fmt(d.scenarioTotalTax))</p>
                <p class="hero-delta" style="color: #6b7280;">Base: \(fmt(d.baseTotalTax)) → After Scenario: \(fmt(d.scenarioTotalTax))
                    <span class="\(deltaCls)">(\(deltaSign)\(fmt(abs(delta))))</span></p>
            </div>
            """
        } else {
            return """
            <div class="hero">
                <p class="hero-label">Estimated Total Tax</p>
                <p class="hero-amount">\(fmt(d.scenarioTotalTax))</p>
                <p class="hero-label">\(d.filingStatus.rawValue) · \(d.selectedState.rawValue)</p>
            </div>
            """
        }
    }

    // MARK: - Section: Visual Tax Bar

    private static func sectionTaxBar(_ d: PDFExportData) -> String {
        // Use scenario values (which equal base values when no scenario is active)
        let fed = d.scenarioFederalTax
        let state = d.scenarioStateTax
        let niit = d.scenarioNIITAmount
        let amt = d.scenarioAMTAmount
        let total = d.scenarioTotalTax
        guard total > 0 else { return "" }

        // Build segments: (label, amount, color)
        var segments: [(String, Double, String)] = []
        if fed > 0 { segments.append(("Federal", fed, "#2563eb")) }
        if state > 0 { segments.append(("State", state, "#0891b2")) }
        if niit > 0 { segments.append(("NIIT", niit, "#ea580c")) }
        if amt > 0 { segments.append(("AMT", amt, "#7c3aed")) }

        var bars = ""
        for (label, amount, color) in segments {
            let pct = (amount / total) * 100
            let displayLabel = pct > 12 ? "\(label) \(fmt(amount))" : (pct > 6 ? fmt(amount) : "")
            bars += "<div class=\"tax-bar-seg\" style=\"width:\(String(format: "%.1f", pct))%;background:\(color);\">\(displayLabel)</div>"
        }

        var legend = ""
        for (label, amount, color) in segments {
            legend += "<span><span class=\"tax-bar-dot\" style=\"background:\(color);\"></span>\(label): \(fmt(amount))</span>"
        }

        return """
        <div class="tax-bar-container">
            <div class="tax-bar">\(bars)</div>
            <div class="tax-bar-legend">\(legend)</div>
        </div>
        """
    }

    // MARK: - Section: Tax Comparison (merged base + scenario + rates)

    private static func sectionTaxComparison(_ d: PDFExportData) -> String {
        if d.hasActiveScenario {
            // ── Side-by-side comparison table ──
            let baseDeduction = max(d.standardDeductionAmount, d.baseItemizedDeductions)


            func compareRow(_ label: String, _ baseVal: String, _ scenVal: String, cls: String = "") -> String {
                let valCls = cls.isEmpty ? "amt" : "amt \(cls)"
                return "<tr><td>\(label)</td><td class=\"\(valCls)\">\(baseVal)</td><td class=\"\(valCls)\">\(scenVal)</td></tr>"
            }

            var rows = ""
            rows += "<tr><th></th><th class=\"amt\">Base Case</th><th class=\"amt\">After Scenario</th></tr>"
            rows += compareRow("Gross Income", fmt(d.baseGrossIncome), fmt(d.scenarioGrossIncome))
            rows += compareRow("Less: Deduction", "−\(fmt(baseDeduction))", "−\(fmt(d.effectiveDeductionAmount))")
            rows += "<tr class=\"total\"><td>Taxable Income</td><td class=\"amt\">\(fmt(d.baseTaxableIncome))</td><td class=\"amt\">\(fmt(d.scenarioTaxableIncome))</td></tr>"
            rows += compareRow("Federal Tax", fmt(d.baseFederalTax), fmt(d.scenarioFederalTax), cls: "red")
            rows += compareRow("State Tax (\(d.selectedState.abbreviation))", fmt(d.baseStateTax), fmt(d.scenarioStateTax), cls: "red")
            if d.baseNIITAmount > 0 || d.scenarioNIITAmount > 0 {
                rows += compareRow("NIIT (3.8%)", d.baseNIITAmount > 0 ? fmt(d.baseNIITAmount) : "—", d.scenarioNIITAmount > 0 ? fmt(d.scenarioNIITAmount) : "—", cls: "red")
            }
            if d.scenarioAMTAmount > 0 {
                rows += compareRow("AMT", "—", fmt(d.scenarioAMTAmount), cls: "red")
            }
            rows += "<tr class=\"total\"><td class=\"red\">Total Tax</td><td class=\"amt red\">\(fmt(d.baseTotalTax))</td><td class=\"amt red\">\(fmt(d.scenarioTotalTax))</td></tr>"

            // Delta row
            let delta = d.scenarioTotalTax - d.baseTotalTax
            let deltaCls = delta >= 0 ? "red" : "green"
            let deltaSign = delta >= 0 ? "+" : "−"
            rows += "<tr><td class=\"muted\">Change</td><td></td><td class=\"amt \(deltaCls)\">\(deltaSign)\(fmt(abs(delta)))</td></tr>"

            // Tax rates merged in
            rows += "<tr style=\"border-top:1px solid #cbd5e1;\"><td class=\"muted\">Federal Marginal Rate</td><td class=\"amt\">\(fmtPct(d.baseFederalMarginalRate))</td><td class=\"amt\">\(fmtPct(d.federalMarginalRate))</td></tr>"
            rows += "<tr><td class=\"muted\">Federal Average Rate</td><td class=\"amt\">\(fmtPct(d.baseFederalAverageRate))</td><td class=\"amt\">\(fmtPct(d.federalAverageRate))</td></tr>"
            rows += "<tr><td class=\"muted\">State Marginal Rate</td><td class=\"amt\">\(fmtPct(d.baseStateMarginalRate))</td><td class=\"amt\">\(fmtPct(d.stateMarginalRate))</td></tr>"
            rows += "<tr><td class=\"muted\">State Average Rate</td><td class=\"amt\">\(fmtPct(d.baseStateAverageRate))</td><td class=\"amt\">\(fmtPct(d.stateAverageRate))</td></tr>"

            return "<h2>Tax Comparison</h2><table class=\"compare\">\(rows)</table>"
        } else {
            // ── Single-column summary (no scenario) ──
            var rows = ""
            rows += kvRow("Gross Income", fmt(d.scenarioGrossIncome))
            rows += kvRow("Less: Deduction (\(d.scenarioEffectiveItemize ? "Itemized" : "Standard"))", "−\(fmt(d.effectiveDeductionAmount))")
            rows += "<tr class=\"total\"><td>Taxable Income</td><td class=\"amt\">\(fmt(d.scenarioTaxableIncome))</td></tr>"
            rows += kvRow("Federal Income Tax", fmt(d.scenarioFederalTax), cls: "red")
            rows += kvRow("State Income Tax (\(d.selectedState.abbreviation))", fmt(d.scenarioStateTax), cls: "red")
            if d.scenarioNIITAmount > 0 {
                rows += kvRow("NIIT (3.8% Surtax)", fmt(d.scenarioNIITAmount), cls: "red")
            }
            if d.scenarioAMTAmount > 0 {
                rows += kvRow("AMT (26%/28%)", fmt(d.scenarioAMTAmount), cls: "red")
            }
            rows += "<tr class=\"total\"><td class=\"red\">Total Tax</td><td class=\"amt red\">\(fmt(d.scenarioTotalTax))</td></tr>"

            // Tax rates merged in
            rows += "<tr style=\"border-top:1px solid #cbd5e1;\"><td class=\"muted\">Federal Marginal / Average Rate</td><td class=\"amt\">\(fmtPct(d.federalMarginalRate)) / \(fmtPct(d.federalAverageRate))</td></tr>"
            rows += "<tr><td class=\"muted\">State Marginal / Average Rate</td><td class=\"amt\">\(fmtPct(d.stateMarginalRate)) / \(fmtPct(d.stateAverageRate))</td></tr>"

            return "<h2>Tax Summary</h2><table class=\"kv\">\(rows)</table>"
        }
    }

    // MARK: - Section: Planning Insights (simplified callout boxes)

    private static func sectionPlanningInsights(_ d: PDFExportData) -> String {
        var html = "<h2>Planning Insights</h2>"

        // Bracket room callout
        let rateStr = String(format: "%.0f%%", d.baseBracketCurrentRate * 100)
        if d.baseBracketRoomRemaining > 0 {
            let plus1Str = d.baseBracketPlus1Rate.map { String(format: "%.0f%%", $0 * 100) } ?? "higher"
            html += """
            <div class="callout callout-green">
                <strong>Bracket Room:</strong> You have \(fmt(d.baseBracketRoomRemaining)) of room in the \(rateStr) bracket before crossing into \(plus1Str). This is the capacity for Roth conversions or extra withdrawals at the current marginal rate.
            </div>
            """
        } else {
            html += """
            <div class="callout callout-orange">
                <strong>Top Bracket:</strong> You are in the top \(rateStr) federal bracket. All additional income is taxed at this rate.
            </div>
            """
        }

        // IRMAA callout (only if Medicare eligible)
        if d.medicareMemberCount > 0 {
            if d.baseIRMAA.tier == 0, let distNext = d.baseIRMAA.distanceToNextTier {
                html += """
                <div class="callout callout-blue">
                    <strong>IRMAA:</strong> You are \(fmt(distNext)) below the next Medicare premium tier (Tier 1). No IRMAA surcharge applies at current income.
                </div>
                """
            } else if d.baseIRMAA.tier > 0 {
                var msg = "<strong>IRMAA Tier \(d.baseIRMAA.tier):</strong> "
                if let distPrev = d.baseIRMAA.distanceToPreviousTier {
                    msg += "You are \(fmt(distPrev)) above the current tier threshold. "
                    let savings = d.baseIRMAA.annualSurchargePerPerson - d.irmaaPreviousTierSurcharge
                    if savings > 0 {
                        let totalSavings = savings * Double(d.medicareMemberCount)
                        msg += "Dropping below would save \(fmt(totalSavings))/year in premiums."
                    }
                }
                html += "<div class=\"callout callout-orange\">\(msg)</div>"
            }
        }

        // SALT auto-inclusion confirmation
        if d.stateHasIncomeTax && d.autoEstimatedStatePayments > 0 {
            html += """
            <div class="callout callout-blue">
                <strong>Smart SALT:</strong> Your estimated state tax payments (\(fmt(d.autoEstimatedStatePayments))) have been automatically included in your SALT deduction. This amount is calculated from your state tax liability after withholding credits and updates as your income and scenario decisions change.
            </div>
            """
        }

        // Form 2210 warning: annualized income method
        if d.requiresForm2210ScheduleAI {
            html += """
            <div class="callout callout-orange">
                <strong>Form 2210 Required:</strong> Your estimated payments are allocated by quarter based on when income events occur (annualized income installment method). This requires filing IRS Form 2210, Schedule AI to justify uneven payments and avoid underpayment penalties. Note: This may incur additional tax preparation fees.
            </div>
            """
        }

        // Safe harbor comparison (neutral — no recommendation)
        let currentYearAmt = d.currentYearSafeHarborAmount
        let priorYearAmt = d.priorYearSafeHarborAmount
        if priorYearAmt > 0 || d.isStateDisqualifiedFromPriorYear {
            let fedRateLabel = d.priorYearSafeHarborRate > 1.0 ? "110%" : "100%"
            let stateRateStr = d.stateCurrentYearSafeHarborRate != 0.90
                ? String(format: " (state uses %.0f%%)", d.stateCurrentYearSafeHarborRate * 100)
                : ""
            var body = "<strong>Safe Harbor Comparison:</strong><br>"
            body += "<strong>Current Year:</strong> \(fmt(currentYearAmt))\(stateRateStr) — May result in lower payments if current-year tax is less than prior year. Risk: if income is higher than estimated, you may underpay and owe penalties.<br>"
            if d.isStateDisqualifiedFromPriorYear {
                body += "<strong>\(fedRateLabel) of Prior Year:</strong> \(fmt(priorYearAmt)) (federal only) — \(d.selectedStateName) does not allow prior-year safe harbor at your income level. State payments use current-year method.<br>"
            } else if priorYearAmt > 0 {
                body += "<strong>\(fedRateLabel) of Prior Year:</strong> \(fmt(priorYearAmt)) — Guaranteed penalty-free regardless of current-year income. Risk: may overpay if current-year tax is significantly lower; overpayment is refunded but cash is tied up.<br>"
            }
            body += "<em>Currently using: \(d.safeHarborMethod.label)</em>"
            html += "<div class=\"callout callout-blue\">\(body)</div>"
        }

        return html
    }

    // MARK: - Section: Per-Decision Impact (Page 2)

    private static func sectionPerDecisionImpact(_ d: PDFExportData) -> String {
        guard d.hasActiveScenario else { return "" }

        let showIRMAA = d.medicareMemberCount > 0
        var header = "<tr><th>Action</th><th class=\"amt\">Amount</th><th class=\"amt\">Tax Impact</th>"
        if showIRMAA { header += "<th class=\"amt\">IRMAA Impact</th>" }
        header += "</tr>"

        var rows = ""
        var netTax = 0.0
        var netIRMAA = 0.0

        // Helper to add an impact row with background tint
        func addRow(_ label: String, amount: Double, tax: Double, irmaa: Double, taxCls: String, irmaaCls: String) {
            let rowCls = taxCls == "impact-neg" ? "impact-save" : "impact-cost"
            rows += "<tr class=\"\(rowCls)\"><td>\(label)</td><td class=\"amt\">\(fmt(amount))</td>"
            rows += "<td class=\"amt \(taxCls)\">\(taxCls == "impact-neg" ? "−" : "+")\(fmt(abs(tax)))</td>"
            if showIRMAA {
                if abs(irmaa) < 1 {
                    rows += "<td class=\"amt muted\">—</td>"
                } else {
                    rows += "<td class=\"amt \(irmaaCls)\">\(irmaaCls == "impact-neg" ? "−" : "+")\(fmt(abs(irmaa)))</td>"
                }
            }
            rows += "</tr>"
            netTax += (taxCls == "impact-neg" ? -abs(tax) : abs(tax))
            netIRMAA += (irmaaCls == "impact-neg" ? -abs(irmaa) : abs(irmaa))
        }

        // Roth conversions
        if d.scenarioTotalRothConversion > 0 {
            addRow("Roth Conversion", amount: d.scenarioTotalRothConversion,
                   tax: d.rothConversionTaxImpact, irmaa: d.rothConversionIRMAAImpact,
                   taxCls: "impact-pos", irmaaCls: "impact-pos")
        }

        // Extra withdrawals
        if d.scenarioTotalExtraWithdrawal > 0 {
            addRow("Extra IRA Withdrawals", amount: d.scenarioTotalExtraWithdrawal,
                   tax: d.extraWithdrawalTaxImpact, irmaa: d.extraWithdrawalIRMAAImpact,
                   taxCls: "impact-pos", irmaaCls: "impact-pos")
        }

        // Inherited IRA extra withdrawals
        if d.inheritedExtraWithdrawalTotal > 0 {
            addRow("Inherited IRA Extra Withdrawal", amount: d.inheritedExtraWithdrawalTotal,
                   tax: d.inheritedExtraWithdrawalTaxImpact, irmaa: d.inheritedExtraWithdrawalIRMAAImpact,
                   taxCls: "impact-pos", irmaaCls: "impact-pos")
        }

        // QCDs
        if d.scenarioTotalQCD > 0 {
            addRow("Qualified Charitable Distribution", amount: d.scenarioTotalQCD,
                   tax: d.qcdTaxSavings, irmaa: d.qcdIRMAASavings,
                   taxCls: "impact-neg", irmaaCls: "impact-neg")
        }

        // Stock donation
        if d.stockDonationEnabled && d.stockCurrentValue > 0 {
            addRow("Appreciated Stock Donation", amount: d.stockCurrentValue,
                   tax: d.stockDonationTaxSavings, irmaa: 0,
                   taxCls: "impact-neg", irmaaCls: "impact-neg")
        }

        // Cash donation
        if d.cashDonationAmount > 0 {
            addRow("Cash Charitable Donation", amount: d.cashDonationAmount,
                   tax: d.cashDonationTaxSavings, irmaa: 0,
                   taxCls: "impact-neg", irmaaCls: "impact-neg")
        }

        // Net collective impact
        let netTaxCls = netTax >= 0 ? "impact-pos" : "impact-neg"
        var netRow = "<tr class=\"impact-net\"><td>Net Collective Impact</td><td class=\"amt\"></td>"
        netRow += "<td class=\"amt \(netTaxCls)\">\(netTax >= 0 ? "+" : "−")\(fmt(abs(netTax)))</td>"
        if showIRMAA {
            let netIRMAACls = netIRMAA >= 0 ? "impact-pos" : "impact-neg"
            netRow += "<td class=\"amt \(netIRMAACls)\">\(netIRMAA >= 0 ? "+" : "−")\(fmt(abs(netIRMAA)))</td>"
        }
        netRow += "</tr>"
        rows += netRow

        return "<h2>Per-Decision Tax &amp; IRMAA Impact</h2><table>\(header)\(rows)</table><p class=\"muted\">Individual impacts are marginal (computed one at a time). The net collective row sums these; actual collective impact may differ slightly due to bracket interactions.</p>"
    }

    // MARK: - Section: Personal Information

    private static func sectionPersonalInfo(_ d: PDFExportData) -> String {
        let primary = d.userName.isEmpty ? "Primary" : esc(d.userName)
        var rows = """
        <tr><td>Filing Status</td><td>\(d.filingStatus.rawValue)</td></tr>
        <tr><td>State of Residence</td><td>\(d.selectedState.rawValue)</td></tr>
        <tr><td>\(primary) Age</td><td>\(d.currentAge)</td></tr>
        """
        if d.enableSpouse {
            let sp = d.spouseName.isEmpty ? "Spouse" : esc(d.spouseName)
            rows += "<tr><td>\(sp) Age</td><td>\(d.spouseCurrentAge)</td></tr>"
        }
        if d.isRMDRequired {
            rows += "<tr><td>RMD Status</td><td class=\"red\">Required</td></tr>"
        } else {
            rows += "<tr><td>RMD Begins</td><td>Age \(d.rmdAge) (\(d.yearsUntilRMD) years)</td></tr>"
        }
        return """
        <h2>Personal Information</h2>
        <table class="kv">\(rows)</table>
        """
    }

    // MARK: - Section: Income Sources (simplified, with RMDs folded in)

    private static func sectionIncomeSources(_ d: PDFExportData) -> String {
        let hasIncome = !d.incomeSources.isEmpty
        let totalRMD = d.primaryRMD + d.spouseRMD + d.inheritedIRARMDTotal
        guard hasIncome || totalRMD > 0 else {
            return "<h2>Income Sources</h2><p class=\"muted\">No income sources entered.</p>"
        }
        let showOwner = d.enableSpouse
        var header = "<tr><th>Source</th>"
        if showOwner { header += "<th>Owner</th>" }
        header += "<th class=\"amt\">Amount</th></tr>"

        var rows = ""
        var totalAmt = 0.0
        for s in d.incomeSources {
            rows += "<tr><td>\(esc(s.name))</td>"
            if showOwner { rows += "<td>\(s.owner.rawValue)</td>" }
            rows += "<td class=\"amt\">\(fmt(s.annualAmount))</td></tr>"
            totalAmt += s.annualAmount
        }

        // Fold RMDs into income table
        let primary = d.userName.isEmpty ? "Your" : esc(d.userName) + "'s"
        if d.primaryRMD > 0 {
            let rmdLabel = d.enableSpouse ? "\(primary) RMD" : "Required Minimum Distribution"
            rows += "<tr><td>\(rmdLabel)</td>"
            if showOwner { rows += "<td>Primary</td>" }
            rows += "<td class=\"amt red\">\(fmt(d.primaryRMD))</td></tr>"
            totalAmt += d.primaryRMD
        }
        if d.enableSpouse && d.spouseRMD > 0 {
            let sp = d.spouseName.isEmpty ? "Spouse" : esc(d.spouseName)
            rows += "<tr><td>\(sp)'s RMD</td>"
            if showOwner { rows += "<td>\(sp)</td>" }
            rows += "<td class=\"amt red\">\(fmt(d.spouseRMD))</td></tr>"
            totalAmt += d.spouseRMD
        }
        if d.inheritedIRARMDTotal > 0 {
            rows += "<tr><td>Inherited IRA RMD</td>"
            if showOwner { rows += "<td></td>" }
            rows += "<td class=\"amt orange\">\(fmt(d.inheritedIRARMDTotal))</td></tr>"
            totalAmt += d.inheritedIRARMDTotal
        }

        let cols = showOwner ? 2 : 1
        let foot = "<tr class=\"total\"><td colspan=\"\(cols)\">Total</td><td class=\"amt\">\(fmt(totalAmt))</td></tr>"

        return "<h2>Income Sources</h2><table>\(header)\(rows)\(foot)</table>"
    }

    // MARK: - Section: Scenario Decisions

    private static func sectionScenarioDecisions(_ d: PDFExportData) -> String {
        guard d.hasActiveScenario else { return "" }

        var rows = ""
        if d.scenarioTotalRothConversion > 0 {
            if d.enableSpouse {
                if d.yourRothConversion > 0 { rows += kvRow("Your Roth Conversion", fmt(d.yourRothConversion), cls: "purple") }
                if d.spouseRothConversion > 0 {
                    let sp = d.spouseName.isEmpty ? "Spouse" : esc(d.spouseName)
                    rows += kvRow("\(sp)'s Roth Conversion", fmt(d.spouseRothConversion), cls: "purple")
                }
            } else {
                rows += kvRow("Roth Conversion", fmt(d.scenarioTotalRothConversion), cls: "purple")
            }
        }
        if d.scenarioTotalExtraWithdrawal > 0 {
            rows += kvRow("Extra Withdrawals", fmt(d.scenarioTotalExtraWithdrawal), cls: "blue")
        }
        if d.scenarioTotalQCD > 0 {
            rows += kvRow("Qualified Charitable Distribution (QCD)", fmt(d.scenarioTotalQCD), cls: "green")
        }
        if d.stockDonationEnabled && d.stockCurrentValue > 0 {
            rows += kvRow("Appreciated Stock Donation", fmt(d.stockCurrentValue), cls: "orange")
            if d.scenarioStockGainAvoided > 0 {
                rows += kvRow("  Unrealized Gain Avoided", fmt(d.scenarioStockGainAvoided), cls: "muted")
            }
        }
        if d.cashDonationAmount > 0 {
            rows += kvRow("Cash Donation", fmt(d.cashDonationAmount), cls: "green")
        }
        if d.scenarioTotalCharitable > 0 {
            rows += "<tr class=\"total\"><td>Total Charitable Giving</td><td class=\"amt\">\(fmt(d.scenarioTotalCharitable))</td></tr>"
        }
        rows += kvRow("Deduction Method", d.scenarioEffectiveItemize ? "Itemized" : "Standard")

        return "<h2>Scenario Decisions</h2><table class=\"kv\">\(rows)</table>"
    }

    // MARK: - Section: Deductions

    private static func sectionDeductions(_ d: PDFExportData) -> String {
        // Section 1 shows base-case deductions only (no charitable from scenario decisions).
        // Charitable giving (QCDs, stock donations, cash gifts) appears in Sections 2 & 3.
        let baseItemize = d.baseItemizedDeductions > d.standardDeductionAmount
        let baseEffectiveDeduction = max(d.baseItemizedDeductions, d.standardDeductionAmount)

        var rows = ""
        // Standard deduction
        rows += kvRow("Standard Deduction", fmt(d.standardDeductionAmount), cls: baseItemize ? "" : "green")
        if !baseItemize {
            rows += "<tr><td colspan=\"2\" class=\"muted\">&nbsp;&nbsp;&#10003; Using standard deduction (higher)</td></tr>"
        }

        // Itemized breakdown (base case only — no charitable scenario items)
        rows += "<tr><td colspan=\"2\" style=\"padding-top:8px;\"><strong>Itemized Deduction Breakdown</strong></td></tr>"
        if d.saltAfterCap > 0 {
            let capNote = d.totalSALTBeforeCap > d.saltAfterCap ? " (capped)" : ""
            rows += kvRow("  SALT\(capNote)", fmt(d.saltAfterCap))
            if d.autoEstimatedStatePayments > 0 {
                rows += "<tr><td style=\"font-size:10px; color:#16a34a;\">&nbsp;&nbsp;&nbsp;&nbsp;Includes est. state payments (auto): \(fmt(d.autoEstimatedStatePayments))</td><td></td></tr>"
            }
        }
        if d.deductibleMedicalExpenses > 0 {
            rows += kvRow("  Medical (after 7.5% AGI floor)", fmt(d.deductibleMedicalExpenses))
        }
        for item in d.deductionItems where item.type == .mortgageInterest {
            rows += kvRow("  Mortgage Interest", fmt(item.annualAmount))
        }
        for item in d.deductionItems where item.type == .other {
            rows += kvRow("  \(esc(item.name))", fmt(item.annualAmount))
        }
        rows += "<tr class=\"total\"><td>Total Itemized</td><td class=\"amt\">\(fmt(d.baseItemizedDeductions))</td></tr>"
        if baseItemize {
            rows += "<tr><td colspan=\"2\" class=\"muted\">&nbsp;&nbsp;&#10003; Using itemized deduction (higher)</td></tr>"
        }

        rows += "<tr class=\"total\"><td><strong>Effective Deduction</strong></td><td class=\"amt\"><strong>\(fmt(baseEffectiveDeduction))</strong></td></tr>"

        return "<h2>Deductions</h2><table class=\"kv\">\(rows)</table>"
    }

    // MARK: - Section: What You Owe (merged withholding + remaining + quarterly)

    private static func sectionWhatYouOwe(_ d: PDFExportData) -> String {
        var html = "<h2>What You Owe</h2>"

        // Withholding & remaining tax
        var rows = ""
        rows += kvRow("Total Tax", fmt(d.scenarioTotalTax), cls: "red")
        if d.totalWithholding > 0 {
            rows += kvRow("Less: Withholding", "−\(fmt(d.totalWithholding))", cls: "green")
        }
        rows += "<tr class=\"total\"><td><strong>Remaining Tax Due</strong></td><td class=\"amt\"><strong>\(fmt(d.scenarioRemainingTax))</strong></td></tr>"
        html += "<table class=\"kv\">\(rows)</table>"

        // Quarterly estimated payments (inline)
        let qp = d.scenarioQuarterlyPayments
        if qp.total > 0 {
            let dueDates = ["April 15", "June 15", "September 15", "January 15"]
            let currentPayments = d.quarterlyPayments.filter { $0.year == d.currentYear }.sorted { $0.quarter < $1.quarter }

            let header = "<tr><th>Quarter</th><th>Due Date</th><th class=\"amt\">Federal</th><th class=\"amt\">State</th><th class=\"amt\">Total</th><th>Status</th></tr>"
            var qRows = ""
            for q in 1...4 {
                let fed = qp.federal[q]
                let state = qp.state[q]
                let total = qp[q]
                let dueYear = q == 4 ? d.currentYear + 1 : d.currentYear
                let paid = currentPayments.first { $0.quarter == q }
                let status: String
                if let p = paid, p.isPaid {
                    status = "<span class=\"green\">Paid \(fmt(p.paidAmount))</span>"
                } else {
                    status = "<span class=\"muted\">Not Paid</span>"
                }
                qRows += "<tr><td>Q\(q)</td><td>\(dueDates[q-1]), \(dueYear)</td>"
                qRows += "<td class=\"amt\">\(fmt(fed))</td><td class=\"amt\">\(fmt(state))</td>"
                qRows += "<td class=\"amt\">\(fmt(total))</td><td>\(status)</td></tr>"
            }
            var foot = "<tr class=\"total\"><td colspan=\"2\">Annual Total</td>"
            foot += "<td class=\"amt\">\(fmt(qp.federalTotal))</td><td class=\"amt\">\(fmt(qp.stateTotal))</td>"
            foot += "<td class=\"amt\">\(fmt(qp.total))</td><td></td></tr>"

            html += "<p style=\"margin:12px 0 4px 0; font-size:11px; color:#1e40af; font-weight:600;\">Quarterly Estimated Payments</p>"
            html += "<table>\(header)\(qRows)\(foot)</table>"
            var safeHarborNote = "Based on \(d.safeHarborMethod.label) safe harbor rule."
            if d.stateEstimatedSchedule != .federal {
                safeHarborNote += " \(d.selectedStateName) payments use the required \(d.stateEstimatedSchedule.label) quarterly schedule."
            }
            safeHarborNote += " Withholding from income sources has been credited."
            html += "<p class=\"muted\">\(safeHarborNote)</p>"
        }

        return html
    }

    // MARK: - Section: IRMAA

    private static func sectionIRMAA(_ d: PDFExportData) -> String {
        guard d.medicareMemberCount > 0 else { return "" }
        let irmaa = d.scenarioIRMAA
        var rows = ""
        rows += kvRow("IRMAA Tier", "\(irmaa.tier)")
        rows += kvRow("Monthly Part B Premium", fmt(irmaa.monthlyPartB))
        rows += kvRow("Monthly Part D Surcharge", fmt(irmaa.monthlyPartD))
        rows += kvRow("Annual Surcharge (per person)", fmt(irmaa.annualSurchargePerPerson), cls: irmaa.tier > 0 ? "red" : "green")
        if d.medicareMemberCount > 1 {
            rows += kvRow("Medicare Members", "\(d.medicareMemberCount)")
            rows += kvRow("Household Annual Surcharge", fmt(d.scenarioIRMAATotalSurcharge), cls: "red")
        }
        if let dist = irmaa.distanceToNextTier {
            rows += kvRow("Distance to Next Tier", fmt(dist), cls: "orange")
        }
        if let dist = irmaa.distanceToPreviousTier {
            rows += kvRow("Above Current Tier Threshold", fmt(dist), cls: "blue")
        }
        rows += kvRow("MAGI for IRMAA", fmt(irmaa.magi))

        return "<h2>IRMAA (Medicare Premium Surcharge)</h2><table class=\"kv\">\(rows)</table>"
    }

    // MARK: - Section: NIIT

    private static func sectionNIIT(_ d: PDFExportData) -> String {
        guard d.scenarioNetInvestmentIncome > 0 else { return "" }
        let niit = d.scenarioNIIT
        var rows = ""
        rows += kvRow("Net Investment Income", fmt(niit.netInvestmentIncome))
        rows += kvRow("MAGI", fmt(niit.magi))
        rows += kvRow("Threshold (\(d.filingStatus.rawValue))", fmt(niit.threshold))
        if niit.annualNIITax > 0 {
            rows += kvRow("MAGI Excess Over Threshold", fmt(niit.magiExcess), cls: "red")
            rows += kvRow("Taxable NII", fmt(niit.taxableNII))
            rows += "<tr class=\"total\"><td class=\"red\">NIIT (3.8%)</td><td class=\"amt red\">\(fmt(niit.annualNIITax))</td></tr>"
        } else {
            rows += kvRow("Distance Below Threshold", fmt(niit.distanceToThreshold), cls: "green")
            rows += "<tr><td colspan=\"2\" class=\"muted\">&#10003; Below NIIT threshold — no surtax</td></tr>"
        }

        return "<h2>NIIT (3.8% Net Investment Income Tax)</h2><table class=\"kv\">\(rows)</table>"
    }

    // MARK: - Section: Appendix (page break + accounts + action items)

    private static func sectionAppendix(_ d: PDFExportData) -> String {
        let hasAccounts = !d.iraAccounts.isEmpty
        let hasActions = !d.actionItems.isEmpty
        guard hasAccounts || hasActions else { return "" }

        var html = "<p style=\"font-size:1px;line-height:1px;margin:0;padding:0;color:white;\">PAGEBRK</p>"
        html += "<h2 class=\"section-start\" style=\"font-size:14px; margin-top:0;\">Appendix — Reference</h2>"
        html += sectionAccounts(d)
        html += sectionActionItems(d)
        return html
    }

    // MARK: - Section: Account Balances

    private static func sectionAccounts(_ d: PDFExportData) -> String {
        guard !d.iraAccounts.isEmpty else {
            return "<h2>Retirement Account Balances</h2><p class=\"muted\">No accounts entered.</p>"
        }
        let showOwner = d.enableSpouse
        var header = "<tr><th>Account</th><th>Type</th>"
        if showOwner { header += "<th>Owner</th>" }
        header += "<th class=\"amt\">Balance</th></tr>"

        var rows = ""
        for a in d.iraAccounts {
            rows += "<tr><td>\(esc(a.name))</td><td>\(a.accountType.rawValue)</td>"
            if showOwner { rows += "<td>\(a.owner.rawValue)</td>" }
            rows += "<td class=\"amt\">\(fmt(a.balance))</td></tr>"
        }

        // Category subtotals
        let traditionalTotal = d.primaryTraditionalIRABalance + d.spouseTraditionalIRABalance
        let rothTotal = d.primaryRothBalance + d.spouseRothBalance
        let cols = showOwner ? 3 : 2
        if traditionalTotal > 0 {
            rows += "<tr class=\"total\"><td colspan=\"\(cols)\">Traditional IRA/401(k)</td><td class=\"amt\">\(fmt(traditionalTotal))</td></tr>"
        }
        if rothTotal > 0 {
            rows += "<tr class=\"total\"><td colspan=\"\(cols)\">Roth IRA/401(k)</td><td class=\"amt\">\(fmt(rothTotal))</td></tr>"
        }
        if d.totalInheritedBalance > 0 {
            rows += "<tr class=\"total\"><td colspan=\"\(cols)\">Inherited IRA</td><td class=\"amt\">\(fmt(d.totalInheritedBalance))</td></tr>"
        }

        return "<h2>Retirement Account Balances</h2><table>\(header)\(rows)</table>"
    }

    // MARK: - Section: Action Items

    private static func sectionActionItems(_ d: PDFExportData) -> String {
        guard !d.actionItems.isEmpty else { return "" }
        var rows = ""
        for item in d.actionItems {
            let done = d.completedActionKeys.contains(item.id)
            let check = done ? "<span class=\"check\">&#9745;</span>" : "<span class=\"uncheck\">&#9744;</span>"
            let style = done ? "text-decoration: line-through; color: #9ca3af;" : ""
            rows += "<tr><td style=\"width:24px;\">\(check)</td>"
            rows += "<td style=\"\(style)\">\(esc(item.title))<br><span class=\"muted\">\(esc(item.detail))</span></td>"
            rows += "<td class=\"amt\" style=\"\(style)\">\(esc(item.deadline))</td></tr>"
        }
        let completed = d.actionItems.filter { d.completedActionKeys.contains($0.id) }.count
        let total = d.actionItems.count

        return "<h2>Action Items (\(completed)/\(total) completed)</h2><table>\(rows)</table>"
    }

    // MARK: - KV Row Helper

    private static func kvRow(_ label: String, _ value: String, cls: String = "") -> String {
        let valClass = cls.isEmpty ? "amt" : "amt \(cls)"
        return "<tr><td>\(label)</td><td class=\"\(valClass)\">\(value)</td></tr>"
    }

}

// MARK: - WKWebView PDF Renderer (iOS only)

#if canImport(UIKit)
/// Loads HTML into an offscreen WKWebView and generates a multi-page PDF
/// using UIKit's viewPrintFormatter + UIPrintPageRenderer, which properly
/// respects CSS page-break directives and produces paginated output.
/// macOS uses the NSLayoutManager-based renderer in PDFExportService instead.
private class WebViewPDFRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private let completion: (Data) -> Void

    init(completion: @escaping (Data) -> Void) {
        self.completion = completion
        super.init()
    }

    func load(html: String) {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func finish(with data: Data) {
        webView?.navigationDelegate = nil
        webView = nil
        completion(data)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printableRect = pageRect.insetBy(dx: 54, dy: 54)

        let formatter = webView.viewPrintFormatter()

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)
        }
        UIGraphicsEndPDFContext()
        finish(with: pdfData as Data)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: Data())
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(with: Data())
    }
}
#endif

// MARK: - Share Sheet (iOS) / Save Panel (macOS)

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let pdfData: Data
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? pdfData.write(to: tempURL)
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif canImport(AppKit)
import AppKit

/// Writes the PDF to a temp file and opens it in Preview (no sandbox entitlement needed).
struct MacPDFExporter {
    static func save(pdfData: Data, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
        } catch {
            // Fallback: show in Finder
            NSWorkspace.shared.activateFileViewerSelecting([tempURL])
        }
    }
}
#endif

