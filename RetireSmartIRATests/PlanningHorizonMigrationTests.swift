import XCTest
@testable import RetireSmartIRA

final class PlanningHorizonMigrationTests: XCTestCase {
    func test_newUser_defaultsTo95_97() {
        let p = SSWhatIfParameters()
        XCTAssertEqual(p.primaryLifeExpectancy, 95)
        XCTAssertEqual(p.spouseLifeExpectancy, 97)
    }

    func test_existingUser_keepsOldValue() throws {
        // Simulate decoding a record that was persisted under the old 85/87 default.
        let oldJSON = """
        {"primaryLifeExpectancy":85,"spouseLifeExpectancy":87,"colaRate":2.5,"discountRate":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SSWhatIfParameters.self, from: oldJSON)
        XCTAssertEqual(decoded.primaryLifeExpectancy, 85)
        XCTAssertEqual(decoded.spouseLifeExpectancy, 87)
    }

    func test_explicitInit_values_arePreserved() {
        let p = SSWhatIfParameters(primaryLifeExpectancy: 88, spouseLifeExpectancy: 90)
        XCTAssertEqual(p.primaryLifeExpectancy, 88)
        XCTAssertEqual(p.spouseLifeExpectancy, 90)
    }
}
