import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 0 — NIIT in the multi-year engine", .serialized)
@MainActor
struct NIITMultiYearTests {

    @Test("TaxBreakdown.total includes niit")
    func totalIncludesNIIT() {
        let b = TaxBreakdown(federal: 1_000, state: 200, irmaa: 300, acaPremiumImpact: 0, niit: 380)
        #expect(b.total == 1_880)
    }

    @Test("TaxBreakdown niit defaults to zero and zero-value has niit 0")
    func niitDefaultsZero() {
        let b = TaxBreakdown(federal: 1_000, state: 0, irmaa: 0, acaPremiumImpact: 0)
        #expect(b.niit == 0)
        #expect(b.total == 1_000)
        #expect(TaxBreakdown.zero.niit == 0)
    }

    @Test("TaxBreakdown decodes legacy JSON without a niit key as niit == 0")
    func decodesLegacyWithoutNIIT() throws {
        let legacy = #"{"federal":1000,"state":0,"irmaa":0,"acaPremiumImpact":0}"#
        let decoded = try JSONDecoder().decode(TaxBreakdown.self, from: Data(legacy.utf8))
        #expect(decoded.niit == 0)
        #expect(decoded.total == 1_000)
    }

    @Test("Adapter NII helper sums only NIIT-qualifying investment types")
    func adapterNIIHelperAllowlist() {
        // owner defaults to .primary on IncomeSource (same construction the single-year tests use)
        let sources: [IncomeSource] = [
            IncomeSource(name: "Interest",        type: .interest,           annualAmount: 5_000),
            IncomeSource(name: "Ord Dividends",   type: .dividends,          annualAmount: 3_000),
            IncomeSource(name: "Qual Dividends",  type: .qualifiedDividends, annualAmount: 4_000),
            IncomeSource(name: "LT Gains",        type: .capitalGainsLong,   annualAmount: 6_000),
            IncomeSource(name: "ST Gains",        type: .capitalGainsShort,  annualAmount: 2_000),
            IncomeSource(name: "State Refund",    type: .stateTaxRefund,     annualAmount: 1_000), // NOT NII
            IncomeSource(name: "Pension",         type: .pension,            annualAmount: 30_000) // NOT NII
        ]
        let nii = MultiYearInputAdapter.primaryNetInvestmentIncome(from: sources)
        #expect(nii == 20_000) // 5000+3000+4000+6000+2000; excludes state refund + pension
    }

    @Test("Adapter NII helper returns 0 for spouse when spouse disabled")
    func adapterNIISpouseDisabled() {
        let sources = [IncomeSource(name: "Interest", type: .interest, annualAmount: 5_000)]
        #expect(MultiYearInputAdapter.spouseNetInvestmentIncome(from: sources, enableSpouse: false) == 0)
    }
}
