import XCTest
@testable import RetireSmartIRA

final class MultiYearTypesTests: XCTestCase {

    // MARK: WithdrawalOrderingRule

    func test_WithdrawalOrderingRule_hasFourCases() {
        XCTAssertEqual(WithdrawalOrderingRule.allCases.count, 4)
    }

    func test_WithdrawalOrderingRule_codableRoundTrip() throws {
        for rule in WithdrawalOrderingRule.allCases {
            let data = try JSONEncoder().encode(rule)
            let decoded = try JSONDecoder().decode(WithdrawalOrderingRule.self, from: data)
            XCTAssertEqual(decoded, rule)
        }
    }

    func test_WithdrawalOrderingRule_defaultIsTaxEfficient() {
        XCTAssertEqual(WithdrawalOrderingRule.default, .taxEfficient)
    }

    func test_WithdrawalOrderingRule_rawValues() {
        XCTAssertEqual(WithdrawalOrderingRule.taxEfficient.rawValue, "tax_efficient")
        XCTAssertEqual(WithdrawalOrderingRule.depleteTradFirst.rawValue, "deplete_trad_first")
        XCTAssertEqual(WithdrawalOrderingRule.preserveRoth.rawValue, "preserve_roth")
        XCTAssertEqual(WithdrawalOrderingRule.proportional.rawValue, "proportional")
    }

    // MARK: LeverAction

    func test_LeverAction_rothConversion_storesAmount() {
        let action = LeverAction.rothConversion(amount: 50_000)
        if case .rothConversion(let amount) = action {
            XCTAssertEqual(amount, 50_000, accuracy: 0.01)
        } else {
            XCTFail("Expected .rothConversion")
        }
    }

    func test_LeverAction_codableRoundTrip_allCases() throws {
        let actions: [LeverAction] = [
            .rothConversion(amount: 50_000),
            .traditionalWithdrawal(amount: 80_000),
            .taxableWithdrawal(amount: 20_000),
            .rothWithdrawal(amount: 10_000),
            .hsaContribution(amount: 4_300),
            .fourOhOneKContribution(amount: 23_000),
            .deferSocialSecurity,
            .claimSocialSecurity(spouse: .primary),
            .claimSocialSecurity(spouse: .spouse)
        ]
        let data = try JSONEncoder().encode(actions)
        let decoded = try JSONDecoder().decode([LeverAction].self, from: data)
        XCTAssertEqual(decoded, actions)
    }

    func test_LeverAction_equality_distinguishesAmounts() {
        XCTAssertNotEqual(
            LeverAction.rothConversion(amount: 50_000),
            LeverAction.rothConversion(amount: 60_000)
        )
    }

    func test_LeverAction_equality_distinguishesSpouses() {
        XCTAssertNotEqual(
            LeverAction.claimSocialSecurity(spouse: .primary),
            LeverAction.claimSocialSecurity(spouse: .spouse)
        )
    }

    // MARK: ConstraintType

    func test_ConstraintType_irmaaTier_storesLevel() {
        let type = ConstraintType.irmaaTier(level: 2)
        if case .irmaaTier(let level) = type {
            XCTAssertEqual(level, 2)
        } else {
            XCTFail("Expected .irmaaTier")
        }
    }

    func test_ConstraintType_bracketOverrun_storesBothBrackets() {
        let type = ConstraintType.bracketOverrun(fromBracket: 12, toBracket: 22)
        if case .bracketOverrun(let from, let to) = type {
            XCTAssertEqual(from, 12)
            XCTAssertEqual(to, 22)
        } else {
            XCTFail("Expected .bracketOverrun")
        }
    }

    func test_ConstraintType_codableRoundTrip_allVariants() throws {
        let types: [ConstraintType] = [
            .irmaaTier(level: 1),
            .irmaaTier(level: 5),
            .acaCliff,
            .bracketOverrun(fromBracket: 12, toBracket: 22),
            .bracketOverrun(fromBracket: 22, toBracket: 24)
        ]
        let data = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([ConstraintType].self, from: data)
        XCTAssertEqual(decoded, types)
    }

    func test_ConstraintType_acaCliff_hasNoAssociatedValue() {
        XCTAssertEqual(ConstraintType.acaCliff, ConstraintType.acaCliff)
    }
}
